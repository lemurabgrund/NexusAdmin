-- ============================================================
--  NexusAdmin | sv_cmd_tickets.lua
--  !ticket  – Spieler erstellt ein Support-Ticket
--  !tickets – Admin öffnet die Ticket-Zentrale (UI)
-- ============================================================

-- ── !ticket ──────────────────────────────────────────────────
NexusAdmin.RegisterCommand("ticket", {
    description = "Erstellt ein Support-Ticket für die Admins.",
    permission  = "public",  -- Jeder darf ein Ticket erstellen
    args = {
        { name = "grund", type = "string", required = true },
    },

    callback = function(caller, args)
        if #args == 0 or not args[1] or args[1] == "" then
            NexusAdmin.SendNotify(caller, {
                text     = "Nutzung: !ticket <Grund>",
                icon     = "error",
                duration = 4,
            })
            return
        end

        local reason = table.concat(args, " ")

        -- Über Net-Message (damit sv_tickets.lua die Logik hält)
        net.Start("NexusAdmin_TicketCreate")
            net.WriteString(reason)
        net.Send(caller)   -- Loopback: Server → Server via Receive
        -- Hinweis: Da RegisterCommand server-seitig läuft, senden wir
        -- direkt zum Receive-Handler (sv_tickets.lua verarbeitet es).
        -- Alternativ: direkt hier die Logik aufrufen.
    end,
})

-- Der obige Loopback-Trick klappt in GMod nicht (net an sich selbst).
-- Daher rufen wir die Ticket-Logik direkt inline auf:
NexusAdmin.Commands["ticket"].callback = function(caller, args)
    if #args == 0 or not args[1] or args[1] == "" then
        NexusAdmin.SendNotify(caller, {
            text = "Nutzung: !ticket <Grund>", icon = "error", duration = 4,
        })
        return
    end

    local reason = table.concat(args, " "):Trim()
    if #reason > 300 then reason = reason:sub(1, 300) end

    -- Maximal 1 offenes Ticket pro Spieler
    for _, t in pairs(NexusAdmin._Tickets or {}) do
        if t.authorSid == caller:SteamID64() and t.status == "open" then
            NexusAdmin.SendNotify(caller, {
                text = "Du hast bereits ein offenes Ticket (#" .. t.id .. ").",
                icon = "warning", duration = 4,
            })
            return
        end
    end

    NexusAdmin._Tickets       = NexusAdmin._Tickets       or {}
    NexusAdmin._TicketCounter = NexusAdmin._TicketCounter or 0
    NexusAdmin._TicketCounter = NexusAdmin._TicketCounter + 1
    local id = NexusAdmin._TicketCounter

    NexusAdmin._Tickets[id] = {
        id         = id,
        authorName = caller:Nick(),
        authorSid  = caller:SteamID64(),
        reason     = reason,
        status     = "open",
        acceptedBy = nil,
        createdAt  = os.time(),
    }

    NexusAdmin.SendNotify(caller, {
        text = string.format("Ticket #%d erstellt. Ein Admin wird sich kümmern.", id),
        icon = "success", duration = 5,
    })

    NexusAdmin.NotifyAdmins(
        string.format("[TICKET #%d] %s: %s", id, caller:Nick(), reason),
        Color(0, 210, 255)
    )

    NexusAdmin.Log(string.format("TICKET #%d von %s (%s): %s",
        id, caller:Nick(), caller:SteamID64(), reason), "TICKET")

    -- Broadcast an alle Admins
    local list = {}
    for _, t in pairs(NexusAdmin._Tickets) do list[#list + 1] = t end
    table.sort(list, function(a, b) return a.createdAt > b.createdAt end)

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:IsAdmin() then continue end
        net.Start("NexusAdmin_TicketList")
            net.WriteUInt(#list, 16)
            for _, t in ipairs(list) do
                net.WriteUInt(t.id,  16)
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

-- ── !tickets ─────────────────────────────────────────────────
NexusAdmin.RegisterCommand("tickets", {
    description = "Öffnet die Admin-Ticket-Zentrale.",
    permission  = "kick",
    args        = {},

    callback = function(caller, args)
        -- Öffnet client-seitig die Admin-Zentrale (Tickets-Tab)
        -- Wird via net.Send an den Caller geschickt; cl_admintools.lua
        -- öffnet dann na_admintools mit dem Ticket-Tab aktiv.
        -- Da wir keine eigene Net-Message dafür haben, nutzen wir concommand.
        -- Der Caller ruft es per console auf.
        NexusAdmin.SendNotify(caller, {
            text = "Öffne Admin-Zentrale mit na_admintools.",
            icon = "info", duration = 3,
        })
    end,
})

-- ── !admintools / !at ─────────────────────────────────────────
NexusAdmin.RegisterCommand("at", {
    description = "Öffnet die Admin-Zentrale (Bans, Warns, Tickets).",
    permission  = "kick",
    args        = {},
    callback = function(caller, _)
        NexusAdmin.SendNotify(caller, {
            text = "Admin-Zentrale: Gib 'na_admintools' in die Konsole ein oder nutze das Menü.",
            icon = "info", duration = 4,
        })
    end,
})

NexusAdmin.RegisterCommand("admintools", {
    description = "Öffnet die Admin-Zentrale.",
    permission  = "kick",
    args        = {},
    callback = function(caller, _)
        NexusAdmin.SendNotify(caller, {
            text = "Admin-Zentrale: Gib 'na_admintools' in die Konsole ein.",
            icon = "info", duration = 4,
        })
    end,
})

-- ── !perms ────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("perms", {
    description = "Öffnet die Permissions-Verwaltung (Superadmin).",
    permission  = "givrank",
    args        = {},
    callback = function(caller, _)
        NexusAdmin.SendNotify(caller, {
            text = "Permissions: Gib 'na_perms' in die Konsole ein.",
            icon = "info", duration = 4,
        })
    end,
})
