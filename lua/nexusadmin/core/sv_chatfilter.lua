-- ============================================================
--  NexusAdmin | sv_chatfilter.lua
--  Wortfilter mit automatischem Mute-System.
--
--  Ablauf wenn Blacklist-Wort erkannt wird:
--    1. Nachricht unterdrücken (return "" im PlayerSay-Hook)
--    2. Spieler für Config.ChatFilter.MuteDuration Sekunden muten
--    3. Admins per NexusAdmin_Notify informieren (mit exaktem Match)
--    4. Spieler bekommt eine Warnung angezeigt
--
--  Mute-Status:
--    Server-seitig in NexusAdmin._MutedPlayers gecacht.
--    Inhalt: { [userID] = expiresAt (unix-timestamp) }
--    0 = permanent gemuted (via !quiet permanent)
--
--  Befehle: !quiet <target> [dauer] · !unquiet <target>
--  Dauer-Format: 30s / 5m / 1h / 0 = permanent
-- ============================================================

-- Globaler Mute-Cache (wird nicht persistiert — Session-Daten)
NexusAdmin._MutedPlayers = NexusAdmin._MutedPlayers or {}

-- ── Config-Defaults (überschreibbar in sh_config.lua) ────────
NexusAdmin.Config.ChatFilter = NexusAdmin.Config.ChatFilter or {
    Enabled      = true,
    -- Blacklist-Wörter (case-insensitiv, Partial-Match)
    -- Server-Betreiber erweitern diese Liste in sh_config.lua
    Blacklist    = {
        "nigger", "nigga", "faggot", "chink", "spic",
        "kike", "tranny", "retard",
    },
    -- Dauer des automatischen Mutes in Sekunden (default: 5 Minuten)
    MuteDuration = 300,
    -- Maximale Länge einer Nachricht (0 = kein Limit)
    MaxLength    = 250,
}

-- ── Hilfsfunktionen ──────────────────────────────────────────

-- Prüft ob ein Spieler aktuell gemutet ist.
-- Berücksichtigt automatisch abgelaufene Mutes.
-- @param ply   Player – Zu prüfender Spieler
-- @return bool, number – (istGemutet, verbleibendeZeit in Sekunden)
function NexusAdmin.IsMuted(ply)
    if not IsValid(ply) then return false, 0 end

    local uid    = ply:UserID()
    local entry  = NexusAdmin._MutedPlayers[uid]
    if not entry then return false, 0 end

    local expires = entry.expires

    -- Permanent gemutet (0 = kein Ablauf)
    if expires == 0 then return true, 0 end

    -- Abgelaufen: Cache bereinigen
    if os.time() > expires then
        NexusAdmin._MutedPlayers[uid] = nil
        ply:SetNWBool("na_muted", false)
        return false, 0
    end

    return true, expires - os.time()
end

-- Mutet einen Spieler für eine bestimmte Dauer.
-- @param target     Player  – Zu mutender Spieler
-- @param duration   number  – Dauer in Sekunden (0 = permanent)
-- @param mutedBy    string  – Nick des mutenden Admins
function NexusAdmin.MutePlayer(target, duration, mutedBy)
    if not IsValid(target) then return end

    local uid     = target:UserID()
    local expires = (duration and duration > 0) and (os.time() + duration) or 0

    NexusAdmin._MutedPlayers[uid] = {
        expires  = expires,
        mutedBy  = mutedBy or "system",
        mutedAt  = os.time(),
    }

    -- NWBool damit das Scoreboard/UI den Mute-Status anzeigen kann
    target:SetNWBool("na_muted", true)

    -- Spieler informieren
    local durStr = (duration and duration > 0)
        and math.ceil(duration / 60) .. " Minute(n)"
        or  "permanent"

    NexusAdmin.SendNotify(target, {
        text     = "Du wurdest für " .. durStr .. " zum Schweigen gebracht.",
        icon     = "warning",
        duration = 6,
    })

    -- Timer für automatisches Unmute anlegen (nur bei zeitlichem Mute)
    if duration and duration > 0 then
        local timerName = "NexusAdmin_Unmute_" .. uid
        timer.Create(timerName, duration, 1, function()
            -- Nochmal prüfen ob Spieler noch online und noch gemutet
            if not IsValid(target) then return end
            local stillMuted, _ = NexusAdmin.IsMuted(target)
            if not stillMuted  then return end

            NexusAdmin.UnmutePlayer(target, "system (Timer)")
        end)
    end

    NexusAdmin.Log(string.format("MUTE: %s (%s) für %ss | Von: %s",
        target:Nick(), target:SteamID64(),
        tostring(duration or "∞"),
        mutedBy or "system"
    ), "FILTER")
