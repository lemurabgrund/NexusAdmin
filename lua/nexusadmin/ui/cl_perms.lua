-- ============================================================
--  NexusAdmin | cl_perms.lua
--  Permissions-UI – Rang-Vergabe über ein UI.
--
--  Nur für hohe Ränge (superadmin) zugänglich.
--  Zeigt alle Online-Spieler, erlaubt Rang-Änderung per Dropdown.
--  Änderung wird via !setrank weitergeleitet (nutzt bestehende
--  Server-Logik inkl. DB-Persistenz).
-- ============================================================

local PERMS_W = 540
local PERMS_H = 500

function NexusAdmin.OpenPermsUI()
    local myRank = NexusAdmin._RankCache and NexusAdmin._RankCache[LocalPlayer():SteamID64()] or "user"
    if not NexusAdmin.RankHasPermission(myRank, "givrank") then
        chat.AddText(Color(255, 50, 80), "[NexusAdmin] Kein Zugriff – nur Superadmins.")
        return
    end

    if IsValid(NexusAdmin._PermsFrame) then
        NexusAdmin._PermsFrame:Remove()
    end

    local T = NexusAdmin.Theme

    local frame = vgui.Create("DPanel")
    NexusAdmin._PermsFrame = frame
    frame:SetSize(PERMS_W, PERMS_H)
    frame:SetPos(ScrW() * 0.5 - PERMS_W * 0.5, ScrH() * 0.5 - PERMS_H * 0.5)
    frame:MakePopup()

    frame._alpha = 0
    frame.Paint = function(self, w, h)
        self._alpha = math.Approach(self._alpha, 255, FrameTime() * 800)
        local a = self._alpha

        T.DrawBlur(self, T.BlurStrength)
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 12, 18, math.floor(a * 0.96)))
        draw.RoundedBoxEx(10, 1, 1, w - 2, math.floor(h * 0.14),
            Color(255, 255, 255, math.floor(a * 0.04)), true, true, false, false)
        T.DrawBorder(0, 0, w, h, Color(160, 80, 255, math.floor(a * 0.5)), 10)

        draw.SimpleText("PERMISSIONS", T.Fonts.Title,
            w * 0.5, 26, Color(160, 80, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(Color(160, 80, 255, 30))
        surface.DrawRect(16, 50, w - 32, 1)
    end

    -- Schließen
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(PERMS_W - 38, 8)
    closeBtn:SetSize(30, 30)
    closeBtn:SetText("")
    closeBtn._hv = 0
    closeBtn.Paint = function(self, w, h)
        self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 50, 80, math.floor(self._hv * 60)))
        draw.SimpleText("✕", T.Fonts.Body, w * 0.5, h * 0.5,
            Color(200, 80, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Remove() end

    -- ── Info-Label ────────────────────────────────────────────
    local infoLbl = vgui.Create("DPanel", frame)
    infoLbl:SetPos(16, 56)
    infoLbl:SetSize(PERMS_W - 32, 24)
    infoLbl.Paint = function(self, w, h)
        draw.SimpleText(
            "Rang-Änderungen gelten sofort und werden in der Datenbank gespeichert.",
            T.Fonts.Small, 0, h * 0.5, Color(80, 100, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- ── Scroll-Liste ──────────────────────────────────────────
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(16, 86)
    scroll:SetSize(PERMS_W - 32, PERMS_H - 96)
    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    function sbar:Paint(w, h)     draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30)) end
    function sbar.btnUp:Paint()   end
    function sbar.btnDown:Paint() end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(160, 80, 255, 120))
    end

    -- Rang-Optionen sammeln (sortiert nach Level aufsteigend)
    local rankOptions = {}
    for id, rankData in pairs(NexusAdmin.Ranks or {}) do
        rankOptions[#rankOptions + 1] = { id = id, name = rankData.name, level = rankData.level or 0 }
    end
    table.sort(rankOptions, function(a, b) return a.level < b.level end)

    -- Spieler-Karten aufbauen
    local players = player.GetAll()
    table.sort(players, function(a, b) return a:Nick() < b:Nick() end)

    for _, ply in ipairs(players) do
        if not IsValid(ply) then continue end

        local row = vgui.Create("DPanel", scroll)
        row:SetSize(scroll:GetWide() - 8, 54)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)

        local currentRankId = NexusAdmin._RankCache and NexusAdmin._RankCache[ply:SteamID64()] or "user"
        local currentRank   = NexusAdmin.Ranks[currentRankId] or {}
        local rankCol       = currentRank.color or Color(120, 140, 160)

        row.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(22, 24, 34, 220))
            draw.RoundedBox(4, 0, 6, 3, h - 12, rankCol)

            -- Avatar-Bereich
            draw.SimpleText(ply:Nick(), T.Fonts.Body,
                50, h * 0.5 - 6, Color(220, 235, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(ply:SteamID(), T.Fonts.Small,
                50, h * 0.5 + 8, Color(70, 90, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- Avatar
        local av = vgui.Create("AvatarImage", row)
        av:SetPos(6, 7)
        av:SetSize(38, 38)
        av:SetPlayer(ply, 32)

        -- Rang-Dropdown
        local combo = vgui.Create("DComboBox", row)
        combo:SetPos(row:GetWide() - 200, 11)
        combo:SetSize(192, 32)
        combo:SetFont(T.Fonts.Small)
        combo:SetValue(currentRank.name or "User")

        combo.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20, 22, 30, 220))
            T.DrawBorder(0, 0, w, h, Color(160, 80, 255, 60), 6)
            draw.SimpleText(self:GetValue(), T.Fonts.Small,
                10, h * 0.5, Color(220, 235, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("▼", T.Fonts.Small,
                w - 14, h * 0.5, Color(160, 80, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        for _, opt in ipairs(rankOptions) do
            combo:AddChoice(opt.name, opt.id)
        end

        combo.OnSelect = function(self, index, value, data)
            local newRankId = data
            if newRankId == currentRankId then return end

            Derma_Query(
                string.format("Rang von %s auf '%s' setzen?", ply:Nick(), value),
                "Rang ändern",
                "Ja", function()
                    LocalPlayer():ConCommand("say !setrank " .. ply:Nick() .. " " .. newRankId .. "\n")
                    currentRankId = newRankId
                    local rd = NexusAdmin.Ranks[newRankId] or {}
                    rankCol = rd.color or Color(120, 140, 160)
                    self:SetValue(rd.name or newRankId)
                end,
                "Abbrechen", function()
                    self:SetValue(currentRank.name or "User")
                end
            )
        end
    end

    -- Leer-State
    if #players == 0 then
        local empty = vgui.Create("DPanel", scroll)
        empty:SetSize(scroll:GetWide() - 8, 60)
        empty:Dock(TOP)
        empty.Paint = function(self, w, h)
            draw.SimpleText("Keine Spieler online.", T.Fonts.Body,
                w * 0.5, h * 0.5, Color(80, 100, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

-- ── ConCommand ────────────────────────────────────────────────
concommand.Add("na_perms", function()
    NexusAdmin.OpenPermsUI()
end)
