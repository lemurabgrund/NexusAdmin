-- ============================================================
--  NexusAdmin | sv_cmd_control.lua
--  Spieler-Kontroll-Befehle mit moderner Benennung.
--
--  !halt <target>     – Spieler einfrieren (Freeze)
--  !resume <target>   – Spieler wieder auftauen (Unfreeze)
--  !isolate <target>  – Spieler in Arrest-Zone teleportieren (Jail)
--  !release <target>  – Spieler aus Arrest-Zone befreien (Unjail)
--  !observe <target>  – In den Beobachter-Modus wechseln (Spectate)
--  !void <target>     – Spieler eliminieren (Slay)
--
--  Alle Befehle unterstützen Targeting-Schlüsselwörter: ^ * @
-- ============================================================

-- ── Lokale Zustands-Caches ───────────────────────────────────
-- Speichert welche Spieler gerade eingefroren/isoliert sind
-- und wo sie vor der Isolation waren.
local FrozenPlayers   = {}   -- { [userID] = true }
local IsolatedPlayers = {}   -- { [userID] = { pos = Vector, oldMove = bool } }

-- Arrest-Position: Mitten auf der Map weit oben (konfigurierbar)
-- In einer produktiven Version käme dies aus der Config.
local ARREST_POS = Vector(0, 0, 16384)

-- ── Hilfsfunktion: Freeze-Status setzen ──────────────────────
local function SetFrozen(target, frozen)
    if not IsValid(target) then return end

    target:SetMoveType(frozen and MOVETYPE_NONE or MOVETYPE_WALK)
    target:SetNWBool("na_frozen", frozen)

    if frozen then
        FrozenPlayers[target:UserID()] = true
    else
        FrozenPlayers[target:UserID()] = nil
    end
end

-- ── !halt ────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("halt", {
    description = "Friert einen oder alle Spieler ein.",
    permission  = "freeze",
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

        local halted = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            if not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            -- Bereits eingefroren? Hinweis ausgeben und überspringen
            if FrozenPlayers[target:UserID()] then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist bereits eingefroren. Nutze !resume.",
                    icon = "warning", duration = 3,
                })
                continue
            end

            SetFrozen(target, true)
            table.insert(halted, target:Nick())

            NexusAdmin.SendNotify(target, {
                text = "Du wurdest von " .. caller:Nick() .. " eingefroren.",
                icon = "warning", duration = 5,
            })
        end

        if #halted > 0 then
            local nameStr = table.concat(halted, ", ")
            NexusAdmin.SendNotify(caller, {
                text = "Eingefroren: " .. nameStr, icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("HALT: [%s] | Von: %s",
                nameStr, caller:Nick()), "CMD")
        end
    end,
})

-- ── !resume ──────────────────────────────────────────────────
NexusAdmin.RegisterCommand("resume", {
    description = "Taut einen oder alle eingefrorenen Spieler auf.",
    permission  = "freeze",
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

        local resumed = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            if not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            if not FrozenPlayers[target:UserID()] then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist nicht eingefroren.",
                    icon = "warning", duration = 3,
                })
                continue
            end

            SetFrozen(target, false)
            table.insert(resumed, target:Nick())

            NexusAdmin.SendNotify(target, {
                text = "Du wurdest von " .. caller:Nick() .. " aufgetaut.",
                icon = "info", duration = 4,
            })
        end

        if #resumed > 0 then
            local nameStr = table.concat(resumed, ", ")
            NexusAdmin.SendNotify(caller, {
                text = "Aufgetaut: " .. nameStr, icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("RESUME: [%s] | Von: %s",
                nameStr, caller:Nick()), "CMD")
        end
    end,
})

-- ── !isolate ─────────────────────────────────────────────────
NexusAdmin.RegisterCommand("isolate", {
    description = "Teleportiert einen Spieler in eine Arrest-Zone.",
    permission  = "jail",
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

        local isolated = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            if not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            if IsolatedPlayers[target:UserID()] then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist bereits isoliert. Nutze !release.",
                    icon = "warning", duration = 3,
                })
                continue
            end

            -- Vorherige Position und Bewegungs-Status merken
            IsolatedPlayers[target:UserID()] = {
                pos = target:GetPos(),
            }

            -- In Arrest-Zone teleportieren und einfrieren
            target:SetPos(ARREST_POS)
            SetFrozen(target, true)
            table.insert(isolated, target:Nick())

            NexusAdmin.SendNotify(target, {
                text = "Du wurdest von " .. caller:Nick() .. " isoliert.",
                icon = "error", duration = 0,  -- Bleibt bis !release
            })
        end

        if #isolated > 0 then
            local nameStr = table.concat(isolated, ", ")
            NexusAdmin.SendNotify(caller, {
                text = "Isoliert: " .. nameStr, icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("ISOLATE: [%s] | Von: %s",
                nameStr, caller:Nick()), "CMD")
        end
    end,
})

