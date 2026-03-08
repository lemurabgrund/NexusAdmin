-- ============================================================
--  NexusAdmin | cl_theme.lua  v2 – Glassmorphism & Cyber-Minimalism
--
--  Design-Sprache:
--    Tiefschwarze Hintergründe · Neon-Cyan/Blau Akzente
--    Blur-Panels · 8px Radius · sanfte Lerp-Animationen
--
--  Alle UI-Dateien referenzieren ausschliesslich diese Tabelle.
--  Für einen anderen Look genügt es, hier Werte zu ändern.
-- ============================================================

NexusAdmin.Theme = {

    -- ── Hintergründe (Glassmorphism-Schichten) ────────────────
    BG_Base    = Color(8,   10,  14,  255),   -- Tiefschwarz (hinter Blur)
    BG_Dark    = Color(15,  15,  20,  240),   -- Haupt-Panel (leicht transparent)
    BG_Medium  = Color(20,  22,  30,  230),   -- Sub-Panel
    BG_Light   = Color(30,  34,  48,  220),   -- Hover / aktiver Tab
    BG_Glass   = Color(255, 255, 255, 8),     -- Glas-Highlight-Schicht

    -- ── Akzente (Neon-Cyan-Palette) ───────────────────────────
    Accent        = Color(0,   210, 255, 255),  -- Primär-Cyan
    AccentHover   = Color(80,  230, 255, 255),  -- Heller beim Hover
    AccentDim     = Color(0,   140, 180, 120),  -- Gedimmt (inaktiv)
    AccentGlow    = Color(0,   210, 255, 40),   -- Glow-Overlay

    -- ── Sekundär-Akzente ──────────────────────────────────────
    Neon_Purple   = Color(160, 80,  255, 255),  -- Rang-Highlights etc.
    Neon_Red      = Color(255, 50,  80,  255),  -- Fehler / Bann / Danger
    Neon_Green    = Color(50,  255, 140, 255),  -- Erfolg / Online
    Neon_Yellow   = Color(255, 200, 40,  255),  -- Warnung / Strike

    -- ── Text ──────────────────────────────────────────────────
    TextMain      = Color(220, 235, 245, 255),
    TextMuted     = Color(90,  110, 135, 255),
    TextAccent    = Color(0,   210, 255, 255),
    TextDanger    = Color(255, 80,  100, 255),

    -- ── Linien & Trennelemente ────────────────────────────────
    Divider       = Color(0,   210, 255, 30),   -- Subtile Cyan-Linie
    Border        = Color(0,   210, 255, 60),   -- Sichtbarer Rand
    BorderHover   = Color(0,   210, 255, 180),

    -- ── Schriftarten (werden weiter unten registriert) ────────
    Fonts = {
        Title   = "NA_Font_Title",
        Body    = "NA_Font_Body",
        Small   = "NA_Font_Small",
        Mono    = "NA_Font_Mono",
        TitleLg = "NA_Font_TitleLg",
    },

    -- ── Animation-Konstanten ──────────────────────────────────
    -- Für Lerp-Calls: Wert = Geschwindigkeit (je höher, desto schneller)
    Anim = {
        Fast   = 12,  -- Hover-Fade
        Medium = 6,   -- Panel-Slide
        Slow   = 3,   -- Menü-Öffnen
    },

    -- ── Blur-Stärke ───────────────────────────────────────────
    BlurStrength = 6,   -- Stärke für DrawBlur (1–10)
}

-- ── Schriftarten registrieren ────────────────────────────────
surface.CreateFont("NA_Font_TitleLg", {
    font      = "Roboto",
    size      = 30,
    weight    = 700,
    antialias = true,
})

surface.CreateFont("NA_Font_Title", {
    font      = "Roboto",
    size      = 20,
    weight    = 700,
    antialias = true,
})

surface.CreateFont("NA_Font_Body", {
    font      = "Roboto",
    size      = 14,
    weight    = 400,
    antialias = true,
})

surface.CreateFont("NA_Font_Small", {
    font      = "Roboto",
    size      = 11,
    weight    = 400,
    antialias = true,
})

-- Monospace für SteamIDs, Logs, etc.
surface.CreateFont("NA_Font_Mono", {
    font      = "Lucida Console",
    size      = 12,
    weight    = 400,
    antialias = false,  -- Monospace ohne AA für Schärfe
})

