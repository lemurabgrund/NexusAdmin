-- ============================================================
--  NexusAdmin | sv_tickets.lua
--  Server-seitiges Ticket-System.
--
--  Ablauf:
--    User:  !ticket <grund>  → Ticket wird erstellt
--    Admin: Sieht Liste, klickt "Annehmen" → bekommt Hinweis
--           "Nutze !summon um den Spieler zu dir zu holen"
--    Admin: Schließt Ticket mit optionalem Grund
--
--  KEINE automatische Teleportation. Admins handeln manuell.
-- ============================================================

util.AddNetworkString("NexusAdmin_TicketCreate")
util.AddNetworkString("NexusAdmin_TicketList")
util.AddNetworkString("NexusAdmin_TicketAccept")
util.AddNetworkString("NexusAdmin_TicketClose")
util.AddNetworkString("NexusAdmin_TicketMessage")
util.AddNetworkString("NexusAdmin_RequestTicketMessages")
util.AddNetworkString("NexusAdmin_TicketMessages")
util.AddNetworkString("NexusAdmin_MyTicketUpdate")
util.AddNetworkString("NexusAdmin_OpenTicket")
util.AddNetworkString("NexusAdmin_RequestBanList")
util.AddNetworkString("NexusAdmin_BanList")
util.AddNetworkString("NexusAdmin_RequestWarnList")
util.AddNetworkString("NexusAdmin_WarnList")

-- Ticket-Speicher (Session-Daten, kein Persist nötig)
NexusAdmin._Tickets        = NexusAdmin._Tickets        or {}
NexusAdmin._TicketCounter  = NexusAdmin._TicketCounter  or 0

-- ── Hilfsfunktion: Ticket-Status an Autor senden ─────────────
local function SendAuthorUpdate(t)
    local author = player.GetBySteamID64(t.authorSid)
    if not IsValid(author) then return end
    net.Start("NexusAdmin_MyTicketUpdate")
        net.WriteUInt(t.id,           16)
        net.WriteString(t.status)
        net.WriteString(t.reason)
        net.WriteString(t.authorSid)
        net.WriteString(t.authorName)
    net.Send(author)
end
NexusAdmin.SendAuthorUpdate = SendAuthorUpdate  -- für sv_cmd_tickets zugänglich

