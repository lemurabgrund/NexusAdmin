-- ============================================================
--  NexusAdmin | sv_cmd_warnings.lua
--  Befehle für das Verwarnungs-System.
--
--  !strike <target> <reason>    – Spieler verwarnen
--  !clearstrikes <target>       – Aktive Warns manuell deaktivieren
--  !strikelist <target>         – Warn-Historie in der Konsole ausgeben
--
--  Abhängigkeiten: sv_warning_system.lua (muss vorher geladen sein)
-- ============================================================

-- ── !strike ──────────────────────────────────────────────────
NexusAdmin.RegisterCommand("strike", {
    description = "Verwarnt einen Spieler. Bei " .. NexusAdmin.Config.WarnThreshold
                  .. " aktiven Verwarnungen erfolgt ein automatischer Bann.",
    permission  = "kick",   -- Admins dürfen verwarnen (gleiches Level wie Kick)
    args = {
        { name = "ziel",  type = "player", required = true  },
        { name = "grund", type = "string", required = true  },
    },

    callback = function(caller, args)
        local target = NexusAdmin.FindPlayer(args[1], caller)

        if not IsValid(target) then
            NexusAdmin.SendNotify(caller, {
                text     = "Spieler nicht gefunden: " .. tostring(args[1]),
                icon     = "error", duration = 4,
            })
            return
        end

        local grund = args[2]
        if not grund or grund == "" then
            NexusAdmin.SendNotify(caller, {
                text     = "Bitte gib einen Grund an.",
                icon     = "error", duration = 4,
            })
            return
        end

        -- Kern-Logik delegieren: Immunität + DB + Auto-Bann drin
        local result = NexusAdmin.AddWarning(target, caller, grund)

        if not result.success then
            NexusAdmin.SendNotify(caller, {
                text     = "Verwarnung fehlgeschlagen: " .. (result.error or "Unbekannter Fehler"),
                icon     = "error", duration = 5,
            })
            return
        end

        local threshold = NexusAdmin.Config.WarnThreshold

        -- ── Ziel-Spieler informieren ─────────────────────────
        if not result.autoBanned then
            -- Noch nicht gebannt: über aktuellen Stand informieren
            local remaining = threshold - result.newCount

            NexusAdmin.SendNotify(target, {
                text = string.format(
                    "Verwarnung von %s: %s  |  Warns: %d/%d  |  Noch %d bis zum Bann",
                    caller:Nick(), grund,
                    result.newCount, threshold,
                    remaining
                ),
                color    = Color(255, 160, 40),
                icon     = "warning",
                duration = 8,
            })
        end
        -- Wenn autoBanned = true, wurde der Spieler bereits gekickt –
        -- keine weitere Notify nötig.

        -- ── Caller-Bestätigung ───────────────────────────────
        if result.autoBanned then
            NexusAdmin.SendNotify(caller, {
                text = string.format(
                    "%s automatisch gebannt nach %d/%d Verwarnungen.",
                    target:Nick(), result.newCount, threshold
                ),
                icon     = "success", duration = 6,
            })
        else
            NexusAdmin.SendNotify(caller, {
                text = string.format(
                    "%s verwarnt (%d/%d) | %s",
                    target:Nick(), result.newCount, threshold, grund
                ),
                icon     = "success", duration = 5,
            })
        end

        -- ── Admin-Broadcast ──────────────────────────────────
        -- Alle anderen Admins über die Verwarnung informieren
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if ply == caller        then continue end
            if not ply:IsAdmin()    then continue end

            NexusAdmin.SendNotify(ply, {
                text = string.format(
                    "[Strike] %s → %s (%d/%d): %s",
                    caller:Nick(), target:Nick(),
                    result.newCount, threshold,
                    grund
                ),
                color    = Color(255, 160, 40),
                icon     = "warning",
                duration = 6,
            })
        end
    end,
})

