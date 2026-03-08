-- ============================================================
--  NexusAdmin | sv_networking.lua
--  Server-seitiges Net-System:
--   - Rang-Sync beim Join und bei Rang-Änderungen
--   - NexusAdmin_Notify: UI-Benachrichtigungen an Clients
--   - NexusAdmin_RequestAllRanks: Client fordert alle Ränge an
-- ============================================================

-- Net-Message-Namen vorab registrieren (Pflicht in GMod)
util.AddNetworkString("NexusAdmin_Notify")
util.AddNetworkString("NexusAdmin_SyncRank")
util.AddNetworkString("NexusAdmin_SyncAllRanks")
util.AddNetworkString("NexusAdmin_RequestAllRanks")

-- ── Zentraler Rang-Setter ────────────────────────────────────
-- Setzt den Rang eines Spielers lokal (NW-String) UND in der DB,
-- und broadcastet die Änderung an alle Clients.
-- Alle Rang-Änderungen im System laufen über diese Funktion.
--
-- @param target     Player  – Ziel-Spieler
-- @param rankId     string  – Neuer Rang (z.B. "admin")
-- @param assignedBy string  – Nick des zuweisenden Admins
function NexusAdmin.SetPlayerRank(target, rankId, assignedBy)
    if not IsValid(target) then return false end
    if not NexusAdmin.Ranks[rankId]  then return false end

    -- 1. Rang im NW-String setzen → UI aller Clients aktualisiert sich sofort
    target:SetNWString("na_rank", rankId)

    -- 2. Persistenz: In Datenbank schreiben
    NexusAdmin.SavePlayerRank(target, rankId, assignedBy)

    -- 3. Broadcast: Alle Clients über die Änderung informieren,
    --    damit cl_playerlist.lua den neuen Rang sofort darstellt.
    net.Start("NexusAdmin_SyncRank")
        net.WriteUInt(target:UserID(), 16)  -- UserID statt Entity-Index (stabiler)
        net.WriteString(rankId)
    net.Broadcast()

    return true
end

-- ── Spieler joint dem Server ─────────────────────────────────
hook.Add("PlayerInitialSpawn", "NexusAdmin_LoadRankOnJoin", function(ply)
    -- Kurze Verzögerung: Sicherstellen dass der Spieler vollständig
    -- initialisiert ist, bevor Net-Messages gesendet werden.
    timer.Simple(1, function()
        if not IsValid(ply) then return end

        -- Rang aus Datenbank laden und setzen
        local rankId = NexusAdmin.LoadPlayerRank(ply)
        NexusAdmin.SetPlayerRank(ply, rankId, "system")

        -- Willkommens-Benachrichtigung an den neuen Spieler
        local rankData = NexusAdmin.Ranks[rankId]
        NexusAdmin.SendNotify(ply, {
            text     = "Willkommen! Dein Rang: " .. rankData.name,
            color    = rankData.color,
            icon     = "info",
            duration = 5,
        })
    end)
end)

-- ── Client fordert alle aktuellen Ränge an ───────────────────
-- Wird vom Client beim Öffnen des Menüs gesendet,
-- um eine frische Rang-Liste zu erhalten.
net.Receive("NexusAdmin_RequestAllRanks", function(_, ply)
    -- Sicherheitsprüfung: Nur Admins dürfen die volle Liste anfragen
    if not IsValid(ply) or not ply:IsAdmin() then
        NexusAdmin.SendNotify(ply, {
            text     = "Keine Berechtigung für diese Anfrage.",
            color    = Color(220, 60, 60),
            icon     = "error",
            duration = 3,
        })
        return
    end

    -- Tabelle aller Online-Spieler mit ihren Rängen serialisieren
    local rankTable = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            rankTable[p:UserID()] = p:GetNWString("na_rank", "user")
        end
    end

    net.Start("NexusAdmin_SyncAllRanks")
        net.WriteTable(rankTable)   -- Ganze Tabelle auf einmal senden
    net.Send(ply)
end)

-- ── NexusAdmin_Notify: UI-Benachrichtigungen senden ─────────
-- Sendet eine strukturierte Benachrichtigung an einen oder alle Clients.
--
-- @param target   Player|nil  – Ziel-Spieler, nil = Broadcast
-- @param data     table       – { text, color, icon, duration }
function NexusAdmin.SendNotify(target, data)
    net.Start("NexusAdmin_Notify")
        net.WriteString(data.text or "")
        -- Color als einzelne Bytes senden (kompakter als WriteTable)
        local c = data.color or Color(255, 255, 255)
        net.WriteUInt(c.r, 8)
        net.WriteUInt(c.g, 8)
        net.WriteUInt(c.b, 8)
        net.WriteString(data.icon or "info")         -- "info"|"success"|"error"|"warning"
        net.WriteFloat(data.duration or NexusAdmin.Config.DefaultNotifyDuration)
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

-- Shorthand für Admin-Broadcasts (z.B. aus Befehls-Callbacks)
function NexusAdmin.NotifyAdmins(text, color)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsAdmin() then
            NexusAdmin.SendNotify(ply, {
                text     = text,
                color    = color or Color(255, 200, 80),
                icon     = "warning",
                duration = 5,
            })
        end
    end
end
