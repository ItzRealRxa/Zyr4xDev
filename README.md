# Zyr4x Hub - Roblox Anti-AFK, Auto-Clicker & Smart Rebirth Panel

A draggable in-game utility menu that combines 24/7 Anti-AFK protection, a high-speed Auto-Clicker, and a dual-mode Auto-Rebirth engine.

## File

- [`anti_afk.lua`](file:///c:/Users/ASUS/Desktop/Roblox%20Script/anti_afk.lua)

## Why It Didn't Work Before & What Changed

In your game (shown in the screenshot), the rebirth system uses a custom modal GUI with an explicit green **"Rebirth"** button (and level requirement `Level 860 / 860`), rather than a simple public remote event.

The updated script now uses a **Smart Rebirth Engine**:
1. **Direct UI Auto-Clicker**:
   - Searches your `PlayerGui` for the green **"Rebirth"** button.
   - Automatically activates it using `getconnections`, `firesignal`, and hardware cursor clicks (`VirtualUser`).
2. **Remote Event Fallback**:
   - Continues to look for any backend `RemoteEvent` or `RemoteFunction` in `ReplicatedStorage`.
3. **Turbo In-Game Remote Multiplier (Speed Up Built-in Auto Clicker)**:
   - When the in-game **"Auto Clicker"** is turned **On**, Zyr4x Hub sniffs the exact training RemoteEvent being fired.
   - Spams that exact remote event at your chosen CPS (up to 100 clicks/sec), turning the game's slow ~1-2 CPS auto-clicker into a 100 CPS power generator!
   - Shows live target status on the panel (`Target: [Remote Name] (Locked)`).
4. **Diagnostic Tools**:
   - Buttons to dump all remotes and scan all UI elements in F9 console.
5. **Anti-AFK**:
   - Keeps your player active 24/7 preventing the 20-minute idle disconnect.
