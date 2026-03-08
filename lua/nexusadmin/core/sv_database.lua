-- ============================================================
--  NexusAdmin | sv_database.lua
--  SQLite-Persistenz für Spieler-Ränge und Ausschlüsse.
--  Nutzt Garmods eingebaute sql-Bibliothek (sv.db).
--
--  Tabellen:
--    nexusadmin_players    – Spieler-Ränge
--    nexusadmin_exclusions – Server-Ausschlüsse (Bans)
--    nexusadmin_warnings   – Verwarnungs-Historie
-- ============================================================

NexusAdmin.DB = NexusAdmin.DB or {}

-- ── Initialisierung ──────────────────────────────────────────
-- Legt beide Tabellen an falls sie noch nicht existieren.
function NexusAdmin.DB.Init()
    -- Spieler-Ränge
    local q1 = sql.Query([[
        CREATE TABLE IF NOT EXISTS nexusadmin_players (
            steamid     TEXT    PRIMARY KEY NOT NULL,
            rank        TEXT    NOT NULL DEFAULT 'user',
            assigned_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            assigned_by TEXT    NOT NULL DEFAULT 'system'
        )
    ]])

    if q1 == false then
        ErrorNoHalt("[NexusAdmin] DB: Tabelle nexusadmin_players fehlgeschlagen: "
            .. sql.LastError() .. "\n")
        return false
    end

    -- Server-Ausschlüsse (Bans)
    -- expires_at = 0 bedeutet permanenter Ausschluss
    local q2 = sql.Query([[
        CREATE TABLE IF NOT EXISTS nexusadmin_exclusions (
            steamid     TEXT    PRIMARY KEY NOT NULL,
            reason      TEXT    NOT NULL DEFAULT 'Kein Grund angegeben',
            banned_by   TEXT    NOT NULL DEFAULT 'system',
            banned_at   INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            expires_at  INTEGER NOT NULL DEFAULT 0
        )
    ]])

    if q2 == false then
        ErrorNoHalt("[NexusAdmin] DB: Tabelle nexusadmin_exclusions fehlgeschlagen: "
            .. sql.LastError() .. "\n")
        return false
    end

    -- Verwarnungs-Historie
    -- is_active = 1 → zählt zum nächsten Auto-Bann
    -- is_active = 0 → historisch / nach Auto-Bann deaktiviert ("geblacklisted")
    -- id wird als INTEGER PRIMARY KEY automatisch zu einem ROWID-Alias → Auto-Increment
    local q3 = sql.Query([[
        CREATE TABLE IF NOT EXISTS nexusadmin_warnings (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            target_sid64  TEXT    NOT NULL,
            admin_sid64   TEXT    NOT NULL DEFAULT 'system',
            reason        TEXT    NOT NULL DEFAULT 'Kein Grund angegeben',
            timestamp     INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            is_active     INTEGER NOT NULL DEFAULT 1
        )
    ]])

    if q3 == false then
        ErrorNoHalt("[NexusAdmin] DB: Tabelle nexusadmin_warnings fehlgeschlagen: "
            .. sql.LastError() .. "\n")
        return false
    end

    -- Index für schnelle Abfragen nach SteamID + is_active
    -- Wird automatisch übersprungen wenn er bereits existiert.
    sql.Query([[
        CREATE INDEX IF NOT EXISTS idx_warnings_target
        ON nexusadmin_warnings (target_sid64, is_active)
    ]])

    print("[NexusAdmin] Datenbank bereit (players + exclusions + warnings).")
    return true
end

-- ════════════════════════════════════════════════════════════
--  SPIELER-RÄNGE
-- ════════════════════════════════════════════════════════════

