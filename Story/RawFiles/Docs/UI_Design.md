You are absolutely correct. While SWF is "dead" for the rest of the industry, **for Divinity: Original Sin 2 (DOS2), SWF is the standard and required method** for UI modding because the game engine relies on the legacy **Scaleform GFx** middleware.

The guide you found is excellent and correctly uses Norbyte's Script Extender (SE), which is essential for modding DOS2 UI.

Here are the refined steps with critical details added (specifically **Export Settings** and **Decompiling**) that are missing from your snippet but necessary to make it actually work.

### 1. Tools Required (Updated)

* **Adobe Animate (or Flash CC):** You need this to author the `.swf` files.
* **JPEXS Free Flash Decompiler (FFDec):** **Critical Tool.** You need this to open Larian's vanilla `.swf` files to see how they structured their UIs. You cannot easily guess the component structure without looking at their files.
* **VS Code + DOS2 Lua Extension:** For writing the Script Extender code.

### 2. The "Hidden" Step: Adobe Animate Export Settings

The game will likely crash or fail to load your UI if you export with modern web settings. You must match the Scaleform version DOS2 uses.

* **Target:** Flash Player 11.2 (or 10.3)
* **Script:** ActionScript 3.0
* **Compression:** **Disabled** (Uncompressed SWF is safer for game middleware).
* **OutputPath:** Direct to your mod's GUI folder to save time.

### 3. Refined Workflow

#### Phase A: Reverse Engineering (The most important step)

Before writing your `ForgingUI`, look at how Larian did it.

1. Use a **PAK Extractor** (part of Larian's modding tools) to extract `Game.pak` or `Textures.pak`.
2. Locate `Public/Game/GUI/`.
3. Open files like `characterSheet.swf` or `crafting.swf` in **JPEXS**.
4. Look at their ActionScript to see how they expose functions to the engine (usually via `ExternalInterface.addCallback`).

#### Phase B: The Lua Bridge (Your code is correct)

Your Lua snippet is spot on. Here is a slightly more robust version that includes safety checks:

```lua
-- BootstrapClient.lua

function InitForgingUI()
    -- Create the UI on layer 100 (high priority)
    -- Path must be relative to the Data folder structure
    local ui = Ext.CreateUI("ForgingSystem_UI", "Public/MyMod_UUID/GUI/ForgingUI.swf", 100)
    
    if ui then
        -- Register the listeners immediately
        Ext.RegisterUICall(ui, "onForgeButtonClicked", function(ui, call, ...)
            local args = {...}
            Ext.Print("Forge button clicked! Arg1:", args[1])
            -- Add your crafting logic here
        end)
        
        ui:Show()
    else
        Ext.Print("Error: Failed to create Forging UI")
    end
end

-- Initialize when the session loads
Ext.RegisterListener("SessionLoaded", InitForgingUI)

```

#### Phase C: The Flash (ActionScript 3) Side

In Adobe Animate, on the first frame of your timeline, you need to set up the receiver.

```actionscript
import flash.external.ExternalInterface;

// 1. Allow Lua to call this function
ExternalInterface.addCallback("updateItemSlot", this.updateItemSlot);

// 2. The function Lua calls
function updateItemSlot(slotID:int, itemName:String):void {
    // Assuming you have a MovieClip on stage named 'slot_mc'
    this.slot_mc.itemText.text = itemName;
}

// 3. Calling Lua from Flash (e.g., on a button click)
forgeBtn.addEventListener(MouseEvent.CLICK, onForgeClick);

function onForgeClick(e:MouseEvent):void {
    // The string "onForgeButtonClicked" matches the Lua RegisterUICall
    ExternalInterface.call("onForgeButtonClicked", 5, "Sword_Iron"); 
}

```

### 4. Common Pitfalls for DOS2 UI Modding

1. **Fonts:** DOS2 uses specific embedded fonts. If you use "Arial" in Animate, it might look correct in the editor but invisible in-game. You often need to embed the font in the library or use standard text fields that inherit the game's font map.
2. **Coordinates:** The coordinate system (0,0) is usually the top-left, but Scaleform can behave differently depending on how the viewport is set up. Use `ui:SetPosition(x, y)` in Lua to tweak it if it appears off-screen.
3. **Black Box:** If your SWF shows up as a black box, you likely enabled "Opaque Background" in Animate. Set the background to **Transparent** in Publish Settings.

### Next Step

I recommend you **download JPEXS Decompiler** immediately and extract `Shared.swf` from the game files. This file contains the common UI assets (buttons, frames, scrollbars) that Larian uses. You can export these assets and import them into your own `ForgingUI.fla` so your custom UI looks exactly like the native game UI.

... [Divinity: Original Sin 2 - Modding Tutorials: Your first level](https://www.youtube.com/watch?v=zHf_wNTDNIo) ...

I selected this video because it is the official Larian tutorial that introduces the engine and file structure, which is the foundational knowledge required before placing custom UI files into the directory.