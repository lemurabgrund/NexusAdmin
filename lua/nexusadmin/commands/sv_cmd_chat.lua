-- ============================================================
--  NexusAdmin | sv_cmd_chat.lua
--  Chat- und Gesundheits-Befehle.
--
--  !sethp  <target> <amount>  – Setzt HP auf exakten Wert
--  !heal   <target>           – Heilt komplett (HP + Armor auf 100)
--  !pm     <target> <msg>     – Private Message an Spieler
--  !m      <msg>              – Admin-Broadcast an alle Teammitglieder
--
--  Alle Befehle nutzen NexusAdmin.AnnounceAction für anonyme Notices.
-- ============================================================

-- ── !sethp ───────────────────────────────────────────────────
NexusAdmin.RegisterCommand("sethp", {
    description = "Setzt die Gesundheit eines oder aller Spieler auf einen exakten Wert.",
    permission  = "sethealth",
    args = {
        { name = "ziel",   type = "player/all", required = true },
        { name = "menge",  type = "number",     required = true },
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
                text = "Ungültige Menge: " .. tostring(args[2]),
                icon = "error", duration = 4,
            })
            return
        end

        -- 1–2000 clampen
        amount = math.Clamp(math.floor(amount), 1, 2000)

        local changed = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end
            if target ~= caller and not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            target:SetHealth(amount)
            if amount > 100 then target:SetMaxHealth(amount) end
            table.insert(changed, target:Nick())

            -- Ziel informieren (wenn es nicht der Caller selbst ist)
            if target ~= caller then
                NexusAdmin.SendNotify(target, {
                    text = string.format("Deine HP wurden auf %d gesetzt.", amount),
                    icon = amount >= 50 and "success" or "warning",
                    duration = 4,
                })
            end
        end

        if #changed > 0 then
            NexusAdmin.SendNotify(caller, {
                text = string.format("HP auf %d: %s", amount, table.concat(changed, ", ")),
                icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("SETHP: %d HP → [%s] | Von: %s",
                amount, table.concat(changed, ", "), caller:Nick()), "CMD")
        end
    end,
})

-- ── !heal ────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("heal", {
    description = "Heilt einen oder alle Spieler vollständig (100 HP + 100 Armor).",
    permission  = "sethealth",
    args = {
        -- Ohne Argument: sich selbst heilen
        { name = "ziel", type = "player/all", required = false },
    },

    callback = function(caller, args)
        -- Ziel auflösen: Argument oder eigener Spieler
        local targets
        if args[1] then
            targets = NexusAdmin.ResolveTargets(args[1], caller)
            if #targets == 0 then
                NexusAdmin.SendNotify(caller, {
                    text = "Ziel nicht gefunden: " .. tostring(args[1]),
                    icon = "error", duration = 4,
                })
                return
            end
        else
            targets = { caller }
        end

        local healed = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end
            if target ~= caller and not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            -- Vollständig heilen
            target:SetHealth(100)
            target:SetMaxHealth(100)
            target:SetArmor(100)
            table.insert(healed, target:Nick())

            if target ~= caller then
                NexusAdmin.SendNotify(target, {
                    text = "Du wurdest von " .. caller:Nick() .. " vollständig geheilt.",
                    icon = "success", duration = 4,
                })
            end
        end

        if #healed > 0 then
            NexusAdmin.SendNotify(caller, {
                text = "Geheilt: " .. table.concat(healed, ", "),
                icon = "success", duration = 4,
            })
            NexusAdmin.Log(string.format("HEAL: [%s] | Von: %s",
                table.concat(healed, ", "), caller:Nick()), "CMD")
        end
    end,
})

-- ── !pm ──────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("pm", {
    description = "Sendet eine private Nachricht an einen Spieler.",
    permission  = "kick",  -- Admins dürfen PMs senden
    args = {
        { name = "ziel",      type = "player", required = true },
        { name = "nachricht", type = "string", required = true },
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
            NexusAdmin.SendNotify(caller, {
                text = "Du kannst dir selbst keine PM schicken.",
                icon = "warning", duration = 3,
            })
            return
        end

        -- Nachricht aus restlichen Args zusammensetzen
        -- (args[2] kann ein einzelnes Wort sein, wenn Spieler spaces nutzen)
        local message = args[2] or ""
        for i = 3, #args do
            message = message .. " " .. args[i]
        end

        if message == "" then
            NexusAdmin.SendNotify(caller, {
                text = "Bitte gib eine Nachricht an.",
                icon = "error", duration = 4,
            })
            return
        end

        NexusAdmin.SendPrivateMessage(caller, target, message)

        NexusAdmin.SendNotify(caller, {
            text = "PM an " .. target:Nick() .. " gesendet.",
            icon = "success", duration = 3,
        })
    end,
})

-- ── !m ───────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("m", {
    description = "Sendet eine hervorgehobene Nachricht an alle Teammitglieder (Admins).",
    permission  = "kick",
    args = {
        { name = "nachricht", type = "string", required = true },
    },

    callback = function(caller, args)
        if #args == 0 or not args[1] or args[1] == "" then
            NexusAdmin.SendNotify(caller, {
                text = "Bitte gib eine Nachricht an.",
                icon = "error", duration = 4,
            })
            return
        end

        -- Alle Args zur vollständigen Nachricht zusammensetzen
        local message = table.concat(args, " ")

        NexusAdmin.SendAdminMessage(caller, message)

        NexusAdmin.SendNotify(caller, {
            text = "Admin-Nachricht gesendet.",
            icon = "success", duration = 3,
        })
    end,
})