-- Speichert oder aktualisiert den Rang eines Spielers (UPSERT).
-- sql.SQLStr() an jedem Eingabepunkt → kein SQL-Injection-Vektor.
function NexusAdmin.SavePlayerRank(ply, rankId, assignedBy)
    if not IsValid(ply) then
        ErrorNoHalt("[NexusAdmin] SavePlayerRank: Ungültiger Spieler.\n")
        return false
    end

    if not NexusAdmin.Ranks[rankId] then
        ErrorNoHalt("[NexusAdmin] SavePlayerRank: Unbekannter Rang '"
            .. tostring(rankId) .. "'.\n")
        return false
    end

    local safeSteamId    = sql.SQLStr(ply:SteamID64())
    local safeRank       = sql.SQLStr(rankId)
    local safeAssignedBy = sql.SQLStr(assignedBy or "system")

    local result = sql.Query(string.format([[
        INSERT OR REPLACE INTO nexusadmin_players
            (steamid, rank, assigned_at, assigned_by)
        VALUES
            (%s, %s, strftime('%%s','now'), %s)
    ]], safeSteamId, safeRank, safeAssignedBy))

    if result == false then
        ErrorNoHalt("[NexusAdmin] SavePlayerRank fehlgeschlagen für "
            .. ply:Nick() .. ": " .. sql.LastError() .. "\n")
        return false
    end

    NexusAdmin.Log(string.format("%s → Rang '%s' (von: %s)",
        ply:Nick(), rankId, assignedBy or "system"), "DB")
    return true
end

-- Liest den Rang eines Spielers aus der DB.
-- Gibt den Rang-String zurück, oder Config.DefaultRank als Fallback.
function NexusAdmin.LoadPlayerRank(ply)
    if not IsValid(ply) then return NexusAdmin.Config.DefaultRank end

    local result = sql.Query(string.format(
        "SELECT rank FROM nexusadmin_players WHERE steamid = %s LIMIT 1",
        sql.SQLStr(ply:SteamID64())
    ))

    if result == nil  then return NexusAdmin.Config.DefaultRank end
    if result == false then
        ErrorNoHalt("[NexusAdmin] LoadPlayerRank fehlgeschlagen für "
            .. ply:Nick() .. ": " .. sql.LastError() .. "\n")
        return NexusAdmin.Config.DefaultRank
    end

    local rankId = result[1].rank

    if not NexusAdmin.Ranks[rankId] then
        print("[NexusAdmin] Warnung: Unbekannter DB-Rang '"
            .. rankId .. "' für " .. ply:Nick()
            .. " → Fallback: " .. NexusAdmin.Config.DefaultRank)
        return NexusAdmin.Config.DefaultRank
    end

    return rankId
end

-- Alle gespeicherten Spieler zurückgeben (z.B. für UI).
function NexusAdmin.DB.GetAllPlayers()
    local result = sql.Query(
        "SELECT steamid, rank, assigned_at, assigned_by FROM nexusadmin_players"
    )
    return (result ~= false and result) or {}
end

-- ════════════════════════════════════════════════════════════
--  AUSSCHLÜSSE (BANS)
-- ════════════════════════════════════════════════════════════

-- Speichert einen neuen Ausschluss in der Datenbank.
-- Bei doppeltem Eintrag (REPLACE) wird der alte überschrieben.
--
-- @param steamId   string  – SteamID64 des Spielers
-- @param reason    string  – Ausschluss-Grund
-- @param bannedBy  string  – Nick des ausschließenden Admins
-- @param duration  number  – Dauer in Sekunden (0 = permanent)
-- @return          boolean – Erfolg
function NexusAdmin.DB.AddExclusion(steamId, reason, bannedBy, duration)
    if not steamId or steamId == "" then return false end

    -- expires_at berechnen: 0 = permanent, sonst jetzt + Dauer
    local expiresAt = (duration and duration > 0)
        and (os.time() + duration)
        or  0

    local result = sql.Query(string.format([[
        INSERT OR REPLACE INTO nexusadmin_exclusions
            (steamid, reason, banned_by, banned_at, expires_at)
        VALUES
            (%s, %s, %s, strftime('%%s','now'), %d)
    ]],
        sql.SQLStr(steamId),
        sql.SQLStr(reason  or "Kein Grund angegeben"),
        sql.SQLStr(bannedBy or "system"),
        expiresAt
    ))

    if result == false then
        ErrorNoHalt("[NexusAdmin] AddExclusion fehlgeschlagen: "
            .. sql.LastError() .. "\n")
        return false
    end

    NexusAdmin.Log(string.format("Ausschluss gespeichert: %s | Grund: %s | Dauer: %s | Von: %s",
        steamId,
        reason or "Kein Grund",
        duration and duration > 0 and (duration .. "s") or "permanent",
        bannedBy or "system"
    ), "DB")
    return true
