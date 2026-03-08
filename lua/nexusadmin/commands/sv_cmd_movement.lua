-- ============================================================
--  NexusAdmin | sv_cmd_movement.lua
--  Teleportations-Befehle mit moderner Benennung.
--
--  !visit <target>              – Teleportiert den Admin zum Spieler
--  !summon <target>             – Ruft den Spieler zum Admin
--  !send <target> <destination> – Teleportiert Spieler A zu Spieler B
--  !back <target>               – Bringt Spieler zur vorherigen Position
--
--  Unterstützt Targeting-Schlüsselwörter: ^ * @
-- ============================================================

-- Lokaler Cache für vorherige Positionen.
-- Format: { [userID] = Vector, ... }
-- Wird vor jedem Teleport befüllt damit !back funktioniert.
local PreviousPositions = {}

-- Speichert die aktuelle Position eines Spielers als "vorherige Position".
local function SavePosition(ply)
    if IsValid(ply) then
        PreviousPositions[ply:UserID()] = ply:GetPos()
    end
end

-- ── !visit ───────────────────────────────────────────────────
NexusAdmin.RegisterCommand("visit", {
    description = "Teleportiert dich zu einem Spieler.",
    permission  = "teleport",
    args = {
        { name = "ziel", type = "player", required = true },
    },

    callback = function(caller, args)
        local targets = NexusAdmin.ResolveTargets(args[1], caller)

        if #targets == 0 then
            NexusAdmin.SendNotify(caller, {
                text = "Ziel nicht gefunden: " .. tostring(args[1]),
                icon = "error", duration = 4,
            })
            return
        end

        -- Bei * oder mehreren Treffern: zum ersten gehen
        local target = targets[1]

        if target == caller then
            NexusAdmin.SendNotify(caller, {
                text = "Du kannst nicht zu dir selbst teleportieren.",
                icon = "warning", duration = 3,
            })
            return
        end

        -- Immunität: Admin kann nur zu gleichrangigen oder höheren schauen,
        -- aber selbst teleportieren darf jeder zu jedem (kein Schaden am Ziel)
        SavePosition(caller)
        caller:SetPos(target:GetPos() + Vector(0, 0, 10))

        NexusAdmin.SendNotify(caller, {
            text     = "Zu " .. target:Nick() .. " teleportiert.",
            icon     = "success", duration = 3,
        })

        NexusAdmin.Log(string.format("%s besucht %s",
            caller:Nick(), target:Nick()), "CMD")
    end,
})

-- ── !summon ──────────────────────────────────────────────────
NexusAdmin.RegisterCommand("summon", {
    description = "Ruft einen oder alle Spieler zu dir.",
    permission  = "teleport",
    args = {
        { name = "ziel", type = "player/all", required = true },
    },

    callback = function(caller, args)
        local targets = NexusAdmin.ResolveTargets(args[1], caller)

        if #targets == 0 then
            NexusAdmin.SendNotify(caller, {
                text = "Ziel nicht gefunden: " .. tostring(args[1]),
                icon = "error", duration = 4,
            })
            return
        end

        local summoned = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end
            if target == caller     then continue end

            -- Immunität prüfen
            if not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text     = target:Nick() .. " ist immun gegen diesen Befehl.",
                    icon     = "warning", duration = 3,
                })
                continue
            end

            SavePosition(target)
            -- Leicht versetzt spawnen damit Spieler sich nicht überlagern
            local offset = Vector(
                math.random(-30, 30),
                math.random(-30, 30),
                10
            )
            target:SetPos(caller:GetPos() + offset)

            NexusAdmin.SendNotify(target, {
                text     = "Du wurdest von " .. caller:Nick() .. " gerufen.",
                icon     = "info", duration = 4,
            })
            table.insert(summoned, target:Nick())
        end

        if #summoned > 0 then
            NexusAdmin.SendNotify(caller, {
                text     = "Gerufen: " .. table.concat(summoned, ", "),
                icon     = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("%s ruft: %s",
                caller:Nick(), table.concat(summoned, ", ")), "CMD")
        end
    end,
})

