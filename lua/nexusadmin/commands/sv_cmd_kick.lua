-- ============================================================
--  NexusAdmin | sv_cmd_kick.lua
--  Kickt einen Spieler vom Server.
-- ============================================================

NexusAdmin.RegisterCommand("kick", {
    description = "Kickt einen Spieler vom Server.",
    permission  = "kick",
    args = {
        { name = "spieler", type = "player", required = true  },
        { name = "grund",   type = "string", required = false, default = "Kein Grund angegeben" },
    },

    callback = function(caller, args)
        local target = NexusAdmin.FindPlayer(args[1])

        if not IsValid(target) then
            NexusAdmin.SendNotify(caller, {
                text     = "Spieler nicht gefunden: " .. tostring(args[1]),
                icon     = "error",
                duration = 4,
            })
            return
        end

        -- Rang-Hierarchie: kann nur niedrigere Ränge kicken
        if not NexusAdmin.CanTarget(caller, target) then
            NexusAdmin.SendNotify(caller, {
                text     = target:Nick() .. " ist immun gegen diesen Befehl.",
                icon     = "error",
                duration = 4,
            })
            return
        end

        -- Spieler kann sich nicht selbst kicken
        if target == caller then
            NexusAdmin.SendNotify(caller, {
                text     = "Du kannst dich nicht selbst kicken.",
                icon     = "warning",
                duration = 3,
            })
            return
        end

        local grund = args[2] or "Kein Grund angegeben"

        -- Alle Admins über den Kick informieren
        NexusAdmin.NotifyAdmins(
            caller:Nick() .. " hat " .. target:Nick() .. " gekickt. (" .. grund .. ")",
            Color(255, 150, 50)
        )

        target:Kick("[NexusAdmin] Du wurdest gekickt: " .. grund)
    end,
})
