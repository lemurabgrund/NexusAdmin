-- ============================================================
--  NexusAdmin | sv_warning_system.lua
--  Kern-Logik für das Verwarnungs-System.
--
--  Verantwortlichkeiten:
--    - Verwarnungen erstellen und in DB persistieren
--    - Aktiven Warn-Count per NWInt an alle Clients broadcasten
--    - Auto-Bann auslösen wenn Schwelle (Config.WarnThreshold) erreicht
--    - Nach Auto-Bann alle aktiven Warns "blacklisten" (is_active → 0)
--    - Warn-Count beim Join aus der DB wiederherstellen
--
--  Abhängigkeiten (müssen vorher geladen sein):
--    sh_config.lua, sv_database.lua, sv_networking.lua
-- ============================================================

-- Net-Message für Warn-Count Sync zum Client registrieren.
-- Jeder Client muss den aktuellen Warn-Count eines Spielers kennen
-- damit cl_playerlist.lua ihn neben dem Namen anzeigen kann.
util.AddNetworkString("NexusAdmin_SyncWarnCount")

-- ── Warn-Count NWInt ──────────────────────────────────────────
-- Der Warn-Count wird als NWInt "na_warns" auf dem Spieler gesetzt.
-- NWInt ist für alle Clients automatisch sichtbar ohne extra Net-Message,
-- wir broadcasten trotzdem explizit für Echtzeit-UI-Updates.

-- Intern: Aktualisiert NWInt und broadcastet die Änderung.
local function SyncWarnCount(target, count)
    if not IsValid(target) then return end

    target:SetNWInt("na_warns", count)

    -- Expliziter Broadcast: cl_networking.lua nimmt ihn entgegen
    -- und refresht die Playerlist wenn das Menü offen ist.
    net.Start("NexusAdmin_SyncWarnCount")
        net.WriteUInt(target:UserID(), 16)
        net.WriteUInt(math.Clamp(count, 0, 255), 8)
    net.Broadcast()
end

-- ── AddWarning ───────────────────────────────────────────────
-- Hauptfunktion. Legt eine Verwarnung an und triggert ggf. den Auto-Bann.
--
-- Rückgabe-Tabelle:
--   { success, warnId, newCount, autoBanned }
--   success    bool   – Eintrag in DB erfolgreich
--   warnId     number – ID des neuen Datensatzes
--   newCount   number – Neue Anzahl aktiver Warns
--   autoBanned bool   – Wurde sofort automatisch gebannt?
--
-- @param target   Player  – Zu verwarnender Spieler (muss online sein)
-- @param admin    Player  – Ausführender Admin
-- @param reason   string  – Verwarnungs-Grund
function NexusAdmin.AddWarning(target, admin, reason)
    -- ── Eingaben validieren ──────────────────────────────────
    if not IsValid(target) then
        return { success = false, error = "Ungültiger Ziel-Spieler" }
    end
    if not IsValid(admin) then
        return { success = false, error = "Ungültiger Admin" }
    end

    local targetSid = target:SteamID64()
    local adminSid  = admin:SteamID64()
    local safeReason = reason or "Kein Grund angegeben"

    -- ── Immunität: Admins können nur Spieler niedrigerer Rangstufe warnen
    if not NexusAdmin.CanTarget(admin, target) then
        return { success = false, error = target:Nick() .. " ist immun gegen Verwarnungen" }
    end

    -- ── Eintrag in Datenbank ──────────────────────────────────
    local warnId = NexusAdmin.DB.AddWarning(targetSid, adminSid, safeReason)

    if not warnId then
        return { success = false, error = "Datenbankfehler beim Speichern der Verwarnung" }
    end

    -- ── Neuen aktiven Warn-Count aus DB lesen ─────────────────
    -- Direkt nach dem INSERT aus DB lesen statt manuell hochzählen
    -- → Single Source of Truth, verhindert Race-Conditions
    local newCount = NexusAdmin.DB.GetActiveWarningCount(targetSid)

    -- ── NWInt + Broadcast aktualisieren ──────────────────────
    SyncWarnCount(target, newCount)

    -- ── Log: Neue Verwarnung ──────────────────────────────────
    NexusAdmin.Log(string.format(
        "WARN #%d: %s (%s) | Grund: %s | Von: %s | Aktive Warns: %d/%d",
        warnId,
        target:Nick(), targetSid,
        safeReason,
        admin:Nick(),
        newCount, NexusAdmin.Config.WarnThreshold
    ), "WARN")

    -- ── Auto-Bann prüfen ─────────────────────────────────────
    local autoBanned = false

    if newCount >= NexusAdmin.Config.WarnThreshold then
        autoBanned = NexusAdmin.TriggerAutoBan(target, admin, newCount)
    end

    return {
        success    = true,
        warnId     = warnId,
        newCount   = newCount,
        autoBanned = autoBanned,
    }