-- ── Shared Render-Hilfsfunktionen ────────────────────────────
-- Alle hier definierten Funktionen sind CLIENT-only.

-- Blur-Material (gamemode-unabhängig, funktioniert in Sandbox UND DarkRP etc.)
local _blurMat = Material("pp/blurscreen")

-- Zeichnet einen Blur-Hintergrund für ein Panel.
-- Muss innerhalb von Paint() aufgerufen werden.
-- Nutzt pp/blurscreen statt DrawBlurredScrollingBackground (Sandbox-only).
-- @param panel    PANEL  – Das Panel (für LocalToScreen)
-- @param passes   number – Anzahl Blur-Passes (= Stärke, default BlurStrength)
function NexusAdmin.Theme.DrawBlur(panel, passes)
    passes = math.Clamp(math.floor((passes or NexusAdmin.Theme.BlurStrength) * 0.6), 1, 5)

    local x, y = panel:LocalToScreen(0, 0)
    local w, h  = panel:GetSize()
    local sw    = ScrW()
    local sh    = ScrH()

    surface.SetMaterial(_blurMat)
    surface.SetDrawColor(255, 255, 255, 200)

    for _ = 1, passes do
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRectUV(
            0, 0, w, h,
            x / sw,       y / sh,
            (x + w) / sw, (y + h) / sh
        )
    end

    -- Dunkle Overlay-Schicht als abgerundetes Rect (Glassmorphism-Ecken)
    -- Ecken bleiben blur-transparent → echter Glas-Effekt
    local bg = NexusAdmin.Theme.BG_Dark
    draw.RoundedBox(10, 0, 0, w, h, Color(bg.r, bg.g, bg.b, bg.a))
end

-- Zeichnet einen Neon-Rahmen (1px) um ein Rechteck.
-- @param x, y, w, h  number  – Position und Größe
-- @param col         Color   – Rahmenfarbe
-- @param radius      number  – Ecken-Radius (default 8)
function NexusAdmin.Theme.DrawBorder(x, y, w, h, col, radius)
    radius = radius or 8
    local T = NexusAdmin.Theme

    -- Äußerer Rahmen (leuchtet)
    surface.SetDrawColor(col or T.Border)
    -- Obere Linie
    surface.DrawRect(x + radius, y, w - radius * 2, 1)
    -- Untere Linie
    surface.DrawRect(x + radius, y + h - 1, w - radius * 2, 1)
    -- Linke Linie
    surface.DrawRect(x, y + radius, 1, h - radius * 2)
    -- Rechte Linie
    surface.DrawRect(x + w - 1, y + radius, 1, h - radius * 2)
end

-- Zeichnet einen Neon-Glow-Effekt unter einem Panel (mehrere transparente Rects).
-- Simuliert einen Schein-Effekt ohne Shader.
-- @param x, y, w, h  number  – Bereich
-- @param col         Color   – Glow-Farbe
function NexusAdmin.Theme.DrawGlow(x, y, w, h, col)
    col = col or NexusAdmin.Theme.AccentGlow
    for i = 1, 4 do
        surface.SetDrawColor(col.r, col.g, col.b, math.floor(col.a / i))
        surface.DrawRect(x - i, y - i, w + i * 2, h + i * 2)
    end
end

-- Zeichnet einen Verlaufs-Balken (links-Cyan → rechts-transparent).
-- Nützlich für Trennlinien mit Fade-Out.
-- @param x, y, w, h  number – Bereich
-- @param col         Color  – Startfarbe
function NexusAdmin.Theme.DrawFadeLine(x, y, w, h, col)
    col = col or NexusAdmin.Theme.Accent
    local steps = math.max(1, w)
    for i = 0, steps do
        local alpha = math.floor(col.a * (1 - i / steps))
        surface.SetDrawColor(col.r, col.g, col.b, alpha)
        surface.DrawRect(x + i, y, 1, h)
    end
end

-- Lerp-Helper: gibt den aktuellen Wert basierend auf Ziel und Speed zurück.
-- Muss jedes Frame aufgerufen werden (in Think oder Paint).
-- @param current  number – Aktueller Wert
-- @param target   number – Zielwert
-- @param speed    number – Geschwindigkeit (aus Theme.Anim)
-- @return         number – Neuer Wert
function NexusAdmin.Theme.Lerp(current, target, speed)
    speed = speed or NexusAdmin.Theme.Anim.Medium
    return Lerp(FrameTime() * speed, current, target)
end
