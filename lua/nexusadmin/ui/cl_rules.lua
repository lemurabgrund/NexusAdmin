-- ============================================================
--  NexusAdmin | cl_rules.lua
--  F1-Regel-Menü – Glassmorphism-Design, dynamisch aus Config.
--
--  Öffnen: F1-Taste
--  Inhalt: NexusAdmin.Config.Rules (sh_config.lua)
-- ============================================================

local _rulesFrame = nil

-- ── Regel-Fenster öffnen ─────────────────────────────────────
local function OpenRulesMenu()
    if IsValid(_rulesFrame) then
        _rulesFrame:Remove()
        return
    end

    local T       = NexusAdmin.Theme
    local rules   = NexusAdmin.Config.Rules or {}
    local W, H    = 560, 560
    local HDR_H   = 70
    local BTN_H   = 48
    local PAD     = 12

    local frame = vgui.Create("DPanel")
    _rulesFrame = frame

    frame:SetSize(W, H)
    frame:SetPos(ScrW() * 0.5 - W * 0.5, ScrH() * 0.5 - H * 0.5)
    frame:MakePopup()

    frame._alpha = 0
    frame.Paint = function(self, w, h)
        self._alpha = math.Approach(self._alpha, 255, FrameTime() * 800)
        local a = self._alpha

        T.DrawBlur(self, T.BlurStrength)
        draw.RoundedBox(10, 0, 0, w, h,
            Color(12, 13, 18, math.floor(a * 0.97)))
        draw.RoundedBoxEx(10, 1, 1, w - 2, HDR_H,
            Color(255, 255, 255, math.floor(a * 0.03)), true, true, false, false)
        T.DrawBorder(0, 0, w, h,
            Color(0, 210, 255, math.floor(a * 0.55)), 10)
    end

    -- ── Header ───────────────────────────────────────────────
    local header = vgui.Create("DPanel", frame)
    header:SetPos(0, 0)
    header:SetSize(W, HDR_H)
    header.Paint = function(self, w, h)
        draw.SimpleText("SERVER REGELN", T.Fonts.Large,
            w * 0.5, h * 0.5 - 8,
            Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Bitte lies und befolge alle Regeln dieses Servers.", T.Fonts.Nexus_Small,
            w * 0.5, h * 0.5 + 16,
            Color(80, 100, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Trennlinie
        surface.SetDrawColor(0, 210, 255, 25)
        surface.DrawRect(PAD * 2, h - 1, w - PAD * 4, 1)
    end

    -- ── Scroll-Bereich ────────────────────────────────────────
    local scrollH = H - HDR_H - BTN_H - PAD * 2
    local scroll  = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(PAD, HDR_H + PAD)
    scroll:SetSize(W - PAD * 2, scrollH)
    scroll.Paint = function() end

    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    function sbar:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30))
    end
    function sbar.btnUp:Paint()   end
    function sbar.btnDown:Paint() end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(0, 210, 255, 130))
    end

    local list = vgui.Create("DListLayout", scroll)
    list:SetWide(W - PAD * 2 - 8)
    list:DockPadding(0, 4, 0, 4)

    -- ── Regel-Boxen ───────────────────────────────────────────
    for i, ruleText in ipairs(rules) do
        -- Höhe dynamisch: ~38 Zeichen pro Zeile bei Medium-Font
        local lines   = math.max(1, math.ceil(#ruleText / 46))
        local boxH    = 16 + lines * 22 + 20

        local ruleBox = vgui.Create("DPanel", list)
        ruleBox:SetTall(boxH + 8)
        ruleBox:SetWide(W - PAD * 2 - 8)
        ruleBox:DockMargin(0, 0, 0, 6)

        local num     = tostring(i)
        local numW    = 32   -- Breite der Nummer-Pill

        ruleBox.Paint = function(self, w, h)
            -- Hintergrund-Box
            draw.RoundedBox(8, 0, 4, w, h - 8,
                Color(18, 20, 30, 210))
            T.DrawBorder(0, 4, w, h - 8,
                Color(0, 210, 255, 28), 8)

            -- Nummern-Pill
            draw.RoundedBox(6, 10, 4 + math.floor((h - 8) * 0.5) - 14, numW, 28,
                Color(0, 210, 255, 30))
            draw.SimpleText(num, T.Fonts.Medium,
                10 + numW * 0.5, 4 + math.floor((h - 8) * 0.5),
                Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Regel-Text (manueller Wrap)
            local maxW  = w - numW - 30
            local words = string.Explode(" ", ruleText)
            local line  = ""
            local lineY = 4 + 12

            surface.SetFont(T.Fonts.Medium)
            for _, word in ipairs(words) do
                local test = line == "" and word or (line .. " " .. word)
                local tw   = surface.GetTextSize(test)
                if tw > maxW and line ~= "" then
                    draw.SimpleText(line, T.Fonts.Medium,
                        numW + 20, lineY,
                        Color(200, 218, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    lineY = lineY + 22
                    line  = word
                else
                    line = test
                end
            end
            if line ~= "" then
                draw.SimpleText(line, T.Fonts.Medium,
                    numW + 20, lineY,
                    Color(200, 218, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
        ruleBox:SetMouseInputEnabled(false)
    end

    -- ── "Gelesen & Verstanden"-Button ─────────────────────────
    local btnY  = H - BTN_H - PAD + 4
    local btnW  = 220
    local btnX  = W * 0.5 - btnW * 0.5
    local btn   = vgui.Create("DButton", frame)
    btn:SetPos(btnX, btnY)
    btn:SetSize(btnW, BTN_H - 8)
    btn:SetText("")
    btn._hv = 0
    btn.Paint = function(self, w, h)
        self._hv = math.Approach(self._hv,
            self:IsHovered() and 1 or 0, FrameTime() * 8)
        draw.RoundedBox(8, 0, 0, w, h,
            Color(0, 210, 255, math.floor(Lerp(self._hv, 40, 95))))
        T.DrawBorder(0, 0, w, h,
            Color(0, 210, 255, math.floor(Lerp(self._hv, 80, 200))), 8)
        draw.SimpleText("✔  GELESEN & VERSTANDEN", T.Fonts.Nexus_Small,
            w * 0.5, h * 0.5,
            Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        surface.PlaySound("buttons/button14.wav")
        frame:Remove()
    end
end

-- ── F1-Keybinding ─────────────────────────────────────────────
hook.Add("PlayerButtonDown", "NexusAdmin_RulesKey", function(ply, btn)
    if ply ~= LocalPlayer() then return end
    if btn == KEY_F1 then
        OpenRulesMenu()
    end
end)
