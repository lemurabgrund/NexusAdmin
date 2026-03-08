-- ============================================================
--  NexusAdmin | sv_cmd_stats.lua
--  Spieler-Statistik-Befehle mit moderner Benennung.
--
--  !vitalize <target> <amount>  – Setzt Gesundheit (HP)
--  !shield <target> <amount>    – Setzt Rüstung (Armor)
--  !invincible <target>         – Schaltet Unverwundbarkeit um (God-Mode Toggle)
--
--  Alle Befehle unterstützen Targeting-Schlüsselwörter: ^ * @
--  Beispiele:
--    !vitalize ^ 100      → Eigene HP auf 100
--    !vitalize * 100      → Alle Spieler auf 100 HP
--    !invincible @        → Angeschauter Spieler: God-Mode toggle
-- ============================================================

-- Lokaler Cache für aktive God-Mode-Spieler.
-- Format: { [userID] = true }
local GodModePlayers = {}

-- ── Hilfsfunktion: Wert clampen ──────────────────────────────
-- Begrenzt einen Wert auf [min, max].
local function Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- ── !vitalize ────────────────────────────────────────────────
NexusAdmin.RegisterCommand("vitalize", {
    description = "Setzt die Gesundheit eines oder aller Spieler.",
    permission  = "sethealth",
    args = {
        { name = "ziel",   type = "player/all", required = true  },
        { name = "menge",  type = "number",     required = true  },
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

        local amount = tonumber(args[2])

        if not amount then
            NexusAdmin.SendNotify(caller, {
                text = "Ungültige Menge: " .. tostring(args[2]) .. " (Zahl erwartet)",
                icon = "error", duration = 4,
            })
            return
        end

        -- HP zwischen 1 und 2000 begrenzen (verhindert negative HP / Overflow)
        amount = Clamp(math.floor(amount), 1, 2000)

        local vitalized = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            -- Bei sich selbst oder erlaubtem Ziel fortfahren
            if target ~= caller and not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            local oldHP = target:Health()
            target:SetHealth(amount)

            -- MaxHealth anpassen wenn amount > Standard-Maximum (100)
            if amount > 100 then
                target:SetMaxHealth(amount)
            end

            table.insert(vitalized, target:Nick())

            -- Ziel informieren wenn jemand anderes die HP setzt
            if target ~= caller then
                NexusAdmin.SendNotify(target, {
                    text = string.format(
                        "%s hat deine HP gesetzt: %d → %d",
                        caller:Nick(), oldHP, amount),
                    icon = amount >= oldHP and "success" or "warning",
                    duration = 4,
                })
            end
        end

        if #vitalized > 0 then
            local nameStr = table.concat(vitalized, ", ")
            NexusAdmin.SendNotify(caller, {
                text = string.format("HP auf %d gesetzt: %s", amount, nameStr),
                icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("VITALIZE: %d HP → [%s] | Von: %s",
                amount, nameStr, caller:Nick()), "CMD")
        end
    end,
})

-- ── !shield ──────────────────────────────────────────────────
NexusAdmin.RegisterCommand("shield", {
    description = "Setzt die Rüstung eines oder aller Spieler.",
    permission  = "setarmor",
    args = {
        { name = "ziel",  type = "player/all", required = true },
        { name = "menge", type = "number",     required = true },
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

        local amount = tonumber(args[2])

        if not amount then
            NexusAdmin.SendNotify(caller, {
                text = "Ungültige Menge: " .. tostring(args[2]) .. " (Zahl erwartet)",
                icon = "error", duration = 4,
            })
            return
        end

        -- Rüstung zwischen 0 und 2000 begrenzen
        amount = Clamp(math.floor(amount), 0, 2000)

        local shielded = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            if target ~= caller and not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            local oldArmor = target:Armor()
            target:SetArmor(amount)
            table.insert(shielded, target:Nick())

            if target ~= caller then
                NexusAdmin.SendNotify(target, {
                    text = string.format(
                        "%s hat deine Rüstung gesetzt: %d → %d",
                        caller:Nick(), oldArmor, amount),
                    icon = amount >= oldArmor and "success" or "warning",
                    duration = 4,
                })
            end
        end

        if #shielded > 0 then
            local nameStr = table.concat(shielded, ", ")
            NexusAdmin.SendNotify(caller, {
                text = string.format("Rüstung auf %d gesetzt: %s", amount, nameStr),
                icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("SHIELD: %d Armor → [%s] | Von: %s",
                amount, nameStr, caller:Nick()), "CMD")
        end
    end,
})

-- ── !invincible ──────────────────────────────────────────────
NexusAdmin.RegisterCommand("invincible", {
    description = "Schaltet den Unverwundbarkeits-Modus eines Spielers um (Toggle).",
    permission  = "god",
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

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            if target ~= caller and not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            local uid     = target:UserID()
            local isGod   = GodModePlayers[uid]
            local newState = not isGod

            if newState then
                -- God-Mode aktivieren
                target:GodEnable()
                GodModePlayers[uid] = true
                target:SetNWBool("na_god", true)

                NexusAdmin.SendNotify(target, {
                    text = (target == caller and "God-Mode aktiviert."
                        or "God-Mode aktiviert von " .. caller:Nick() .. "."),
                    icon = "success", duration = 5,
                })

                NexusAdmin.Log(string.format("INVINCIBLE ON: %s | Von: %s",
                    target:Nick(), caller:Nick()), "CMD")
            else
                -- God-Mode deaktivieren
                target:GodDisable()
                GodModePlayers[uid] = nil
                target:SetNWBool("na_god", false)

                NexusAdmin.SendNotify(target, {
                    text = (target == caller and "God-Mode deaktiviert."
                        or "God-Mode deaktiviert von " .. caller:Nick() .. "."),
                    icon = "warning", duration = 5,
                })

                NexusAdmin.Log(string.format("INVINCIBLE OFF: %s | Von: %s",
                    target:Nick(), caller:Nick()), "CMD")
            end

            -- Caller-Feedback nur wenn Ziel != Caller
            if target ~= caller then
                NexusAdmin.SendNotify(caller, {
                    text = string.format("God-Mode %s: %s",
                        newState and "AN" or "AUS", target:Nick()),
                    icon = newState and "success" or "warning",
                    duration = 4,
                })
            end
        end
    end,
})

-- ── God-Mode nach dem Tod zurücksetzen ────────────────────────
-- Wenn ein Spieler stirbt und respawnt, bleibt der God-Mode aktiv
-- (GodEnable gilt session-weit). Beim Disconnect aber Cache leeren.
hook.Add("PlayerDisconnected", "NexusAdmin_StatsCleanup", function(ply)
    GodModePlayers[ply:UserID()] = nil
end)

-- God-Mode nach Respawn wiederherstellen (wird durch Spawn zurückgesetzt)
hook.Add("PlayerSpawn", "NexusAdmin_RestoreGodMode", function(ply)
    if not IsValid(ply) then return end
    if GodModePlayers[ply:UserID()] then
        -- Kurze Verzögerung: GMod überschreibt GodEnable beim Spawn-Tick
        timer.Simple(0.1, function()
            if IsValid(ply) and GodModePlayers[ply:UserID()] then
                ply:GodEnable()
            end
        end)
    end
end)
