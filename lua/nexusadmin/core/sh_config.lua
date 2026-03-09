-- ============================================================
--  NexusAdmin | sh_config.lua
--  Zentrale Konfiguration des Systems.
--  Hier können Server-Betreiber Einstellungen anpassen.
-- ============================================================

NexusAdmin.Config = {
    -- Taste zum Öffnen des Admin-Menüs (KEY_F4 = 23)
    MenuKey = KEY_F4,

    -- Standard-Rang für neue Spieler
    DefaultRank = "user",

    -- Prefix für Chat-Befehle (z.B. "!" für !kick, !ban)
    ChatPrefix = "!",

    -- Maximale Anzahl gleichzeitiger Benachrichtigungen auf dem Screen
    MaxNotifications = 5,

    -- Dauer von Benachrichtigungen in Sekunden (Fallback)
    DefaultNotifyDuration = 4,

    -- Ob Befehlsausführungen in der Server-Konsole geloggt werden
    LogCommands = true,

    -- Ob Logs zusätzlich in data/nexusadmin/admin.log geschrieben werden
    LogToFile = true,

    -- ── Verwarnungs-System ────────────────────────────────────

    -- Anzahl aktiver Verwarnungen bis zum automatischen Bann
    WarnThreshold = 4,

    -- Dauer des automatischen Banns in Sekunden (604800 = 1 Woche)
    WarnAutoBanDuration = 604800,

    -- Grund der automatisch für den Auto-Bann eingetragen wird
    WarnAutoBanReason = "Automatischer Ausschluss: Verwarnungs-Schwelle erreicht",

    -- Net-Message-Name für Warn-Count-Sync (Client → Spielerliste)
    WarnNetMessage = "NexusAdmin_SyncWarnCount",

    -- ── Server-Regeln (F1-Menü) ───────────────────────────────
    -- Diese Liste kann beliebig erweitert werden.
    -- Jeder Eintrag erscheint als eigene Box im Regel-Fenster.
    Rules = {
        "Kein RDM (Random Deathmatch) – töte nur mit Roleplay-Grund.",
        "Kein NLR (New Life Rule) – nach dem Tod kein sofortiges Zurückkehren.",
        "Respektiere alle Spieler und Admins.",
        "Kein FailRP – spiele realistisch entsprechend deiner Rolle.",
        "Keine Cheats, Exploits oder Hacks.",
        "Englisch oder Deutsch im globalen Chat.",
        "Admins haben das letzte Wort – Entscheidungen sind zu akzeptieren.",
    },
}
