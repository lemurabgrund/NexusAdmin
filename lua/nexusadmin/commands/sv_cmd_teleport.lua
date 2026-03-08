-- ============================================================
--  NexusAdmin | sv_cmd_teleport.lua
--  Teleportiert Spieler A zu Spieler B (oder Admin zu Spieler).
-- ============================================================

NexusAdmin.RegisterCommand("teleport", {
    description = "Teleportiert einen Spieler zu einem anderen (oder dich selbst).",
    permission  = "teleport",
    args = {
        { name = "ziel",   type = "player", required = true  },
        { name = "quelle", type = "player", required = false },
    },

    callback = function(caller, args)
        local ziel = NexusAdmin.FindPlayer(args[1])

        if not IsValid(ziel) then
            NexusAdmin.SendNotify(caller, {
                text     = "Ziel-Spieler nicht gefunden: " .. tostring(args[1]),
                icon     = "error",
                duration = 4,
            })
            return
        end

        -- Optionale Quelle: wenn nicht angegeben, teleportiert sich der Admin selbst
        local quelle
        if args[2] then
            quelle = NexusAdmin.FindPlayer(args[2])
            if not IsValid(quelle) then
                NexusAdmin.SendNotify(caller, {
                    text     = "Quell-Spieler nicht gefunden: " .. tostring(args[2]),
                    icon     = "error",
                    duration = 4,
                })
                return
            end
        else
            quelle = caller
        end

        -- Spieler kann nicht zu sich selbst teleportiert werden
        if quelle == ziel then
            NexusAdmin.SendNotify(caller, {
                text     = "Quelle und Ziel sind identisch.",
                icon     = "warning",
                duration = 3,
            })
            return
        end

        -- Sicher leicht oberhalb des Ziels spawnen (verhindert Stuck-in-Floor)
        local zielPos = ziel:GetPos() + Vector(0, 0, 10)
        quelle:SetPos(zielPos)

        NexusAdmin.SendNotify(caller, {
            text     = quelle:Nick() .. " → " .. ziel:Nick() .. " teleportiert.",
            icon     = "success",
            duration = 3,
        })

        -- Ziel-Spieler informieren wenn er nicht der Caller ist
        if quelle ~= caller then
            NexusAdmin.SendNotify(quelle, {
                text     = "Du wurdest von " .. caller:Nick() .. " zu "
                            .. ziel:Nick() .. " teleportiert.",
                icon     = "info",
                duration = 4,
            })
        end
    end,
})
