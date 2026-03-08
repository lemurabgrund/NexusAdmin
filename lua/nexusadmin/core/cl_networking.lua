-- ============================================================
--  NexusAdmin | cl_networking.lua
--  Client-seitiges Net-System:
--   - Empfängt Rang-Updates und Benachrichtigungen
--   - Empfängt Warn-Count-Updates (NexusAdmin_SyncWarnCount)
--   - Verwaltet die lokale Notify-Queue (Stapel-Animationen)
-- ============================================================

-- ── Warn-Count-Sync empfangen ────────────────────────────────
-- Wird getriggert wenn sich der Warn-Count eines Spielers ändert.
-- Aktualisiert die Spielerliste im Admin-Menü wenn sie gerade offen ist.
net.Receive("NexusAdmin_SyncWarnCount", function()
    local userId   = net.ReadUInt(16)
    local newCount = net.ReadUInt(8)

    -- NWInt wird vom Server bereits gesetzt; hier nur UI-Refresh triggern.
    if IsValid(NexusAdmin._MenuFrame) then
        local content = NexusAdmin._MenuFrame:Find("na_content")
        if IsValid(content) then
            NexusAdmin.BuildPlayerList(content)
        end
    end
end)

-- ── Rang-Sync empfangen ──────────────────────────────────────
-- Wird getriggert wenn der Server einen einzelnen Rang ändert.
net.Receive("NexusAdmin_SyncRank", function()
    local userId = net.ReadUInt(16)
    local rankId = net.ReadString()

    -- Spieler anhand der UserID suchen (sicherer als Entity-Index)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:UserID() == userId then
            -- NWString wird vom Server schon gesetzt,
            -- aber wir aktualisieren die lokale Playerlist-UI falls offen.
            if IsValid(NexusAdmin._MenuFrame) then
                local content = NexusAdmin._MenuFrame:Find("na_content")
                if IsValid(content) then
                    NexusAdmin.BuildPlayerList(content)
                end
            end
            break
        end
    end
end)

-- ── Alle Ränge auf einmal empfangen ─────────────────────────
net.Receive("NexusAdmin_SyncAllRanks", function()
    local rankTable = net.ReadTable()
    -- Tabelle im lokalen Cache speichern für schnellen UI-Zugriff
    NexusAdmin._RankCache = rankTable
end)

-- ── Benachrichtigungs-Queue ──────────────────────────────────
-- Benachrichtigungen werden gestapelt und nacheinander animiert,
-- damit sie sich nicht überlagern.

NexusAdmin._NotifyQueue  = NexusAdmin._NotifyQueue  or {}
NexusAdmin._NotifyActive = NexusAdmin._NotifyActive or {}

-- Konfiguration der Notify-Animationen
local NOTIFY_WIDTH  = 320
local NOTIFY_HEIGHT = 54
local NOTIFY_PAD    = 10

-- Icons je nach Typ (Material-Objekte einmalig laden)
local NotifyIcons = {
    info    = Material("icon16/information.png"),
    success = Material("icon16/accept.png"),
    error   = Material("icon16/cancel.png"),
    warning = Material("icon16/error.png"),
}

local NotifyColors = {
    info    = Color(99,  179, 237),
    success = Color(72,  199, 142),
    error   = Color(220, 60,  60 ),
    warning = Color(255, 180, 50 ),
}

-- Berechnet die Ziel-Y-Position für einen Notify-Slot.
local function NotifyYPos(slot)
    return ScrH() - 80 - (slot * (NOTIFY_HEIGHT + NOTIFY_PAD))
end

-- Entfernt ein Panel aus der Aktiv-Liste und schiebt
-- alle verbleibenden Panels neu zusammen.
local function RemoveFromActive(panel)
    for i, p in ipairs(NexusAdmin._NotifyActive) do
        if p == panel then
            table.remove(NexusAdmin._NotifyActive, i)
            break
        end
    end
    -- Verbleibende Panels neu positionieren
    for i, p in ipairs(NexusAdmin._NotifyActive) do
        if IsValid(p) then
            p:MoveTo(ScrW() - NOTIFY_WIDTH - 20, NotifyYPos(i), 0.2, 0, -1)
        end
    end
end

-- Zeigt eine einzelne Benachrichtigung mit Slide-In Animation an.
local function ShowNotify(data)
    local T = NexusAdmin.Theme
    local slot = #NexusAdmin._NotifyActive + 1

    -- Panel startet rechts außerhalb des Screens
    local panel = vgui.Create("DPanel")
    panel:SetSize(NOTIFY_WIDTH, NOTIFY_HEIGHT)
    panel:SetPos(ScrW() + 10, NotifyYPos(slot))

    local accentColor = NotifyColors[data.icon] or NotifyColors.info
    local icon        = NotifyIcons[data.icon]  or NotifyIcons.info

    panel.Paint = function(self, w, h)
        -- Hintergrund
        draw.RoundedBox(8, 0, 0, w, h, T.BG_Medium)

        -- Farbiger Akzentstreifen links je nach Typ
        draw.RoundedBox(4, 0, 0, 4, h, accentColor)

        -- Icon
        surface.SetDrawColor(accentColor)
        surface.SetMaterial(icon)
        surface.DrawTexturedRect(14, (h - 16) * 0.5, 16, 16)

        -- Nachrichtentext
        surface.SetFont(T.Fonts.Body)
        surface.SetTextColor(T.TextMain)
        surface.SetTextPos(38, (h - 15) * 0.5)
        surface.DrawText(data.text)
    end

    table.insert(NexusAdmin._NotifyActive, panel)

    -- Slide-In Animation
    panel:MoveTo(ScrW() - NOTIFY_WIDTH - 20, NotifyYPos(slot), 0.3, 0, -1)

    -- Nach Ablauf der Anzeigedauer: Slide-Out und entfernen
    timer.Simple(data.duration or NexusAdmin.Config.DefaultNotifyDuration, function()
        if not IsValid(panel) then
            RemoveFromActive(panel)
            return
        end
        panel:MoveTo(ScrW() + 10, panel:GetY(), 0.3, 0, -1, function()
            if IsValid(panel) then panel:Remove() end
            RemoveFromActive(panel)

            -- Nächste Benachrichtigung aus der Queue anzeigen
            if #NexusAdmin._NotifyQueue > 0 then
                ShowNotify(table.remove(NexusAdmin._NotifyQueue, 1))
            end
        end)
    end)
end

-- ── Net-Receive: Benachrichtigung vom Server ─────────────────
net.Receive("NexusAdmin_Notify", function()
    local text     = net.ReadString()
    local r        = net.ReadUInt(8)
    local g        = net.ReadUInt(8)
    local b        = net.ReadUInt(8)
    local icon     = net.ReadString()
    local duration = net.ReadFloat()

    local notifyData = {
        text     = text,
        color    = Color(r, g, b),
        icon     = icon,
        duration = duration,
    }

    -- Wenn zu viele Benachrichtigungen aktiv sind, in Queue stellen
    if #NexusAdmin._NotifyActive >= NexusAdmin.Config.MaxNotifications then
        table.insert(NexusAdmin._NotifyQueue, notifyData)
        return
    end

    ShowNotify(notifyData)
end)
