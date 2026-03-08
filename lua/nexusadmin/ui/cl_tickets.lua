-- ============================================================
--  NexusAdmin | cl_tickets.lua
--  Client-seitiger Empfänger + Admin-Ticket-UI.
--
--  Net-Messages:
--    NexusAdmin_TicketList   – Server → Client (Admin)
--    NexusAdmin_TicketCreate – Client → Server (Player)
--    NexusAdmin_TicketAccept – Client → Server (Admin)
--    NexusAdmin_TicketClose  – Client → Server (Admin)
-- ============================================================

NexusAdmin._TicketCache = {}

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

-- ── Ticket erstellen (Spieler-Seite) ─────────────────────────
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
        draw.RoundedBox(6, 0, 0, w, h, Color(20, 22, 30, 220))
        T.DrawBorder(0, 0, w, h,
            self:IsEditing() and Color(0, 210, 255, 80) or Color(0, 210, 255, 30), 6)
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
            self._hover = math.Approach(self._hover, self:IsHovered() and 1 or 0, FrameTime() * 8)
            draw.RoundedBox(6, 0, 0, w, h,
                Color(col.r, col.g, col.b, math.floor(Lerp(self._hover, 40, 80))))
            T.DrawBorder(0, 0, w, h, Color(col.r, col.g, col.b, math.floor(Lerp(self._hover, 60, 140))), 6)
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
