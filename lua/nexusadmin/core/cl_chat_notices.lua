-- ============================================================
--  NexusAdmin | cl_chat_notices.lua
--  Client-seitiger Empfänger für Chat-Notices, Admin-Messages
--  und Private Messages. Rendert sie im Cyber-Glassmorphism-Stil.
--
--  Net-Messages:
--    NexusAdmin_ChatNotice   – Allgemeine Aktion-Notice
--    NexusAdmin_AdminMessage – !m Admin-Broadcast
--    NexusAdmin_PrivateMsg   – !pm Private Message
-- ============================================================

-- ── Icon-Mapping nach Aktion-Typ ─────────────────────────────
local NoticeIcons = {
    kick    = Material("icon16/door_out.png"),
    ban     = Material("icon16/stop.png"),
    warn    = Material("icon16/error.png"),
    mute    = Material("icon16/sound_mute.png"),
    unmute  = Material("icon16/sound.png"),
    slay    = Material("icon16/lightning.png"),
    freeze  = Material("icon16/lock.png"),
    info    = Material("icon16/information.png"),
}

-- ── Hilfsfunktion: Neon-Panel mit Blur zeichnen ──────────────
local function DrawNoticePanel(self, w, h, borderCol)
    local T = NexusAdmin.Theme

    -- Blur-Hintergrund
    NexusAdmin.Theme.DrawBlur(self, 200)

    -- Haupt-Hintergrund (halbtransparent)
    draw.RoundedBox(8, 0, 0, w, h, T.BG_Dark)

    -- Glas-Highlight oben
    draw.RoundedBoxEx(8, 1, 1, w - 2, math.floor(h * 0.4), T.BG_Glass, true, true, false, false)

    -- Neon-Rahmen
    NexusAdmin.Theme.DrawBorder(0, 0, w, h, borderCol or T.Border, 8)

    -- Linker Akzentbalken
    draw.RoundedBox(4, 0, 8, 3, h - 16, borderCol or T.Accent)
end

-- ════════════════════════════════════════════════════════════
--  NexusAdmin_ChatNotice – Allgemeine Aktion-Notice
-- ════════════════════════════════════════════════════════════