end

-- Hebt einen Ausschluss auf (Unban / Pardon).
-- Löscht den Eintrag vollständig aus der Tabelle.
--
-- @param steamId   string  – SteamID64 des Spielers
-- @return          boolean – true wenn ein Eintrag gelöscht wurde
function NexusAdmin.DB.RemoveExclusion(steamId)
    if not steamId or steamId == "" then return false end

    local result = sql.Query(string.format(
        "DELETE FROM nexusadmin_exclusions WHERE steamid = %s",
        sql.SQLStr(steamId)
    ))

    if result == false then
        ErrorNoHalt("[NexusAdmin] RemoveExclusion fehlgeschlagen: "
            .. sql.LastError() .. "\n")
        return false
    end

    -- sql.AffectedRows() gibt zurück wie viele Zeilen betroffen waren
    local affected = sql.AffectedRows and sql.AffectedRows() or 1
    NexusAdmin.Log("Ausschluss aufgehoben: " .. steamId, "DB")
    return affected > 0
end

-- Prüft ob eine SteamID aktuell ausgeschlossen ist.
-- Berücksichtigt automatisch abgelaufene Ausschlüsse.
--
-- @param steamId   string  – SteamID64
-- @return          table|nil – Ausschluss-Datensatz oder nil
function NexusAdmin.DB.GetExclusion(steamId)
    if not steamId or steamId == "" then return nil end

    local result = sql.Query(string.format(
        "SELECT * FROM nexusadmin_exclusions WHERE steamid = %s LIMIT 1",
        sql.SQLStr(steamId)
    ))

    if not result or result == false then return nil end

    local entry = result[1]

    -- Prüfen ob der Ausschluss abgelaufen ist
    local expiresAt = tonumber(entry.expires_at) or 0
    if expiresAt > 0 and os.time() > expiresAt then
        -- Abgelaufenen Eintrag automatisch bereinigen
        NexusAdmin.DB.RemoveExclusion(steamId)
        return nil
    end

    return entry
end

-- Gibt alle aktiven Ausschlüsse zurück (für Admin-UI).
-- Filtert bereits abgelaufene Einträge heraus.
function NexusAdmin.DB.GetAllExclusions()
    local result = sql.Query(
        "SELECT * FROM nexusadmin_exclusions"
    )
    if not result or result == false then return {} end

    local active  = {}
    local now     = os.time()

    for _, entry in ipairs(result) do
        local expiresAt = tonumber(entry.expires_at) or 0
        -- 0 = permanent (nie ablaufend), oder noch nicht abgelaufen
        if expiresAt == 0 or now <= expiresAt then
            table.insert(active, entry)
        else
            -- Abgelaufene Einträge still bereinigen
            NexusAdmin.DB.RemoveExclusion(entry.steamid)
        end
    end

    return active
end

-- Ban-Check beim Join: Spieler mit aktivem Ausschluss sofort kicken.
hook.Add("CheckPassword", "NexusAdmin_ExclusionCheck",
    function(steamId64, _, _, _, name)
        local entry = NexusAdmin.DB.GetExclusion(steamId64)
        if not entry then return end  -- Nicht gebannt → normal joinen

        -- Ablaufzeit für die Kick-Nachricht berechnen
        local expiresAt = tonumber(entry.expires_at) or 0
        local timeStr   = expiresAt == 0
            and "Permanent"
            or  os.date("%d.%m.%Y %H:%M", expiresAt) .. " Uhr"

        local msg = string.format(
            "[NexusAdmin] Du bist vom Server ausgeschlossen.\nGrund: %s\nLäuft ab: %s",
            entry.reason, timeStr
        )

        NexusAdmin.Log(string.format(
            "Ausgeschlossener Spieler abgewiesen: %s (%s)", name, steamId64), "AUTH")

        -- false = ablehnen, Kick-Nachricht als zweiter Rückgabewert
        return false, msg
    end
)

-- ════════════════════════════════════════════════════════════
--  VERWARNUNGEN (WARNINGS)
-- ════════════════════════════════════════════════════════════

