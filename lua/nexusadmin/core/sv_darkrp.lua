-- ============================================================
--  NexusAdmin | sv_darkrp.lua
--  DarkRP-Integrations-Modul.
--
--  Erkennung: Prüft ob DarkRP global vorhanden ist.
--  Falls ja:
--    - NexusAdmin-Funktionen die mit DarkRP kollidieren
--      werden auf DarkRP-eigene Funktionen umgeleitet.
--    - Neue Befehle: !givemoney, !setjob, !setsalary
--    - Konflikt-Warnung bei potenziell doppelten Systemen.
--
--  Falls nein: Dieses Modul tut nichts.
-- ============================================================

-- DarkRP-Erkennung nach dem Gamemode-Load (DarkRP initialisiert
-- sich während Gamemode-Load, daher Hook auf Initialize).
hook.Add("Initialize", "NexusAdmin_DarkRP_Detect", function()

    -- Prüfen ob DarkRP API vorhanden
    if not DarkRP or not DarkRP.getVar then
        NexusAdmin.Log("DarkRP nicht erkannt – Integration übersprungen.", "DARKRP")
        return
    end

    NexusAdmin.IsDarkRP = true
    NexusAdmin.Log("DarkRP erkannt – Integrationsmodul aktiv.", "DARKRP")

    -- ── Konflikt-Hinweise ─────────────────────────────────────
    -- Informiert Admins beim ersten Join über potenziell
    -- kollidierende Systeme.
    hook.Add("PlayerInitialSpawn", "NexusAdmin_DarkRP_AdminHint", function(ply)
        timer.Simple(3, function()
            if not IsValid(ply) or not ply:IsAdmin() then return end
            NexusAdmin.SendNotify(ply, {
                text = "[DarkRP] NexusAdmin läuft im DarkRP-Kompatibilitätsmodus.",
                icon = "info", duration = 6,
            })
        end)
    end)

    -- ── !givemoney ────────────────────────────────────────────
    NexusAdmin.RegisterCommand("givemoney", {
        description = "Gibt einem Spieler DarkRP-Geld.",
        permission  = "sethealth",   -- Gleiche Stufe wie sethp
        args = {
            { name = "ziel",   type = "player", required = true },
            { name = "menge",  type = "number", required = true },
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

            local amount = math.floor(tonumber(args[2]) or 0)
            if amount == 0 then
                NexusAdmin.SendNotify(caller, {
                    text = "Ungültige Menge.", icon = "error", duration = 3,
                })
                return
            end

            -- Clamp: max 1 Mio auf einmal
            amount = math.Clamp(amount, -1000000, 1000000)

            local changed = {}
            for _, target in ipairs(targets) do
                if not IsValid(target) then continue end
                if target ~= caller and not NexusAdmin.CanTarget(caller, target) then continue end

                -- DarkRP-eigene Funktion verwenden
                target:addMoney(amount)
                table.insert(changed, target:Nick())

                if target ~= caller then
                    NexusAdmin.SendNotify(target, {
                        text = string.format(
                            "Du hast %s%d$ %s.",
                            amount >= 0 and "+" or "",
                            amount,
                            amount >= 0 and "erhalten" or "verloren"
                        ),
                        icon = amount >= 0 and "success" or "warning",
                        duration = 4,
                    })
                end
            end

            if #changed > 0 then
                NexusAdmin.SendNotify(caller, {
                    text = string.format("%s$ an %s.",
                        amount >= 0 and ("+" .. amount) or tostring(amount),
                        table.concat(changed, ", ")),
                    icon = "success", duration = 4,
                })
                NexusAdmin.Log(string.format("GIVEMONEY: %d$ → [%s] | Von: %s",
                    amount, table.concat(changed, ", "), caller:Nick()), "DARKRP")
            end
        end,
    })

    -- ── !setjob ───────────────────────────────────────────────
    NexusAdmin.RegisterCommand("setjob", {
        description = "Setzt den DarkRP-Job eines Spielers.",
        permission  = "sethealth",
        args = {
            { name = "ziel", type = "player", required = true },
            { name = "job",  type = "string", required = true },
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

            if target ~= caller and not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                return
            end

            local jobName = table.concat(args, " ", 2):Trim():lower()

            -- Job in DarkRP-Tabelle suchen (case-insensitiv)
            local foundJob = nil
            for _, jobData in pairs(RPExtraTeams or {}) do
                if jobData.name:lower() == jobName or
                   jobData.command:lower() == jobName then
                    foundJob = jobData
                    break
                end
            end

            if not foundJob then
                NexusAdmin.SendNotify(caller, {
                    text = "Job '" .. jobName .. "' nicht gefunden.",
                    icon = "error", duration = 4,
                })
                return
            end

            -- DarkRP-Job setzen
            target:setDarkRPVar("job", foundJob.name)
            target:SetTeam(foundJob.team)
            if target.updateJob then target:updateJob(true) end

            NexusAdmin.SendNotify(target, {
                text = "Dein Job wurde auf '" .. foundJob.name .. "' gesetzt.",
                icon = "success", duration = 4,
            })
            NexusAdmin.SendNotify(caller, {
                text = target:Nick() .. " → Job: " .. foundJob.name,
                icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("SETJOB: %s → '%s' | Von: %s",
                target:Nick(), foundJob.name, caller:Nick()), "DARKRP")
        end,
    })

    -- ── !setsal ───────────────────────────────────────────────
    NexusAdmin.RegisterCommand("setsal", {
        description = "Setzt das DarkRP-Gehalt eines Spielers.",
        permission  = "sethealth",
        args = {
            { name = "ziel",   type = "player", required = true },
            { name = "gehalt", type = "number", required = true },
        },

        callback = function(caller, args)
            local target = NexusAdmin.FindPlayer(args[1], caller)
            if not IsValid(target) then
                NexusAdmin.SendNotify(caller, {
                    text = "Spieler nicht gefunden.", icon = "error", duration = 4,
                })
                return
            end

            local salary = math.Clamp(math.floor(tonumber(args[2]) or 0), 0, 100000)

            target:setDarkRPVar("salary", salary)

            NexusAdmin.SendNotify(target, {
                text = string.format("Dein Gehalt wurde auf %d$ gesetzt.", salary),
                icon = "success", duration = 4,
            })
            NexusAdmin.SendNotify(caller, {
                text = string.format("Gehalt von %s auf %d$ gesetzt.", target:Nick(), salary),
                icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("SETSAL: %s → %d$ | Von: %s",
                target:Nick(), salary, caller:Nick()), "DARKRP")
        end,
    })

    -- ── DarkRP-Kompatibilität: Kollisionsvermeidung ───────────
    -- Falls DarkRP eigene Punish/Warn-Systeme hat, NexusAdmin
    -- bindet sich trotzdem ein – beide Systeme laufen parallel.
    -- Potenzieller Konflikt: PlayerSay-Hook für Befehle.
    -- DarkRP nutzt "/" als Prefix, NexusAdmin "!" – kein Konflikt.

    -- Falls DarkRP's Arrest-System vorhanden: !halt und !release
    -- leiten auf DarkRP-Arrest weiter wenn vorhanden.
    if DarkRP.createPlayerVar then
        local origHalt = NexusAdmin.Commands["halt"] and NexusAdmin.Commands["halt"].callback
        if origHalt then
            NexusAdmin.Commands["halt"].callback = function(caller, args)
                local targets = NexusAdmin.ResolveTargets(args[1], caller)
                for _, t in ipairs(targets) do
                    if IsValid(t) and t.setDarkRPVar then
                        t:setDarkRPVar("arrested", true)
                    end
                end
                -- Original-Logik zusätzlich ausführen
                origHalt(caller, args)
            end
        end
    end

    NexusAdmin.Log("DarkRP-Integration vollständig geladen.", "DARKRP")
end)