end

-- ── TriggerAutoBan ───────────────────────────────────────────
-- Wird intern aufgerufen wenn die Warn-Schwelle erreicht wurde.
-- Führt den Ban aus und deaktiviert alle aktiven Warns (Blacklisting).
-- Gibt true zurück wenn der Bann erfolgreich war.
--
-- @param target   Player  – Zu bannender Spieler
-- @param admin    Player  – Auslösender Admin (für den Bann-Eintrag)
-- @param count    number  – Aktuelle Warn-Anzahl (für Logging)
function NexusAdmin.TriggerAutoBan(target, admin, count)
    if not IsValid(target) then return false end

    local targetSid  = target:SteamID64()
    local targetNick = target:Nick()
    local duration   = NexusAdmin.Config.WarnAutoBanDuration
    local reason     = NexusAdmin.Config.WarnAutoBanReason

    -- 1. Alle aktiven Warns auf is_active = 0 setzen ("Blacklisting")
    --    Muss VOR dem Kick passieren damit die DB konsistent ist,
    --    auch wenn der Spieler in derselben Tick-Runde disconnected.
    NexusAdmin.DB.DeactivateAllWarnings(targetSid)

    -- 2. NWInt auf 0 zurücksetzen
    SyncWarnCount(target, 0)

    -- 3. Ban in nexusadmin_exclusions eintragen
    local banOk = NexusAdmin.DB.AddExclusion(
        targetSid,
        reason,
        "system (auto-ban nach " .. count .. " Verwarnungen)",
        duration
    )

    if not banOk then
        NexusAdmin.Log(
            "AUTO-BAN FEHLGESCHLAGEN für " .. targetNick .. " (" .. targetSid .. ")",
            "WARN"
        )
        return false
    end

    -- 4. Spieler mit Begründung vom Server entfernen
    local expiresStr = os.date("%d.%m.%Y %H:%M", os.time() + duration)
    target:Kick(string.format(
        "[NexusAdmin] Automatischer Ausschluss.\nGrund: %s\nLäuft ab: %s Uhr",
        reason, expiresStr
    ))

    -- 5. Alle Admins benachrichtigen
    NexusAdmin.NotifyAdmins(
        string.format("AUTO-BANN: %s hat %d Verwarnungen erreicht → %s gesperrt.",
            targetNick,
            count,
            NexusAdmin.Config.WarnAutoBanDuration == 0
                and "permanent"
                or  math.floor(NexusAdmin.Config.WarnAutoBanDuration / 86400) .. " Tage"
        ),
        Color(220, 60, 60)
    )

    NexusAdmin.Log(string.format(
        "AUTO-BAN: %s (%s) | Warns: %d | Dauer: %ds | Ausgelöst von: %s",
        targetNick, targetSid,
        count,
        duration,
        IsValid(admin) and admin:Nick() or "system"
    ), "WARN")

    return true
end

-- ── ClearWarnings ────────────────────────────────────────────
-- Deaktiviert alle aktiven Verwarnungen eines Spielers manuell.
-- Gibt die Anzahl der deaktivierten Warns zurück.
--
-- @param target   Player  – Spieler dessen Warns gelöscht werden
-- @param admin    Player  – Ausführender Admin (für Logging)
-- @return         number  – Anzahl deaktivierter Warns
function NexusAdmin.ClearWarnings(target, admin)
    if not IsValid(target) then return 0 end

    local targetSid = target:SteamID64()

    -- Count vor dem Deaktivieren merken
    local oldCount = NexusAdmin.DB.GetActiveWarningCount(targetSid)

    if oldCount == 0 then return 0 end

    NexusAdmin.DB.DeactivateAllWarnings(targetSid)
    SyncWarnCount(target, 0)

    NexusAdmin.Log(string.format(
        "WARNS GELÖSCHT: %s (%s) | %d aktive Warns deaktiviert | Von: %s",
        target:Nick(), targetSid,
        oldCount,
        IsValid(admin) and admin:Nick() or "system"
    ), "WARN")

    return oldCount
end

-- ── Warn-Count beim Join wiederherstellen ─────────────────────
-- Der NWInt geht beim Disconnect verloren.
-- Beim nächsten Join wird er aus der DB wiederhergestellt damit
-- die Spielerliste sofort den korrekten Count zeigt.
hook.Add("PlayerInitialSpawn", "NexusAdmin_RestoreWarnCount", function(ply)
    timer.Simple(1.5, function()
        if not IsValid(ply) then return end

        local count = NexusAdmin.DB.GetActiveWarningCount(ply:SteamID64())
        if count > 0 then
            SyncWarnCount(ply, count)
        end
    end)
end)
