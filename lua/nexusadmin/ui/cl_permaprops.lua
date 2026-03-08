-- ============================================================
--  NexusAdmin | cl_permaprops.lua
--  Client-seitige PermaProp-Integration.
--
--  - C-Menü (Rechtsklick auf Prop) → "Als PermaProp speichern"
--  - "PermaProp entfernen" (nur wenn Prop bereits PermaProp)
--  - PermaProp-Liste im Admin-Menü (Tab in F4-Menü)
-- ============================================================

-- ── Net-Receiver: PermaProp-Liste ────────────────────────────
NexusAdmin._PermaPropListCache = {}

net.Receive("NexusAdmin_PermaPropList", function()
    NexusAdmin._PermaPropListCache = {}
    local cnt = net.ReadUInt(16)
    for _ = 1, cnt do
        NexusAdmin._PermaPropListCache[#NexusAdmin._PermaPropListCache + 1] = {
            id         = net.ReadUInt(16),
            model      = net.ReadString(),
            created_by = net.ReadString(),
            created_at = net.ReadDouble(),
        }
    end

    -- Falls PermaProp-Tab offen ist: neu aufbauen
    if NexusAdmin.BuildPermaPropList and IsValid(NexusAdmin._MenuFrame) then
        local content = NexusAdmin._MenuFrame:Find("na_content")
        if IsValid(content) then
            NexusAdmin.BuildPermaPropList(content)
        end
    end
end)

-- ── C-Menü: Rechtsklick auf Entity ───────────────────────────
-- Nur sichtbar für Spieler mit "permaprops"-Berechtigung.
hook.Add("PopulateEntityMenu", "NexusAdmin_PermaPropCtx", function(ent, menu)
    if not IsValid(ent) then return end

    -- Nur anzeigen wenn Spieler die Berechtigung hat (NWString check)
    local rankId   = NexusAdmin._RankCache and NexusAdmin._RankCache[LocalPlayer():SteamID64()] or "user"
    local hasPerm  = NexusAdmin.RankHasPermission and NexusAdmin.RankHasPermission(rankId, "permaprops")
    if not hasPerm then return end

    menu:AddSpacer()

    local isPermaProp = ent:GetNWBool("na_permaprop", false)

    if not isPermaProp then
        menu:AddOption("🔒 Als PermaProp speichern", function()
            net.Start("NexusAdmin_AddPermaProp")
                net.WriteEntity(ent)
            net.SendToServer()
        end):SetIcon("icon16/lock.png")
    else
        local ppId = ent:GetNWInt("na_permaprop_id", 0)
        menu:AddOption("🗑 PermaProp entfernen (#" .. ppId .. ")", function()
            Derma_Query(
                "PermaProp #" .. ppId .. " entfernen?",
                "PermaProp löschen",
                "Ja", function()
                    net.Start("NexusAdmin_RemovePermaProp")
                        net.WriteUInt(ppId, 16)
                    net.SendToServer()
                end,
                "Abbrechen", function() end
            )
        end):SetIcon("icon16/delete.png")
    end
end)

