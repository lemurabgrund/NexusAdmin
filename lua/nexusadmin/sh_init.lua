-- ============================================================
--  NexusAdmin | sh_init.lua
--  Zentraler Loader – wird von sv_load.lua und cl_load.lua
--  aufgerufen. Lädt alle Module in der richtigen Reihenfolge.
-- ============================================================

NexusAdmin = NexusAdmin or {}
NexusAdmin.Version = "1.3.0"  -- Phase 3: PermaProps, Config-UI, DarkRP-Integration

-- Hilfsfunktion: Gibt den Realm-Präfix einer Datei zurück.
-- Dateien mit "sv_" laufen nur Server-seitig,
-- "cl_" nur Client-seitig, "sh_" auf beiden Seiten.
local function GetRealm(filename)
    if filename:sub(1, 3) == "sv_" then return "server"
    elseif filename:sub(1, 3) == "cl_" then return "client"
    else return "shared" end
end

-- Lädt eine einzelne Datei und sendet sie bei Bedarf an Clients.
local function LoadFile(path)
    local realm = GetRealm(path:match("([^/]+)$"))

    if realm == "server" and SERVER then
        include(path)
    elseif realm == "client" then
        if SERVER then
            AddCSLuaFile(path)    -- Datei für Client freigeben
        else
            include(path)         -- Client lädt sie selbst
        end
    elseif realm == "shared" then
        if SERVER then AddCSLuaFile(path) end
        include(path)
    end
end

-- Reihenfolge ist wichtig: Abhängigkeiten zuerst laden.
local moduleOrder = {
    "nexusadmin/core/sh_config.lua",
    "nexusadmin/core/sh_utils.lua",
    "nexusadmin/core/sh_ranks.lua",
    "nexusadmin/core/sh_commands.lua",
    "nexusadmin/core/sv_database.lua",
    "nexusadmin/core/sv_networking.lua",
    "nexusadmin/core/sv_warning_system.lua",  -- benötigt sv_database + sv_networking
    -- Phase 1: Chat-Systeme
    "nexusadmin/core/sv_chat_notices.lua",    -- Anonymes Notice-System (vor Chatfilter)
    "nexusadmin/core/sv_chatfilter.lua",      -- Blacklist + Auto-Mute (benötigt sv_chat_notices)
    "nexusadmin/core/cl_networking.lua",
    "nexusadmin/core/cl_chat_notices.lua",    -- Client-Receiver für Notices/PM/AdminMsg
    -- Phase 2: Tickets (Server-Logik vor UI)
    "nexusadmin/core/sv_tickets.lua",
    -- UI (Glassmorphism-Theme zuerst, da alle anderen es referenzieren)
    "nexusadmin/ui/cl_theme.lua",
    "nexusadmin/ui/cl_menu.lua",
    "nexusadmin/ui/cl_playerlist.lua",
    -- Phase 2: UI-Module
    "nexusadmin/ui/cl_scoreboard.lua",    -- Custom Scoreboard
    "nexusadmin/ui/cl_tickets.lua",       -- Ticket-UI (Spieler + Admin)
    "nexusadmin/ui/cl_admintools.lua",    -- Admin-Zentrale (Bans/Warns/Tickets)
    "nexusadmin/ui/cl_perms.lua",         -- Permissions-UI
    -- Phase 3: PermaProps + Config + DarkRP
    "nexusadmin/core/sv_permaprops.lua",  -- PermaProp-System (Server)
    "nexusadmin/core/sv_config.lua",      -- Config-Update-Empfänger (Server)
    "nexusadmin/core/sv_darkrp.lua",      -- DarkRP-Integration (lädt via Initialize-Hook)
    "nexusadmin/ui/cl_permaprops.lua",    -- PermaProp C-Menü + Liste
    "nexusadmin/ui/cl_config_ui.lua",     -- Hybrid-Config-UI
}

-- Lade alle Kern-Module
for _, path in ipairs(moduleOrder) do
    LoadFile(path)
end

-- Lade alle Befehls-Dateien dynamisch aus dem commands/-Ordner.
-- So kann man neue Befehle hinzufügen, ohne sh_init.lua anzufassen.
if SERVER then
    local cmdFiles = file.Find("nexusadmin/commands/*.lua", "LUA")
    for _, filename in ipairs(cmdFiles) do
        LoadFile("nexusadmin/commands/" .. filename)
    end
end

print("[NexusAdmin] v" .. NexusAdmin.Version .. " geladen.")
