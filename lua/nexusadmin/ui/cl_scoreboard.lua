-- ============================================================
--  NexusAdmin | cl_scoreboard.lua
--  Custom Scoreboard – ersetzt das GMod-Standard-Scoreboard.
--
--  Layout:  Header · Spalten-Header · Spieler-Karten (Scroll)
--  Karten:  Avatar · Name + SteamID · Rang-Pill · Ping
--  Rechtsklick-Menü für Admins (nur auf andere Spieler)
-- ============================================================

NexusAdmin._Scoreboard = nil

-- ── Lokale Schriftarten (groß genug für gute Lesbarkeit) ──────
surface.CreateFont("NA_SB_Title", {
    font      = "Trebuchet MS",
    size      = 26,
    weight    = 700,
    antialias = true,
})

surface.CreateFont("NA_SB_Header", {
    font      = "Trebuchet MS",
    size      = 18,
    weight    = 700,
    antialias = true,
})

surface.CreateFont("NA_SB_Name", {
    font      = "Trebuchet MS",
    size      = 22,
    weight    = 700,
    antialias = true,
})

surface.CreateFont("NA_SB_Sub", {
    font      = "Trebuchet MS",
    size      = 13,
    weight    = 400,
    antialias = true,
})

surface.CreateFont("NA_SB_Ping", {
    font      = "Trebuchet MS",
    size      = 17,
    weight    = 700,
    antialias = true,
})

-- ── Dimensionen ───────────────────────────────────────────────
local SB_W      = math.floor(ScrW() * 0.60)
local SB_H      = math.floor(ScrH() * 0.75)
local HEADER_H  = 70    -- Header-Bereich oben
local COLHDR_H  = 34    -- Spalten-Beschriftungszeile
local CARD_H    = 66    -- Höhe einer Spieler-Karte
local CARD_PAD  = 5     -- Abstand zwischen Karten
local AV_SIZE   = 36    -- Avatar-Bildgröße
local AV_PAD    = 12    -- Linker Abstand des Avatars
local COL_NAME  = AV_PAD + AV_SIZE + 10   -- X-Anfang Name-Spalte
local COL_RANK  = 0.62  -- Rang-Spalte (Anteil der Kartenbreite)
local COL_PING  = 1.00  -- Ping (rechtsbündig, -10px)

