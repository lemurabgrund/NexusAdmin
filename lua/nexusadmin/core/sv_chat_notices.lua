-- ============================================================
--  NexusAdmin | sv_chat_notices.lua
--  Anonymes Benachrichtigungs-System.
--
--  Prinzip:
--    Admins sehen:  "[AdminName] hat [Ziel] [Aktion]."
--    User sehen:    "Ein Teammitglied hat [Ziel] [Aktion]."
--
--  Alle Befehle sollen NexusAdmin.AnnounceAction() verwenden
--  statt rohe ChatPrint/NotifyAdmins-Aufrufe.
--
--  Zusätzlich: !m (Admin-Broadcast) und !pm (Private Message)
--  werden hier als Net-Messages definiert damit sie sauber
--  Client-seitig gerendert werden können.
-- ============================================================

util.AddNetworkString("NexusAdmin_ChatNotice")   -- Allgemeine Aktion-Notice
util.AddNetworkString("NexusAdmin_AdminMessage")  -- !m  – Admin-Broadcast
util.AddNetworkString("NexusAdmin_PrivateMsg")    -- !pm – Private Message

-- ── Typ-Konstanten für AnnounceAction ────────────────────────
NexusAdmin.Notice = {
    KICK    = "kick",
    BAN     = "ban",
    WARN    = "warn",
    MUTE    = "mute",
    UNMUTE  = "unmute",
    SLAY    = "slay",
    FREEZE  = "freeze",
    GENERIC = "info",
}

-- ── Aktion-Texte für die anonyme Variante ────────────────────
-- Jeder Typ hat einen vorgefertigten Satz für User (anon) und
-- einen für Admins (mit Namen). %s wird durch Zielnamen ersetzt.
local ActionTemplates = {
    [NexusAdmin.Notice.KICK]    = { anon = "Ein Teammitglied hat %s vom Server entfernt.",    full = "%s hat %s vom Server entfernt."    },
    [NexusAdmin.Notice.BAN]     = { anon = "Ein Teammitglied hat %s ausgeschlossen.",         full = "%s hat %s ausgeschlossen."         },
    [NexusAdmin.Notice.WARN]    = { anon = "Ein Teammitglied hat %s verwarnt.",               full = "%s hat %s verwarnt."               },
    [NexusAdmin.Notice.MUTE]    = { anon = "Ein Teammitglied hat %s zum Schweigen gebracht.", full = "%s hat %s zum Schweigen gebracht." },
    [NexusAdmin.Notice.UNMUTE]  = { anon = "Ein Teammitglied hat %s entstummt.",              full = "%s hat %s entstummt."              },
    [NexusAdmin.Notice.SLAY]    = { anon = "Ein Teammitglied hat %s eliminiert.",             full = "%s hat %s eliminiert."             },
    [NexusAdmin.Notice.FREEZE]  = { anon = "Ein Teammitglied hat %s eingefroren.",            full = "%s hat %s eingefroren."            },
    [NexusAdmin.Notice.GENERIC] = { anon = "Ein Teammitglied hat eine Aktion ausgeführt.",    full = "%s hat eine Aktion ausgeführt."    },
}

-- Farben je nach Aktion-Typ (für das Notify-Panel)
local ActionColors = {
    [NexusAdmin.Notice.KICK]    = Color(255, 160, 40),
    [NexusAdmin.Notice.BAN]     = Color(255, 50,  80),
    [NexusAdmin.Notice.WARN]    = Color(255, 200, 40),
    [NexusAdmin.Notice.MUTE]    = Color(160, 80,  255),
    [NexusAdmin.Notice.UNMUTE]  = Color(50,  255, 140),
    [NexusAdmin.Notice.SLAY]    = Color(255, 50,  80),
    [NexusAdmin.Notice.FREEZE]  = Color(0,   210, 255),
    [NexusAdmin.Notice.GENERIC] = Color(0,   210, 255),
}

