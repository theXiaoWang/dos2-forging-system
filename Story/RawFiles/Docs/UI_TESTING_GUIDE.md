# Forging UI Testing Guide

## Prerequisites

1. **Script Extender** must be installed in the Editor directory
   - Install to: `The Divinity Engine 2\DefEd\` (root of engine installation)
   - The Script Extender console will open automatically when the Editor launches
2. **EPIP Mod (REQUIRED)** - Provides the Generic UI system
   - **This mod REQUIRES EPIP to function** - the UI is built using EPIP's Generic UI framework
   - Download from: https://www.pinewood.team/epip/
   - **For Editor testing**: Extract the `.pak` to `Data/Mods/EpipEncounters_7d32cb52-1cfd-4526-9b84-db4867bf9356/`
   - **For game testing**: Install `.pak` to `Documents\Larian Studios\Divinity Original Sin 2 Definitive Edition\Mods\`
   - **Without EPIP, the UI will not work** - players must install EPIP to use this mod
3. **Your mod** must be in `Data/Mods/forging_system_<UUID>/`

## Testing in Divinity Editor

### Step 1: Open Your Mod in Divinity Editor

1. **Launch Divinity Engine 2** (the Editor, not the game)
2. **Open your mod project**:
   - File → Open Project
   - Navigate to: `Data/Projects/forging_system_<UUID>/` (or your project location)
   - Or open the mod directly from `Data/Mods/forging_system_<UUID>/`
3. **Script Extender Console should open automatically** - Look for a separate console window
   - If it doesn't open, check Script Extender installation
   - The console shows log output from all mods loading

### Step 2: Launch the Game from Editor

1. **Click "Play" or "Test"** in the Editor (or press F5)
   - This launches the game internally with your mod loaded
2. **Wait for the game to load** - You should see initialization messages in the Script Extender console
3. **Look for these messages** in the console:

   **If EPIP is installed** (required):
   ```
   [ForgingSystem] ===== CLIENT BOOTSTRAP STARTING =====
   [ForgingSystem] ✓ EPIP detected - Generic UI system available
   [ForgingSystem] Client side initialized successfully
   [ForgingUI] Session loaded - initializing UI...
   [ForgingUI] Initializing with EPIP Generic UI...
   [ForgingUI] EPIP Generic UI created successfully
   ```

   **If EPIP is NOT installed** (error):
   ```
   [ForgingSystem] ===== CLIENT BOOTSTRAP STARTING =====
   [ForgingSystem] ✗ ERROR: EPIP mod is REQUIRED but not found!
   [ForgingSystem] This mod requires EPIP (EpipEncounters) to function.
   [ForgingSystem] Download from: https://www.pinewood.team/epip/
   [ForgingUI] ✗ ERROR: EPIP Generic UI is REQUIRED but not available!
   ```
   **Note**: The mod will not function without EPIP - install EPIP to proceed.

### Step 3: Access Script Extender Console

1. **The Script Extender console window** should be visible (separate from the game window)
2. **If you don't see it**, check:
   - It might be minimised or behind other windows
   - Look for "Script Extender" in your taskbar
   - Script Extender should have created a console window automatically

### Step 4: Switch to Client Context

In the Script Extender console:

1. **Press `<Enter>`** to enter console mode (log output will pause)
2. **Type `client`** and press `<Enter>` to switch to client context:
   ```
   > client
   ```
   You should see confirmation that you're now in client context.

### Step 5: Test the UI

Once in client context, use these console commands:

#### Show the UI
```
> !showforgeui
```

#### Hide the UI
```
> !hideforgeui
```

#### Toggle UI Visibility
```
> !toggleforgeui
```

#### Expected Console Output

**If EPIP is NOT installed** (most likely scenario initially):
```
[ForgingSystem] ===== CLIENT BOOTSTRAP STARTING =====
[ForgingSystem] EPIP not detected - using basic Ext UI system
[ForgingSystem] Client side initialized successfully
[ForgingUI] Session loaded - initializing UI...
[ForgingUI] WARNING: EPIP not available. Using basic placeholder.
[ForgingUI] Please install EPIP mod to use the full Generic UI system.
[ForgingUI] Using fallback initialization (basic Ext UI)
[ForgingUI] UI shown
```

**If EPIP IS installed**:
```
[ForgingSystem] ===== CLIENT BOOTSTRAP STARTING =====
[ForgingSystem] EPIP detected - using Generic UI system
[ForgingSystem] Client side initialized successfully
[ForgingUI] Session loaded - initializing UI...
[ForgingUI] Initializing with EPIP Generic UI...
[ForgingUI] EPIP Generic UI created successfully
[ForgingUI] UI shown
```

## Testing in the Actual Game (Alternative)

If you prefer to test in the actual game instead of the Editor:

### Step 1: Start the Game

1. Launch Divinity: Original Sin 2 (the actual game, not Editor)
2. The **Script Extender Debug Console** window should open automatically
3. Load a game or start a new game
4. Wait for the session to load completely

### Step 2: Switch to Client Context

In the Script Extender console:

1. Press `<Enter>` to enter console mode
2. Type `client` and press `<Enter>` to switch to client context
   ```
   > client
   ```

### Step 3: Test the UI

Once in client context, use these console commands:

#### Show the UI
```
> !showforgeui
```

#### Hide the UI
```
> !hideforgeui
```

#### Toggle UI Visibility
```
> !toggleforgeui
```

### Step 4: Verify UI Elements

**If EPIP is installed and working**, you should see:
- Top navigation bar with "Forge" and "Unique Forge" buttons
- Three item slots (Main Slot, Preview Slot, Donor Slot)
- Basic UI structure matching the Figma design

**If EPIP is NOT installed** (initial testing):
- You'll see console messages indicating fallback mode
- The UI won't actually appear (fallback is just a placeholder)
- This is expected - you need EPIP for the UI to display

## Testing Workflow

### During Development in Editor

1. **Initial Setup (One-time)**
   - Open your mod in Divinity Editor
   - Verify Script Extender console opens automatically
   - Launch game from Editor (Play/Test button)
   - Check console for initialization messages

2. **Testing Changes**
   - Edit Lua files in `Story/RawFiles/Lua/`
   - **Close the game and restart from Editor** (Script Extender doesn't hot-reload new files)
   - Use console commands to test UI

3. **Quick Test Cycle**
   - Make code changes
   - Stop the game (if running)
   - Click "Play" again in Editor
   - Switch to client context in console
   - Run `!showforgeui`

3. **Debugging**
   - Check Script Extender console for error messages
   - Look for `[ForgingSystem]` and `[ForgingUI]` prefixed messages
   - Use `Ext.Print()` statements in your code for debugging

### Console Commands Reference

#### Client-Side Commands (run in `client` context)
```
!showforgeui      - Show the forging UI
!hideforgeui      - Hide the forging UI
!toggleforgeui    - Toggle UI visibility
```

#### Server-Side Commands (run in `server` context)
```
!forgeinfo        - Display server status information
```

## Troubleshooting

### Script Extender Console Doesn't Appear

1. **Check Script Extender Installation**
   - Verify Script Extender is installed in: `The Divinity Engine 2\DefEd\`
   - Should have `DWrite.dll` and other extender files in the DefEd folder
   - Restart the Editor after installing Script Extender

2. **Check Console Window**
   - Look in taskbar for "Script Extender" window
   - May be minimised or behind other windows
   - Console should open automatically when Editor launches

### UI Doesn't Appear

1. **Check EPIP Installation** (REQUIRED)
   - **For Editor**: Extract EPIP `.pak` to `Data/Mods/EpipEncounters_7d32cb52-1cfd-4526-9b84-db4867bf9356/`
   - **For Game**: Install EPIP `.pak` to `Documents\Larian Studios\Divinity Original Sin 2 Definitive Edition\Mods\`
   - Check console for: `[ForgingSystem] ✓ EPIP detected - Generic UI system available`
   - If you see: `[ForgingSystem] ✗ ERROR: EPIP mod is REQUIRED but not found!`, EPIP is not installed
   - **The mod will not work without EPIP** - it is a mandatory dependency

2. **Check Console Context**
   - Make sure you're in `client` context before running UI commands
   - Type `client` in console to switch context
   - UI is client-side only

3. **Check Initialization**
   - Look for initialization messages in console
   - Verify no error messages during startup
   - Wait for "Session loaded" message before testing

4. **Without EPIP (Expected Behavior)**
   - If EPIP is not installed, you'll see fallback messages
   - The UI won't actually display (fallback is just a placeholder)
   - This is normal - install EPIP to see the actual UI

### Errors in Console

**Common Errors:**

1. **"EPIP not detected" or "EPIP is REQUIRED but not found"**
   - **This is a CRITICAL error** - EPIP is mandatory for this mod
   - **Solution**: Install EPIP mod from https://www.pinewood.team/epip/
   - **For Editor**: Extract to `Data/Mods/EpipEncounters_7d32cb52-1cfd-4526-9b84-db4867bf9356/`
   - **For Game**: Install `.pak` to `Documents\...\Mods\`
   - **Restart the game/Editor** after installing EPIP

2. **"UI not initialized"**
   - **Solution**: Make sure session has fully loaded
   - Try waiting a few seconds after game loads, then retry command

3. **Script errors**
   - Check the full error message in console
   - Verify file paths are correct
   - Ensure all required files exist in `Story/RawFiles/Lua/`

### Hot Reload Limitations

⚠️ **Important**: Script Extender has **limited** hot reloading:
- ✅ Can update existing functions/variables (if global)
- ❌ **Cannot** load new files after game starts
- ❌ **Cannot** change BootstrapClient.lua or BootstrapServer.lua without restart
- ❌ **Cannot** register new console commands after startup

**To apply code changes:**
1. Save your Lua files
2. **Restart the game completely**
3. Test again

## Next Steps

Once basic UI is working:

1. **Expand UI Components**
   - Add inventory grid
   - Implement item slot displays
   - Add forge preview summary panel

2. **Implement Functionality**
   - Item selection logic
   - Forging calculation
   - Probability display

3. **Polish UI**
   - Match Figma design exactly
   - Add animations
   - Improve styling

## Development Tips

1. **Use Console for Quick Testing**
   - Test functions directly: `ForgingUI.Show()`
   - Check variables: `print(uiInstance)`

2. **Debugging Output**
   - All functions use `Ext.Print()` for logging
   - Look for `[ForgingUI]` prefixed messages

3. **EPIP Documentation**
   - Reference: https://www.pinewood.team/epip/docs/
   - Check Generic UI documentation for component APIs

4. **Incremental Development**
   - Start with simple components
   - Test each piece before moving to next
   - Build up complexity gradually

