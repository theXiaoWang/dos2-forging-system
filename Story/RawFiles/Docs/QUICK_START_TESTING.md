# Quick Start: Testing the Forging UI

## Prerequisites

1. **Script Extender** installed for the Editor (`The Divinity Engine 2\DefEd\`).
2. This mod is **standalone** (no EpipEncounters install required).

## Step-by-Step (Divinity Editor)

### 1) Open the mod
- Launch **Divinity Engine 2** (Editor)
- Open: `Data/Mods/forging_system_d581d214-2dd4-4690-bb44-e371432f1bfc/`
- Script Extender Console should open automatically (separate window)

### 2) Launch the game from the Editor
- Click **Play/Test** (or press **F5**)
- Wait for the level to fully load

### 3) Confirm the client bootstrap ran
Look for these messages in the Script Extender console:
```
[ForgingSystem] ===== CLIENT BOOTSTRAP STARTING =====
[ForgingSystem] Client side initialized successfully
[ForgingUI] Session loaded - initializing UI...
```

### 4) Switch to client context
In the Script Extender console:
```
> client
```

### 5) Show the UI
```
> !showforgeui
```

## Smoke Checklist

- Open the UI
- Use search (type, Ctrl+A/Z/Y/C/V/X)
- Preview inventory scroll
- Close button hitbox

## Quick Commands

Once in `client` context:
- `!showforgeui` – Show UI
- `!hideforgeui` – Hide UI
- `!toggleforgeui` – Toggle visibility
- `!forgeuistatus` – Dump key element info