end

-- Hebt den Mute eines Spielers auf.
-- @param target   Player  – Zu entmutender Spieler
-- @param unmutedBy string – Nick des Admins
function NexusAdmin.UnmutePlayer(target, unmutedBy)
    if not IsValid(target) then return end

    local uid = target:UserID()
    NexusAdmin._MutedPlayers[uid] = nil
    target:SetNWBool("na_muted", false)

    -- Laufenden Timer abbrechen falls vorhanden
    local timerName = "NexusAdmin_Unmute_" .. uid
    if timer.Exists(timerName) then timer.Remove(timerName) end

    NexusAdmin.SendNotify(target, {
        text     = "Du wurdest entstummt.",
        icon     = "success",
        duration = 4,
    })

    NexusAdmin.Log(string.format("UNMUTE: %s (%s) | Von: %s",
        target:Nick(), target:SteamID64(),
        unmutedBy or "system"
    ), "FILTER")
end

-- Cache beim Disconnect bereinigen
hook.Add("PlayerDisconnected", "NexusAdmin_MuteCleanup", function(ply)
    local uid = ply:UserID()
    NexusAdmin._MutedPlayers[uid] = nil
    local timerName = "NexusAdmin_Unmute_" .. uid
    if timer.Exists(timerName) then timer.Remove(timerName) end
end)

