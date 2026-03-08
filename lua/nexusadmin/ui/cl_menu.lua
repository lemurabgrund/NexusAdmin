-- ============================================================
--  NexusAdmin | cl_menu.lua
--  Haupt-Admin-Menü – modernes Flat/Blur-Design.
--  Öffnen via: NexusAdmin.OpenMenu()
--  Toggle via: F4 (konfigurierbar in sh_config.lua)
-- ============================================================

local T = NexusAdmin.Theme  -- Kurzreferenz auf Theme-Tabelle

-- ── Blur-Hintergrund ─────────────────────────────────────────
-- Delegiert an T.DrawBlur (pp/blurscreen, gamemode-unabhängig).
local function DrawBlurPanel(panel)
    T.DrawBlur(panel, T.BlurStrength)
end

-- ── Haupt-Menü öffnen ────────────────────────────────────────
function NexusAdmin.OpenMenu()
    -- Verhindert doppeltes Öffnen
    if IsValid(NexusAdmin._MenuFrame) then
        NexusAdmin._MenuFrame:Remove()
    end

    -- ── Frame ────────────────────────────────────────────────
    local frame = vgui.Create("DFrame")
    NexusAdmin._MenuFrame = frame

    frame:SetSize(900, 600)
    frame:Center()
    frame:SetTitle("")           -- Eigenen Titel zeichnen (kein DFrame-Standard)
    frame:SetDraggable(true)
    frame:ShowCloseButton(false) -- Eigenen Close-Button verwenden
    frame:MakePopup()

    frame.Paint = function(self, w, h)
        DrawBlurPanel(self)

        -- Obere Titelleiste (oben abgerundet, unten eckig → liegt auf RoundedBox auf)
        draw.RoundedBoxEx(10, 0, 0, w, 50, T.BG_Medium, true, true, false, false)

        -- Trennlinie unter Titelleiste
        surface.SetDrawColor(T.Divider)
        surface.DrawRect(0, 50, w, 1)

        -- Titel-Text
        surface.SetFont(T.Fonts.Title)
        surface.SetTextColor(T.TextMain)
        surface.SetTextPos(20, 14)
        surface.DrawText("NexusAdmin")

        -- Versions-Label klein daneben
        surface.SetFont(T.Fonts.Small)
        surface.SetTextColor(T.TextMuted)
        surface.SetTextPos(20 + 145, 20)
        surface.DrawText("v" .. NexusAdmin.Version)
    end

    -- ── Schließen-Button ─────────────────────────────────────
    local btnClose = vgui.Create("DButton", frame)
    btnClose:SetSize(40, 40)
    btnClose:SetPos(frame:GetWide() - 45, 5)
    btnClose:SetText("")

    btnClose.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(220, 60, 60) or T.BG_Light
        draw.RoundedBox(6, 0, 0, w, h, col)
        surface.SetFont(T.Fonts.Body)
        surface.SetTextColor(T.TextMain)
        surface.SetTextPos(13, 10)
        surface.DrawText("✕")
    end

    btnClose.DoClick = function()
        frame:Close()
        NexusAdmin._MenuOpen = false
    end

    -- ── Linke Navigationsleiste ───────────────────────────────
    local sidebar = vgui.Create("DPanel", frame)
    sidebar:SetPos(0, 51)
    sidebar:SetSize(180, frame:GetTall() - 51)

    sidebar.Paint = function(self, w, h)
        draw.RoundedBoxEx(10, 0, 0, w, h, T.BG_Medium, false, false, true, false)
        -- Rechte Trennlinie zur Inhaltsfläche
        surface.SetDrawColor(T.Divider)
        surface.DrawRect(w - 1, 0, 1, h)
    end

    -- ── Inhaltsfläche rechts der Sidebar ─────────────────────
    local content = vgui.Create("DPanel", frame)
    content:SetPos(180, 51)
    content:SetSize(frame:GetWide() - 180, frame:GetTall() - 51)
    content:SetName("na_content")   -- Name für Find() aus cl_networking.lua

    content.Paint = function(self, w, h)
        draw.RoundedBoxEx(10, 0, 0, w, h, T.BG_Dark, false, false, false, true)
    end

    -- ── Navigations-Tabs ──────────────────────────────────────
    local navItems = {
        { label = "Spieler",      build = function() NexusAdmin.BuildPlayerList(content) end },
        { label = "Befehle",      build = function() NexusAdmin.BuildCommandList(content) end },
        { label = "Ränge",        build = function() NexusAdmin.BuildRankList(content) end },
        { label = "Tickets",      build = function() if NexusAdmin.OpenAdminTools    then NexusAdmin.OpenAdminTools()              end end },
        { label = "Permissions",  build = function() if NexusAdmin.OpenPermsUI       then NexusAdmin.OpenPermsUI()                 end end },
        { label = "PermaProps",   build = function() if NexusAdmin.BuildPermaPropList then NexusAdmin.BuildPermaPropList(content)   end end },
        { label = "Einstellungen",build = function() if NexusAdmin.OpenConfigUI      then NexusAdmin.OpenConfigUI()                end end },
    }

    local activeTab = 1

    -- Ersten Tab sofort laden
    navItems[1].build()

    -- Nav-Buttons dynamisch erstellen
    for i, item in ipairs(navItems) do
        local btn = vgui.Create("DButton", sidebar)
        btn:SetPos(0, 10 + (i - 1) * 48)
        btn:SetSize(180, 44)
        btn:SetText("")

        -- Referenz auf i mit lokaler Variable einfangen (Loop-Closure)
        local tabIndex = i

        btn.Paint = function(self, w, h)
            local isActive  = (activeTab == tabIndex)
            local isHovered = self:IsHovered()

            if isActive then
                -- Hintergrund aktiver Tab
                draw.RoundedBox(4, 3, 0, w - 3, h, T.BG_Light)
                -- Akzentbalken links
                draw.RoundedBox(3, 0, 8, 3, h - 16, T.Accent)
            elseif isHovered then
                draw.RoundedBox(4, 0, 0, w, h, T.BG_Light)
            end

            surface.SetFont(T.Fonts.Body)
            surface.SetTextColor(isActive and T.Accent or T.TextMuted)
            surface.SetTextPos(20, 13)
            surface.DrawText(item.label)
        end

        btn.DoClick = function()
            activeTab = tabIndex
            content:Clear()
            item.build()
        end
    end
