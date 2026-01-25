# Forging UI Testing Guide

This guide covers testing the Forging System UI from the Divinity Editor.

## Prerequisites

1. **Script Extender** installed in the Editor directory (`The Divinity Engine 2\DefEd\`).
2. This mod is **standalone** (no EpipEncounters install required).
3. The mod exists at `Data/Mods/forging_system_<UUID>/` and contains `Story/RawFiles/Lua/BootstrapClient.lua`.

## Testing in Divinity Editor

### 1) Open the mod

- Launch **Divinity Engine 2** (Editor)
- Open the project/mod
- Confirm the Script Extender console window appears

### 2) Launch the game (F5)

After the level loads, look for:
```
[ForgingSystem] ===== CLIENT BOOTSTRAP STARTING =====
[ForgingSystem] Client side initialized successfully
[ForgingUI] Session loaded - initializing UI...
```

If you see an error about requiring a file, the path is wrong or the file is missing.

### 3) Switch to client context

In the Script Extender console:
```
> client
```

### 4) Use console commands

```
> !showforgeui
> !hideforgeui
> !toggleforgeui
> !forgeuistatus
```

## Smoke Checklist

- UI opens/closes (close button + `!toggleforgeui`)
- Search works (typing + Ctrl+A/Z/Y/C/V/X)
- Preview inventory scroll works (wheel + scrollbar/handle)

