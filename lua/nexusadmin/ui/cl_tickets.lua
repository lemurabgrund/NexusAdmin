-- ============================================================
--  NexusAdmin | cl_tickets.lua
--  Client: Ticket-Erstellen-Dialog + Chat-Fenster + HUD.
--
--  Net-Messages:
--    NexusAdmin_TicketList            – Server → Client (Admin)
--    NexusAdmin_TicketCreate          – Client → Server (Player)
--    NexusAdmin_TicketAccept          – Client → Server (Admin)
--    NexusAdmin_TicketClose           – Client → Server (Admin)
--    NexusAdmin_TicketMessage         – bidirektional (Chat)
--    NexusAdmin_RequestTicketMessages – Client → Server
--    NexusAdmin_TicketMessages        – Server → Client (Historie)
--    NexusAdmin_MyTicketUpdate        – Server → Client (Ticket-Autor)
-- ============================================================

NexusAdmin._TicketCache      = {}
NexusAdmin._TicketChatFrames = {}   -- [ticketId] = DPanel-Referenz
NexusAdmin._MyTicket         = nil  -- Eigenes aktives Ticket {id,status,...}

-- ── Server triggert Client, das Ticket-Fenster zu öffnen ──────
net.Receive("NexusAdmin_OpenTicket", function()
    NexusAdmin.OpenMyTicket()
end)

-- ── Eigenes Ticket vom Server erhalten ───────────────────────
net.Receive("NexusAdmin_MyTicketUpdate", function()
    local id         = net.ReadUInt(16)
    local status     = net.ReadString()
    local reason     = net.ReadString()
    local authorSid  = net.ReadString()
    local authorName = net.ReadString()

    NexusAdmin._MyTicket = {
        id         = id,
        status     = status,
        reason     = reason,
        authorSid  = authorSid,
        authorName = authorName,
    }

    -- Chat-Fenster updaten falls offen (Status-Zeile)
    local frame = NexusAdmin._TicketChatFrames[id]
    if IsValid(frame) then
        frame._ticketStatus = status
    end
end)

