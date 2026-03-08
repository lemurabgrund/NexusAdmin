-- ============================================================
--  NexusAdmin | sv_config.lua
--  Server-seitiger Empfänger für Config-UI-Änderungen.
--  (Getrennt von cl_config_ui.lua wegen Realm-Trennung)
-- ============================================================

util.AddNetworkString("NexusAdmin_UpdateConfig")

net.Receive("NexusAdmin_UpdateConfig", function(_, ply)
    if not IsValid(ply) or not NexusAdmin.PlayerHasPermission(ply, "superadmin") then return end

    local key   = net.ReadString()
    local value = net.ReadString()

    -- Whitelist erlaubter GMod-Convars
    local allowedConvars = {
        sbox_maxprops           = true,
        sbox_maxragdolls        = true,
        sbox_maxeffects         = true,
        sbox_maxballoons        = true,
        sbox_maxnpcs            = true,
        sbox_godmode            = true,
        sbox_playershurtplayers = true,
        sv_gravity              = true,
        sv_airaccelerate        = true,
        mp_friendlyfire         = true,
    }

    if allowedConvars[key] then
        RunConsoleCommand(key, value)
        NexusAdmin.Log(string.format("CONFIG: Convar '%s' = '%s' von %s",
            key, value, ply:Nick()), "CONFIG")
        NexusAdmin.SendNotify(ply, {
            text     = string.format("'%s' auf '%s' gesetzt.", key, value),
            icon     = "success",
            duration = 3,
        })
        return
    end

    -- NexusAdmin-eigene Konfiguration (Laufzeit-Update)
    local cfg = NexusAdmin.Config
    if key == "na_chatfilter_enabled" then
        cfg.ChatFilter.Enabled = (value == "1")
    elseif key == "na_chatfilter_maxlength" then
        cfg.ChatFilter.MaxLength = math.Clamp(tonumber(value) or 250, 0, 500)
    elseif key == "na_chatfilter_mute_duration" then
        cfg.ChatFilter.MuteDuration = math.Clamp(tonumber(value) or 300, 30, 86400)
    elseif key == "na_warn_threshold" then
        cfg.WarnThreshold = math.Clamp(tonumber(value) or 4, 1, 20)
    elseif key == "na_log_to_file" then
        cfg.LogToFile = (value == "1")
    elseif key == "na_max_notifications" then
        cfg.MaxNotifications = math.Clamp(tonumber(value) or 5, 1, 10)
    end

    NexusAdmin.Log(string.format("CONFIG: '%s' = '%s' von %s", key, value, ply:Nick()), "CONFIG")
    NexusAdmin.SendNotify(ply, {
        text     = string.format("Konfiguration: %s = %s", key, value),
        icon     = "success",
        duration = 3,
    })
end)
