-- ============================================================
--  NexusAdmin | sh_utils.lua
--  Gemeinsame Hilfsfunktionen für Server und Client.
--
--  Targeting-Schlüsselwörter:
--    ^        → sich selbst (caller)
--    *        → alle Spieler (gibt Tabelle zurück)
--    @        → Spieler den man gerade anschaut (Trace)
--    <name>   → partieller Namensabgleich (case-insensitiv)
--    <id>     → UserID oder SteamID64 (exakt)
-- ============================================================

-- ── Einzelnen Spieler suchen ─────────────────────────────────
-- Gibt einen einzelnen Player zurück, oder nil.
-- Schlüsselwörter ^ und @ werden hier aufgelöst.
-- Für * muss NexusAdmin.ResolveTargets verwendet werden.
--
-- @param nameOrId  string  – Suchbegriff oder Schlüsselwort
-- @param caller    Player  – Aufrufender (für ^ und @)
-- @return          Player|nil
function NexusAdmin.FindPlayer(nameOrId, caller)
    if not nameOrId then return nil end

    -- ── Schlüsselwort: ^ = sich selbst ───────────────────────
    if nameOrId == "^" then
        return IsValid(caller) and caller or nil
    end

    -- ── Schlüsselwort: @ = angeschauter Spieler ──────────────
    -- Wirft einen Trace-Ray von der Augen-Position des Callers.
    if nameOrId == "@" then
        if not IsValid(caller) then return nil end

        local traceData = util.TraceLine({
            start  = caller:EyePos(),
            endpos = caller:EyePos() + caller:GetAimVector() * 4096,
            filter = caller,
        })

        if IsValid(traceData.Entity) and traceData.Entity:IsPlayer() then
            return traceData.Entity
        end
        return nil
    end

    -- ── Exakte Suche: SteamID64 oder UserID ──────────────────
    local byId = player.GetBySteamID64(nameOrId)
        or player.GetByID(tonumber(nameOrId) or 0)
    if IsValid(byId) then return byId end

    -- ── Partieller Namensabgleich (case-insensitiv) ───────────
    local matches = {}
    local search  = nameOrId:lower()

    for _, ply in ipairs(player.GetAll()) do
        if ply:Nick():lower():find(search, 1, true) then
            table.insert(matches, ply)
        end
    end

    -- Mehrdeutiger Name = kein Ergebnis (verhindert Fehlaktionen)
    if #matches == 1 then return matches[1] end
    return nil
end

-- ── Mehrere Ziele auflösen ───────────────────────────────────
-- Gibt immer eine Tabelle von Spielern zurück.
-- Versteht zusätzlich * = alle Spieler.
--
-- @param nameOrId  string  – Suchbegriff oder Schlüsselwort
-- @param caller    Player  – Aufrufender
-- @return          table   – Liste von Player-Objekten (kann leer sein)
function NexusAdmin.ResolveTargets(nameOrId, caller)
    if not nameOrId then return {} end

    -- ── Schlüsselwort: * = alle Spieler ──────────────────────
    if nameOrId == "*" then
        local all = {}
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                table.insert(all, ply)
            end
        end
        return all
    end

    -- Alle anderen Fälle → einzelnen Spieler suchen
    local single = NexusAdmin.FindPlayer(nameOrId, caller)
    return single and { single } or {}
end

-- ── Immunität prüfen ─────────────────────────────────────────
-- Verhindert, dass ein Admin Befehle gegen gleichrangige oder
-- höherrangige Spieler ausführt.
--
-- Gibt true zurück wenn caller eine Aktion gegen target ausführen darf.
-- Gibt false zurück wenn target immun gegen caller ist.
--
-- @param caller    Player  – Ausführender Admin
-- @param target    Player  – Ziel des Befehls
-- @return          boolean
function NexusAdmin.CanTarget(caller, target)
    if not IsValid(caller) or not IsValid(target) then return false end

    -- Ein Spieler kann immer Befehle gegen sich selbst ausführen
    -- (z.B. !vitalize ^ 100)
    if caller == target then return true end

    local callerRankId = caller:GetNWString("na_rank", "user")
    local targetRankId = target:GetNWString("na_rank", "user")

    local callerLevel  = NexusAdmin.GetRankLevel(callerRankId)
    local targetLevel  = NexusAdmin.GetRankLevel(targetRankId)

    -- Caller muss einen höheren Level haben als das Ziel.
    -- Gleicher Level = immun (verhindert Admin-vs-Admin Missbrauch).
    return callerLevel > targetLevel
end

-- ── Rang-Level abrufen ───────────────────────────────────────
-- Gibt den numerischen Level eines Rangs zurück (aus sh_ranks.lua).
-- Fallback: 0 (niedrigster Level).
function NexusAdmin.GetRankLevel(rankId)
    local rank = NexusAdmin.Ranks[rankId]
    return rank and (rank.level or 0) or 0
end

-- ── Zeitstempel ──────────────────────────────────────────────
function NexusAdmin.Timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- ── Logging ──────────────────────────────────────────────────
-- Schreibt eine formatierte Nachricht in die Server-Konsole
-- und optional in eine Log-Datei (data/nexusadmin/admin.log).
--
-- @param message   string  – Log-Nachricht
-- @param category  string  – Kategorie (optional, z.B. "CMD", "DB", "AUTH")
function NexusAdmin.Log(message, category)
    if not SERVER then return end
    if not NexusAdmin.Config.LogCommands then return end

    category = category or "INFO"
    local line = string.format("[NexusAdmin | %s | %s] %s",
        NexusAdmin.Timestamp(), category, message)

    -- Konsolen-Ausgabe immer
    print(line)

    -- Datei-Logging wenn aktiviert
    if NexusAdmin.Config.LogToFile then
        NexusAdmin.WriteLog(line)
    end
end

-- ── Log-Datei schreiben ──────────────────────────────────────
-- Hängt eine Zeile an data/nexusadmin/admin.log an.
-- Der Ordner wird automatisch angelegt falls er fehlt.
do
    local LOG_DIR  = "nexusadmin"
    local LOG_FILE = "nexusadmin/admin.log"

    function NexusAdmin.WriteLog(line)
        -- Ordner anlegen falls nicht vorhanden (nur einmal)
        if not file.IsDir(LOG_DIR, "DATA") then
            file.CreateDir(LOG_DIR)
        end

        -- Im Append-Modus schreiben (hängt an bestehende Datei an)
        local existing = file.Read(LOG_FILE, "DATA") or ""
        file.Write(LOG_FILE, existing .. line .. "\n")
    end
end

-- ── Hilfsfunktion: Spielerliste als lesbaren String ──────────
-- Gibt "Spieler1, Spieler2, ..." zurück (für Log-Nachrichten).
function NexusAdmin.TargetListStr(targets)
    local names = {}
    for _, ply in ipairs(targets) do
        if IsValid(ply) then
            table.insert(names, ply:Nick())
        end
    end
    return #names > 0 and table.concat(names, ", ") or "(niemand)"
end
