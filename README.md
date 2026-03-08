# 💠 NexusAdmin

A high-performance, modular administration framework for Garry's Mod, built for the modern era. 
NexusAdmin combines **Glassmorphism design** with strict permission security and an intuitive user experience.

---

## 🤖 The AI-Hybrid Workflow
This project is a unique collaboration between **Lemurabgrund** (Vision & Lead Design) and a team of AI collaborators:
* **Gemini 3 Flash** — Lead Architect, UI-Polishing & Strategic Debugging.
* **Claude 3.5 Sonnet** — Core Execution, Logic Implementation & Database Management.
* **The Goal**: Proving that high-end GMod scripts can be built faster and cleaner through human-AI synergy.

---

## ✨ Key Features

### 🖥️ High-End UI/UX
- **Glassmorphism Design**: Real-time blur backgrounds (`surface.DrawBlur`) with neon-cyan accents.
- **Adaptive HUD**: Dynamic UI scaling for all resolutions (FullHD to 4K).
- **Rounded Aesthetics**: Consistent 8px rounded corners on all panels, buttons, and input fields.
- **Clean Scoreboard**: Minimalist player cards, ping-based coloring, and a lag-free experience (Removed cluttered 'Warns' column).

### 🎫 Advanced Ticket System
- **Real-Time Chat**: Dedicated "WhatsApp-Style" chat interface for tickets.
- **Audio Feedback**: Subtle notification sounds (`blip`) for new messages.
- **Admin Tools**: One-click `!bring`, `!goto`, and `!summon` integration directly from the ticket UI.
- **User Commands**: Open or resume your ticket anytime via `!ticket`.

### 🛡️ Security & Core Logic
- **Strict Permissions**: Hierarchical rank system (`user` < `admin` < `superadmin`) with verified server-side checks.
- **PermaProps**: SQLite-based persistence. Props auto-respawn on map cleanup or server restart.
- **Config-in-Game**: Real-time editor for server convars and framework settings (Superadmin only).

---

## 🚀 Installation

1. Create a folder: `garrysmod/addons/NexusAdmin/`.
2. Drop the `lua/`, `addon.json`, and `LICENSE` files into that folder.
3. Ensure you have the `Garry's Mod CSS Content` installed for best blur results.
4. Restart your server.

---

## 📜 Commands

| Command | Rank | Description |
| :--- | :--- | :--- |
| `!ticket` | User | Opens the ticket creation or active chat UI. |
| `!sethp` | Admin | Sets a player's health (Strictly restricted to Admin+). |
| `!perma` | Admin | Saves the looked-at prop to the database. |
| `!menu` | Admin | Opens the NexusAdmin Dashboard. |

---

## 📄 License
Distributed under the **MIT License**. See `LICENSE` for more information.

---
*Developed with ❤️ by Lemurabgrund & AI Assistants.*
