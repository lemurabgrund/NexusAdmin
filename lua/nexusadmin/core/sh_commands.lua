-- ============================================================
--  NexusAdmin | sh_commands.lua
--  Zentrale Registry für alle Befehle.
--  Befehle werden als Tabellen registriert – kein if-elseif.
-- ============================================================

NexusAdmin.Commands = NexusAdmin.Commands or {}

-- Registriert einen neuen Befehl.
-- @param name        string  – Befehlsname (z.B. "kick")
-- @param data        table   – Befehlsdaten (siehe Struktur unten)
function NexusAdmin.RegisterCommand(name, data)
    -- Pflichtfelder validieren
    assert(type(data.callback) == "function",
        "[NexusAdmin] Befehl '" .. name .. "' hat keine callback-Funktion!")
    assert(type(data.permission) == "string",
        "[NexusAdmin] Befehl '" .. name .. "' hat keine permission gesetzt!")

    NexusAdmin.Commands[name:lower()] = {
        name        = name,
        description = data.description or "Keine Beschreibung.",
        permission  = data.permission,
        args        = data.args or {},  -- Argumentdefinitionen für Autocomplete
        callback    = data.callback,
    }

    -- Konsolen-Befehl auf dem Server registrieren für Autocomplete
    if SERVER then
        concommand.Add("na_" .. name:lower(), function(ply, _, args)
            NexusAdmin.ExecuteCommand(ply, name:lower(), args)
        end, NexusAdmin.BuildAutocomplete(name:lower()))
    end

    print("[NexusAdmin] Befehl registriert: !" .. name)
end

-- Führt einen registrierten Befehl aus und prüft Berechtigungen.
function NexusAdmin.ExecuteCommand(caller, name, args)
    local cmd = NexusAdmin.Commands[name:lower()]

    -- Existiert der Befehl überhaupt?
    if not cmd then
        if IsValid(caller) then
            caller:ChatPrint("[NexusAdmin] Unbekannter Befehl: !" .. name)
        end
        return
    end

    -- Berechtigung prüfen
    if not NexusAdmin.PlayerHasPermission(caller, cmd.permission) then
        if IsValid(caller) then
            caller:ChatPrint("[NexusAdmin] Keine Berechtigung für: !" .. name)
        end
        return
    end

    -- Ausführung loggen
    NexusAdmin.Log(string.format("Befehl: %s führt !%s aus | Args: %s",
        IsValid(caller) and caller:Nick() or "Konsole",
        name,
        table.concat(args or {}, ", ")
    ))

    -- Befehl ausführen
    cmd.callback(caller, args)
end

-- Erstellt eine Autocomplete-Funktion für concommand.Add.
-- Gibt eine Liste passender Spielernamen zurück.
function NexusAdmin.BuildAutocomplete(cmdName)
    return function(_, args)
        local suggestions = {}
        for _, ply in ipairs(player.GetAll()) do
            -- Schlägt Spielernamen vor, die zum eingetippten Text passen
            if ply:Nick():lower():find(args:lower(), 1, true) then
                table.insert(suggestions, "na_" .. cmdName .. " " .. ply:Nick())
            end
        end
        return suggestions
    end
end

-- Chat-Hook: Wandelt "!befehl arg1 arg2" in Befehlsaufrufe um.
if SERVER then
    hook.Add("PlayerSay", "NexusAdmin_ChatCommands", function(ply, text)
        if text:sub(1, 1) ~= NexusAdmin.Config.ChatPrefix then return end

        -- Text aufteilen: "!kick SpielerName grund" → {"kick","SpielerName","grund"}
        local parts   = string.Explode(" ", text:sub(2))
        local cmdName = table.remove(parts, 1):lower()

        NexusAdmin.ExecuteCommand(ply, cmdName, parts)

        -- Nachricht unterdrücken (nicht im Chat anzeigen)
        return ""
    end)
end
