-- ============================================================
--  NexusAdmin | sv_cmd_management.lua
--  Server-Verwaltungs-Befehle mit moderner Benennung.
--
--  !exclude <target> <time> <reason>  – Langfristiger Ausschluss
--  !drop <target> <reason>            – Sofortiges Entfernen (Kick)
--  !pardon <steamid>                  – Ausschluss aufheben
--  !promote <target> <rank>           – Rang eines Nutzers ändern
--
--  Zeitformat für !exclude:
--    30m   = 30 Minuten
--    2h    = 2 Stunden
--    7d    = 7 Tage
--    0     = permanent
-- ============================================================

-- ── Zeit-Parser ──────────────────────────────────────────────
-- Wandelt Strings wie "30m", "2h", "7d" in Sekunden um.
-- Gibt 0 zurück bei ungültigem Format (= permanent).
local function ParseDuration(str)
    if not str then return 0 end

    -- Explizit permanent
    if str == "0" or str == "perm" or str == "permanent" then
        return 0
    end

    local value, unit = str:match("^(%d+)([mhd]?)$")
    value = tonumber(value)
    if not value then return 0 end

    if unit == "m" then return value * 60
    elseif unit == "h" then return value * 3600
    elseif unit == "d" then return value * 86400
    else                     return value          -- rohe Sekunden
    end
end

-- Formatiert eine Dauer für Benachrichtigungen (z.B. 3600 → "1h")
local function FormatDuration(seconds)
    if seconds == 0 then return "permanent" end
    if seconds < 60  then return seconds .. "s" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. "h" end
    return math.floor(seconds / 86400) .. "d"
end

-- ── !exclude ─────────────────────────────────────────────────
NexusAdmin.RegisterCommand("exclude", {
    description = "Schließt einen Spieler für eine bestimmte Zeit aus (Ban).",
    permission  = "ban",
    args = {
        { name = "ziel",  type = "player", required = true  },
        { name = "dauer", type = "string", required = true  },   -- z.B. "7d"
        { name = "grund", type = "string", required = false },
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

        -- Immunität: Admins können keine gleichrangigen/höheren bannen
        if not NexusAdmin.CanTarget(caller, target) then
            NexusAdmin.SendNotify(caller, {
                text = target:Nick() .. " ist immun gegen diesen Befehl.",
                icon = "error", duration = 4,
            })
            return
        end

        local duration = ParseDuration(args[2])
        local grund    = args[3] or "Kein Grund angegeben"
        local steamId  = target:SteamID64()
        local nick     = target:Nick()

        -- In Datenbank speichern
        local ok = NexusAdmin.DB.AddExclusion(steamId, grund, caller:Nick(), duration)

        if not ok then
            NexusAdmin.SendNotify(caller, {
                text = "Datenbankfehler. Prüfe die Server-Konsole.",
                icon = "error", duration = 4,
            })
            return
        end

        -- Spieler mit Begründung kicken
        local durStr  = FormatDuration(duration)
        target:Kick(string.format(
            "[NexusAdmin] Du wurdest ausgeschlossen.\nGrund: %s\nDauer: %s",
            grund, durStr
        ))

        -- Benachrichtigungen
        NexusAdmin.SendNotify(caller, {
            text     = nick .. " ausgeschlossen | " .. durStr .. " | " .. grund,
            icon     = "success", duration = 5,
        })

        NexusAdmin.NotifyAdmins(
            caller:Nick() .. " hat " .. nick .. " ausgeschlossen ("
                .. durStr .. "): " .. grund,
            Color(255, 80, 80)
        )

        NexusAdmin.Log(string.format(
            "EXCLUDE: %s (%s) | Dauer: %s | Grund: %s | Von: %s",
            nick, steamId, durStr, grund, caller:Nick()
        ), "CMD")
    end,
})

-- ── !drop ────────────────────────────────────────────────────
NexusAdmin.RegisterCommand("drop", {
    description = "Entfernt einen Spieler sofort vom Server (Kick, kein Ban).",
    permission  = "kick",
    args = {
        { name = "ziel",  type = "player", required = true  },
        { name = "grund", type = "string", required = false },
    },

    callback = function(caller, args)
        local targets = NexusAdmin.ResolveTargets(args[1], caller)

        if #targets == 0 then
            NexusAdmin.SendNotify(caller, {
                text = "Spieler nicht gefunden: " .. tostring(args[1]),
                icon = "error", duration = 4,
            })
            return
        end

        local grund   = args[2] or "Kein Grund angegeben"
        local dropped = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end
            if target == caller     then continue end

            if not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text     = target:Nick() .. " ist immun.",
                    icon     = "warning", duration = 3,
                })
                continue
            end

            table.insert(dropped, target:Nick())
            target:Kick("[NexusAdmin] Du wurdest entfernt: " .. grund)
        end

        if #dropped > 0 then
            local nameStr = table.concat(dropped, ", ")

            NexusAdmin.SendNotify(caller, {
                text     = "Entfernt: " .. nameStr .. " | " .. grund,
                icon     = "success", duration = 4,
            })

            NexusAdmin.NotifyAdmins(
                caller:Nick() .. " hat entfernt: " .. nameStr .. " (" .. grund .. ")",
                Color(255, 160, 40)
            )

            NexusAdmin.Log(string.format("DROP: [%s] | Grund: %s | Von: %s",
                nameStr, grund, caller:Nick()), "CMD")
        end
    end,
})

