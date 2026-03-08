-- ============================================================
--  NexusAdmin | sv_permaprops.lua
--  PermaProps – Persistente Requisiten.
--
--  Speichert: Model · Pos · Ang · Material · Color
--  Datenbank: nexusadmin_permaprops
--
--  Spawn: InitPostEntity → alle DB-Einträge spawnen
--  Schutz:
--    CanDeleteEntity → verhindert physischen Lösch-Versuch
--    PostCleanupMap  → re-spawnt nach Server-Cleanup
-- ============================================================

util.AddNetworkString("NexusAdmin_AddPermaProp")
util.AddNetworkString("NexusAdmin_RemovePermaProp")
util.AddNetworkString("NexusAdmin_PermaPropList")

-- ── Datenbank-Init ────────────────────────────────────────────
sql.Query([[
    CREATE TABLE IF NOT EXISTS nexusadmin_permaprops (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        model       TEXT    NOT NULL,
        pos_x       REAL    NOT NULL,
        pos_y       REAL    NOT NULL,
        pos_z       REAL    NOT NULL,
        ang_p       REAL    NOT NULL,
        ang_y       REAL    NOT NULL,
        ang_r       REAL    NOT NULL,
        material    TEXT    DEFAULT '',
        color_r     INTEGER DEFAULT 255,
        color_g     INTEGER DEFAULT 255,
        color_b     INTEGER DEFAULT 255,
        color_a     INTEGER DEFAULT 255,
        frozen      INTEGER DEFAULT 1,
        created_by  TEXT    NOT NULL,
        created_at  INTEGER NOT NULL
    )
]])

-- Laufender Cache: entity → db_id
NexusAdmin._PermaPropEnts = NexusAdmin._PermaPropEnts or {}  -- { [ent] = id }
NexusAdmin._PermaPropIds  = NexusAdmin._PermaPropIds  or {}  -- { [id]  = ent }

-- ── Prop spawnen (intern) ─────────────────────────────────────
local function SpawnPermaProp(row)
    local model = row.model
    if not util.IsValidModel(model) then return nil end

    local pos = Vector(
        tonumber(row.pos_x), tonumber(row.pos_y), tonumber(row.pos_z)
    )
    local ang = Angle(
        tonumber(row.ang_p), tonumber(row.ang_y), tonumber(row.ang_r)
    )

    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then return nil end

    ent:SetModel(model)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:Activate()

    -- Material
    local mat = row.material or ""
    if mat ~= "" then ent:SetMaterial(mat) end

    -- Farbe
    ent:SetColor(Color(
        tonumber(row.color_r) or 255,
        tonumber(row.color_g) or 255,
        tonumber(row.color_b) or 255,
        tonumber(row.color_a) or 255
    ))

    -- Einfrieren
    if tostring(row.frozen) == "1" then
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
    end

    -- Als PermaProp markieren
    ent:SetNWBool("na_permaprop", true)
    ent:SetNWInt("na_permaprop_id", tonumber(row.id))

    local id = tonumber(row.id)
    NexusAdmin._PermaPropEnts[ent] = id
    NexusAdmin._PermaPropIds[id]   = ent

    return ent
end

