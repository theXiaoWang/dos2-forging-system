-- Client/ForgingUI/Debug/ConsoleCommands.lua
-- Console commands for runtime inspection and UI debugging.

local function GetForgingUI()
    return Client and Client.ForgingUI or nil
end

local function RequireForgingUI(tag)
    local ForgingUI = GetForgingUI()
    if not ForgingUI then
        Ext.Print(string.format("[ForgingUI] %s: UI module not loaded", tostring(tag)))
        return nil
    end
    return ForgingUI
end

Ext.RegisterConsoleCommand("showforgeui", function()
    local ForgingUI = RequireForgingUI("showforgeui")
    if not ForgingUI or not ForgingUI.Show then
        Ext.Print("[ForgingUI] showforgeui: UI not initialized")
        return
    end
    ForgingUI.Show()
end)

Ext.RegisterConsoleCommand("hideforgeui", function()
    local ForgingUI = RequireForgingUI("hideforgeui")
    if not ForgingUI or not ForgingUI.Hide then
        Ext.Print("[ForgingUI] hideforgeui: UI not initialized")
        return
    end
    ForgingUI.Hide()
end)

Ext.RegisterConsoleCommand("toggleforgeui", function()
    local ForgingUI = RequireForgingUI("toggleforgeui")
    if not ForgingUI or not ForgingUI.Toggle then
        Ext.Print("[ForgingUI] toggleforgeui: UI not initialized")
        return
    end
    ForgingUI.Toggle()
end)

Ext.RegisterConsoleCommand("forgeuistatus", function()
    local ForgingUI = GetForgingUI()
    if not ForgingUI or not ForgingUI.Debug then
        Ext.Print("[ForgingUI] forgeuistatus: UI not initialized")
        return
    end

    ForgingUI.Debug.PrintUIState("Status")
    Ext.Print(string.format("[ForgingUI] Background panel name: %s", tostring(ForgingUI.Debug.GetBackgroundPanelName())))
    ForgingUI.Debug.PrintElementInfo("ForgingUI_Root")
    ForgingUI.Debug.PrintElementInfo("ForgingUI_Content")
    ForgingUI.Debug.PrintElementInfo("TopBar")
    ForgingUI.Debug.PrintElementInfo("LeftInfo")
    ForgingUI.Debug.PrintElementInfo("Column_Main")
    ForgingUI.Debug.PrintElementInfo("Column_Preview")
    ForgingUI.Debug.PrintElementInfo("Column_Donor")
    ForgingUI.Debug.PrintElementInfo("ForgeWiki")
    ForgingUI.Debug.PrintElementInfo("ForgeResult")
    ForgingUI.Debug.PrintElementInfo("InventoryPanel")
    ForgingUI.Debug.PrintElementInfo("ForgeBottom")
    ForgingUI.Debug.PrintElementInfo("PreviewInventoryPanel")
    ForgingUI.Debug.PrintElementInfo("PreviewInventory_FilterBar")
    ForgingUI.Debug.PrintElementInfo("PreviewInventory_List")
    ForgingUI.Debug.PrintElementInfo("PreviewInventory_Grid")
    ForgingUI.Debug.PrintElementInfo("Preview_PreviewArea_Inner")
end)

Ext.RegisterConsoleCommand("forgeuidumpinv", function()
    local ForgingUI = GetForgingUI()
    if not ForgingUI or not ForgingUI.Inventory then
        Ext.Print("[ForgingUI] forgeuidumpinv: Inventory module not initialized")
        return
    end
    ForgingUI.Inventory.DebugDump()
end)

Ext.RegisterConsoleCommand("forgeuidumpalpha", function(_, elementId, depth)
    local ForgingUI = GetForgingUI()
    if not ForgingUI or not ForgingUI.Debug or not ForgingUI.Debug.DumpElementTree then
        Ext.Print("[ForgingUI] forgeuidumpalpha: UI not initialized")
        return
    end

    local maxDepth = tonumber(depth) or 2
    if elementId and elementId ~= "" then
        ForgingUI.Debug.DumpElementTree(elementId, maxDepth)
        return
    end

    local ids = {
        "BaseFrame_Frame",
        "LeftInfo_Frame",
        "Column_Main_Frame",
        "Column_Preview_Frame",
        "Column_Donor_Frame",
        "ForgeWiki_Frame",
        "ForgeResult_Frame",
    }
    for _, id in ipairs(ids) do
        ForgingUI.Debug.DumpElementTree(id, maxDepth)
    end
end)

Ext.RegisterConsoleCommand("forgeuidumpfills", function(_, threshold)
    local ForgingUI = GetForgingUI()
    if not ForgingUI or not ForgingUI.Debug or not ForgingUI.Debug.DumpFillElements then
        Ext.Print("[ForgingUI] forgeuidumpfills: UI not initialized")
        return
    end
    ForgingUI.Debug.DumpFillElements(threshold)
end)

Ext.RegisterConsoleCommand("forgeuidumppreview", function()
    local ForgingUI = GetForgingUI()
    if not ForgingUI or not ForgingUI.Widgets or not ForgingUI.Widgets.GetPreviewInventory then
        Ext.Print("[ForgingUI] forgeuidumppreview: Widgets not initialized")
        return
    end

    local preview = ForgingUI.Widgets.GetPreviewInventory()
    if not preview then
        Ext.Print("[ForgingUI] forgeuidumppreview: Preview inventory not available")
        return
    end

    local slotCount = preview.Slots and #preview.Slots or 0
    local gridChildren = preview.Grid and preview.Grid.GetChildren and #(preview.Grid:GetChildren() or {}) or 0
    local listChildren = preview.ScrollList and preview.ScrollList.GetChildren and #(preview.ScrollList:GetChildren() or {}) or 0

    Ext.Print(string.format(
        "[ForgingUI] PreviewInventory: Root=%s Filter=%s Slots=%s Grid=%s GridChildren=%s ScrollList=%s ScrollChildren=%s",
        tostring(preview.Root ~= nil),
        tostring(preview.Filter),
        tostring(slotCount),
        tostring(preview.Grid ~= nil),
        tostring(gridChildren),
        tostring(preview.ScrollList ~= nil),
        tostring(listChildren)
    ))
    Ext.Print(string.format(
        "[ForgingUI] PreviewInventory: AutoSort=%s SortBy=%s SortPanel=%s SortList=%s Options=%s",
        tostring(preview.AutoSortButton ~= nil),
        tostring(preview.SortByButton ~= nil),
        tostring(preview.SortByPanel ~= nil),
        tostring(preview.SortByList ~= nil),
        tostring(preview.SortByOptions and #preview.SortByOptions or 0)
    ))
end)

Ext.RegisterConsoleCommand("forgeuirefreshpreview", function()
    local ForgingUI = GetForgingUI()
    if not ForgingUI or not ForgingUI.Widgets or not ForgingUI.Widgets.RenderPreviewInventory then
        Ext.Print("[ForgingUI] forgeuirefreshpreview: Widgets not initialized")
        return
    end
    ForgingUI.Widgets.RenderPreviewInventory()
    Ext.Print("[ForgingUI] forgeuirefreshpreview: RenderPreviewInventory called")
end)