-- Fügt eine neue Verwarnung ein.
-- Gibt die neue Warn-ID zurück, oder nil bei Fehler.
--
-- @param targetSid64  string  – SteamID64 des Verwarnten
-- @param adminSid64   string  – SteamID64 des Admins (oder "system")
-- @param reason       string  – Verwarnungs-Grund
-- @return             number|nil – Neue Row-ID
function NexusAdmin.DB.AddWarning(targetSid64, adminSid64, reason)
    if not targetSid64 or targetSid64 == "" then return nil end

    local result = sql.Query(string.format([[
        INSERT INTO nexusadmin_warnings
            (target_sid64, admin_sid64, reason, timestamp, is_active)
        VALUES
            (%s, %s, %s, strftime('%%s','now'), 1)
    ]],
        sql.SQLStr(targetSid64),
        sql.SQLStr(adminSid64 or "system"),
        sql.SQLStr(reason or "Kein Grund angegeben")
    ))

    if result == false then
        ErrorNoHalt("[NexusAdmin] AddWarning fehlgeschlagen: "
            .. sql.LastError() .. "\n")
        return nil
    end

    -- Zuletzt eingefügte ROWID abrufen
    local idResult = sql.Query("SELECT last_insert_rowid() AS id")
    return idResult and tonumber(idResult[1].id) or nil
end

-- Gibt die Anzahl aktiver Verwarnungen einer SteamID zurück.
-- "Aktiv" = is_active = 1. Nur diese zählen für den Auto-Bann.
--
-- @param  targetSid64  string  – SteamID64
-- @return number               – Anzahl aktiver Warns (0 wenn keine)
function NexusAdmin.DB.GetActiveWarningCount(targetSid64)
    if not targetSid64 or targetSid64 == "" then return 0 end

    local result = sql.Query(string.format(
        "SELECT COUNT(*) AS cnt FROM nexusadmin_warnings WHERE target_sid64 = %s AND is_active = 1",
        sql.SQLStr(targetSid64)
    ))

    if not result or result == false then return 0 end
    return tonumber(result[1].cnt) or 0
end

-- Gibt alle Verwarnungen einer SteamID zurück (aktive + historische).
-- Sortiert nach Datum absteigend (neueste zuerst).
--
-- @param  targetSid64  string  – SteamID64
-- @return table                – Liste von Warn-Datensätzen
function NexusAdmin.DB.GetAllWarnings(targetSid64)
    if not targetSid64 or targetSid64 == "" then return {} end

    local result = sql.Query(string.format(
        "SELECT * FROM nexusadmin_warnings WHERE target_sid64 = %s ORDER BY timestamp DESC",
        sql.SQLStr(targetSid64)
    ))

    return (result ~= false and result) or {}
end

-- Deaktiviert alle aktiven Verwarnungen einer SteamID (Blacklisting).
-- Die Einträge bleiben für die Historien-Anzeige erhalten (is_active → 0).
-- Wird nach einem Auto-Bann aufgerufen damit der Zähler neu startet.
--
-- @param  targetSid64  string  – SteamID64
-- @return boolean              – Erfolg
function NexusAdmin.DB.DeactivateAllWarnings(targetSid64)
    if not targetSid64 or targetSid64 == "" then return false end

    local result = sql.Query(string.format(
        "UPDATE nexusadmin_warnings SET is_active = 0 WHERE target_sid64 = %s AND is_active = 1",
        sql.SQLStr(targetSid64)
    ))

    if result == false then
        ErrorNoHalt("[NexusAdmin] DeactivateAllWarnings fehlgeschlagen: "
            .. sql.LastError() .. "\n")
        return false
    end

    return true
end

-- Deaktiviert alle aktiven Verwarnungen via Player-Objekt (Kurzform).
-- Wrapper um DeactivateAllWarnings für Aufrufe mit isValidem Spieler.
function NexusAdmin.DB.ClearActiveWarnings(ply)
    if not IsValid(ply) then return false end
    return NexusAdmin.DB.DeactivateAllWarnings(ply:SteamID64())
end

-- Datenbank beim Laden des Moduls sofort initialisieren
NexusAdmin.DB.Init()