-- ── !release ─────────────────────────────────────────────────
NexusAdmin.RegisterCommand("release", {
    description = "Befreit einen Spieler aus der Arrest-Zone.",
    permission  = "jail",
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

        local released = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            if not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            local jailData = IsolatedPlayers[target:UserID()]

            if not jailData then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist nicht isoliert.",
                    icon = "warning", duration = 3,
                })
                continue
            end

            -- Zur vorherigen Position zurückbringen und auftauen
            target:SetPos(jailData.pos)
            SetFrozen(target, false)
            IsolatedPlayers[target:UserID()] = nil
            table.insert(released, target:Nick())

            NexusAdmin.SendNotify(target, {
                text = "Du wurdest von " .. caller:Nick() .. " freigelassen.",
                icon = "success", duration = 4,
            })
        end

        if #released > 0 then
            local nameStr = table.concat(released, ", ")
            NexusAdmin.SendNotify(caller, {
                text = "Freigelassen: " .. nameStr, icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("RELEASE: [%s] | Von: %s",
                nameStr, caller:Nick()), "CMD")
        end
    end,
})

-- ── !observe ─────────────────────────────────────────────────
NexusAdmin.RegisterCommand("observe", {
    description = "Wechselt in den Beobachter-Modus eines Spielers.",
    permission  = "spectate",
    args = {
        { name = "ziel", type = "player", required = true },
    },

    callback = function(caller, args)
        local target = NexusAdmin.FindPlayer(args[1], caller)

        if not IsValid(target) then
            NexusAdmin.SendNotify(caller, {
                text = "Spieler nicht gefunden: " .. tostring(args[1]),
                icon = "error", duration = 4,
            })
            return
        end

        if target == caller then
            -- Eigener Spectate-Modus beenden (zurück zu normalem Spawn)
            caller:UnSpectate()
            caller:Spawn()
            NexusAdmin.SendNotify(caller, {
                text = "Beobachter-Modus beendet.", icon = "info", duration = 3,
            })
            return
        end

        -- In Spectator-Team wechseln und Ziel beobachten
        caller:SetTeam(TEAM_SPECTATOR)
        caller:Spectate(OBS_MODE_IN_EYE)
        caller:SpectateEntity(target)

        NexusAdmin.SendNotify(caller, {
            text     = "Beobachte: " .. target:Nick() .. " | !observe ^ zum Beenden",
            icon     = "info", duration = 5,
        })

        NexusAdmin.Log(string.format("OBSERVE: %s beobachtet %s",
            caller:Nick(), target:Nick()), "CMD")
    end,
})

-- ── !void ────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("void", {
    description = "Eliminiert einen oder alle Spieler (Slay).",
    permission  = "slay",
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

        local voided = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            if not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            table.insert(voided, target:Nick())

            -- Spieler mit maximalen Schaden töten (kein Selbstmord-Flag)
            target:TakeDamage(target:Health() + target:Armor() + 1,
                caller, caller)
        end

        if #voided > 0 then
            local nameStr = table.concat(voided, ", ")
            NexusAdmin.SendNotify(caller, {
                text = "Ins Nichts geschickt: " .. nameStr,
                icon = "success", duration = 4,
            })
            NexusAdmin.NotifyAdmins(
                caller:Nick() .. " hat eliminiert: " .. nameStr,
                Color(220, 60, 60)
            )
            NexusAdmin.Log(string.format("VOID: [%s] | Von: %s",
                nameStr, caller:Nick()), "CMD")
        end
    end,
})

-- ── Cleanup beim Disconnect ───────────────────────────────────
-- Caches bereinigen wenn ein Spieler den Server verlässt.
hook.Add("PlayerDisconnected", "NexusAdmin_ControlCleanup", function(ply)
    FrozenPlayers[ply:UserID()]   = nil
    IsolatedPlayers[ply:UserID()] = nil
end)
