-- ============================================================
--  NexusAdmin | cl_config_ui.lua
--  Hybrid-Config-UI – NexusAdmin-Settings + GMod-Convars.
--
--  Zwei Bereiche:
--    NEXUSADMIN  – ChatFilter, Warn-Schwelle, Log, Prefix…
--    SERVER      – sbox_maxprops, sv_cheats, sbox_godmode…
--
--  Änderungen werden via concommand an den Server gesendet.
--  Nur für Superadmins zugänglich.
-- ============================================================

-- Server-seitiger Empfänger: nexusadmin/core/sv_config.lua
-- Net-String wird dort registriert.

local CFG_W = 680
local CFG_H = 540

-- ── Config-UI öffnen ─────────────────────────────────────────
function NexusAdmin.OpenConfigUI()
    local myRank = NexusAdmin._RankCache and NexusAdmin._RankCache[LocalPlayer():SteamID64()] or "user"
    if not NexusAdmin.RankHasPermission(myRank, "superadmin") then
        chat.AddText(Color(255, 50, 80), "[NexusAdmin] Nur für Superadmins.")
        return
    end

    if IsValid(NexusAdmin._ConfigFrame) then
        NexusAdmin._ConfigFrame:Remove()
    end

    local T = NexusAdmin.Theme

    local frame = vgui.Create("DPanel")
    NexusAdmin._ConfigFrame = frame
    frame:SetSize(CFG_W, CFG_H)
    frame:SetPos(ScrW() * 0.5 - CFG_W * 0.5, ScrH() * 0.5 - CFG_H * 0.5)
    frame:MakePopup()

    frame._alpha = 0
    frame.Paint = function(self, w, h)
        self._alpha = math.Approach(self._alpha, 255, FrameTime() * 800)
        local a = self._alpha
        T.DrawBlur(self, T.BlurStrength)
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 12, 18, math.floor(a * 0.96)))
        draw.RoundedBoxEx(10, 1, 1, w - 2, math.floor(h * 0.12),
            Color(255, 255, 255, math.floor(a * 0.04)), true, true, false, false)
        T.DrawBorder(0, 0, w, h, Color(160, 80, 255, math.floor(a * 0.5)), 10)
        draw.SimpleText("KONFIGURATION", T.Fonts.Title,
            w * 0.5, 26, Color(160, 80, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(Color(160, 80, 255, 30))
        surface.DrawRect(16, 50, w - 32, 1)
    end

    -- Schließen
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(CFG_W - 38, 8)
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

    -- ── Tabs: NEXUSADMIN / SERVER ─────────────────────────────
    local TABS    = { "NEXUSADMIN", "SERVER" }
    local tabBtns = {}
    local activeTab = "NEXUSADMIN"

    local content = vgui.Create("DScrollPanel", frame)
    content:SetPos(16, 90)
    content:SetSize(CFG_W - 32, CFG_H - 100)
    local csbar = content:GetVBar()
    csbar:SetWide(4)
    function csbar:Paint(w, h)     draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30)) end
    function csbar.btnUp:Paint()   end
    function csbar.btnDown:Paint() end
    function csbar.btnGrip:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(160, 80, 255, 120))
    end

    -- ── Hilfs-Funktion: Konfig-Zeile ──────────────────────────
    local function AddRow(parent, label, desc, netKey, valueType, currentVal, opts)
        local row = vgui.Create("DPanel", parent)
        row:SetSize(content:GetWide() - 8, 62)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)

        row.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(22, 24, 34, 200))
            draw.RoundedBox(4, 0, 6, 3, h - 12, Color(160, 80, 255, 180))
            draw.SimpleText(label, T.Fonts.Body,    12, 14, Color(220, 235, 245))
            draw.SimpleText(desc,  T.Fonts.Small,   12, 34, Color(80, 100, 120))
        end

        if valueType == "bool" then
            local cb = vgui.Create("DCheckBox", row)
            cb:SetPos(row:GetWide() - 40, 20)
            cb:SetSize(22, 22)
            cb:SetValue(currentVal and true or false)
            cb.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(20, 22, 30, 220))
                T.DrawBorder(0, 0, w, h, Color(160, 80, 255, 80), 4)
                if self:GetChecked() then
                    draw.RoundedBox(3, 4, 4, w - 8, h - 8, Color(160, 80, 255))
                end
            end
            cb.OnChange = function(self, val)
                net.Start("NexusAdmin_UpdateConfig")
                    net.WriteString(netKey)
                    net.WriteString(val and "1" or "0")
                net.SendToServer()
            end

        elseif valueType == "number" then
            local input = vgui.Create("DTextEntry", row)
            input:SetPos(row:GetWide() - 130, 15)
            input:SetSize(120, 32)
            input:SetFont(T.Fonts.Small)
            input:SetText(tostring(currentVal))
            input:SetNumeric(true)
            input.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(20, 22, 30, 220))
                T.DrawBorder(0, 0, w, h,
                    self:IsEditing() and Color(160, 80, 255, 100) or Color(160, 80, 255, 40), 4)
                self:DrawTextEntryText(Color(220, 235, 245), Color(160, 80, 255, 100), Color(160, 80, 255))
            end
            input.OnEnter = function(self)
                net.Start("NexusAdmin_UpdateConfig")
                    net.WriteString(netKey)
                    net.WriteString(self:GetValue())
                net.SendToServer()
            end

        elseif valueType == "convar" then
            local input = vgui.Create("DTextEntry", row)
            input:SetPos(row:GetWide() - 130, 15)
            input:SetSize(120, 32)
            input:SetFont(T.Fonts.Small)
            input:SetText(GetConVar(netKey) and GetConVar(netKey):GetString() or tostring(currentVal))
            input.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(20, 22, 30, 220))
                T.DrawBorder(0, 0, w, h,
                    self:IsEditing() and Color(0, 210, 255, 100) or Color(0, 210, 255, 40), 4)
                self:DrawTextEntryText(Color(220, 235, 245), Color(0, 210, 255, 100), Color(0, 210, 255))
            end
            input.OnEnter = function(self)
                net.Start("NexusAdmin_UpdateConfig")
                    net.WriteString(netKey)
                    net.WriteString(self:GetValue())
                net.SendToServer()
            end
        end
    end

    -- ── Sektion-Header ─────────────────────────────────────────
    local function AddSection(parent, title, col)
        local sec = vgui.Create("DPanel", parent)
        sec:SetSize(content:GetWide() - 8, 32)
        sec:Dock(TOP)
        sec:DockMargin(0, 8, 0, 4)
        sec.Paint = function(self, w, h)
            draw.SimpleText(title, T.Fonts.Small,
                10, h * 0.5, col or Color(0, 210, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor((col or Color(0, 210, 255)).r,
                (col or Color(0, 210, 255)).g,
                (col or Color(0, 210, 255)).b, 30)
            surface.DrawRect(0, h - 1, w, 1)
        end
    end

    -- ── Tab-Inhalte ───────────────────────────────────────────
    local cfg = NexusAdmin.Config

    local function BuildNexusAdminTab()
        content:Clear()

        AddSection(content, "CHAT-FILTER", Color(0, 210, 255))
        AddRow(content, "Chatfilter aktiv",
            "Blacklist-Scan und Auto-Mute aktivieren",
            "na_chatfilter_enabled", "bool",
            cfg.ChatFilter and cfg.ChatFilter.Enabled)

        AddRow(content, "Max. Nachrichtenlänge",
            "0 = kein Limit (Zeichen)",
            "na_chatfilter_maxlength", "number",
            cfg.ChatFilter and cfg.ChatFilter.MaxLength or 250)

        AddRow(content, "Auto-Mute Dauer",
            "In Sekunden (Standard: 300 = 5 Minuten)",
            "na_chatfilter_mute_duration", "number",
            cfg.ChatFilter and cfg.ChatFilter.MuteDuration or 300)

        AddSection(content, "VERWARNUNGEN", Color(255, 200, 40))
        AddRow(content, "Verwarnungs-Schwelle",
            "Anzahl Verwarnungen bis zum Auto-Bann",
            "na_warn_threshold", "number",
            cfg.WarnThreshold or 4)

        AddSection(content, "SYSTEM", Color(160, 80, 255))
        AddRow(content, "In Datei loggen",
            "Logs in data/nexusadmin/admin.log schreiben",
            "na_log_to_file", "bool",
            cfg.LogToFile)

        AddRow(content, "Max. Benachrichtigungen",
            "Gleichzeitige Notify-Panels (1–10)",
            "na_max_notifications", "number",
            cfg.MaxNotifications or 5)
    end

    local function BuildServerTab()
        content:Clear()

        AddSection(content, "PHYSIK", Color(0, 210, 255))
        AddRow(content, "Gravitation (sv_gravity)",
            "Standard: 600",
            "sv_gravity", "convar", 600)

        AddRow(content, "Air Accelerate (sv_airaccelerate)",
            "Luftbeschleunigung (Standard: 10)",
            "sv_airaccelerate", "convar", 10)

        AddSection(content, "SANDBOX LIMITS", Color(50, 255, 140))
        local sbLimits = {
            { "Max. Props",      "sbox_maxprops",    200 },
            { "Max. Ragdolls",   "sbox_maxragdolls",  5  },
            { "Max. Effects",    "sbox_maxeffects",  200 },
            { "Max. Balloons",   "sbox_maxballoons",  10 },
            { "Max. NPCs",       "sbox_maxnpcs",      10 },
        }
        for _, v in ipairs(sbLimits) do
            AddRow(content, v[1], "Spieler-Limit", v[2], "convar", v[3])
        end

        AddSection(content, "GAMEPLAY", Color(255, 200, 40))
        AddRow(content, "Godmode für alle (sbox_godmode)",
            "1 = alle unverwundbar",
            "sbox_godmode", "convar", 0)

        AddRow(content, "Spieler können sich gegenseitig verletzen",
            "sbox_playershurtplayers",
            "sbox_playershurtplayers", "convar", 1)
    end

    local tabFuncs = {
        NEXUSADMIN = BuildNexusAdminTab,
        SERVER     = BuildServerTab,
    }

    for i, tabName in ipairs(TABS) do
        local btn = vgui.Create("DButton", frame)
        btn:SetPos(16 + (i - 1) * 150, 56)
        btn:SetSize(140, 30)
        btn:SetText("")
        btn._tabName = tabName
        btn._active  = (tabName == activeTab)
        btn._hv      = 0
        tabBtns[i]   = btn

        btn.Paint = function(self, w, h)
            self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
            local active = self._active
            local col    = active and Color(160, 80, 255) or Color(0, 210, 255)

            draw.RoundedBox(6, 0, 0, w, h,
                Color(col.r, col.g, col.b, active and 40 or math.floor(self._hv * 30)))
            if active then
                T.DrawBorder(0, 0, w, h, Color(col.r, col.g, col.b, 80), 6)
                surface.SetDrawColor(col)
                surface.DrawRect(6, h - 2, w - 12, 2)
            end
            draw.SimpleText(tabName, T.Fonts.Small, w * 0.5, h * 0.5,
                active and col or Color(120, 140, 160),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function()
            activeTab = tabName
            for _, b in ipairs(tabBtns) do b._active = (b._tabName == tabName) end
            local fn = tabFuncs[tabName]
            if fn then fn() end
        end
    end

    BuildNexusAdminTab()
end

-- ── ConCommand ────────────────────────────────────────────────
concommand.Add("na_config", function()
    NexusAdmin.OpenConfigUI()
end)

-- (end of cl_config_ui.lua)