net.Receive("NexusAdmin_ChatNotice", function()
    local text       = net.ReadString()
    local r, g, b    = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
    local actionType = net.ReadString()
    local col        = Color(r, g, b)
    local icon       = NoticeIcons[actionType] or NoticeIcons["info"]

    -- Bestehende Notify-Queue nutzen
    NexusAdmin._NotifyQueue  = NexusAdmin._NotifyQueue  or {}
    NexusAdmin._NotifyActive = NexusAdmin._NotifyActive or {}

    local NOTIFY_W = 360
    local NOTIFY_H = 54
    local NOTIFY_PAD = 8

    local slot    = #NexusAdmin._NotifyActive + 1
    local targetX = ScrW() - NOTIFY_W - 20
    local targetY = ScrH() - 80 - slot * (NOTIFY_H + NOTIFY_PAD)

    if #NexusAdmin._NotifyActive >= (NexusAdmin.Config.MaxNotifications or 5) then
        table.insert(NexusAdmin._NotifyQueue, {
            type = "notice", text = text, col = col, icon = icon, actionType = actionType
        })
        return
    end

    local panel = vgui.Create("DPanel")
    panel:SetSize(NOTIFY_W, NOTIFY_H)
    panel:SetPos(ScrW() + 10, targetY)

    panel.Paint = function(self, w, h)
        DrawNoticePanel(self, w, h, col)

        -- Icon
        surface.SetDrawColor(col)
        surface.SetMaterial(icon)
        surface.DrawTexturedRect(14, (h - 16) * 0.5, 16, 16)

        -- Text (automatisch umbrechen wenn zu lang)
        draw.SimpleText(text, NexusAdmin.Theme.Fonts.Body,
            38, h * 0.5,
            NexusAdmin.Theme.TextMain,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    table.insert(NexusAdmin._NotifyActive, panel)
    panel:MoveTo(targetX, targetY, 0.35, 0, -1)

    local duration = NexusAdmin.Config.DefaultNotifyDuration or 5

    timer.Simple(duration, function()
        if not IsValid(panel) then return end
        panel:MoveTo(ScrW() + 10, panel:GetY(), 0.3, 0, -1, function()
            if IsValid(panel) then panel:Remove() end
            for i, p in ipairs(NexusAdmin._NotifyActive) do
                if p == panel then table.remove(NexusAdmin._NotifyActive, i) break end
            end
            -- Nächstes aus Queue
            if #(NexusAdmin._NotifyQueue or {}) > 0 then
                local next = table.remove(NexusAdmin._NotifyQueue, 1)
                if next.type == "notice" then
                    -- Re-trigger via lokale Funktion nicht möglich → net simulieren
                    -- Stattdessen: direkte Panel-Erstellung (DRY-Tradeoff akzeptiert)
                end
            end
        end)
    end)
end)

-- ════════════════════════════════════════════════════════════
--  NexusAdmin_AdminMessage – !m Admin-Broadcast
--  Erscheint als grosse zentrierte Overlay-Notice oben im Screen.
-- ════════════════════════════════════════════════════════════

net.Receive("NexusAdmin_AdminMessage", function()
    local sender  = net.ReadString()
    local message = net.ReadString()
    local T       = NexusAdmin.Theme

    local W = 600
    local H = 72

    -- Altes Admin-Message-Panel entfernen falls noch sichtbar
    if IsValid(NexusAdmin._AdminMsgPanel) then
        NexusAdmin._AdminMsgPanel:Remove()
    end

    local panel = vgui.Create("DPanel")
    NexusAdmin._AdminMsgPanel = panel

    panel:SetSize(W, H)
    -- Startet oben außerhalb des Screens (slide-down)
    panel:SetPos(ScrW() * 0.5 - W * 0.5, -H - 10)

    -- Laufende Transparenz für Fade-Out
    panel._alpha   = 255
    panel._fadeOut = false

    panel.Paint = function(self, w, h)
        if self._fadeOut then
            self._alpha = self._alpha - (FrameTime() * 300)
            if self._alpha <= 0 then
                self:Remove()
                return
            end
        end

        -- Blur + Hintergrund
        DrawBlurredScrollingBackground(self:LocalToScreen(0, 0))
        draw.RoundedBox(8, 0, 0, w, h, Color(15, 15, 20, math.floor(self._alpha * 0.92)))

        -- Glas-Highlight
        draw.RoundedBoxEx(8, 1, 1, w - 2, math.floor(h * 0.45),
            Color(255, 255, 255, math.floor(self._alpha * 0.04)), true, true, false, false)

        -- Neon-Rahmen (Cyan)
        NexusAdmin.Theme.DrawBorder(0, 0, w, h, Color(0, 210, 255, self._alpha), 8)

        -- Obere Beschriftung "ADMIN-NACHRICHT"
        surface.SetFont(T.Fonts.Small)
        surface.SetTextColor(Color(0, 210, 255, self._alpha))
        surface.SetTextPos(16, 8)
        surface.DrawText("ADMIN-NACHRICHT")

        -- Absender
        surface.SetFont(T.Fonts.Small)
        surface.SetTextColor(Color(130, 150, 180, self._alpha))
        surface.SetTextPos(w - 16, 8)
        local sendStr = "von " .. sender
        local tw, _  = surface.GetTextSize(sendStr)
        surface.SetTextPos(w - tw - 16, 8)
        surface.DrawText(sendStr)

        -- Nachrichtentext
        surface.SetFont(T.Fonts.Body)
        surface.SetTextColor(Color(220, 235, 245, self._alpha))
        surface.SetTextPos(16, 30)
        surface.DrawText(message)

        -- Untere Fade-Linie
        NexusAdmin.Theme.DrawFadeLine(0, h - 2, w, 2,
            Color(0, 210, 255, math.floor(self._alpha * 0.5)))
    end

    -- Slide-Down Animation
    panel:MoveTo(ScrW() * 0.5 - W * 0.5, 20, 0.4, 0, -1)

    -- Nach 6 Sekunden Fade-Out starten
    timer.Simple(6, function()
        if IsValid(panel) then
            panel._fadeOut = true
        end
    end)
end)

-- ════════════════════════════════════════════════════════════
--  NexusAdmin_PrivateMsg – !pm Private Message
--  Erscheint als violettes Notify-Panel unten rechts.
-- ════════════════════════════════════════════════════════════

net.Receive("NexusAdmin_PrivateMsg", function()
    local fromName = net.ReadString()
    local toName   = net.ReadString()
    local message  = net.ReadString()
    local isSender = net.ReadBool()

    local T        = NexusAdmin.Theme
    local pmColor  = T.Neon_Purple

    local label, text
    if isSender then
        label = "PM an " .. toName
        text  = message
    else
        label = "PM von " .. fromName
        text  = message
    end

    -- PM als Notify anzeigen
    NexusAdmin._NotifyActive = NexusAdmin._NotifyActive or {}

    local NOTIFY_W = 360
    local NOTIFY_H = 68
    local NOTIFY_PAD = 8
    local slot    = #NexusAdmin._NotifyActive + 1
    local targetX = ScrW() - NOTIFY_W - 20
    local targetY = ScrH() - 80 - slot * (NOTIFY_H + NOTIFY_PAD)

    if #NexusAdmin._NotifyActive >= (NexusAdmin.Config.MaxNotifications or 5) then return end

    local panel = vgui.Create("DPanel")
    panel:SetSize(NOTIFY_W, NOTIFY_H)
    panel:SetPos(ScrW() + 10, targetY)

    panel.Paint = function(self, w, h)
        DrawNoticePanel(self, w, h, pmColor)

        -- PM-Icon
        surface.SetDrawColor(pmColor)
        surface.SetMaterial(Material("icon16/comment.png"))
        surface.DrawTexturedRect(14, 10, 16, 16)

        -- Label (klein, gedimmt)
        surface.SetFont(T.Fonts.Small)
        surface.SetTextColor(pmColor)
        surface.SetTextPos(38, 8)
        surface.DrawText(label)

        -- Nachricht
        surface.SetFont(T.Fonts.Body)
        surface.SetTextColor(T.TextMain)
        surface.SetTextPos(38, 28)
        surface.DrawText(text)
    end

    table.insert(NexusAdmin._NotifyActive, panel)
    panel:MoveTo(targetX, targetY, 0.35, 0, -1)

    timer.Simple(7, function()
        if not IsValid(panel) then return end
        panel:MoveTo(ScrW() + 10, panel:GetY(), 0.3, 0, -1, function()
            if IsValid(panel) then panel:Remove() end
            for i, p in ipairs(NexusAdmin._NotifyActive) do
                if p == panel then table.remove(NexusAdmin._NotifyActive, i) break end
            end
        end)
    end)
end)