-- ── !clearstrikes ────────────────────────────────────────────
NexusAdmin.RegisterCommand("clearstrikes", {
    description = "Setzt alle aktiven Verwarnungen eines Spielers auf inaktiv.",
    permission  = "ban",    -- Warns löschen ist schwerwiegender → Ban-Permission
    args = {
        { name = "ziel", type = "player", required = true },
    },

    callback = function(caller, args)
        local target = NexusAdmin.FindPlayer(args[1], caller)

        if not IsValid(target) then
            NexusAdmin.SendNotify(caller, {
                text     = "Spieler nicht gefunden: " .. tostring(args[1]),
                icon     = "error", duration = 4,
            })
            return
        end

        -- Immunität prüfen
        if not NexusAdmin.CanTarget(caller, target) then
            NexusAdmin.SendNotify(caller, {
                text     = target:Nick() .. " ist immun gegen diesen Befehl.",
                icon     = "error", duration = 4,
            })
            return
        end

        local cleared = NexusAdmin.ClearWarnings(target, caller)

        if cleared == 0 then
            NexusAdmin.SendNotify(caller, {
                text     = target:Nick() .. " hat keine aktiven Verwarnungen.",
                icon     = "warning", duration = 4,
            })
            return
        end

        -- Betroffenen Spieler informieren
        NexusAdmin.SendNotify(target, {
            text     = "Deine " .. cleared .. " aktive(n) Verwarnungen wurden von "
                        .. caller:Nick() .. " gelöscht.",
            icon     = "success", duration = 5,
        })

        NexusAdmin.SendNotify(caller, {
            text     = cleared .. " Verwarnungen von " .. target:Nick() .. " gelöscht.",
            icon     = "success", duration = 4,
        })

        NexusAdmin.NotifyAdmins(
            caller:Nick() .. " hat " .. cleared .. " Warns von "
                .. target:Nick() .. " gelöscht.",
            Color(72, 199, 142)
        )
    end,
})

-- ── !strikelist ──────────────────────────────────────────────
NexusAdmin.RegisterCommand("strikelist", {
    description = "Listet alle Verwarnungen eines Spielers in der Server-Konsole auf.",
    permission  = "kick",
    args = {
        { name = "ziel", type = "player", required = true },
    },

    callback = function(caller, args)
        local target = NexusAdmin.FindPlayer(args[1], caller)

        if not IsValid(target) then
            NexusAdmin.SendNotify(caller, {
                text     = "Spieler nicht gefunden: " .. tostring(args[1]),
                icon     = "error", duration = 4,
            })
            return
        end

        local sid     = target:SteamID64()
        local warns   = NexusAdmin.DB.GetAllWarnings(sid)
        local active  = NexusAdmin.DB.GetActiveWarningCount(sid)

        -- ── Ausgabe in die Server-Konsole ─────────────────────
        -- Ausgabe immer in die Konsole damit die Geschichte lesbar ist,
        -- auch wenn der Admin nur im RCON sitzt.
        local sep = string.rep("─", 60)
        print("\n" .. sep)
        print(string.format("[NexusAdmin] Verwarnungs-Liste: %s (%s)",
            target:Nick(), sid))
        print(string.format("  Aktive Warns: %d/%d",
            active, NexusAdmin.Config.WarnThreshold))
        print(sep)

        if #warns == 0 then
            print("  (Keine Verwarnungen in der Datenbank)")
        else
            for i, w in ipairs(warns) do
                local statusStr = w.is_active == "1" and "[AKTIV]  " or "[inaktiv]"
                local dateStr   = os.date("%d.%m.%Y %H:%M", tonumber(w.timestamp) or 0)
                print(string.format(
                    "  #%-3d %s %s  Admin: %s  |  %s",
                    tonumber(w.id) or i,
                    statusStr,
                    dateStr,
                    w.admin_sid64,
                    w.reason
                ))
            end
        end

        print(sep .. "\n")

        -- ── Kurz-Info an den anfragenden Admin ────────────────
        -- Die vollständige Liste ist in der Konsole; hier nur eine Kurzinfo.
        NexusAdmin.SendNotify(caller, {
            text = string.format(
                "%s: %d Verwarnungen gesamt, %d aktiv – Details in der Konsole.",
                target:Nick(), #warns, active
            ),
            icon     = "info", duration = 6,
        })
    end,
})
