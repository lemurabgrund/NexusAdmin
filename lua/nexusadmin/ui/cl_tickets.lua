-- ============================================================
--  NexusAdmin | cl_tickets.lua
--  Client: Ticket-Erstellen-Dialog + Chat-Fenster.
--
--  Net-Messages:
--    NexusAdmin_TicketList            – Server → Client (Admin)
--    NexusAdmin_TicketCreate          – Client → Server (Player)
--    NexusAdmin_TicketAccept          – Client → Server (Admin)
--    NexusAdmin_TicketClose           – Client → Server (Admin)
--    NexusAdmin_TicketMessage         – bidirektional (Chat)
--    NexusAdmin_RequestTicketMessages – Client → Server
--    NexusAdmin_TicketMessages        – Server → Client (Historie)
-- ============================================================

NexusAdmin._TicketCache      = {}
NexusAdmin._TicketChatFrames = {}   -- [ticketId] = DPanel-Referenz

-- ── Ticket-Liste vom Server empfangen ────────────────────────
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

    -- Falls Admin-Panel offen ist: neu aufbauen
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
        frame._AddMessage(senderName, text, isAdmin, time)
    end
end)

-- ── Nachrichtenhistorie empfangen (beim Öffnen des Chats) ─────
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
            frame._AddMessage(m.senderName, m.text, m.isAdmin, m.time)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  Chat-Fenster öffnen