end

-- ── Stub-Funktionen für noch nicht implementierte Tabs ────────
-- Verhindert Fehler wenn ein Tab geklickt wird.
function NexusAdmin.BuildCommandList(parent)
    parent:Clear()
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(20, 20)
    lbl:SetText("Befehls-Liste – coming soon.")
    lbl:SetFont(T.Fonts.Body)
    lbl:SetTextColor(T.TextMuted)
    lbl:SizeToContents()
end

function NexusAdmin.BuildRankList(parent)
    parent:Clear()
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(20, 20)
    lbl:SetText("Rang-Übersicht – coming soon.")
    lbl:SetFont(T.Fonts.Body)
    lbl:SetTextColor(T.TextMuted)
    lbl:SizeToContents()
end

function NexusAdmin.BuildSettings(parent)
    parent:Clear()
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(20, 20)
    lbl:SetText("Einstellungen – coming soon.")
    lbl:SetFont(T.Fonts.Body)
    lbl:SetTextColor(T.TextMuted)
    lbl:SizeToContents()
end

-- ── F4-Toggle ────────────────────────────────────────────────
-- Lokaler Toggle-State – verhindert Mehrfachauslösung beim Halten.
NexusAdmin._MenuOpen = false
local keyWasDown     = false

hook.Add("Think", "NexusAdmin_MenuKeybind", function()
    if not IsValid(LocalPlayer()) then return end
    if not LocalPlayer():IsAdmin()  then return end

    local isDown = input.IsKeyDown(NexusAdmin.Config.MenuKey)

    -- Steigende Flanke: Taste wurde GERADE gedrückt (nicht gehalten)
    if isDown and not keyWasDown then
        keyWasDown = true

        if NexusAdmin._MenuOpen and IsValid(NexusAdmin._MenuFrame) then
            -- Menü ist offen → schließen
            NexusAdmin._MenuFrame:Close()
            NexusAdmin._MenuOpen = false
        else
            -- Menü öffnen und frische Rang-Daten vom Server anfordern
            NexusAdmin.OpenMenu()
            NexusAdmin._MenuOpen = true

            net.Start("NexusAdmin_RequestAllRanks")
            net.SendToServer()
        end
    end

    -- Fallende Flanke: Taste losgelassen → nächsten Druck erlauben
    if not isDown then
        keyWasDown = false
    end
end)

-- Wenn das Menü extern geschlossen wird (z.B. per Escape-Taste),
-- den _MenuOpen-State zurücksetzen.
hook.Add("OnScreenSizeChanged", "NexusAdmin_ResetMenuState", function()
    NexusAdmin._MenuOpen = false
    keyWasDown           = false
end)

-- Konsolenbefehl als Alternative zum Keybind
concommand.Add("na_menu", function()
    if not IsValid(LocalPlayer()) then return end
    if not LocalPlayer():IsAdmin()  then return end

    if NexusAdmin._MenuOpen and IsValid(NexusAdmin._MenuFrame) then
        NexusAdmin._MenuFrame:Close()
        NexusAdmin._MenuOpen = false
    else
        NexusAdmin.OpenMenu()
        NexusAdmin._MenuOpen = true
        net.Start("NexusAdmin_RequestAllRanks")
        net.SendToServer()
    end
end)