-- ── Hilfsfunktion: Ticket-Liste an alle Admins senden ────────
local function BroadcastTickets(target)
    local list = {}
    for id, t in pairs(NexusAdmin._Tickets) do
        list[#list + 1] = t
    end
    -- Sortiert nach Erstellzeit (neueste zuerst)
    table.sort(list, function(a, b) return a.createdAt > b.createdAt end)

    local recipients = target and { target } or player.GetAll()

    for _, ply in ipairs(recipients) do
        if not IsValid(ply) then continue end
        if not NexusAdmin.PlayerHasPermission(ply, "kick")  then continue end

        net.Start("NexusAdmin_TicketList")
            net.WriteUInt(#list, 16)
            for _, t in ipairs(list) do
                net.WriteUInt(t.id,         16)
                net.WriteString(t.authorName)
                net.WriteString(t.authorSid)
                net.WriteString(t.reason)
                net.WriteString(t.status)
                net.WriteString(t.acceptedBy or "")
                net.WriteDouble(t.createdAt)
            end
        net.Send(ply)
    end
end

-- ── Spieler erstellt Ticket ───────────────────────────────────
net.Receive("NexusAdmin_TicketCreate", function(_, ply)
    if not IsValid(ply) then return end

    local reason = net.ReadString():Trim()
    if reason == "" then return end
    if #reason > 300 then reason = reason:sub(1, 300) end

    -- Maximal 1 offenes Ticket pro Spieler
    for _, t in pairs(NexusAdmin._Tickets) do
        if t.authorSid == ply:SteamID64() and t.status == "open" then
            NexusAdmin.SendNotify(ply, {
                text = "Du hast bereits ein offenes Ticket (#" .. t.id .. ").",
                icon = "warning", duration = 4,
            })
            return
        end
    end

    NexusAdmin._TicketCounter = NexusAdmin._TicketCounter + 1
    local id = NexusAdmin._TicketCounter

    NexusAdmin._Tickets[id] = {
        id         = id,
        authorName = ply:Nick(),
        authorSid  = ply:SteamID64(),
        reason     = reason,
        status     = "open",
        acceptedBy = nil,
        createdAt  = os.time(),
    }

    NexusAdmin.SendNotify(ply, {
        text = string.format("Ticket #%d erstellt. Ein Admin wird sich kümmern.", id),
        icon = "success", duration = 5,
    })

    NexusAdmin.NotifyAdmins(
        string.format("[TICKET #%d] %s: %s", id, ply:Nick(), reason),
        Color(0, 210, 255)
    )

    NexusAdmin.Log(string.format("TICKET #%d von %s (%s): %s",
        id, ply:Nick(), ply:SteamID64(), reason), "TICKET")

    SendAuthorUpdate(NexusAdmin._Tickets[id])
    BroadcastTickets()
end)

-- ── Admin nimmt Ticket an ────────────────────────────────────
net.Receive("NexusAdmin_TicketAccept", function(_, ply)
    if not IsValid(ply) or not NexusAdmin.PlayerHasPermission(ply, "kick") then return end

    local id = net.ReadUInt(16)
    local t  = NexusAdmin._Tickets[id]
    if not t or t.status ~= "open" then return end

    t.status     = "accepted"
    t.acceptedBy = ply:Nick()

    -- Admin-Hinweis: KEINE automatische Teleportation
    NexusAdmin.SendNotify(ply, {
        text = string.format("Ticket #%d angenommen. Nutze !summon %s um den Spieler zu dir zu holen.",
            id, t.authorName),
        icon = "info", duration = 8,
    })

    -- Ticket-Ersteller informieren
    local author = player.GetBySteamID64(t.authorSid)
    if IsValid(author) then
        NexusAdmin.SendNotify(author, {
            text = "Dein Ticket wird von " .. ply:Nick() .. " bearbeitet.",
            icon = "success", duration = 5,
        })
    end

    NexusAdmin.Log(string.format("TICKET #%d angenommen von %s", id, ply:Nick()), "TICKET")
    SendAuthorUpdate(t)
    BroadcastTickets()
end)

-- ── Admin schließt Ticket ─────────────────────────────────────
net.Receive("NexusAdmin_TicketClose", function(_, ply)
    if not IsValid(ply) or not NexusAdmin.PlayerHasPermission(ply, "kick") then return end

    local id     = net.ReadUInt(16)
    local reason = net.ReadString():Trim()
    local t      = NexusAdmin._Tickets[id]
    if not t then return end

    t.status = "closed"

    local author = player.GetBySteamID64(t.authorSid)
    if IsValid(author) then
        NexusAdmin.SendNotify(author, {
            text = "Dein Ticket wurde geschlossen." .. (reason ~= "" and " | " .. reason or ""),
            icon = "info", duration = 5,
        })
    end

    NexusAdmin.Log(string.format("TICKET #%d geschlossen von %s. Grund: %s",
        id, ply:Nick(), reason ~= "" and reason or "–"), "TICKET")

    SendAuthorUpdate(t)
    BroadcastTickets()
end)

-- ── Ticket-Chat: Nachricht senden ────────────────────────────
net.Receive("NexusAdmin_TicketMessage", function(_, ply)
    if not IsValid(ply) then return end

    local id   = net.ReadUInt(16)
    local text = net.ReadString():Trim()
    if text == "" or #text > 300 then return end

    local t = NexusAdmin._Tickets[id]
    if not t or t.status == "closed" then return end

    local isAdmin  = NexusAdmin.PlayerHasPermission(ply, "kick")
    local isAuthor = (ply:SteamID64() == t.authorSid)
    if not isAdmin and not isAuthor then return end

    t.messages = t.messages or {}
    local msg = {
        senderName = ply:Nick(),
        senderSid  = ply:SteamID64(),
        text       = text,
        time       = os.time(),
        isAdmin    = isAdmin,
    }
    t.messages[#t.messages + 1] = msg

    -- Relay an Ticket-Autor + alle Admins
    local recipients = {}
    local author = player.GetBySteamID64(t.authorSid)
    if IsValid(author) then
        recipients[#recipients + 1] = author
    end
    for _, p in ipairs(player.GetAll()) do
        if NexusAdmin.PlayerHasPermission(p, "kick") and p ~= author then
            recipients[#recipients + 1] = p
        end
    end

    net.Start("NexusAdmin_TicketMessage")
        net.WriteUInt(id,            16)
        net.WriteString(msg.senderName)
        net.WriteString(msg.senderSid)
        net.WriteString(msg.text)
        net.WriteDouble(msg.time)
        net.WriteBool(msg.isAdmin)
    net.Send(recipients)

    NexusAdmin.Log(string.format("TICKET #%d Nachricht von %s: %s",
        id, ply:Nick(), text), "TICKET")
end)

-- ── Ticket-Chat: Nachrichtenhistorie anfordern ────────────────
net.Receive("NexusAdmin_RequestTicketMessages", function(_, ply)
    if not IsValid(ply) then return end

    local id = net.ReadUInt(16)
    local t  = NexusAdmin._Tickets[id]
    if not t then return end

    local isAdmin  = NexusAdmin.PlayerHasPermission(ply, "kick")
    local isAuthor = (ply:SteamID64() == t.authorSid)
    if not isAdmin and not isAuthor then return end

    local msgs = t.messages or {}
    net.Start("NexusAdmin_TicketMessages")
        net.WriteUInt(id, 16)
        net.WriteUInt(#msgs, 16)
        for _, m in ipairs(msgs) do
            net.WriteString(m.senderName)
            net.WriteString(m.senderSid)
            net.WriteString(m.text)
            net.WriteDouble(m.time)
            net.WriteBool(m.isAdmin)
        end
    net.Send(ply)
end)

-- ── Admin-Zentrale: Ban-Liste anfordern ───────────────────────
net.Receive("NexusAdmin_RequestBanList", function(_, ply)
    if not IsValid(ply) or not NexusAdmin.PlayerHasPermission(ply, "kick") then return end

    local bans = NexusAdmin.GetAllExclusions and NexusAdmin.GetAllExclusions() or {}

    net.Start("NexusAdmin_BanList")
        net.WriteUInt(#bans, 16)
        for _, b in ipairs(bans) do
            net.WriteString(tostring(b.steam_id  or ""))
            net.WriteString(tostring(b.reason    or ""))
            net.WriteString(tostring(b.banned_by or ""))
            net.WriteDouble(tonumber(b.banned_at  or 0))
            net.WriteDouble(tonumber(b.expires_at or 0))
        end
    net.Send(ply)
end)

-- ── Admin-Zentrale: Warn-Liste anfordern (mit Suche) ──────────
net.Receive("NexusAdmin_RequestWarnList", function(_, ply)
    if not IsValid(ply) or not NexusAdmin.PlayerHasPermission(ply, "kick") then return end

    local query = net.ReadString():Trim()
    local results = {}

    if query == "" then
        -- Alle Online-Spieler mit aktiven Verwarnungen
        for _, p in ipairs(player.GetAll()) do
            local count = p:GetNWInt("na_warns", 0)
            if count > 0 then
                results[#results + 1] = {
                    name   = p:Nick(),
                    sid    = p:SteamID64(),
                    count  = count,
                    online = true,
                }
            end
        end
    else
        -- DB-Suche nach SteamID64 oder Name (nur SteamIDs in DB)
        local safeQ = sql.SQLStr("%" .. query .. "%")
        local rows  = sql.Query(
            "SELECT target_sid64, COUNT(*) as cnt " ..
            "FROM nexusadmin_warnings " ..
            "WHERE is_active = 1 AND target_sid64 LIKE " .. safeQ ..
            " GROUP BY target_sid64"
        )
        if rows then
            for _, row in ipairs(rows) do
                local onlinePly = player.GetBySteamID64(row.target_sid64)
                results[#results + 1] = {
                    name   = IsValid(onlinePly) and onlinePly:Nick() or row.target_sid64,
                    sid    = row.target_sid64,
                    count  = tonumber(row.cnt) or 0,
                    online = IsValid(onlinePly),
                }
            end
        end
    end

    net.Start("NexusAdmin_WarnList")
        net.WriteUInt(#results, 16)
        for _, r in ipairs(results) do
            net.WriteString(r.name)
            net.WriteString(r.sid)
            net.WriteUInt(math.Clamp(r.count, 0, 255), 8)
            net.WriteBool(r.online)
        end
    net.Send(ply)
end)

-- ── Sync: Neue Admins erhalten die Ticket-Liste ───────────────
hook.Add("PlayerInitialSpawn", "NexusAdmin_TicketSync", function(ply)
    timer.Simple(2, function()
        if not IsValid(ply) or not NexusAdmin.PlayerHasPermission(ply, "kick") then return end
        BroadcastTickets(ply)
    end)
end)