-- ── Chatfilter-Hook ──────────────────────────────────────────
-- Hängt sich VOR dem bestehenden Command-Hook ein (Priorität über Hook-Name).
-- Der Command-Hook in sh_commands.lua verarbeitet !-Befehle.
-- Dieser Hook prüft normale Nachrichten auf Blacklist-Treffer.
hook.Add("PlayerSay", "NexusAdmin_ChatFilter", function(ply, text)
    if not IsValid(ply) then return end

    -- Befehle nicht filtern (fangen den !-Prefix)
    if text:sub(1, 1) == NexusAdmin.Config.ChatPrefix then return end

    local cfg = NexusAdmin.Config.ChatFilter

    -- ── Mute-Check ───────────────────────────────────────────
    local muted, remaining = NexusAdmin.IsMuted(ply)
    if muted then
        local timeStr = (remaining > 0)
            and string.format("(noch %ds)", math.ceil(remaining))
            or  "(permanent)"

        NexusAdmin.SendNotify(ply, {
            text     = "Du bist stumm geschaltet " .. timeStr .. ". Deine Nachricht wurde blockiert.",
            icon     = "error",
            duration = 3,
        })
        return ""  -- Nachricht unterdrücken
    end

    -- ── Maximale Länge ───────────────────────────────────────
    if cfg.MaxLength > 0 and #text > cfg.MaxLength then
        NexusAdmin.SendNotify(ply, {
            text     = string.format("Nachricht zu lang (%d/%d Zeichen).", #text, cfg.MaxLength),
            icon     = "warning",
            duration = 3,
        })
        return ""
    end

    -- ── Blacklist-Scan ───────────────────────────────────────
    if not cfg.Enabled then return end

    local lowerText = text:lower()
    local matched   = nil

    for _, word in ipairs(cfg.Blacklist) do
        if lowerText:find(word:lower(), 1, true) then
            matched = word
            break
        end
    end

    if not matched then return end  -- Keine Treffer → normal weiter

    -- ── Treffer: Mute + Admin-Benachrichtigung ───────────────
    NexusAdmin.MutePlayer(ply, cfg.MuteDuration, "system (auto-filter)")

    -- Admins mit Details informieren
    NexusAdmin.NotifyAdmins(
        string.format("[CHATFILTER] %s: '%s' (Treffer: '%s') → Auto-Mute %ds",
            ply:Nick(), text, matched, cfg.MuteDuration),
        Color(255, 200, 40)
    )

    -- Aktion als anonyme Notice broadcasten
    NexusAdmin.AnnounceAction("system", ply:Nick(), NexusAdmin.Notice.MUTE,
        "Automatische Stummschaltung")

    NexusAdmin.Log(string.format(
        "CHATFILTER: %s (%s) | Nachricht: '%s' | Treffer: '%s'",
        ply:Nick(), ply:SteamID64(), text, matched
    ), "FILTER")

    return ""  -- Nachricht unterdrücken
end)

-- ── !quiet – Manueller Mute ──────────────────────────────────
NexusAdmin.RegisterCommand("quiet", {
    description = "Stummt einen Spieler für eine bestimmte Zeit.",
    permission  = "kick",
    args = {
        { name = "ziel",  type = "player", required = true  },
        { name = "dauer", type = "string", required = false },
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

        -- Dauer parsen (nutzt ParseDuration aus sv_cmd_management wenn vorhanden)
        local rawDur  = args[2] or "5m"
        local duration
        if rawDur == "0" or rawDur == "perm" or rawDur == "permanent" then
            duration = 0
        else
            local val, unit = rawDur:match("^(%d+)([smhd]?)$")
            val = tonumber(val) or 300
            if unit == "s"     then duration = val
            elseif unit == "m" then duration = val * 60
            elseif unit == "h" then duration = val * 3600
            elseif unit == "d" then duration = val * 86400
            else                    duration = val end
        end

        local grund = args[3] or "Kein Grund angegeben"
        local muted = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            if not NexusAdmin.CanTarget(caller, target) then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist immun.", icon = "warning", duration = 3,
                })
                continue
            end

            NexusAdmin.MutePlayer(target, duration, caller:Nick())
            table.insert(muted, target:Nick())

            NexusAdmin.AnnounceAction(caller, target:Nick(), NexusAdmin.Notice.MUTE, grund)
        end

        if #muted > 0 then
            local durStr = duration == 0
                and "permanent"
                or  math.ceil(duration / 60) .. "m"

            NexusAdmin.SendNotify(caller, {
                text = table.concat(muted, ", ") .. " gemutet (" .. durStr .. ")",
                icon = "success", duration = 4,
            })
        end
    end,
})

-- ── !unquiet – Manueller Unmute ──────────────────────────────
NexusAdmin.RegisterCommand("unquiet", {
    description = "Hebt den Mute eines Spielers auf.",
    permission  = "kick",
    args = {
        { name = "ziel", type = "player", required = true },
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

        local unmuted = {}

        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end

            local wasMuted, _ = NexusAdmin.IsMuted(target)
            if not wasMuted then
                NexusAdmin.SendNotify(caller, {
                    text = target:Nick() .. " ist nicht gemutet.",
                    icon = "warning", duration = 3,
                })
                continue
            end

            NexusAdmin.UnmutePlayer(target, caller:Nick())
            table.insert(unmuted, target:Nick())

            NexusAdmin.AnnounceAction(caller, target:Nick(), NexusAdmin.Notice.UNMUTE)
        end

        if #unmuted > 0 then
            NexusAdmin.SendNotify(caller, {
                text = table.concat(unmuted, ", ") .. " entstummt.",
                icon = "success", duration = 4,
            })
        end
    end,
})
