# Quick Start: Testing Your Forging UI

## Step-by-Step: Test in Divinity Editor

### 1. Open Your Mod
- Launch **Divinity Engine 2** (the Editor)
- Open your mod: `Data/Mods/forging_system_d581d214-2dd4-4690-bb44-e371432f1bfc/`
- **Script Extender Console should open automatically** (separate window)

### 2. Launch the Game
- Click **"Play"** or **"Test"** button in the Editor (or press F5)
- The game will launch internally with your mod loaded
- **Wait for the game to fully load** (you'll see a level/character)

### 3. Check Console Messages
Look in the **Script Extender Console** window for:
```
[ForgingSystem] ===== CLIENT BOOTSTRAP STARTING =====
[ForgingSystem] EPIP not detected - using basic Ext UI system
[ForgingSystem] Client side initialized successfully
[ForgingUI] Session loaded - initializing UI...
```

**Note**: If you see "EPIP not detected" or error messages, **EPIP is required** - the mod will not work without it.

### 4. Switch to Client Context
In the **Script Extender Console**:
1. Press `<Enter>` (enters console mode)
2. Type: `client` and press `<Enter>`
   ```
   > client
   ```

### 5. Show the UI
Type the command:
```
> !showforgeui
```

### 6. What to Expect

**With EPIP installed** (REQUIRED):
- Console will show: `[ForgingUI] EPIP Generic UI created successfully`
- **UI should appear in-game** with your forging interface
- This is the expected working state

**Without EPIP installed** (ERROR):
- Console will show: `[ForgingSystem] ✗ ERROR: EPIP mod is REQUIRED but not found!`
- **UI will NOT appear** - the mod cannot function without EPIP
- **You must install EPIP** for the mod to work

## Quick Commands Reference

Once in `client` context:
- `!showforgeui` - Show UI
- `!hideforgeui` - Hide UI  
- `!toggleforgeui` - Toggle visibility

## Next Steps

1. **Verify your code loads** (check console messages)
2. **Install EPIP (REQUIRED)** - The mod will not work without it:
   - Download from: https://www.pinewood.team/epip/
   - **For Editor**: Extract to `Data/Mods/EpipEncounters_7d32cb52-1cfd-4526-9b84-db4867bf9356/`
   - **For Game**: Install `.pak` to `Documents\Larian Studios\Divinity Original Sin 2 Definitive Edition\Mods\`
3. **Test again** - UI should now appear when you run `!showforgeui`

## Troubleshooting

**Console doesn't open?**
- Check Script Extender is installed in `The Divinity Engine 2\DefEd\`
- Restart the Editor

**No initialization messages?**
- Check your mod is in `Data/Mods/forging_system_<UUID>/`
- Verify `BootstrapClient.lua` exists in `Story/RawFiles/Lua/`
- Check console for error messages

**Commands don't work?**
- Make sure you're in `client` context (type `client` first)
- Wait for "Session loaded" message before running commands