-- ── Alle gespeicherten Props laden ────────────────────────────
local function SpawnAllPermaProps()
    -- Alte Entities aus Cache entfernen
    for ent, _ in pairs(NexusAdmin._PermaPropEnts) do
        if IsValid(ent) then ent:Remove() end
    end
    NexusAdmin._PermaPropEnts = {}
    NexusAdmin._PermaPropIds  = {}

    local rows = sql.Query("SELECT * FROM nexusadmin_permaprops ORDER BY id ASC")
    if not rows then return end

    for _, row in ipairs(rows) do
        SpawnPermaProp(row)
    end

    NexusAdmin.Log(string.format("PERMAPROPS: %d Props geladen.", #rows), "PERMAPROP")
end

-- ── PermaProp hinzufügen ──────────────────────────────────────
function NexusAdmin.AddPermaProp(ent, adminNick)
    if not IsValid(ent) then return false, "Ungültige Entity." end
    if not ent:GetModel()    then return false, "Kein Model." end

    -- Bereits PermaProp?
    if NexusAdmin._PermaPropEnts[ent] then
        return false, "Entity ist bereits ein PermaProp."
    end

    local pos   = ent:GetPos()
    local ang   = ent:GetAngles()
    local mat   = ent:GetMaterial() or ""
    local col   = ent:GetColor()
    local phys  = ent:GetPhysicsObject()
    local frozen = (IsValid(phys) and not phys:IsMotionEnabled()) and 1 or 0

    sql.Query(string.format(
        "INSERT INTO nexusadmin_permaprops (model,pos_x,pos_y,pos_z,ang_p,ang_y,ang_r,material,color_r,color_g,color_b,color_a,frozen,created_by,created_at) " ..
        "VALUES (%s,%f,%f,%f,%f,%f,%f,%s,%d,%d,%d,%d,%d,%s,%d)",
        sql.SQLStr(ent:GetModel()),
        pos.x, pos.y, pos.z,
        ang.p, ang.y, ang.r,
        sql.SQLStr(mat),
        col.r, col.g, col.b, col.a,
        frozen,
        sql.SQLStr(adminNick or "system"),
        os.time()
    ))

    local id = tonumber(sql.QueryValue("SELECT last_insert_rowid()"))
    ent:SetNWBool("na_permaprop", true)
    ent:SetNWInt("na_permaprop_id", id)
    NexusAdmin._PermaPropEnts[ent] = id
    NexusAdmin._PermaPropIds[id]   = ent

    NexusAdmin.Log(string.format("PERMAPROP ADD: ID=%d Model=%s Von=%s",
        id, ent:GetModel(), adminNick or "system"), "PERMAPROP")

    return true, id
end

-- ── PermaProp entfernen (nach ID) ─────────────────────────────
function NexusAdmin.RemovePermaProp(id, adminNick)
    id = tonumber(id)
    if not id then return false end

    sql.Query("DELETE FROM nexusadmin_permaprops WHERE id = " .. id)

    local ent = NexusAdmin._PermaPropIds[id]
    if IsValid(ent) then
        ent:SetNWBool("na_permaprop", false)
        ent:Remove()
    end
    NexusAdmin._PermaPropIds[id] = nil
    if IsValid(ent) then
        NexusAdmin._PermaPropEnts[ent] = nil
    end

    NexusAdmin.Log(string.format("PERMAPROP REMOVE: ID=%d Von=%s",
        id, adminNick or "system"), "PERMAPROP")

    return true
end

-- ── Liste an Client senden ────────────────────────────────────
local function SendPermaPropList(ply)
    local rows = sql.Query("SELECT id, model, created_by, created_at FROM nexusadmin_permaprops ORDER BY id ASC") or {}

    net.Start("NexusAdmin_PermaPropList")
        net.WriteUInt(#rows, 16)
        for _, row in ipairs(rows) do
            net.WriteUInt(tonumber(row.id) or 0, 16)
            net.WriteString(row.model      or "")
            net.WriteString(row.created_by or "")
            net.WriteDouble(tonumber(row.created_at) or 0)
        end
    net.Send(ply)
end

-- ── Net-Receiver: PermaProp hinzufügen ───────────────────────
net.Receive("NexusAdmin_AddPermaProp", function(_, ply)
    if not IsValid(ply) then return end
    if not NexusAdmin.HasPermission(ply, "permaprops") then
        NexusAdmin.SendNotify(ply, { text = "Keine Berechtigung.", icon = "error", duration = 3 })
        return
    end

    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    local ok, result = NexusAdmin.AddPermaProp(ent, ply:Nick())
    if ok then
        NexusAdmin.SendNotify(ply, {
            text = string.format("PermaProp gespeichert (ID: %d).", result),
            icon = "success", duration = 4,
        })
    else
        NexusAdmin.SendNotify(ply, { text = result, icon = "warning", duration = 3 })
    end
end)

-- ── Net-Receiver: PermaProp entfernen ────────────────────────
net.Receive("NexusAdmin_RemovePermaProp", function(_, ply)
    if not IsValid(ply) then return end
    if not NexusAdmin.HasPermission(ply, "permaprops") then
        NexusAdmin.SendNotify(ply, { text = "Keine Berechtigung.", icon = "error", duration = 3 })
        return
    end

    local id = net.ReadUInt(16)
    local ok = NexusAdmin.RemovePermaProp(id, ply:Nick())
    NexusAdmin.SendNotify(ply, {
        text = ok and ("PermaProp #" .. id .. " entfernt.") or "PermaProp nicht gefunden.",
        icon = ok and "success" or "error",
        duration = 3,
    })
end)

-- ── Schutz: CanDeleteEntity ───────────────────────────────────
-- Verhindert, dass Admins PermaProps aus Versehen mit dem Physgun löschen.
hook.Add("CanDeleteEntity", "NexusAdmin_PermaPropProtect", function(ent)
    if NexusAdmin._PermaPropEnts[ent] then
        return false
    end
end)

-- ── Schutz: Physgun-Pickup für Nicht-Berechtigte ──────────────
hook.Add("PhysgunPickup", "NexusAdmin_PermaPropPickup", function(ply, ent)
    if not NexusAdmin._PermaPropEnts[ent] then return end
    if NexusAdmin.HasPermission(ply, "permaprops") then return true end
    return false
end)

-- ── Re-Spawn nach Map-Cleanup ─────────────────────────────────
hook.Add("PostCleanupMap", "NexusAdmin_RespawnPermaProps", function()
    -- Cache leeren (Entities wurden gelöscht)
    NexusAdmin._PermaPropEnts = {}
    NexusAdmin._PermaPropIds  = {}

    -- Kurze Verzögerung damit die Welt bereit ist
    timer.Simple(0.5, SpawnAllPermaProps)
end)

-- ── Initial: Props beim Server-Start spawnen ──────────────────
hook.Add("InitPostEntity", "NexusAdmin_LoadPermaProps", function()
    timer.Simple(1, SpawnAllPermaProps)
end)

-- ── !permaprop-Befehle ────────────────────────────────────────
NexusAdmin.RegisterCommand("pp", {
    description = "Speichert das anvisierten Prop als PermaProp.",
    permission  = "permaprops",
    args        = {},

    callback = function(caller, _)
        -- Traciert was der Caller anschaut
        local tr = caller:GetEyeTrace()
        local ent = tr.Entity

        if not IsValid(ent) or not ent:IsValid() then
            NexusAdmin.SendNotify(caller, {
                text = "Kein Prop anvisiert.", icon = "error", duration = 3,
            })
            return
        end

        if not ent:GetModel() then
            NexusAdmin.SendNotify(caller, {
                text = "Entity hat kein Model.", icon = "error", duration = 3,
            })
            return
        end

        local ok, result = NexusAdmin.AddPermaProp(ent, caller:Nick())
        if ok then
            NexusAdmin.SendNotify(caller, {
                text = string.format("PermaProp gespeichert (ID: %d).", result),
                icon = "success", duration = 4,
            })
        else
            NexusAdmin.SendNotify(caller, { text = result, icon = "warning", duration = 3 })
        end
    end,
})

NexusAdmin.RegisterCommand("ppremove", {
    description = "Entfernt das anvisierten PermaProp (Angabe der ID möglich).",
    permission  = "permaprops",
    args = {
        { name = "id", type = "number", required = false },
    },

    callback = function(caller, args)
        local id = tonumber(args[1])

        if not id then
            -- Tracieren
            local tr  = caller:GetEyeTrace()
            local ent = tr.Entity
            if IsValid(ent) and NexusAdmin._PermaPropEnts[ent] then
                id = NexusAdmin._PermaPropEnts[ent]
            end
        end

        if not id then
            NexusAdmin.SendNotify(caller, {
                text = "Kein PermaProp anvisiert. Nutze !ppremove <id>.",
                icon = "error", duration = 4,
            })
            return
        end

        local ok = NexusAdmin.RemovePermaProp(id, caller:Nick())
        NexusAdmin.SendNotify(caller, {
            text = ok and ("PermaProp #" .. id .. " entfernt.") or "PermaProp nicht gefunden.",
            icon = ok and "success" or "error", duration = 3,
        })
    end,
})

NexusAdmin.RegisterCommand("pplist", {
    description = "Listet alle gespeicherten PermaProps auf.",
    permission  = "permaprops",
    args        = {},

    callback = function(caller, _)
        SendPermaPropList(caller)
        NexusAdmin.SendNotify(caller, {
            text = "PermaProp-Liste gesendet. Öffne das Admin-Menü (F4).",
            icon = "info", duration = 4,
        })
    end,
})