--  ticket = { id, authorName, authorSid, reason, status, ... }
-- ═══════════════════════════════════════════════════════════════
function NexusAdmin.OpenTicketChat(ticket)
    local T = NexusAdmin.Theme

    -- Altes Fenster für dieses Ticket schließen
    local existing = NexusAdmin._TicketChatFrames[ticket.id]
    if IsValid(existing) then existing:Remove() end

    local myRank   = LocalPlayer():GetNWString("na_rank", "user")
    local isAdmin  = NexusAdmin.RankHasPermission(myRank, "kick")
    local isAuthor = (LocalPlayer():SteamID64() == ticket.authorSid)

    -- Nur Ticket-Ersteller und Admins dürfen den Chat sehen
    if not isAdmin and not isAuthor then return end

    -- ── Fenster-Dimensionen ───────────────────────────────────
    local W, H    = 500, 520
    local HDR_H   = 60     -- Header-Zeile
    local BTN_H   = 36     -- Button-Leiste
    local INP_H   = 44     -- Eingabezeile
    local CHAT_H  = H - HDR_H - BTN_H - INP_H - 10

    local frame = vgui.Create("DPanel")
    NexusAdmin._TicketChatFrames[ticket.id] = frame

    frame:SetSize(W, H)
    frame:SetPos(ScrW() * 0.5 - W * 0.5, ScrH() * 0.5 - H * 0.5)
    frame:MakePopup()

    frame._alpha = 0
    frame.Paint = function(self, w, h)
        self._alpha = math.Approach(self._alpha, 255, FrameTime() * 900)
        local a = self._alpha

        T.DrawBlur(self, T.BlurStrength)
        draw.RoundedBox(10, 0, 0, w, h,
            Color(12, 13, 18, math.floor(a * 0.97)))
        draw.RoundedBoxEx(10, 1, 1, w - 2, HDR_H,
            Color(255, 255, 255, math.floor(a * 0.03)), true, true, false, false)
        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, math.floor(a * 0.5)), 10)
    end

    -- ── Header ───────────────────────────────────────────────
    local header = vgui.Create("DPanel", frame)
    header:SetPos(0, 0)
    header:SetSize(W, HDR_H)
    header.Paint = function(self, w, h)
        local statusCol = ticket.status == "open"     and Color(255, 200,  40)
                        or ticket.status == "accepted" and Color(50,  200, 130)
                        or                                 Color(100, 100, 120)

        draw.SimpleText(
            string.format("TICKET #%d  –  %s", ticket.id, ticket.authorName),
            T.Fonts.Title, 16, h * 0.5 - 9,
            Color(0, 210, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText(
            "Status: " .. ticket.status:upper(),
            T.Fonts.Small, 16, h * 0.5 + 11,
            statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Schließen-Kreuz
        draw.SimpleText("✕", T.Fonts.Body,
            w - 20, h * 0.5,
            Color(80, 100, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        surface.SetDrawColor(0, 210, 255, 20)
        surface.DrawRect(16, h - 1, w - 32, 1)
    end

    -- Fenster per Klick auf Kreuz schließen
    header:SetMouseInputEnabled(true)
    header.OnMousePressed = function(self, btn)
        if btn == MOUSE_LEFT then
            local mx, my = self:CursorPos()
            if mx > W - 40 then frame:Remove() end
        end
    end

    -- ── Action-Buttons (für Admins) ───────────────────────────
    local btnY = HDR_H + 4
    if isAdmin then
        local function MakeActionBtn(label, x, bw, col, onclick)
            local btn = vgui.Create("DButton", frame)
            btn:SetPos(x, btnY)
            btn:SetSize(bw, BTN_H)
            btn:SetText("")
            btn._hv = 0
            btn.Paint = function(self, w, h)
                self._hv = math.Approach(self._hv,
                    self:IsHovered() and 1 or 0, FrameTime() * 8)
                draw.RoundedBox(8, 0, 0, w, h,
                    Color(col.r, col.g, col.b,
                          math.floor(Lerp(self._hv, 35, 75))))
                T.DrawBorder(0, 0, w, h,
                    Color(col.r, col.g, col.b,
                          math.floor(Lerp(self._hv, 55, 130))), 8)
                draw.SimpleText(label, T.Fonts.Small,
                    w * 0.5, h * 0.5, col,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = onclick
            return btn
        end

        -- Summon-Button
        MakeActionBtn("⤴  SUMMON", 10, 140, Color(0, 210, 255), function()
            LocalPlayer():ConCommand(
                "say !summon " .. ticket.authorName .. "\n")
        end)

        -- Annehmen (nur bei open)
        if ticket.status == "open" then
            MakeActionBtn("✔  ANNEHMEN", 158, 140, Color(50, 200, 130), function()
                net.Start("NexusAdmin_TicketAccept")
                    net.WriteUInt(ticket.id, 16)
                net.SendToServer()
                ticket.status = "accepted"
            end)
        end

        -- Schließen
        MakeActionBtn("✖  SCHLIESSEN", W - 160, 148, Color(255, 60, 90), function()
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

    local chatTopY = HDR_H + (isAdmin and (BTN_H + 6) or 4)

    -- ── Ursprünglicher Grund (Pinned-Box) ────────────────────
    local REASON_H = 48
    local reasonBox = vgui.Create("DPanel", frame)
    reasonBox:SetPos(10, chatTopY)
    reasonBox:SetSize(W - 20, REASON_H)
    reasonBox.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 22, 34, 200))
        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, 25), 8)
        draw.SimpleText("Anliegen:", T.Fonts.Small,
            12, 10, Color(0, 210, 255, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(ticket.reason, T.Fonts.Small,
            12, 28, Color(180, 200, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    chatTopY = chatTopY + REASON_H + 6
    local scrollH = H - chatTopY - INP_H - 8

    -- ── Scroll-Chat-Bereich ───────────────────────────────────
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(10, chatTopY)
    scroll:SetSize(W - 20, scrollH)

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

    -- Inline-List für Nachrichten
    local list = vgui.Create("DListLayout", scroll)
    list:SetWide(W - 28)
    list:DockPadding(4, 4, 4, 4)

    -- ── Hilfsfunktion: Nachricht hinzufügen ──────────────────
    --  isAdmin = true → blaue Admin-Bubble links
    --  isAdmin = false → dunkle User-Bubble rechts
    frame._AddMessage = function(senderName, text, msgIsAdmin, timestamp)
        local BUBBLE_MAX = W - 100
        local BUBBLE_PAD = 10

        -- Texthöhe schätzen (Zeilenlänge ~50 Zeichen)
        local lines   = math.max(1, math.ceil(#text / 52))
        local bubbleH = 20 + lines * 16 + BUBBLE_PAD * 2

        local row = vgui.Create("DPanel", list)
        row:SetTall(bubbleH + 22)
        row:SetWide(W - 28)
        row:DockMargin(0, 2, 0, 2)

        -- Farben
        local bubbleCol = msgIsAdmin
            and Color(18, 40, 80, 220)   -- Blau → Admin
            or  Color(28, 32, 44, 210)   -- Dunkelgrau → User
        local borderCol = msgIsAdmin
            and Color(0, 150, 255, 80)
            or  Color(80, 90, 110, 60)
        local nameCol   = msgIsAdmin
            and Color(60, 160, 255)
            or  Color(140, 155, 175)
        local textCol   = Color(210, 225, 240)

        -- Rechts ausrichten wenn ich selbst = Autor (und kein Admin)
        local isMine = (LocalPlayer():SteamID64() ==
            (msgIsAdmin and "ADMIN" or "USER"))  -- Vereinfacht: eigene Nachrichten
        -- Korrekte Seiten-Logik:
        -- Admin-Nachrichten immer links; User-Nachrichten immer rechts
        local alignRight = not msgIsAdmin

        local timeStr = os.date("%H:%M", timestamp)

        row.Paint = function(self, w, h)
            local bw = math.min(BUBBLE_MAX, w - 20)
            local bx = alignRight and (w - bw - 6) or 6

            draw.RoundedBox(8, bx, 18, bw, bubbleH, bubbleCol)
            T.DrawBorder(bx, 18, bw, bubbleH, borderCol, 8)

            -- Sender-Name + Zeit
            draw.SimpleText(senderName, T.Fonts.Small,
                bx + 10, 4, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(timeStr, T.Fonts.Small,
                bx + bw - 6, 4, Color(60, 75, 95),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            -- Nachrichtentext (einfacher wrap über draw.SimpleText)
            local maxW  = bw - BUBBLE_PAD * 2
            local words = string.Explode(" ", text)
            local line  = ""
            local lineY = 18 + BUBBLE_PAD

            for _, word in ipairs(words) do
                local test = line == "" and word or (line .. " " .. word)
                surface.SetFont(T.Fonts.Small)
                local tw = surface.GetTextSize(test)

                if tw > maxW and line ~= "" then
                    draw.SimpleText(line, T.Fonts.Small,
                        bx + BUBBLE_PAD, lineY, textCol,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    lineY = lineY + 16
                    line  = word
                else
                    line = test
                end
            end
            if line ~= "" then
                draw.SimpleText(line, T.Fonts.Small,
                    bx + BUBBLE_PAD, lineY, textCol,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end

        row:SetMouseInputEnabled(false)

        -- Automatisch nach unten scrollen
        timer.Simple(0, function()
            if IsValid(scroll) then
                scroll:GetVBar():SetScroll(scroll:GetVBar():GetMax())
            end
        end)
    end

    -- ── Eingabe-Zeile ─────────────────────────────────────────
    local inputY = H - INP_H - 4
    local input  = vgui.Create("DTextEntry", frame)
    input:SetPos(10, inputY)
    input:SetSize(W - 94, INP_H - 6)
    input:SetFont(T.Fonts.Body)
    input:SetMaximumCharCount(300)
    input:SetPlaceholderText(
        ticket.status == "closed"
            and "Ticket geschlossen."
            or  "Nachricht eingeben…")
    input:SetEnabled(ticket.status ~= "closed")
    input.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 23, 33, 230))
        T.DrawBorder(0, 0, w, h,
            self:IsEditing() and Color(0, 210, 255, 100)
                              or Color(0, 210, 255, 30), 8)
        self:DrawTextEntryText(
            Color(220, 235, 245),
            Color(0, 210, 255, 100),
            Color(0, 210, 255))
    end

    -- Senden per Enter
    input.OnEnter = function(self)
        local text = self:GetValue():Trim()
        if text == "" or ticket.status == "closed" then return end
        net.Start("NexusAdmin_TicketMessage")
            net.WriteUInt(ticket.id, 16)
            net.WriteString(text)
        net.SendToServer()
        self:SetValue("")
    end

    -- Senden-Button
    local sendBtn = vgui.Create("DButton", frame)
    sendBtn:SetPos(W - 80, inputY)
    sendBtn:SetSize(70, INP_H - 6)
    sendBtn:SetText("")
    sendBtn._hv = 0
    sendBtn.Paint = function(self, w, h)
        self._hv = math.Approach(self._hv,
            self:IsHovered() and 1 or 0, FrameTime() * 8)
        draw.RoundedBox(8, 0, 0, w, h,
            Color(0, 210, 255, math.floor(Lerp(self._hv, 40, 90))))
        T.DrawBorder(0, 0, w, h,
            Color(0, 210, 255, math.floor(Lerp(self._hv, 70, 160))), 8)
        draw.SimpleText("SENDEN", T.Fonts.Small,
            w * 0.5, h * 0.5,
            Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    sendBtn.DoClick = function()
        input:OnEnter()
    end

    -- ── Nachrichtenhistorie anfordern ─────────────────────────
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

    -- Text-Eingabe
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

    -- Schaltflächen
    local function MakeBtn(parent, label, x, col, callback)
        local btn = vgui.Create("DButton", parent)
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

    MakeBtn(frame, "SENDEN", 16, Color(0, 210, 255), function()
        local text = input:GetValue():Trim()
        if text == "" then return end
        net.Start("NexusAdmin_TicketCreate")
            net.WriteString(text)
        net.SendToServer()
        frame:Remove()
    end)

    MakeBtn(frame, "ABBRECHEN", 160, Color(255, 50, 80), function()
        frame:Remove()
    end)
end
