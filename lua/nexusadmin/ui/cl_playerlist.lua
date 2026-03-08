-- ============================================================
--  NexusAdmin | cl_playerlist.lua
--  Scrollbare Spielerliste mit Rechtsklick-Kontext-Menü.
--  Wird in cl_menu.lua als Standard-Tab geladen.
-- ============================================================

local T = NexusAdmin.Theme

function NexusAdmin.BuildPlayerList(parent)
    parent:Clear()

    -- ── Kopfzeile ─────────────────────────────────────────────
    local header = vgui.Create("DPanel", parent)
    header:SetSize(parent:GetWide(), 36)
    header:SetPos(0, 0)

    header.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, T.BG_Light)
        surface.SetDrawColor(T.Divider)
        surface.DrawRect(0, h - 1, w, 1)

        -- Spalten-Bezeichnungen
        surface.SetFont(T.Fonts.Small)
        surface.SetTextColor(T.TextMuted)

        surface.SetTextPos(18, 10)
        surface.DrawText("SPIELER")

        surface.SetTextPos(parent:GetWide() - 200, 10)
        surface.DrawText("RANG")

        surface.SetTextPos(parent:GetWide() - 90, 10)
        surface.DrawText("PING")
    end

    -- ── Scrollbarer Bereich ───────────────────────────────────
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:SetPos(0, 36)
    scroll:SetSize(parent:GetWide(), parent:GetTall() - 36)

    -- Scrollbar mit passendem Design überschreiben
    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = function(self, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.BG_Light)
    end
    sbar.btnUp.Paint   = function() end  -- Pfeil-Buttons ausblenden
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.Accent)
    end

    -- ── Spieler-Zeilen ────────────────────────────────────────
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local row = vgui.Create("DPanel", scroll)
        row:SetSize(0, 54)
        row:Dock(TOP)
        row:DockMargin(8, 4, 8, 0)

        -- Werte zum Erstellungszeitpunkt einfangen
        local nick     = ply:Nick()
        local rankId   = ply:GetNWString("na_rank", "user")
        local rankData = NexusAdmin.Ranks[rankId] or NexusAdmin.Ranks["user"]

        -- Spieler-Entity für spätere Aktionen sicher referenzieren
        local plyRef = ply

        -- ── Warn-Badge ────────────────────────────────────────
        -- Zeichnet eine kleine farbige Zahl neben dem Spielernamen.
        -- Liest den aktuellen Warn-Count aus dem NWInt "na_warns" –
        -- dieser wird von sv_warning_system.lua bei jeder Änderung
        -- per net.Broadcast aktualisiert.
        local function DrawWarnBadge(ww)
            if not IsValid(plyRef) then return end

            local warnCount = plyRef:GetNWInt("na_warns", 0)
            if warnCount <= 0 then return end

            local threshold = NexusAdmin.Config.WarnThreshold

            -- Gelb = unter Schwelle, Rot = Schwelle erreicht/überschritten
            local badgeColor = (warnCount >= threshold)
                and Color(220, 60, 60)
                or  Color(255, 160, 40)

            -- Badge-Abmessungen: kleines gerundetes Rechteck
            local badgeW = 18
            local badgeH = 14
            local badgeX = ww - 120   -- Links neben dem Ping-Wert
            local badgeY = 9

            draw.RoundedBox(4, badgeX, badgeY, badgeW, badgeH, badgeColor)

            -- Warn-Zahl zentriert im Badge
            local numStr = tostring(warnCount)
            surface.SetFont(T.Fonts.Small)
            local tw, _ = surface.GetTextSize(numStr)
            surface.SetTextColor(Color(255, 255, 255))
            surface.SetTextPos(badgeX + math.floor((badgeW - tw) * 0.5), badgeY + 1)
            surface.DrawText(numStr)
        end

        row.Paint = function(self, w, h)
            local bg = self:IsHovered() and T.BG_Light or T.BG_Medium
            draw.RoundedBox(6, 0, 0, w, h, bg)

            -- Rangfarbe als schmaler Balken links
            draw.RoundedBox(3, 0, 10, 4, h - 20, rankData.color)

            -- Avatar (wird vom Framework gecacht)
            if IsValid(plyRef) then
                local avatar = vgui.Create("AvatarImage", self)
                avatar:SetSize(32, 32)
                avatar:SetPos(12, (h - 32) * 0.5)
                avatar:SetPlayer(plyRef, 32)
                -- Avatar nur einmal erstellen, danach überspringen
                row.Paint = function(selfInner, ww, hh)
                    local bgInner = selfInner:IsHovered() and T.BG_Light or T.BG_Medium
                    draw.RoundedBox(6, 0, 0, ww, hh, bgInner)
                    draw.RoundedBox(3, 0, 10, 4, hh - 20, rankData.color)

                    -- Spielername
                    surface.SetFont(T.Fonts.Body)
                    surface.SetTextColor(T.TextMain)
                    surface.SetTextPos(52, 10)
                    surface.DrawText(nick)

                    -- Rang-Label
                    surface.SetFont(T.Fonts.Small)
                    surface.SetTextColor(rankData.color)
                    surface.SetTextPos(52, 30)
                    surface.DrawText(rankData.name)

                    -- Warn-Badge (Zahl in gelbem/rotem Kasten)
                    DrawWarnBadge(ww)

                    -- Ping rechts
                    if IsValid(plyRef) then
                        surface.SetFont(T.Fonts.Small)
                        surface.SetTextColor(T.TextMuted)
                        surface.SetTextPos(ww - 70, (hh - 12) * 0.5)
                        surface.DrawText(plyRef:Ping() .. " ms")
                    end
                end
            end
        end

        -- ── Rechtsklick → Kontext-Menü ────────────────────────
        row.DoRightClick = function()
            if not IsValid(plyRef) then return end

            local menu = DermaMenu()

            menu:AddOption("Zu " .. nick .. " teleportieren", function()
                RunConsoleCommand("na_teleport", nick)
            end):SetIcon("icon16/arrow_right.png")

            menu:AddOption("Kicken", function()
                Derma_StringRequest(
                    "Kick: " .. nick,
                    "Bitte gib einen Grund an:",
                    "Kein Grund angegeben",
                    function(grund)
                        RunConsoleCommand("na_kick", nick, grund)
                    end
                )
            end):SetIcon("icon16/door_out.png")

            menu:AddOption("Verwarnen (Strike)", function()
                local warnCount  = IsValid(plyRef) and plyRef:GetNWInt("na_warns", 0) or 0
                local threshold  = NexusAdmin.Config.WarnThreshold
                local warnInfo   = string.format("Aktive Warns: %d/%d", warnCount, threshold)

                Derma_StringRequest(
                    "Strike: " .. nick,
                    "Verwarnungsgrund eingeben\n" .. warnInfo,
                    "",
                    function(grund)
                        if grund and grund ~= "" then
                            RunConsoleCommand("na_strike", nick, grund)
                        end
                    end
                )
            end):SetIcon("icon16/error.png")

            menu:AddOption("Verwarnungen löschen", function()
                local warnCount = IsValid(plyRef) and plyRef:GetNWInt("na_warns", 0) or 0
                if warnCount == 0 then
                    -- Kein separater Popup nötig – direkte Rückmeldung via Notify
                    RunConsoleCommand("na_clearstrikes", nick)
                    return
                end
                Derma_Query(
                    string.format("Alle %d aktiven Verwarnungen von %s löschen?",
                        warnCount, nick),
                    "Bestätigung",
                    "Ja, löschen",  function() RunConsoleCommand("na_clearstrikes", nick) end,
                    "Abbrechen",    function() end
                )
            end):SetIcon("icon16/delete.png")

            menu:AddOption("Rang ändern", function()
                -- Dropdown mit verfügbaren Rängen bauen
                local rankFrame = vgui.Create("DFrame")
                rankFrame:SetTitle("Rang setzen: " .. nick)
                rankFrame:SetSize(280, 160)
                rankFrame:Center()
                rankFrame:MakePopup()

                local combo = vgui.Create("DComboBox", rankFrame)
                combo:SetPos(10, 30)
                combo:SetSize(260, 30)
                combo:SetValue("Rang wählen...")

                for rId, rData in pairs(NexusAdmin.Ranks) do
                    combo:AddChoice(rData.name, rId)
                end

                local btnApply = vgui.Create("DButton", rankFrame)
                btnApply:SetPos(10, 110)
                btnApply:SetSize(260, 32)
                btnApply:SetText("Anwenden")

                btnApply.DoClick = function()
                    local _, selectedRankId = combo:GetSelected()
                    if selectedRankId then
                        RunConsoleCommand("na_setrank", nick, selectedRankId)
                        rankFrame:Close()
                    end
                end
            end):SetIcon("icon16/shield.png")

            menu:AddSpacer()

            menu:AddOption("Abbrechen"):SetIcon("icon16/cancel.png")
            menu:Open()
        end
    end

    -- Leere-Liste Hinweis wenn keine Spieler online
    if #player.GetAll() == 0 then
        local lbl = vgui.Create("DLabel", scroll)
        lbl:SetText("Keine Spieler online.")
        lbl:SetFont(T.Fonts.Body)
        lbl:SetTextColor(T.TextMuted)
        lbl:SizeToContents()
        lbl:SetPos(20, 20)
    end
end
