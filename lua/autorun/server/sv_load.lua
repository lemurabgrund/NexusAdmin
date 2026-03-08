-- ============================================================
--  NexusAdmin | autorun/server/sv_load.lua
--  Server-Einstiegspunkt.
--  GMod lädt alle Dateien in autorun/server/ automatisch.
-- ============================================================

-- sh_init.lua muss zuerst per AddCSLuaFile an den Client gesendet werden,
-- bevor der Client es via cl_load.lua includen kann.
AddCSLuaFile("nexusadmin/sh_init.lua")
include("nexusadmin/sh_init.lua")