-- ── !pardon ──────────────────────────────────────────────────
NexusAdmin.RegisterCommand("pardon", {
    description = "Hebt den Ausschluss einer SteamID auf (Unban).",
    permission  = "ban",
    args = {
        { name = "steamid", type = "string", required = true },
    },

    callback = function(caller, args)
        local steamId = args[1]

        if not steamId or steamId == "" then
            NexusAdmin.SendNotify(caller, {
                text = "Keine SteamID angegeben.",
                icon = "error", duration = 4,
            })
            return
        end

        -- Prüfen ob überhaupt ein Eintrag existiert
        local entry = NexusAdmin.DB.GetExclusion(steamId)
        if not entry then
            NexusAdmin.SendNotify(caller, {
                text = "Kein aktiver Ausschluss für: " .. steamId,
                icon = "warning", duration = 4,
            })
            return
        end

        local ok = NexusAdmin.DB.RemoveExclusion(steamId)

        if not ok then
            NexusAdmin.SendNotify(caller, {
                text = "Datenbankfehler. Prüfe die Server-Konsole.",
                icon = "error", duration = 4,
            })
            return
        end

        NexusAdmin.SendNotify(caller, {
            text     = "Ausschluss aufgehoben für: " .. steamId,
            icon     = "success", duration = 4,
        })

        NexusAdmin.NotifyAdmins(
            caller:Nick() .. " hat Ausschluss aufgehoben für: " .. steamId,
            Color(72, 199, 142)
        )

        NexusAdmin.Log(string.format("PARDON: %s | Von: %s",
            steamId, caller:Nick()), "CMD")
    end,
})

-- ── !promote ─────────────────────────────────────────────────
NexusAdmin.RegisterCommand("promote", {
    description = "Ändert den Rang eines Spielers.",
    permission  = "givrank",
    args = {
        { name = "ziel", type = "player", required = true },
        { name = "rang", type = "string", required = true },
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

        local newRankId = args[2] and args[2]:lower()
        if not newRankId or not NexusAdmin.Ranks[newRankId] then
            local validRanks = table.concat(table.GetKeys(NexusAdmin.Ranks), ", ")
            NexusAdmin.SendNotify(caller, {
                text     = "Ungültiger Rang. Verfügbar: " .. validRanks,
                icon     = "error", duration = 5,
            })
            return
        end

        -- Prüfen ob Caller den Ziel-Rang überhaupt vergeben darf
        -- (nur Ränge strikt unterhalb des eigenen Levels dürfen vergeben werden)
        local callerRankId = caller:GetNWString("na_rank", "user")
        local callerLevel  = NexusAdmin.GetRankLevel(callerRankId)
        local newRankLevel = NexusAdmin.GetRankLevel(newRankId)

        -- Niemand kann sich selbst auf einen niedrigeren Rang setzen
        if target == caller and newRankLevel < callerLevel then
            NexusAdmin.SendNotify(caller, {
                text = "Du kannst deinen eigenen Rang nicht senken.",
                icon = "warning", duration = 4,
            })
            return
        end

        if newRankLevel >= callerLevel then
            NexusAdmin.SendNotify(caller, {
                text = "Du kannst keine Ränge vergeben die deinem Level entsprechen oder höher sind.",
                icon = "error", duration = 5,
            })
            return
        end

        local oldRankId   = target:GetNWString("na_rank", "user")
        local oldRankName = (NexusAdmin.Ranks[oldRankId] or NexusAdmin.Ranks["user"]).name
        local newRankName = NexusAdmin.Ranks[newRankId].name

        local ok = NexusAdmin.SetPlayerRank(target, newRankId, caller:Nick())

        if not ok then
            NexusAdmin.SendNotify(caller, {
                text = "Fehler beim Speichern. Prüfe die Server-Konsole.",
                icon = "error", duration = 4,
            })
            return
        end

        NexusAdmin.SendNotify(target, {
            text     = "Dein Rang: " .. oldRankName .. " → " .. newRankName,
            color    = NexusAdmin.Ranks[newRankId].color,
            icon     = "info", duration = 6,
        })

        NexusAdmin.SendNotify(caller, {
            text     = target:Nick() .. ": " .. oldRankName .. " → " .. newRankName,
            icon     = "success", duration = 4,
        })

        NexusAdmin.NotifyAdmins(
            caller:Nick() .. " hat " .. target:Nick()
                .. " zu '" .. newRankName .. "' befördert.",
            NexusAdmin.Ranks[newRankId].color
        )

        NexusAdmin.Log(string.format("PROMOTE: %s → %s | Ziel: %s | Von: %s",
            oldRankName, newRankName, target:Nick(), caller:Nick()), "CMD")
    end,
})
