-- ============================================================
--  NexusAdmin | sv_cmd_setrank.lua
--  Weist einem Spieler einen neuen Rang zu.
--  Schreibt in die Datenbank und broadcastet die Änderung.
-- ============================================================

NexusAdmin.RegisterCommand("setrank", {
    description = "Weist einem Spieler einen neuen Rang zu.",
    permission  = "givrank",   -- Nur Superadmins (sh_ranks.lua)
    args = {
        { name = "spieler", type = "player", required = true },
        { name = "rang",    type = "string", required = true },
    },

    callback = function(caller, args)
        -- ── Eingaben validieren ──────────────────────────────
        local target = NexusAdmin.FindPlayer(args[1])
        if not IsValid(target) then
            NexusAdmin.SendNotify(caller, {
                text     = "Spieler nicht gefunden: " .. tostring(args[1]),
                icon     = "error",
                duration = 4,
            })
            return
        end

        local newRankId = args[2] and args[2]:lower()
        if not newRankId or not NexusAdmin.Ranks[newRankId] then
            -- Verfügbare Ränge auflisten damit der Admin weiß was möglich ist
            local validRanks = table.concat(table.GetKeys(NexusAdmin.Ranks), ", ")
            NexusAdmin.SendNotify(caller, {
                text     = "Ungültiger Rang. Verfügbar: " .. validRanks,
                icon     = "error",
                duration = 5,
            })
            return
        end

        -- ── Selbst-Degradierung verhindern ───────────────────
        local callerLevel  = NexusAdmin.GetRankLevel(caller:GetNWString("na_rank", "user"))
        local newRankLevel = NexusAdmin.GetRankLevel(newRankId)

        if target == caller and newRankLevel < callerLevel then
            NexusAdmin.SendNotify(caller, {
                text     = "Du kannst deinen eigenen Rang nicht senken.",
                icon     = "warning",
                duration = 4,
            })
            return
        end

        local oldRankId   = target:GetNWString("na_rank", "user")
        local oldRankName = (NexusAdmin.Ranks[oldRankId] or NexusAdmin.Ranks["user"]).name
        local newRankName = NexusAdmin.Ranks[newRankId].name

        -- ── Rang setzen (DB + NWString + Broadcast) ──────────
        local success = NexusAdmin.SetPlayerRank(target, newRankId, caller:Nick())

        if not success then
            NexusAdmin.SendNotify(caller, {
                text     = "Fehler beim Speichern. Prüfe die Server-Konsole.",
                icon     = "error",
                duration = 4,
            })
            return
        end

        -- Ziel-Spieler benachrichtigen
        NexusAdmin.SendNotify(target, {
            text     = "Dein Rang wurde geändert: " .. oldRankName .. " → " .. newRankName,
            color    = NexusAdmin.Ranks[newRankId].color,
            icon     = "info",
            duration = 6,
        })

        -- Ausführenden Admin bestätigen
        NexusAdmin.SendNotify(caller, {
            text     = target:Nick() .. ": " .. oldRankName .. " → " .. newRankName,
            icon     = "success",
            duration = 4,
        })

        -- Alle anderen Admins informieren (Audit-Trail)
        NexusAdmin.NotifyAdmins(
            caller:Nick() .. " hat " .. target:Nick()
                .. " den Rang '" .. newRankName .. "' gegeben.",
            NexusAdmin.Ranks[newRankId].color
        )
    end,
})