-- ── Scoreboard öffnen ─────────────────────────────────────────
function NexusAdmin.OpenScoreboard()
    if IsValid(NexusAdmin._Scoreboard) then
        NexusAdmin._Scoreboard:Remove()
    end

    local T    = NexusAdmin.Theme
    local scrW = ScrW()
    local scrH = ScrH()

    -- Dimensionen bei jedem Öffnen neu berechnen (Auflösung kann sich ändern)
    SB_W = math.floor(scrW * 0.60)
    SB_H = math.floor(scrH * 0.75)

    local frame = vgui.Create("DPanel")
    NexusAdmin._Scoreboard = frame

    frame:SetSize(SB_W, SB_H)
    frame:SetPos(math.floor(scrW * 0.5 - SB_W * 0.5),
                 math.floor(scrH * 0.5 - SB_H * 0.5))
    frame:MakePopup()

    -- Fade-In
    frame._alpha = 0

    -- ── Haupt-Hintergrund ──────────────────────────────────────
    frame.Paint = function(self, w, h)
        self._alpha = math.Approach(self._alpha, 255, FrameTime() * 600)
        local a = math.floor(self._alpha)

        -- Blur-Hintergrund
        T.DrawBlur(self, T.BlurStrength)

        -- Dunkles Panel
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 13, 18, math.floor(a * 0.97)))

        -- Heller Glanz-Streifen oben
        draw.RoundedBoxEx(10, 1, 1, w - 2, HEADER_H,
            Color(255, 255, 255, math.floor(a * 0.03)), true, true, false, false)

        -- Neon-Rahmen
        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, math.floor(a * 0.5)), 10)
    end

    -- ── Header ────────────────────────────────────────────────
    local header = vgui.Create("DPanel", frame)
    header:SetPos(0, 0)
    header:SetSize(SB_W, HEADER_H)
    header.Paint = function(self, w, h)
        -- Titel
        draw.SimpleText("SCOREBOARD", "NA_SB_Title",
            w * 0.5, h * 0.5 - 10,
            Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Servername
        draw.SimpleText(GetHostName(), "NA_SB_Sub",
            w * 0.5, h * 0.5 + 13,
            Color(80, 110, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Spielerzahl (rechts)
        draw.SimpleText(
            #player.GetAll() .. " / " .. game.MaxPlayers() .. " Spieler",
            "NA_SB_Sub", w - 18, h * 0.5,
            Color(50, 200, 130), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        -- Trennlinie
        surface.SetDrawColor(0, 210, 255, 30)
        surface.DrawRect(16, h - 1, w - 32, 1)
    end

    -- ── Spalten-Header ────────────────────────────────────────
    local colHdr = vgui.Create("DPanel", frame)
    colHdr:SetPos(10, HEADER_H)
    colHdr:SetSize(SB_W - 20, COLHDR_H)
    colHdr.Paint = function(self, w, h)
        local lc = Color(60, 90, 115)
        draw.SimpleText("SPIELER", "NA_SB_Header",
            COL_NAME, h * 0.5, lc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("RANG", "NA_SB_Header",
            w * COL_RANK, h * 0.5, lc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("PING", "NA_SB_Header",
            w - 10, h * 0.5, lc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- ── Scroll-Container ──────────────────────────────────────
    local scrollTop = HEADER_H + COLHDR_H + 4
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(10, scrollTop)
    scroll:SetSize(SB_W - 20, SB_H - scrollTop - 8)
    scroll.Paint = function() end  -- kein Standard-Grau-Hintergrund

    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    function sbar:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30))
    end
    function sbar.btnUp:Paint()   end
    function sbar.btnDown:Paint() end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(0, 210, 255, 140))
    end

    -- ── Spielerkarten ─────────────────────────────────────────
    local function BuildCards()
        scroll:Clear()

        local players = player.GetAll()

        -- Sortierung: höchster Rang zuerst, dann alphabetisch
        table.sort(players, function(a, b)
            local ra = NexusAdmin._RankCache and NexusAdmin._RankCache[a:SteamID64()] or "user"
            local rb = NexusAdmin._RankCache and NexusAdmin._RankCache[b:SteamID64()] or "user"
            local la = NexusAdmin.Ranks[ra] and NexusAdmin.Ranks[ra].level or 0
            local lb = NexusAdmin.Ranks[rb] and NexusAdmin.Ranks[rb].level or 0
            if la ~= lb then return la > lb end
            return a:Nick() < b:Nick()
        end)

        for _, ply in ipairs(players) do
            if not IsValid(ply) then continue end

            local isMe      = (ply == LocalPlayer())
            local rankId    = (NexusAdmin._RankCache and NexusAdmin._RankCache[ply:SteamID64()]) or "user"
            local rankData  = NexusAdmin.Ranks[rankId] or NexusAdmin.Ranks["user"] or {}
            local rankCol   = rankData.color or Color(90, 110, 135)
            local rankName  = rankData.name  or "User"

            local card = vgui.Create("DPanel", scroll)
            card:SetSize(scroll:GetWide() - 6, CARD_H)
            card:Dock(TOP)
            card:DockMargin(0, 0, 0, CARD_PAD)
            card._hv = 0

            card.Paint = function(self, w, h)
                -- Hover-Interpolation
                self._hv = math.Approach(self._hv,
                    self:IsHovered() and 1 or 0, FrameTime() * 10)
                local hv = self._hv

                -- Hintergrundfarbe (eigener Spieler leicht blau getönt)
                local bgR = isMe and math.floor(Lerp(hv, 18, 28)) or math.floor(Lerp(hv, 26, 36))
                local bgG = isMe and math.floor(Lerp(hv, 22, 34)) or math.floor(Lerp(hv, 28, 36))
                local bgB = isMe and math.floor(Lerp(hv, 42, 58)) or math.floor(Lerp(hv, 36, 50))

                draw.RoundedBox(7, 0, 0, w, h, Color(bgR, bgG, bgB, 220))

                -- Hover-Rahmen
                if hv > 0.02 then
                    T.DrawBorder(0, 0, w, h,
                        Color(0, 210, 255, math.floor(hv * 80)), 7)
                end

                -- Eigener Spieler: Cyan-Schimmer
                if isMe then
                    draw.RoundedBox(7, 0, 0, w, h, Color(0, 210, 255, 10))
                end

                -- Rang-Farbbalken links (schmaler Streifen)
                draw.RoundedBox(3, 0, 10, 3, h - 20, rankCol)

                -- ── Name ──
                draw.SimpleText(ply:Nick(), "NA_SB_Name",
                    COL_NAME, math.floor(h * 0.5) - 10,
                    Color(220, 235, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- ── SteamID ──
                draw.SimpleText(ply:SteamID(), "NA_SB_Sub",
                    COL_NAME, math.floor(h * 0.5) + 14,
                    Color(48, 68, 92), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- ── Rang-Pill ──
                local pillW = 90
                local pillX = math.floor(w * COL_RANK)
                local pillY = math.floor(h * 0.5 - 11)
                local pillH = 22

                -- Transparenter Pill-Hintergrund
                draw.RoundedBox(pillH * 0.5, pillX, pillY, pillW, pillH,
                    Color(rankCol.r, rankCol.g, rankCol.b, 40))
                -- Farbiger linker Akzent
                draw.RoundedBox(pillH * 0.5, pillX, pillY, 4, pillH, rankCol)
                -- Rang-Name
                draw.SimpleText(rankName, "NA_SB_Sub",
                    pillX + pillW * 0.5 + 2, math.floor(h * 0.5),
                    rankCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                -- ── Ping ──
                local ping = ply:Ping()
                local pc   = ping < 80  and Color(50,  255, 140)
                          or ping < 150 and Color(255, 200, 40)
                          or              Color(255, 50,  80)

                draw.SimpleText(ping .. " ms", "NA_SB_Ping",
                    w - 10, math.floor(h * 0.5),
                    pc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            -- ── Avatar-Bild ──
            local av = vgui.Create("AvatarImage", card)
            av:SetPos(AV_PAD, math.floor((CARD_H - AV_SIZE) * 0.5))
            av:SetSize(AV_SIZE, AV_SIZE)
            av:SetPlayer(ply, 64)

            -- ── Rechtsklick-Menü (nur Admins, nicht auf sich selbst) ──
            card:SetMouseInputEnabled(true)
            card.OnMousePressed = function(self, btn)
                if btn ~= MOUSE_RIGHT       then return end
                if isMe                     then return end
                if not LocalPlayer():IsAdmin() then return end

                local menu = DermaMenu()

                menu:AddOption("Zu mir holen  (!summon)", function()
                    LocalPlayer():ConCommand("say !summon " .. ply:Nick() .. "\n")
                end):SetIcon("icon16/arrow_in.png")

                menu:AddOption("Teleport zu ihm  (!visit)", function()
                    LocalPlayer():ConCommand("say !visit " .. ply:Nick() .. "\n")
                end):SetIcon("icon16/arrow_out.png")

                menu:AddSpacer()

                menu:AddOption("Verwarnen  (!strike)", function()
                    Derma_StringRequest("Verwarnung – " .. ply:Nick(), "Grund:", "",
                        function(reason)
                            if reason and reason ~= "" then
                                LocalPlayer():ConCommand(
                                    "say !strike " .. ply:Nick() .. " " .. reason .. "\n")
                            end
                        end)
                end):SetIcon("icon16/error.png")

                menu:AddOption("Stumm schalten  (!quiet)", function()
                    LocalPlayer():ConCommand("say !quiet " .. ply:Nick() .. "\n")
                end):SetIcon("icon16/sound_mute.png")

                menu:AddSpacer()

                menu:AddOption("Kicken  (!kick)", function()
                    Derma_StringRequest("Kick – " .. ply:Nick(), "Grund:", "",
                        function(reason)
                            if reason and reason ~= "" then
                                LocalPlayer():ConCommand(
                                    "say !kick " .. ply:Nick() .. " " .. reason .. "\n")
                            end
                        end)
                end):SetIcon("icon16/door_out.png")

                menu:Open()
            end
        end
    end

    BuildCards()

    -- Karten alle 3 Sekunden aktualisieren (Ping, Spielerliste)
    timer.Create("NexusAdmin_ScoreboardRefresh", 3, 0, function()
        if not IsValid(frame) then
            timer.Remove("NexusAdmin_ScoreboardRefresh")
            return
        end
        BuildCards()
    end)
end

-- ── Scoreboard schließen ──────────────────────────────────────
function NexusAdmin.CloseScoreboard()
    timer.Remove("NexusAdmin_ScoreboardRefresh")
    if IsValid(NexusAdmin._Scoreboard) then
        NexusAdmin._Scoreboard:Remove()
        NexusAdmin._Scoreboard = nil
    end
end

-- ── GMod-Hooks überschreiben ──────────────────────────────────
hook.Add("ScoreboardShow", "NexusAdmin_SB_Show", function()
    NexusAdmin.OpenScoreboard()
    return true
end)

hook.Add("ScoreboardHide", "NexusAdmin_SB_Hide", function()
    NexusAdmin.CloseScoreboard()
    return true
end)
