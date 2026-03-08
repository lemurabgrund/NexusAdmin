-- ============================================================
--  NexusAdmin | sh_ranks.lua
--  Leichtgewichtiges Rang-System mit Berechtigungs-Vererbung.
--
--  "level" bestimmt die Position in der Hierarchie:
--    Höherer Level = mehr Macht = kann niedrigere targeten.
--    Gleicher Level = gegenseitige Immunität.
--
--  "inherits" vererbt alle Permissions des Eltern-Rangs.
-- ============================================================

NexusAdmin.Ranks = NexusAdmin.Ranks or {}

-- ── Rang-Definitionen ────────────────────────────────────────

NexusAdmin.Ranks["user"] = {
    name        = "User",
    color       = Color(180, 180, 180),
    level       = 0,        -- Niedrigster Level: kein Admin-Zugang
    inherits    = nil,
    permissions = {},
}

NexusAdmin.Ranks["admin"] = {
    name        = "Admin",
    color       = Color(100, 180, 255),
    level       = 10,
    inherits    = "user",
    permissions = {
        ["kick"]       = true,
        ["teleport"]   = true,
        ["slay"]       = true,
        ["freeze"]     = true,
        ["spectate"]   = true,
        ["sethealth"]  = true,
        ["setarmor"]   = true,
        ["permaprops"] = true,
    },
}

NexusAdmin.Ranks["superadmin"] = {
    name        = "Superadmin",
    color       = Color(255, 100, 100),
    level       = 100,
    inherits    = "admin",
    permissions = {
        ["ban"]        = true,
        ["rcon"]       = true,
        ["givrank"]    = true,
        ["god"]        = true,
        ["jail"]       = true,
        ["superadmin"] = true,  -- Für Befehle die nur Superadmins ausführen dürfen
    },
}

-- ── Berechtigungs-Prüfung (rekursiv mit Vererbung) ───────────
-- Durchläuft die Vererbungskette bis zur Wurzel.
function NexusAdmin.RankHasPermission(rankId, permission)
    local rank = NexusAdmin.Ranks[rankId]
    if not rank then return false end

    if rank.permissions[permission] then return true end

    if rank.inherits then
        return NexusAdmin.RankHasPermission(rank.inherits, permission)
    end

    return false
end

-- Kurzform: Prüft ob ein Spieler eine Berechtigung hat.
-- SICHERHEIT: Berechtigungen basieren ausschließlich auf dem NexusAdmin-Rang.
-- Der GMod-native IsSuperAdmin()-Flag wird NICHT als Bypass akzeptiert,
-- da er durch andere Plugins (ULX, etc.) gesetzt sein könnte.
-- Ausnahme: Server-Konsole (kein gültiger Spieler-Ent) → immer true.
function NexusAdmin.PlayerHasPermission(ply, permission)
    -- Ungültiger Caller (z.B. Server-Konsole): immer erlaubt
    if not IsValid(ply) then return true end

    -- Spieler ohne permission-String → sicher verweigern
    if not permission or permission == "" then return false end

    -- "public" = Jeder darf den Befehl nutzen (z.B. !ticket)
    if permission == "public" then return true end

    -- Rang-basierte Prüfung (einzige Autorität)
    local rankId = ply:GetNWString("na_rank", "user")
    return NexusAdmin.RankHasPermission(rankId, permission)
end

-- ── Hierarchie-Vergleich ─────────────────────────────────────
-- Gibt den numerischen Level eines Rangs zurück.
-- Wird von NexusAdmin.CanTarget() in sh_utils.lua genutzt.
function NexusAdmin.GetRankLevel(rankId)
    local rank = NexusAdmin.Ranks[rankId]
    return rank and (rank.level or 0) or 0
end

-- Gibt true zurück wenn rankA streng höher ist als rankB.
-- "Streng höher" = kann die andere Person targeten.
function NexusAdmin.RankOutranks(rankIdA, rankIdB)
    return NexusAdmin.GetRankLevel(rankIdA) > NexusAdmin.GetRankLevel(rankIdB)
end
