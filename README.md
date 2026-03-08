# NexusAdmin

A lightweight, modular administration framework for Garry's Mod.
This addon has been written in combination with Claude Sonnet 4.6.
The Ideas are written by me and Claude executes them.

## Features

- **Rank System** — Hierarchical ranks (`user`, `admin`, `superadmin`) with permission inheritance
- **Command System** — Chat-based commands (`!kick`, `!ban`, `!freeze`, `!setrank`, etc.) with argument parsing
- **Ticket System** — Players create support tickets; admins manage them via the Admin-Zentrale UI
- **PermaProps** — Persistent props saved to SQLite, auto-spawned on map load/cleanup
- **Glassmorphism UI** — Blur-based panels, neon-cyan accents, rounded corners throughout
- **Scoreboard** — Custom scoreboard with player cards, ping coloring, and admin right-click menu
- **Config UI** — In-game config editor for GMod convars and NexusAdmin settings (superadmin only)
- **Permissions UI** — Visual permission editor per rank (superadmin only)

## Installation

1. Copy the `lua/` folder into your GMod server's `garrysmod/addons/NexusAdmin/` directory.
2. Restart the server.
3. Set your SteamID64 as superadmin via the database or startup hook.

## Rank Permissions

| Permission   | admin | superadmin |
|-------------|-------|------------|
| kick        | ✓     | ✓          |
| teleport    | ✓     | ✓          |
| slay        | ✓     | ✓          |
| freeze      | ✓     | ✓          |
| spectate    | ✓     | ✓          |
| sethealth   | ✓     | ✓          |
| setarmor    | ✓     | ✓          |
| permaprops  | ✓     | ✓          |
| ban         |       | ✓          |
| rcon        |       | ✓          |
| givrank     |       | ✓          |
| god         |       | ✓          |
| jail        |       | ✓          |

## License

MIT