-- ── Ticket-Liste vom Server empfangen (Admins) ───────────────
net.Receive("NexusAdmin_TicketList", function()
    local count = net.ReadUInt(16)
    NexusAdmin._TicketCache = {}

    for _ = 1, count do
        local t = {
            id         = net.ReadUInt(16),
            authorName = net.ReadString(),
            authorSid  = net.ReadString(),
            reason     = net.ReadString(),
            status     = net.ReadString(),
            acceptedBy = net.ReadString(),
            createdAt  = net.ReadDouble(),
        }
        NexusAdmin._TicketCache[#NexusAdmin._TicketCache + 1] = t
    end

    if IsValid(NexusAdmin._AdminToolsFrame) then
        if NexusAdmin.AdminTools_RebuildTickets then
            NexusAdmin.AdminTools_RebuildTickets()
        end
    end
end)

-- ── Eingehende Chat-Nachricht ─────────────────────────────────
net.Receive("NexusAdmin_TicketMessage", function()
    local id         = net.ReadUInt(16)
    local senderName = net.ReadString()
    local senderSid  = net.ReadString()
    local text       = net.ReadString()
    local time       = net.ReadDouble()
    local isAdmin    = net.ReadBool()

    local frame = NexusAdmin._TicketChatFrames[id]
    if IsValid(frame) and frame._AddMessage then
        frame._AddMessage(senderName, senderSid, text, isAdmin, time)
    end
end)

-- ── Nachrichtenhistorie empfangen ────────────────────────────
net.Receive("NexusAdmin_TicketMessages", function()
    local id    = net.ReadUInt(16)
    local count = net.ReadUInt(16)
    local msgs  = {}

    for _ = 1, count do
        msgs[#msgs + 1] = {
            senderName = net.ReadString(),
            senderSid  = net.ReadString(),
            text       = net.ReadString(),
            time       = net.ReadDouble(),
            isAdmin    = net.ReadBool(),
        }
    end

    local frame = NexusAdmin._TicketChatFrames[id]
    if not IsValid(frame) then return end

    for _, m in ipairs(msgs) do
        if frame._AddMessage then
            frame._AddMessage(m.senderName, m.senderSid, m.text, m.isAdmin, m.time)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  HUD: Aktives Ticket anzeigen (bottom-right)
-- ═══════════════════════════════════════════════════════════════
local HUD_W, HUD_H = 260, 48
local HUD_PAD_R    = 16
local HUD_PAD_B    = 16
local _hudAlpha    = 0
local _hudHover    = 0

hook.Add("HUDPaint", "NexusAdmin_TicketHUD", function()
    local t = NexusAdmin._MyTicket
    if not t or t.status == "closed" then
        _hudAlpha = math.Approach(_hudAlpha, 0, FrameTime() * 300)
        if _hudAlpha <= 0 then return end
    else
        _hudAlpha = math.Approach(_hudAlpha, 220, FrameTime() * 400)
    end

    if _hudAlpha <= 1 then return end

    local T   = NexusAdmin.Theme
    local x   = ScrW() - HUD_W - HUD_PAD_R
    local y   = ScrH() - HUD_H - HUD_PAD_B
    local a   = math.floor(_hudAlpha)

    local statusCol = (t and t.status == "accepted")
        and Color(50, 200, 130)
        or  Color(255, 200, 40)

    -- Hintergrund
    draw.RoundedBox(8, x, y, HUD_W, HUD_H,
        Color(12, 14, 22, a))

    -- Linker Akzent-Streifen
    draw.RoundedBox(8, x, y, 3, HUD_H, statusCol)

    -- Cyan-Rahmen
    if T and T.DrawBorder then
        T.DrawBorder(x, y, HUD_W, HUD_H, Color(0, 210, 255, math.floor(a * 0.4)), 8)
    end

    -- Texte
    local label = t and string.format("TICKET #%d", t.id) or "TICKET"
    local sub   = t and ("Status: " .. t.status:upper()) or ""

    draw.SimpleText(label, "NA_Font_NSmall",
        x + 14, y + 10, Color(0, 210, 255, a),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(sub, "NA_Font_NSmall",
        x + 14, y + 28, statusCol,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("Öffnen →", "NA_Font_NSmall",
        x + HUD_W - 10, y + HUD_H * 0.5,
        Color(50, 70, 90, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)

-- Klick auf HUD-Element öffnet Chat-Fenster
hook.Add("Think", "NexusAdmin_TicketHUD_Click", function()
    if _hudAlpha <= 10 then return end
    if not input.IsMouseDown(MOUSE_LEFT) then return end

    local mx, my  = gui.MousePos()
    local x       = ScrW() - HUD_W - HUD_PAD_R
    local y       = ScrH() - HUD_H - HUD_PAD_B

    if mx >= x and mx <= x + HUD_W and my >= y and my <= y + HUD_H then
        local t = NexusAdmin._MyTicket
        if t and t.status ~= "closed" then
            NexusAdmin.OpenTicketChat(t)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  OpenMyTicket – Chat öffnen oder Formular zeigen
-- ═══════════════════════════════════════════════════════════════
function NexusAdmin.OpenMyTicket()
    local t = NexusAdmin._MyTicket
    if t and t.status ~= "closed" then
        NexusAdmin.OpenTicketChat(t)
    else
        NexusAdmin.OpenTicketCreate()
    end
end

-- ═══════════════════════════════════════════════════════════════
--  Chat-Fenster öffnen
--  ticket = { id, authorName, authorSid, reason, status, ... }
-- ═══════════════════════════════════════════════════════════════
function NexusAdmin.OpenTicketChat(ticket)
    local T = NexusAdmin.Theme

    local existing = NexusAdmin._TicketChatFrames[ticket.id]
    if IsValid(existing) then existing:Remove() end

    local myRank   = LocalPlayer():GetNWString("na_rank", "user")
    local isAdmin  = NexusAdmin.RankHasPermission(myRank, "kick")
    local isAuthor = (LocalPlayer():SteamID64() == ticket.authorSid)

    if not isAdmin and not isAuthor then return end

    -- ── Dimensionen ───────────────────────────────────────────
    local W      = 500
    local H      = 520
    local HDR_H  = 60
    local BTN_H  = isAdmin and 42 or 0
    local INP_H  = 44

    local frame = vgui.Create("DPanel")
    NexusAdmin._TicketChatFrames[ticket.id] = frame
    frame._ticketStatus = ticket.status

    frame:SetSize(W, H)
    frame:SetPos(ScrW() * 0.5 - W * 0.5, ScrH() * 0.5 - H * 0.5)
    frame:MakePopup()

    frame._alpha = 0
    frame.Paint = function(self, w, h)
        self._alpha = math.Approach(self._alpha, 255, FrameTime() * 900)
        local a = self._alpha
        T.DrawBlur(self, T.BlurStrength)
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 13, 18, math.floor(a * 0.97)))
        draw.RoundedBoxEx(10, 1, 1, w - 2, HDR_H,
            Color(255, 255, 255, math.floor(a * 0.03)), true, true, false, false)
        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, math.floor(a * 0.5)), 10)
    end

    -- ── Header ───────────────────────────────────────────────
    local header = vgui.Create("DPanel", frame)
    header:SetPos(0, 0)
    header:SetSize(W, HDR_H)
    header.Paint = function(self, w, h)
        local st = frame._ticketStatus or ticket.status
        local statusCol = st == "open"     and Color(255, 200, 40)
                        or st == "accepted" and Color(50, 200, 130)
                        or                     Color(100, 100, 120)

        draw.SimpleText(
            string.format("TICKET #%d  –  %s", ticket.id, ticket.authorName),
            T.Fonts.Large, 16, h * 0.5 - 10,
            Color(0, 210, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(
            "Status: " .. st:upper(),
            T.Fonts.Nexus_Small, 16, h * 0.5 + 14,
            statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("✕", T.Fonts.Medium,
            w - 20, h * 0.5, Color(80, 100, 130),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(0, 210, 255, 20)
        surface.DrawRect(16, h - 1, w - 32, 1)
    end

    header:SetMouseInputEnabled(true)
    header.OnMousePressed = function(self, btn)
        if btn == MOUSE_LEFT then
            local mx = self:CursorPos()
            if mx > W - 40 then frame:Remove() end
        end
    end

    -- ── Admin-Buttons ─────────────────────────────────────────
    local contentTopY = HDR_H + 4
    if isAdmin then
        local btnY = HDR_H + 4
        contentTopY = btnY + BTN_H + 4

        local function MakeActionBtn(label, x, bw, col, onclick)
            local btn = vgui.Create("DButton", frame)
            btn:SetPos(x, btnY)
            btn:SetSize(bw, BTN_H - 4)
            btn:SetText("")
            btn._hv = 0
            btn.Paint = function(self, w, h)
                self._hv = math.Approach(self._hv,
                    self:IsHovered() and 1 or 0, FrameTime() * 8)
                draw.RoundedBox(8, 0, 0, w, h,
                    Color(col.r, col.g, col.b, math.floor(Lerp(self._hv, 35, 75))))
                T.DrawBorder(0, 0, w, h,
                    Color(col.r, col.g, col.b, math.floor(Lerp(self._hv, 55, 130))), 8)
                draw.SimpleText(label, T.Fonts.Nexus_Small, w * 0.5, h * 0.5, col,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = onclick
            return btn
        end

        MakeActionBtn("⤴  SUMMON", 10, 136, Color(0, 210, 255), function()
            LocalPlayer():ConCommand("say !summon " .. ticket.authorName .. "\n")
        end)

        if (frame._ticketStatus or ticket.status) == "open" then
            MakeActionBtn("✔  ANNEHMEN", 152, 136, Color(50, 200, 130), function()
                net.Start("NexusAdmin_TicketAccept")
                    net.WriteUInt(ticket.id, 16)
                net.SendToServer()
                frame._ticketStatus = "accepted"
            end)
        end

        MakeActionBtn("✖  SCHLIESSEN", W - 148, 136, Color(255, 60, 90), function()
            Derma_StringRequest(
                "Ticket #" .. ticket.id .. " schließen",
                "Abschluss-Grund (optional):", "",
                function(reason)
                    net.Start("NexusAdmin_TicketClose")
                        net.WriteUInt(ticket.id, 16)
                        net.WriteString(reason or "")
                    net.SendToServer()
                    frame:Remove()
                end)
        end)
    end

    -- ── Ursprünglicher Grund ──────────────────────────────────
    local REASON_H = 44
    local reasonBox = vgui.Create("DPanel", frame)
    reasonBox:SetPos(10, contentTopY)
    reasonBox:SetSize(W - 20, REASON_H)
    reasonBox.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(16, 20, 32, 200))
        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, 22), 8)
        draw.SimpleText("Anliegen:", T.Fonts.Small,
            12, 8, Color(0, 210, 255, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(ticket.reason, T.Fonts.Small,
            12, 24, Color(170, 190, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local scrollY = contentTopY + REASON_H + 6
    local scrollH = H - scrollY - INP_H - 6

    -- ── Chat-Scroll-Bereich ───────────────────────────────────
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(10, scrollY)
    scroll:SetSize(W - 20, scrollH)
    scroll.Paint = function() end  -- kein Standard-Hintergrund

    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    function sbar:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30))
    end
    function sbar.btnUp:Paint()   end
    function sbar.btnDown:Paint() end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(0, 210, 255, 120))
    end

    local list = vgui.Create("DListLayout", scroll)
    list:SetWide(W - 28)
    list:DockPadding(4, 4, 4, 4)

    -- ── Nachricht hinzufügen ──────────────────────────────────
    --   senderSid  → bestimmt links/rechts (eigene = rechts)
    --   isAdmin    → Farbe der Bubble (blau vs. grau)
    frame._AddMessage = function(senderName, senderSid, text, msgIsAdmin, timestamp)
        local isMine    = (senderSid == LocalPlayer():SteamID64())
        local BMAX      = W - 100
        local BPAD      = 10

        local lines   = math.max(1, math.ceil(#text / 38))
        local bubbleH = 22 + lines * 22 + BPAD * 2

        local row = vgui.Create("DPanel", list)
        row:SetTall(bubbleH + 22)
        row:SetWide(W - 28)
        row:DockMargin(0, 2, 0, 2)

        -- Eigene Nachrichten: dunkelblau rechts
        -- Fremde Nachrichten: dunkelgrau links
        local bubbleCol = isMine
            and Color(18, 36, 72, 225)
            or  Color(26, 30, 44, 210)
        local borderCol = isMine
            and Color(0, 150, 255, 90)
            or  Color(80, 90, 110, 55)
        local nameCol   = msgIsAdmin
            and Color(60, 160, 255)
            or  Color(130, 148, 170)
        local textCol   = Color(210, 225, 240)
        local timeStr   = os.date("%H:%M", timestamp)

        row.Paint = function(self, w, h)
            local bw = math.min(BMAX, w - 20)
            local bx = isMine and (w - bw - 6) or 6

            draw.RoundedBox(8, bx, 18, bw, bubbleH, bubbleCol)
            T.DrawBorder(bx, 18, bw, bubbleH, borderCol, 8)

            draw.SimpleText(senderName, T.Fonts.Nexus_Small,
                bx + 10, 2, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(timeStr, T.Fonts.Nexus_Small,
                bx + bw - 6, 2, Color(55, 70, 90),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            -- Automatischer Zeilenumbruch (Medium-Font, 22px Zeilenabstand)
            local maxW  = bw - BPAD * 2
            local words = string.Explode(" ", text)
            local line  = ""
            local lineY = 20 + BPAD
            for _, word in ipairs(words) do
                local test = line == "" and word or (line .. " " .. word)
                surface.SetFont(T.Fonts.Medium)
                local tw = surface.GetTextSize(test)
                if tw > maxW and line ~= "" then
                    draw.SimpleText(line, T.Fonts.Medium,
                        bx + BPAD, lineY, textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    lineY = lineY + 22
                    line  = word
                else
                    line = test
                end
            end
            if line ~= "" then
                draw.SimpleText(line, T.Fonts.Medium,
                    bx + BPAD, lineY, textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
        row:SetMouseInputEnabled(false)

        -- Sound-Feedback + Auto-scroll
        surface.PlaySound("buttons/blip1.wav")
        timer.Simple(0, function()
            if IsValid(scroll) then
                scroll:GetVBar():SetScroll(scroll:GetVBar():GetMax())
            end
        end)
    end

    -- ── Eingabe-Zeile ─────────────────────────────────────────
    local isClosed = (ticket.status == "closed")
    local inputY   = H - INP_H - 2

    local input = vgui.Create("DTextEntry", frame)
    input:SetPos(10, inputY)
    input:SetSize(W - 86, INP_H - 4)
    input:SetFont(T.Fonts.Medium)
    input:SetMaximumCharCount(300)
    input:SetAllowNonAsciiCharacters(true)
    input:SetEnabled(not isClosed)
    input:SetPlaceholderText(isClosed and "Ticket geschlossen." or "Nachricht eingeben…")
    input.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 23, 33, 230))
        T.DrawBorder(0, 0, w, h,
            self:IsEditing() and Color(0, 210, 255, 100) or Color(0, 210, 255, 28), 8)
        self:DrawTextEntryText(
            Color(220, 235, 245), Color(0, 210, 255, 100), Color(0, 210, 255))
    end

    local function DoSend()
        local text = input:GetValue():Trim()
        if text == "" then return end
        if (frame._ticketStatus or ticket.status) == "closed" then return end
        net.Start("NexusAdmin_TicketMessage")
            net.WriteUInt(ticket.id, 16)
            net.WriteString(text)
        net.SendToServer()
        input:SetValue("")
    end
    input.OnEnter = DoSend

    local sendBtn = vgui.Create("DButton", frame)
    sendBtn:SetPos(W - 72, inputY)
    sendBtn:SetSize(62, INP_H - 4)
    sendBtn:SetText("")
    sendBtn._hv = 0
    sendBtn.Paint = function(self, w, h)
        self._hv = math.Approach(self._hv,
            self:IsHovered() and 1 or 0, FrameTime() * 8)
        draw.RoundedBox(8, 0, 0, w, h,
            Color(0, 210, 255, math.floor(Lerp(self._hv, 40, 90))))
        T.DrawBorder(0, 0, w, h,
            Color(0, 210, 255, math.floor(Lerp(self._hv, 70, 160))), 8)
        draw.SimpleText("▶", T.Fonts.Medium, w * 0.5, h * 0.5,
            Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    sendBtn.DoClick = DoSend

    -- Nachrichtenhistorie vom Server anfordern
    net.Start("NexusAdmin_RequestTicketMessages")
        net.WriteUInt(ticket.id, 16)
    net.SendToServer()
end

-- ═══════════════════════════════════════════════════════════════
--  Ticket erstellen (Spieler-Seite)
-- ═══════════════════════════════════════════════════════════════
function NexusAdmin.OpenTicketCreate()
    local T = NexusAdmin.Theme

    if IsValid(NexusAdmin._TicketCreateFrame) then
        NexusAdmin._TicketCreateFrame:Remove()
    end

    local W, H = 440, 200
    local frame = vgui.Create("DPanel")
    NexusAdmin._TicketCreateFrame = frame

    frame:SetSize(W, H)
    frame:SetPos(ScrW() * 0.5 - W * 0.5, ScrH() * 0.5 - H * 0.5)
    frame:MakePopup()

    frame._alpha = 0
    frame.Paint = function(self, w, h)
        self._alpha = math.Approach(self._alpha, 255, FrameTime() * 900)
        local a = self._alpha
        T.DrawBlur(self, T.BlurStrength)
        draw.RoundedBox(8, 0, 0, w, h, Color(15, 15, 20, math.floor(a * 0.96)))
        draw.RoundedBoxEx(8, 1, 1, w - 2, math.floor(h * 0.35),
            Color(255, 255, 255, math.floor(a * 0.04)), true, true, false, false)
        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, math.floor(a * 0.5)), 8)
        draw.SimpleText("TICKET ERSTELLEN", T.Fonts.Title,
            w * 0.5, 20, Color(0, 210, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Beschreibe dein Anliegen:", T.Fonts.Small,
            16, 48, Color(120, 140, 160, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local input = vgui.Create("DTextEntry", frame)
    input:SetPos(16, 60)
    input:SetSize(W - 32, 80)
    input:SetMultiline(true)
    input:SetMaximumCharCount(300)
    input:SetFont(T.Fonts.Body)
    input:SetPlaceholderText("Beschreibe dein Problem...")
    input.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 22, 30, 220))
        T.DrawBorder(0, 0, w, h,
            self:IsEditing() and Color(0, 210, 255, 80) or Color(0, 210, 255, 30), 8)
        self:DrawTextEntryText(Color(220, 235, 245), Color(0, 210, 255, 100), Color(0, 210, 255))
    end

    local function MakeBtn(label, x, col, callback)
        local btn = vgui.Create("DButton", frame)
        btn:SetPos(x, H - 44)
        btn:SetSize(130, 32)
        btn:SetText("")
        btn._hover = 0
        btn.Paint = function(self, w, h)
            self._hover = math.Approach(self._hover,
                self:IsHovered() and 1 or 0, FrameTime() * 8)
            draw.RoundedBox(8, 0, 0, w, h,
                Color(col.r, col.g, col.b, math.floor(Lerp(self._hover, 40, 80))))
            T.DrawBorder(0, 0, w, h,
                Color(col.r, col.g, col.b, math.floor(Lerp(self._hover, 60, 140))), 8)
            draw.SimpleText(label, T.Fonts.Small, w * 0.5, h * 0.5,
                Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = callback
        return btn
    end

    MakeBtn("SENDEN", 16, Color(0, 210, 255), function()
        local text = input:GetValue():Trim()
        if text == "" then return end
        net.Start("NexusAdmin_TicketCreate")
            net.WriteString(text)
        net.SendToServer()
        frame:Remove()
    end)

    MakeBtn("ABBRECHEN", 160, Color(255, 50, 80), function()
        frame:Remove()
    end)
end

-- ── F4-Keybind: Ticket-Fenster öffnen ────────────────────────
hook.Add("PlayerButtonDown", "NexusAdmin_TicketKey", function(ply, btn)
    if ply ~= LocalPlayer() then return end
    if btn ~= KEY_F4 then return end
    NexusAdmin.OpenMyTicket()
end)