-- ── PermaProp-Tab im F4-Admin-Menü ────────────────────────────
function NexusAdmin.BuildPermaPropList(parent)
    parent:Clear()

    local T = NexusAdmin.Theme
    local W = parent:GetWide()
    local H = parent:GetTall()

    -- Header
    local header = vgui.Create("DPanel", parent)
    header:SetPos(0, 0)
    header:SetSize(W, 50)
    header.Paint = function(self, w, h)
        draw.SimpleText("PERMAPROPS", T.Fonts.Title,
            16, h * 0.5, Color(0, 210, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(
            tostring(#NexusAdmin._PermaPropListCache) .. " gespeichert",
            T.Fonts.Small,
            w - 16, h * 0.5, Color(80, 100, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(Color(0, 210, 255, 30))
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- Toolbar
    local toolbar = vgui.Create("DPanel", parent)
    toolbar:SetPos(0, 50)
    toolbar:SetSize(W, 40)
    toolbar.Paint = function() end

    -- Refresh-Button
    local refreshBtn = vgui.Create("DButton", toolbar)
    refreshBtn:SetPos(W - 120, 4)
    refreshBtn:SetSize(110, 32)
    refreshBtn:SetText("")
    refreshBtn._hv = 0
    refreshBtn.Paint = function(self, w, h)
        self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
        draw.RoundedBox(6, 0, 0, w, h, Color(0, 210, 255, math.floor(self._hv * 60 + 20)))
        T.DrawBorder(0, 0, w, h, Color(0, 210, 255, math.floor(self._hv * 80 + 40)), 6)
        draw.SimpleText("↻ AKTUALISIEREN", T.Fonts.Small, w * 0.5, h * 0.5,
            Color(0, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    refreshBtn.DoClick = function()
        LocalPlayer():ConCommand("say !pplist\n")
    end

    -- Scrollliste
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:SetPos(0, 92)
    scroll:SetSize(W, H - 92)
    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    function sbar:Paint(w, h)    draw.RoundedBox(2, 0, 0, w, h, Color(20, 22, 30)) end
    function sbar.btnUp:Paint()  end
    function sbar.btnDown:Paint() end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(0, 210, 255, 120))
    end

    local list = NexusAdmin._PermaPropListCache
    if #list == 0 then
        local empty = vgui.Create("DPanel", scroll)
        empty:SetSize(W - 8, 60)
        empty:Dock(TOP)
        empty.Paint = function(self, w, h)
            draw.SimpleText("Keine PermaProps gespeichert.", T.Fonts.Body,
                w * 0.5, h * 0.5, Color(80, 100, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return
    end

    for _, pp in ipairs(list) do
        local row = vgui.Create("DPanel", scroll)
        row:SetSize(W - 8, 52)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)

        -- Modell-Name kürzen
        local modelShort = pp.model:match("([^/]+)$") or pp.model

        -- Zeitangabe
        local ago = os.time() - pp.created_at
        local agoStr = ago < 3600 and math.floor(ago / 60) .. "m"
            or ago < 86400 and math.floor(ago / 3600) .. "h"
            or math.floor(ago / 86400) .. "d"

        row.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(22, 24, 34, 220))
            draw.RoundedBox(4, 0, 6, 3, h - 12, Color(0, 210, 255, 180))

            draw.SimpleText("#" .. pp.id .. "  " .. modelShort, T.Fonts.Body,
                12, h * 0.5 - 7, Color(220, 235, 245), TEXT_ALIGN_LEFT)
            draw.SimpleText("von " .. pp.created_by, T.Fonts.Small,
                12, h * 0.5 + 8, Color(70, 90, 110), TEXT_ALIGN_LEFT)
            draw.SimpleText("vor " .. agoStr, T.Fonts.Small,
                w - 12, h * 0.5, Color(80, 100, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- Entfernen-Button (nur für Spieler mit permaprops-Berechtigung)
        local myRank2 = NexusAdmin._RankCache and NexusAdmin._RankCache[LocalPlayer():SteamID64()] or "user"
        if NexusAdmin.RankHasPermission(myRank2, "permaprops") then
            local delBtn = vgui.Create("DButton", row)
            delBtn:SetPos(row:GetWide() - 110, 10)
            delBtn:SetSize(100, 32)
            delBtn:SetText("")
            delBtn._hv = 0
            delBtn.Paint = function(self, w, h)
                self._hv = math.Approach(self._hv, self:IsHovered() and 1 or 0, FrameTime() * 8)
                draw.RoundedBox(4, 0, 0, w, h, Color(255, 50, 80, math.floor(self._hv * 60 + 20)))
                T.DrawBorder(0, 0, w, h, Color(255, 50, 80, math.floor(self._hv * 80 + 40)), 4)
                draw.SimpleText("ENTFERNEN", T.Fonts.Small, w * 0.5, h * 0.5,
                    Color(255, 100, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            delBtn.DoClick = function()
                Derma_Query(
                    "PermaProp #" .. pp.id .. " entfernen?",
                    "Bestätigen",
                    "Ja", function()
                        net.Start("NexusAdmin_RemovePermaProp")
                            net.WriteUInt(pp.id, 16)
                        net.SendToServer()
                    end,
                    "Abbrechen", function() end
                )
            end
        end
    end
end