-- ── AnnounceAction ───────────────────────────────────────────
-- Sendet eine rollenbasiert getrennte Benachrichtigung.
-- Admins sehen den echten Admin-Namen, User nur "Ein Teammitglied".
--
-- @param admin       Player|string  – Ausführender Admin (oder "system")
-- @param targetNick  string         – Name des betroffenen Spielers
-- @param actionType  string         – Aus NexusAdmin.Notice.*
-- @param extra       string|nil     – Optionaler Zusatztext (z.B. Grund)
function NexusAdmin.AnnounceAction(admin, targetNick, actionType, extra)
    local tmpl = ActionTemplates[actionType] or ActionTemplates[NexusAdmin.Notice.GENERIC]
    local col  = ActionColors[actionType]    or ActionColors[NexusAdmin.Notice.GENERIC]

    -- Admin-Name auflösen
    local adminName = IsValid(admin) and admin:Nick() or "System"

    -- Texte vorbereiten
    local textFull, textAnon

    if actionType == NexusAdmin.Notice.GENERIC then
        textFull = string.format(tmpl.full, adminName)
        textAnon = tmpl.anon
    else
        textFull = string.format(tmpl.full, adminName, targetNick)
        textAnon = string.format(tmpl.anon, targetNick)
    end

    -- Optionalen Grund anhängen
    if extra and extra ~= "" then
        textFull = textFull .. "  |  " .. extra
        textAnon = textAnon .. "  |  " .. extra
    end

    -- An jeden Spieler individuell senden
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local isAdmin = ply:IsAdmin()
        local text    = isAdmin and textFull or textAnon

        net.Start("NexusAdmin_ChatNotice")
            net.WriteString(text)
            net.WriteUInt(col.r, 8)
            net.WriteUInt(col.g, 8)
            net.WriteUInt(col.b, 8)
            net.WriteString(actionType)
        net.Send(ply)
    end

    -- Server-seitig loggen (immer mit vollem Namen)
    NexusAdmin.Log(string.format("NOTICE [%s]: %s", actionType, textFull), "NOTICE")
end

-- ── !m – Admin-Broadcast ─────────────────────────────────────
-- Sendet eine hervorgehobene Nachricht an alle Teammitglieder (Admins).
-- Net-Message NexusAdmin_AdminMessage wird client-seitig gerendert.
function NexusAdmin.SendAdminMessage(sender, message)
    if not message or message == "" then return end

    local senderName = IsValid(sender) and sender:Nick() or "System"

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:IsAdmin()  then continue end

        net.Start("NexusAdmin_AdminMessage")
            net.WriteString(senderName)
            net.WriteString(message)
        net.Send(ply)
    end

    NexusAdmin.Log(string.format("ADMIN-MSG von %s: %s", senderName, message), "CHAT")
end

-- ── !pm – Private Message ────────────────────────────────────
-- Sendet eine private Nachricht von Admin zu Spieler (oder umgekehrt).
function NexusAdmin.SendPrivateMessage(sender, target, message)
    if not IsValid(sender) or not IsValid(target) then return end
    if not message or message == "" then return end

    local fromName = sender:Nick()
    local toName   = target:Nick()

    -- Sender bekommt Sendequittung
    net.Start("NexusAdmin_PrivateMsg")
        net.WriteString(fromName)
        net.WriteString(toName)
        net.WriteString(message)
        net.WriteBool(true)   -- isSender = true
    net.Send(sender)

    -- Empfänger bekommt die Nachricht
    net.Start("NexusAdmin_PrivateMsg")
        net.WriteString(fromName)
        net.WriteString(toName)
        net.WriteString(message)
        net.WriteBool(false)  -- isSender = false
    net.Send(target)

    NexusAdmin.Log(string.format("PM: %s → %s: %s", fromName, toName, message), "CHAT")
end

-- ── cl_chat_notices.lua (Client-Receiver) ────────────────────
-- Hinweis: Die Empfangs-Logik steht in cl_chat_notices.lua
-- damit der Client-Code sauber getrennt bleibt.