-- ── !send ────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("send", {
    description = "Teleportiert Spieler A zu Spieler B.",
    permission  = "teleport",
    args = {
        { name = "quelle",    type = "player", required = true },
        { name = "ziel",      type = "player", required = true },
    },

    callback = function(caller, args)
        local sources = NexusAdmin.ResolveTargets(args[1], caller)
        local dest    = NexusAdmin.FindPlayer(args[2], caller)

        if #sources == 0 then
            NexusAdmin.SendNotify(caller, {
                text = "Quelle nicht gefunden: " .. tostring(args[1]),
                icon = "error", duration = 4,
            })
            return
        end

        if not IsValid(dest) then
            NexusAdmin.SendNotify(caller, {
                text = "Ziel nicht gefunden: " .. tostring(args[2]),
                icon = "error", duration = 4,
            })
            return
        end

        local moved = {}

        for _, src in ipairs(sources) do
            if not IsValid(src) then continue end
            if src == dest         then continue end

            if not NexusAdmin.CanTarget(caller, src) then
                NexusAdmin.SendNotify(caller, {
                    text     = src:Nick() .. " ist immun.",
                    icon     = "warning", duration = 3,
                })
                continue
            end

            SavePosition(src)
            local offset = Vector(math.random(-20, 20), math.random(-20, 20), 10)
            src:SetPos(dest:GetPos() + offset)

            NexusAdmin.SendNotify(src, {
                text     = "Du wurdest von " .. caller:Nick()
                            .. " zu " .. dest:Nick() .. " geschickt.",
                icon     = "info", duration = 4,
            })
            table.insert(moved, src:Nick())
        end

        if #moved > 0 then
            NexusAdmin.SendNotify(caller, {
                text     = table.concat(moved, ", ") .. " → " .. dest:Nick(),
                icon     = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("%s sendet [%s] zu %s",
                caller:Nick(), table.concat(moved, ", "), dest:Nick()), "CMD")
        end
    end,
})

-- ── !back ────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("back", {
    description = "Teleportiert einen Spieler zu seiner vorherigen Position.",
    permission  = "teleport",
    args = {
        -- Ohne Argument: eigene vorherige Position
        { name = "ziel", type = "player", required = false },
    },

    callback = function(caller, args)
        -- Ziel bestimmen: Argument oder sich selbst
        local target
        if args[1] then
            target = NexusAdmin.FindPlayer(args[1], caller)
            if not IsValid(target) then
                NexusAdmin.SendNotify(caller, {
                    text = "Spieler nicht gefunden: " .. tostring(args[1]),
                    icon = "error", duration = 4,
                })
                return
            end
            -- Fremdes Ziel benötigt Immunität-Check
            if target ~= caller and not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.",
                    icon = "warning", duration = 3,
                })
                return
            end
        else
            target = caller
        end

        local prevPos = PreviousPositions[target:UserID()]

        if not prevPos then
            NexusAdmin.SendNotify(caller, {
                text = (target == caller and "Du hast" or target:Nick() .. " hat")
                        .. " keine gespeicherte Position.",
                icon = "warning", duration = 4,
            })
            return
        end

        -- Aktuelle Position sichern bevor wir zurück teleportieren
        SavePosition(target)
        target:SetPos(prevPos)

        -- Verwendete Position aus Cache entfernen
        PreviousPositions[target:UserID()] = nil

        if target == caller then
            NexusAdmin.SendNotify(caller, {
                text = "Zur vorherigen Position zurückgekehrt.",
                icon = "success", duration = 3,
            })
        else
            NexusAdmin.SendNotify(caller, {
                text = target:Nick() .. " zurückgebracht.",
                icon = "success", duration = 3,
            })
            NexusAdmin.SendNotify(target, {
                text = "Du wurdest von " .. caller:Nick() .. " zurückgebracht.",
                icon = "info", duration = 4,
            })
        end

        NexusAdmin.Log(string.format("%s: !back auf %s",
            caller:Nick(), target:Nick()), "CMD")
    end,
})

-- Positionen beim Disconnect bereinigen
hook.Add("PlayerDisconnected", "NexusAdmin_ClearBackPos", function(ply)
    PreviousPositions[ply:UserID()] = nil
end)
