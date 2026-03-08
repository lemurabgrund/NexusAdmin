-- ============================================================
--  NexusAdmin | cl_admintools.lua
--  Admin-Zentrale – Dashboard mit Live-Suche.
--
--  Tabs:
--    BANS    – Ban-Liste (Suche nach SteamID / Name)
--    WARNS   – Verwarnungs-Liste (Live-Suche)
--    TICKETS – Ticket-Liste mit Annehmen / Schließen
--
--  Öffnen: !at / !admintools  →  na_admintools concommand
-- ============================================================

local AT_W = 780
local AT_H = 560

-- ── Hilfs-Funktion: Status-Pill ───────────────────────────────
local function DrawPill(x, y, w, h, col, label, font)
    draw.RoundedBox(h * 0.5, x, y, w, h, Color(col.r, col.g, col.b, 40))
    draw.RoundedBox(h * 0.5, x, y, 3, h, col)
    draw.SimpleText(label, font or NexusAdmin.Theme.Fonts.Small,
        x + 10, y + h * 0.5, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

-- ── Haupt-Frame ───────────────────────────────────────────────
function NexusAdmin.OpenAdminTools()
    local myRank = NexusAdmin._RankCache and NexusAdmin._RankCache[LocalPlayer():SteamID64()] or "user"
    if not NexusAdmin.RankHasPermission(myRank, "kick") then
        chat.AddText(Color(255, 50, 80), "[NexusAdmin] Kein Zugriff.")
        return
    end

    if IsValid(NexusAdmin._AdminToolsFrame) then
        NexusAdmin._AdminToolsFrame:Remove()
    end

    local T = NexusAdmin.Theme

    local frame = vgui.Create("DPanel")
    NexusAdmin._AdminToolsFrame = frame
    frame:SetSize(AT_W, AT_H)
    frame:SetPos(ScrW() * 0.5 - AT_W * 0.5, ScrH() * 0.5 - AT_H * 0.5)
    frame:MakePopup()

    frame._alpha = 0
    frame.Paint = function(self, w, h)
        self._alpha = math.Approach(self._alpha, 255, FrameTime() * 800)
        local a = self._alpha
        T.DrawBlur(self, T.BlurStrength)
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 12, 18, math.floor(a * 0.96)))
        draw.RoundedBoxEx(10, 1, 1, w - 2, math.floor(h * 0.12),
            Color(255, 255, 255, math.floor(a * 0.04)), true, true, false, false)
        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, math.floor(a * 0.5)), 10)

        -- Titel
        draw.SimpleText("ADMIN-ZENTRALE", T.Fonts.Title,
            w * 0.5, 26, Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Trennlinie
        surface.SetDrawColor(Color(0, 210, 255, 30))
        surface.DrawRect(16, 50, w - 32, 1)
    end

    -- Schließen-Button (X)
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(AT_W - 38, 8)
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

    -- ── Tab-Leiste ────────────────────────────────────────────
    local TABS   = { "BANS", "WARNS", "TICKETS" }
    local tabBtns = {}
    local activeTab = "BANS"

    -- Content-Container
    local content = vgui.Create("DPanel", frame)
    content:SetPos(16, 90)
    content:SetSize(AT_W - 32, AT_H - 100)
    content.Paint = function() end

    -- ── Tab-Inhalt-Funktionen ─────────────────────────────────

    -- ── BANS ─────────────────────────────────────────────────
    local function BuildBansTab()
        content:Clear()

        local banCache = {}

        -- Suchleiste
        local searchBox = vgui.Create("DTextEntry", content)
        searchBox:SetPos(0, 0)
        searchBox:SetSize(content:GetWide(), 32)
        searchBox:SetFont(T.Fonts.Body)
        searchBox:SetPlaceholderText("SteamID64 oder Name suchen…")
        searchBox.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20, 22, 30, 220))
            T.DrawBorder(0, 0, w, h,
                self:IsEditing() and Color(0, 210, 255, 80) or Color(0, 210, 255, 25), 6)
            self:DrawTextEntryText(Color(220, 235, 245), Color(0, 210, 255, 100), Color(0, 210, 255))
        end

        local scroll = vgui.Create("DScrollPanel", content)
        scroll:SetPos(0, 40)
        scroll:SetSize(content:GetWide(), content:GetTall() - 40)
        local sbar = scroll:GetVBar()
        sbar:SetWide(4)
        function sbar:Paint(w, h)       draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30)) end
        function sbar.btnUp:Paint()     end
        function sbar.btnDown:Paint()   end
        function sbar.btnGrip:Paint(w, h)
            draw.RoundedBox(2, 0, 0, w, h, Color(0, 210, 255, 120))
        end

        local function PopulateRows(filter)
            scroll:Clear()
            local shown = 0
            for _, b in ipairs(banCache) do
                local steam = b.steam_id or ""
                local reason = b.reason  or ""
                local by     = b.banned_by or ""
                local match  = filter == ""
                    or steam:lower():find(filter:lower(), 1, true)
                    or reason:lower():find(filter:lower(), 1, true)
                    or by:lower():find(filter:lower(), 1, true)
                if not match then continue end

                shown = shown + 1
                local row = vgui.Create("DPanel", scroll)
                row:SetSize(scroll:GetWide() - 8, 52)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 4)

                local expStr
                if (b.expires_at or 0) == 0 then
                    expStr = "Permanent"
                else
                    local remaining = b.expires_at - os.time()
                    if remaining <= 0 then
                        expStr = "Abgelaufen"
                    else
                        expStr = math.ceil(remaining / 3600) .. "h verbleibend"
                    end
                end

                row.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(22, 24, 34, 220))
                    draw.RoundedBox(4, 0, 6, 3, h - 12, Color(255, 50, 80))
                    draw.SimpleText(steam, T.Fonts.Small, 12, 14, Color(150, 170, 200), TEXT_ALIGN_LEFT)
                    draw.SimpleText(reason, T.Fonts.Body,  12, 32, Color(220, 235, 245), TEXT_ALIGN_LEFT)
                    draw.SimpleText("von " .. by .. "  |  " .. expStr, T.Fonts.Small,
                        w - 12, 14, Color(100, 120, 140), TEXT_ALIGN_RIGHT)
                end

                -- Entbannen-Button (nur für Superadmins mit ban-Berechtigung)
                local myRankAT = NexusAdmin._RankCache and NexusAdmin._RankCache[LocalPlayer():SteamID64()] or "user"
                if NexusAdmin.RankHasPermission(myRankAT, "ban") then
                    local unbanBtn = vgui.Create("DButton", row)
                    unbanBtn:SetPos(row:GetWide() - 90, 10)
                    unbanBtn:SetSize(80, 32)
                    unbanBtn:SetText("")
                    unbanBtn._hv = 0
                    unbanBtn.Paint = function(self, w, h)
                        self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
                        draw.RoundedBox(4, 0, 0, w, h, Color(255, 50, 80, math.floor(self._hv * 60 + 20)))
                        T.DrawBorder(0, 0, w, h, Color(255, 50, 80, math.floor(self._hv * 80 + 40)), 4)
                        draw.SimpleText("ENTBANNEN", T.Fonts.Small, w * 0.5, h * 0.5,
                            Color(255, 100, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    unbanBtn.DoClick = function()
                        Derma_Query(
                            "Bann für " .. steam .. " aufheben?",
                            "Entbannen",
                            "Ja", function()
                                LocalPlayer():ConCommand("say !pardon " .. steam .. "\n")
                                timer.Simple(0.5, function()
                                    net.Start("NexusAdmin_RequestBanList") net.SendToServer()
                                end)
                            end,
                            "Abbrechen", function() end
                        )
                    end
                end
            end

            if shown == 0 then
                local empty = vgui.Create("DPanel", scroll)
                empty:SetSize(scroll:GetWide() - 8, 60)
                empty:Dock(TOP)
                empty.Paint = function(self, w, h)
                    draw.SimpleText("Keine Einträge gefunden.", T.Fonts.Body,
                        w * 0.5, h * 0.5, Color(80, 100, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end

        searchBox.OnValueChange = function(self, val)
            PopulateRows(val)
        end

        -- Ban-Liste anfragen
        net.Start("NexusAdmin_RequestBanList") net.SendToServer()

        net.Receive("NexusAdmin_BanList", function()
            banCache = {}
            local cnt = net.ReadUInt(16)
            for _ = 1, cnt do
                banCache[#banCache + 1] = {
                    steam_id  = net.ReadString(),
                    reason    = net.ReadString(),
                    banned_by = net.ReadString(),
                    banned_at  = net.ReadDouble(),
                    expires_at = net.ReadDouble(),
                }
            end
            PopulateRows(searchBox:GetValue())
        end)
    end

    -- ── WARNS ─────────────────────────────────────────────────
    local function BuildWarnsTab()
        content:Clear()

        local warnCache = {}

        local searchBox = vgui.Create("DTextEntry", content)
        searchBox:SetPos(0, 0)
        searchBox:SetSize(content:GetWide() - 120, 32)
        searchBox:SetFont(T.Fonts.Body)
        searchBox:SetPlaceholderText("SteamID64 suchen…")
        searchBox.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20, 22, 30, 220))
            T.DrawBorder(0, 0, w, h,
                self:IsEditing() and Color(0, 210, 255, 80) or Color(0, 210, 255, 25), 6)
            self:DrawTextEntryText(Color(220, 235, 245), Color(0, 210, 255, 100), Color(0, 210, 255))
        end

        -- Such-Button
        local searchBtn = vgui.Create("DButton", content)
        searchBtn:SetPos(content:GetWide() - 116, 0)
        searchBtn:SetSize(116, 32)
        searchBtn:SetText("")
        searchBtn._hv = 0
        searchBtn.Paint = function(self, w, h)
            self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
            draw.RoundedBox(6, 0, 0, w, h, Color(0, 210, 255, math.floor(self._hv * 60 + 25)))
            T.DrawBorder(0, 0, w, h, Color(0, 210, 255, math.floor(self._hv * 80 + 40)), 6)
            draw.SimpleText("SUCHEN", T.Fonts.Small, w * 0.5, h * 0.5,
                Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local scroll = vgui.Create("DScrollPanel", content)
        scroll:SetPos(0, 40)
        scroll:SetSize(content:GetWide(), content:GetTall() - 40)
        local sbar = scroll:GetVBar()
        sbar:SetWide(4)
        function sbar:Paint(w, h)      draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30)) end
        function sbar.btnUp:Paint()    end
        function sbar.btnDown:Paint()  end
        function sbar.btnGrip:Paint(w, h)
            draw.RoundedBox(2, 0, 0, w, h, Color(0, 210, 255, 120))
        end

        local function PopulateWarnRows()
            scroll:Clear()
            local threshold = NexusAdmin.Config.WarnThreshold or 4

            if #warnCache == 0 then
                local empty = vgui.Create("DPanel", scroll)
                empty:SetSize(scroll:GetWide() - 8, 60)
                empty:Dock(TOP)
                empty.Paint = function(self, w, h)
                    draw.SimpleText("Keine Verwarnungen gefunden.", T.Fonts.Body,
                        w * 0.5, h * 0.5, Color(80, 100, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                return
            end

            for _, r in ipairs(warnCache) do
                local row = vgui.Create("DPanel", scroll)
                row:SetSize(scroll:GetWide() - 8, 48)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 4)

                local warnCol = r.count >= threshold and Color(255, 50, 80) or Color(255, 200, 40)
                local onlineStr = r.online and "Online" or "Offline"

                row.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(22, 24, 34, 220))
                    draw.RoundedBox(4, 0, 6, 3, h - 12, warnCol)

                    draw.SimpleText(r.name, T.Fonts.Body,   12, h * 0.5 - 7, Color(220, 235, 245), TEXT_ALIGN_LEFT)
                    draw.SimpleText(r.sid,  T.Fonts.Small,  12, h * 0.5 + 7, Color(70, 90, 110),  TEXT_ALIGN_LEFT)

                    -- Warn-Zahl
                    draw.RoundedBox(4, w - 90, h * 0.5 - 10, 30, 20, warnCol)
                    draw.SimpleText(tostring(r.count), T.Fonts.Small,
                        w - 75, h * 0.5, Color(15, 15, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.SimpleText(onlineStr, T.Fonts.Small,
                        w - 50, h * 0.5, r.online and Color(50, 255, 140) or Color(80, 100, 120),
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                -- Verwarnungen löschen
                local clearBtn = vgui.Create("DButton", row)
                clearBtn:SetPos(row:GetWide() - 200, 8)
                clearBtn:SetSize(100, 32)
                clearBtn:SetText("")
                clearBtn._hv = 0
                clearBtn.Paint = function(self, w, h)
                    self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
                    draw.RoundedBox(4, 0, 0, w, h, Color(255, 200, 40, math.floor(self._hv * 50 + 20)))
                    T.DrawBorder(0, 0, w, h, Color(255, 200, 40, math.floor(self._hv * 80 + 40)), 4)
                    draw.SimpleText("LÖSCHEN", T.Fonts.Small, w * 0.5, h * 0.5,
                        Color(255, 200, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                clearBtn.DoClick = function()
                    Derma_Query(
                        "Alle Verwarnungen für " .. r.name .. " löschen?",
                        "Verwarnungen löschen",
                        "Ja", function()
                            LocalPlayer():ConCommand("say !clearstrikes " .. r.sid .. "\n")
                        end,
                        "Abbrechen", function() end
                    )
                end
            end
        end

        local function DoSearch()
            local q = searchBox:GetValue():Trim()
            net.Start("NexusAdmin_RequestWarnList")
                net.WriteString(q)
            net.SendToServer()
        end

        net.Receive("NexusAdmin_WarnList", function()
            warnCache = {}
            local cnt = net.ReadUInt(16)
            for _ = 1, cnt do
                warnCache[#warnCache + 1] = {
                    name   = net.ReadString(),
                    sid    = net.ReadString(),
                    count  = net.ReadUInt(8),
                    online = net.ReadBool(),
                }
            end
            PopulateWarnRows()
        end)

        searchBtn.DoClick = DoSearch
        searchBox.OnEnter = DoSearch

        DoSearch()  -- Initial: alle Online-Spieler mit Warns
    end

    -- ── TICKETS ───────────────────────────────────────────────
    local function BuildTicketsTab()
        content:Clear()

        local scroll = vgui.Create("DScrollPanel", content)
        scroll:SetPos(0, 0)
        scroll:SetSize(content:GetWide(), content:GetTall())
        local sbar = scroll:GetVBar()
        sbar:SetWide(4)
        function sbar:Paint(w, h)     draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30)) end
        function sbar.btnUp:Paint()   end
        function sbar.btnDown:Paint() end
        function sbar.btnGrip:Paint(w, h)
            draw.RoundedBox(2, 0, 0, w, h, Color(0, 210, 255, 120))
        end

        local function PopulateTicketRows()
            scroll:Clear()

            local tickets = NexusAdmin._TicketCache or {}
            if #tickets == 0 then
                local empty = vgui.Create("DPanel", scroll)
                empty:SetSize(scroll:GetWide() - 8, 60)
                empty:Dock(TOP)
                empty.Paint = function(self, w, h)
                    draw.SimpleText("Keine Tickets vorhanden.", T.Fonts.Body,
                        w * 0.5, h * 0.5, Color(80, 100, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                return
            end

            for _, t in ipairs(tickets) do
                local row = vgui.Create("DPanel", scroll)
                row:SetSize(scroll:GetWide() - 8, 64)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 4)

                local statusCol = t.status == "open"     and Color(0, 210, 255)
                    or t.status == "accepted" and Color(50, 255, 140)
                    or Color(80, 100, 120)

                local statusLabel = t.status == "open"     and "OFFEN"
                    or t.status == "accepted" and "ANGENOMMEN"
                    or "GESCHLOSSEN"

                local timeAgo = os.time() - t.createdAt
                local timeStr = timeAgo < 60 and "gerade eben"
                    or timeAgo < 3600 and math.floor(timeAgo / 60) .. "m"
                    or math.floor(timeAgo / 3600) .. "h"

                row.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(22, 24, 34, 220))
                    draw.RoundedBox(4, 0, 6, 3, h - 12, statusCol)

                    draw.SimpleText("#" .. t.id .. "  " .. t.authorName, T.Fonts.Body,
                        12, 14, Color(220, 235, 245), TEXT_ALIGN_LEFT)
                    draw.SimpleText(t.reason, T.Fonts.Small,
                        12, 34, Color(150, 170, 200), TEXT_ALIGN_LEFT)
                    draw.SimpleText(timeStr, T.Fonts.Small,
                        w - 12, 14, Color(80, 100, 120), TEXT_ALIGN_RIGHT)

                    DrawPill(w - 130, 34, 90, 18, statusCol, statusLabel, T.Fonts.Small)

                    if t.status == "accepted" and t.acceptedBy ~= "" then
                        draw.SimpleText("von " .. t.acceptedBy, T.Fonts.Small,
                            w - 140, 34, Color(70, 90, 110), TEXT_ALIGN_RIGHT)
                    end
                end

                -- Buttons je nach Status
                if t.status == "open" then
                    local acceptBtn = vgui.Create("DButton", row)
                    acceptBtn:SetPos(row:GetWide() - 220, 16)
                    acceptBtn:SetSize(100, 32)
                    acceptBtn:SetText("")
                    acceptBtn._hv = 0
                    acceptBtn.Paint = function(self, w, h)
                        self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
                        draw.RoundedBox(4, 0, 0, w, h, Color(0, 210, 255, math.floor(self._hv * 60 + 25)))
                        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, math.floor(self._hv * 80 + 50)), 4)
                        draw.SimpleText("ANNEHMEN", T.Fonts.Small, w * 0.5, h * 0.5,
                            Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    acceptBtn.DoClick = function()
                        net.Start("NexusAdmin_TicketAccept")
                            net.WriteUInt(t.id, 16)
                        net.SendToServer()
                    end
                end

                if t.status ~= "closed" then
                    local closeBtn = vgui.Create("DButton", row)
                    closeBtn:SetPos(row:GetWide() - 112, 16)
                    closeBtn:SetSize(100, 32)
                    closeBtn:SetText("")
                    closeBtn._hv = 0
                    closeBtn.Paint = function(self, w, h)
                        self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
                        draw.RoundedBox(4, 0, 0, w, h, Color(255, 50, 80, math.floor(self._hv * 60 + 20)))
                        T.DrawBorder(0, 0, w, h, Color(255, 50, 80, math.floor(self._hv * 80 + 40)), 4)
                        draw.SimpleText("SCHLIESSEN", T.Fonts.Small, w * 0.5, h * 0.5,
                            Color(255, 100, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    closeBtn.DoClick = function()
                        Derma_StringRequest(
                            "Ticket #" .. t.id .. " schließen",
                            "Optionaler Abschluss-Grund:",
                            "",
                            function(reason)
                                net.Start("NexusAdmin_TicketClose")
                                    net.WriteUInt(t.id, 16)
                                    net.WriteString(reason or "")
                                net.SendToServer()
                            end
                        )
                    end
                end
            end
        end

        -- Callback für Server-Update
        NexusAdmin.AdminTools_RebuildTickets = PopulateTicketRows

        PopulateTicketRows()
    end

    -- ── Tab-Switching ──────────────────────────────────────────
    local tabFuncs = {
        BANS    = BuildBansTab,
        WARNS   = BuildWarnsTab,
        TICKETS = BuildTicketsTab,
    }

    local function SwitchTab(name)
        activeTab = name
        for _, btn in ipairs(tabBtns) do btn._active = (btn._tabName == name) end
        local fn = tabFuncs[name]
        if fn then fn() end
    end

    for i, tabName in ipairs(TABS) do
        local btn = vgui.Create("DButton", frame)
        btn:SetPos(16 + (i - 1) * 130, 56)
        btn:SetSize(120, 30)
        btn:SetText("")
        btn._tabName = tabName
        btn._active  = (tabName == activeTab)
        btn._hv      = 0
        tabBtns[i]   = btn

        btn.Paint = function(self, w, h)
            self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
            local active = self._active

            local bg = active
                and Color(0, 210, 255, 40)
                or  Color(20, 22, 30, math.floor(self._hv * 60 + 20))

            draw.RoundedBox(6, 0, 0, w, h, bg)

            if active then
                T.DrawBorder(0, 0, w, h, Color(0, 210, 255, 80), 6)
                surface.SetDrawColor(Color(0, 210, 255))
                surface.DrawRect(6, h - 2, w - 12, 2)
            end

            draw.SimpleText(tabName, T.Fonts.Small, w * 0.5, h * 0.5,
                active and Color(0, 210, 255) or Color(120, 140, 160),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function() SwitchTab(tabName) end
    end

    SwitchTab("BANS")
end

-- ── ConCommand ────────────────────────────────────────────────
concommand.Add("na_admintools", function()
    NexusAdmin.OpenAdminTools()
end)
