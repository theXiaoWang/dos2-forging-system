-- Client/ForgingUI/Craft.lua
-- Craft/preview docking logic shared by the forging UI.

local ForgingUI = Client.ForgingUI or {}
Client.ForgingUI = ForgingUI

local Craft = {}
ForgingUI.Craft = Craft

local ctx = nil

local State = {
    Anchor = nil,
    WasVisible = false,
    DockRequested = false,
    PreviewMode = nil,
    PreviewAnchorID = nil,
    PreviewArea = nil,
    PreviewSkin = nil,
    PreviewActive = false,
    HooksInstalled = false,
    PreviousFilter = nil,
    LastFilter = nil,
    LockInstalled = false,
    LockedPosition = nil,
}

Craft.State = State

function Craft.SetContext(nextCtx)
    ctx = nextCtx
end

local function V(...)
    return ctx and ctx.V and ctx.V(...) or Vector.Create(...)
end

local function GetPreviewModes()
    return ctx and ctx.CRAFT_PREVIEW_MODES or {
        Equipment = "Equipment",
        Magical = "Magical",
    }
end

local function GetDisplayModes()
    return ctx and ctx.DISPLAY_MODES or {
        Combine = "Combine",
        Preview = "Preview",
    }
end

local CRAFT_PREVIEW_HIDE_PATHS = {
    "craftPanel_mc.topBar_mc",
    "craftPanel_mc.title_mc",
    "craftPanel_mc.tabList",
    "craftPanel_mc.tabs_mc",
    "craftPanel_mc.tabsHolder_mc",
    "craftPanel_mc.tabButtonList",
    "craftPanel_mc.craftingTabs_mc",
    "craftPanel_mc.recipeHeader_mc",
    "craftPanel_mc.header_mc",
    "craftPanel_mc.header",
    "craftPanel_mc.topPanel_mc",
    "craftPanel_mc.topPanel",
    "craftPanel_mc.navigation_mc",
    "craftPanel_mc.navPanel_mc",
    "craftPanel_mc.modeTabs_mc",
    "craftPanel_mc.modeTabList",
    "craftPanel_mc.tabsPanel_mc",
    "craftPanel_mc.tabsPanel",
    "craftPanel_mc.topNav_mc",
    "craftPanel_mc.topNav",
    "craftPanel_mc.headerBG_mc",
    "craftPanel_mc.headerBG",
    "craftPanel_mc.crafting_mc",
    "craftPanel_mc.craftingHeader_mc",
    "craftPanel_mc.craftingHeader",
    "craftPanel_mc.craftingTitle_mc",
    "craftPanel_mc.craftingTitle",
    "craftPanel_mc.topHeader_mc",
    "craftPanel_mc.topHeader",
    "craftPanel_mc.recipePanel_mc",
    "craftPanel_mc.recipePanel",
    "craftPanel_mc.recipesPanel_mc",
    "craftPanel_mc.recipeList_mc",
    "craftPanel_mc.recipeListHolder_mc",
    "craftPanel_mc.recipesList_mc",
    "craftPanel_mc.recipeTabs_mc",
    "craftPanel_mc.recipesTabs_mc",
    "craftPanel_mc.recipeTabList",
    "craftPanel_mc.recipesTabList",
    "craftPanel_mc.recipeContainer_mc",
    "craftPanel_mc.recipeContainer",
    "craftPanel_mc.recipeBG_mc",
    "craftPanel_mc.recipeBG",
    "craftPanel_mc.recipeContent_mc",
    "craftPanel_mc.recipeContent",
    "craftPanel_mc.combineButton_mc",
    "craftPanel_mc.combineButton",
    "craftPanel_mc.combine_btn",
    "craftPanel_mc.combineBtn",
    "craftPanel_mc.combine_mc",
    "craftPanel_mc.combinePanel_mc",
    "craftPanel_mc.combinePanel",
    "craftPanel_mc.combineSlots_mc",
    "craftPanel_mc.combineSlots",
    "craftPanel_mc.combineSlot_mc",
    "craftPanel_mc.combineSlot",
    "craftPanel_mc.combineArea_mc",
    "craftPanel_mc.combineArea",
    "craftPanel_mc.combineSlotsHolder_mc",
    "craftPanel_mc.combineSlotsHolder",
    "craftPanel_mc.combineResult_mc",
    "craftPanel_mc.combineResult",
    "craftPanel_mc.experimentPanel_mc.combineButton_mc",
    "craftPanel_mc.experimentPanel_mc.combineButton",
    "craftPanel_mc.experimentPanel_mc.combine_btn",
    "craftPanel_mc.experimentPanel_mc.combineBtn",
    "craftPanel_mc.experimentPanel_mc.combine_mc",
    "craftPanel_mc.experimentPanel_mc.combinePanel_mc",
    "craftPanel_mc.experimentPanel_mc.combinePanel",
    "craftPanel_mc.experimentPanel_mc.combineSlots_mc",
    "craftPanel_mc.experimentPanel_mc.combineSlots",
    "craftPanel_mc.experimentPanel_mc.combineSlot_mc",
    "craftPanel_mc.experimentPanel_mc.combineSlot",
    "craftPanel_mc.experimentPanel_mc.combineHeader_mc",
    "craftPanel_mc.experimentPanel_mc.combineHeader",
    "craftPanel_mc.experimentPanel_mc.result_mc",
    "craftPanel_mc.experimentPanel_mc.resultPanel_mc",
    "craftPanel_mc.experimentPanel_mc.resultSlots_mc",
    "craftPanel_mc.experimentPanel_mc.resultSlot_mc",
    "craftPanel_mc.experimentPanel_mc.resultHeader_mc",
    "craftPanel_mc.experimentPanel_mc.resultHeader",
    "craftPanel_mc.experimentPanel_mc.header_mc",
    "craftPanel_mc.experimentPanel_mc.header",
    "craftPanel_mc.experimentPanel_mc.topBar_mc",
    "craftPanel_mc.experimentPanel_mc.topBar",
    "craftPanel_mc.experimentPanel_mc.title_mc",
    "craftPanel_mc.experimentPanel_mc.recipePanel_mc",
    "craftPanel_mc.experimentPanel_mc.recipePanel",
    "craftPanel_mc.resultPanel_mc",
    "craftPanel_mc.resultPanel",
    "craftPanel_mc.resultSlots_mc",
    "craftPanel_mc.resultHolder_mc",
    "craftPanel_mc.result_mc",
    "craftPanel_mc.resultArea_mc",
    "craftPanel_mc.resultArea",
    "craftPanel_mc.runePanel_mc",
    "craftPanel_mc.runePanel",
    "craftPanel_mc.runesPanel_mc",
    "close_btn",
    "closeBtn",
    "closeButton_mc",
    "craftPanel_mc.close_btn",
    "craftPanel_mc.closeBtn",
    "craftPanel_mc.closeButton_mc",
}

local CRAFT_PREVIEW_SHOW_PATHS = {
    "craftPanel_mc.experimentPanel_mc.search_mc",
    "craftPanel_mc.experimentPanel_mc.searchBar_mc",
    "craftPanel_mc.experimentPanel_mc.searchField_mc",
    "craftPanel_mc.experimentPanel_mc.sortBy_mc",
    "craftPanel_mc.experimentPanel_mc.autoSort_mc",
    "craftPanel_mc.experimentPanel_mc.sortButtons_mc",
    "inventory_mc.search_mc",
    "inventory_mc.searchBar_mc",
    "inventory_mc.searchField_mc",
    "inventory_mc.search_txt",
    "inventory_mc.sortBy_mc",
    "inventory_mc.autoSort_mc",
    "inventory_mc.sortButtons_mc",
}

local CRAFT_PREVIEW_DISABLE_MOUSE_PATHS = {
    "drag_mc",
    "dragArea_mc",
    "dragRegion_mc",
    "dragArea",
    "dragRegion",
    "dragHandle_mc",
    "dragHandle",
    "titleBar_mc",
    "header_mc",
    "topBar_mc",
    "craftPanel_mc.drag_mc",
    "craftPanel_mc.dragArea_mc",
    "craftPanel_mc.dragRegion_mc",
    "craftPanel_mc.dragArea",
    "craftPanel_mc.dragRegion",
    "craftPanel_mc.dragHandle_mc",
    "craftPanel_mc.dragHandle",
    "craftPanel_mc.titleBar_mc",
    "craftPanel_mc.header_mc",
    "craftPanel_mc.topBar_mc",
}

local function GetCraftUI()
    if Client and Client.UI and Client.UI.Craft then
        return Client.UI.Craft
    end
    return nil
end

local function GetFlashObjectByPath(root, path)
    local node = root
    for part in string.gmatch(path, "[^%.]+") do
        if not node or node[part] == nil then
            return nil
        end
        node = node[part]
    end
    return node
end

local function CacheAndSetVisibility(root, paths, visible, cache)
    if not root or not paths or not cache then
        return
    end

    for _, path in ipairs(paths) do
        local node = GetFlashObjectByPath(root, path)
        if node and node.visible ~= nil then
            cache[path] = node.visible
            node.visible = visible
        end
    end
end

local function RestoreVisibility(root, cache)
    if not root or not cache then
        return
    end

    for path, previous in pairs(cache) do
        local node = GetFlashObjectByPath(root, path)
        if node and previous ~= nil then
            node.visible = previous
        end
    end
end

local function CacheAndSetMouseEnabled(root, paths, enabled, cache)
    if not root or not paths or not cache then
        return
    end

    for _, path in ipairs(paths) do
        local node = GetFlashObjectByPath(root, path)
        if node then
            local entry = {}
            if node.mouseEnabled ~= nil then
                entry.mouseEnabled = node.mouseEnabled
                node.mouseEnabled = enabled
            end
            if node.mouseChildren ~= nil then
                entry.mouseChildren = node.mouseChildren
                node.mouseChildren = enabled
            end
            if next(entry) ~= nil then
                cache[path] = entry
            end
        end
    end
end

local function RestoreMouseEnabled(root, cache)
    if not root or not cache then
        return
    end

    for path, entry in pairs(cache) do
        local node = GetFlashObjectByPath(root, path)
        if node and entry then
            if entry.mouseEnabled ~= nil then
                node.mouseEnabled = entry.mouseEnabled
            end
            if entry.mouseChildren ~= nil then
                node.mouseChildren = entry.mouseChildren
            end
        end
    end
end

local function GetFlashNumberField(node, ...)
    if not node then
        return nil
    end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if node[key] ~= nil and type(node[key]) == "number" then
            return node[key]
        end
    end
    return nil
end

local function SetFlashNumberField(node, value, ...)
    if not node then
        return
    end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if node[key] ~= nil then
            node[key] = value
            return
        end
    end
end

local function GetCraftClipTop(panel)
    if not panel then
        return nil
    end

    local experiment = panel.experimentPanel_mc or panel.inventoryPanel_mc or panel.inventory_mc
    if not experiment then
        return nil
    end

    local experimentY = GetFlashNumberField(experiment, "y", "_y")
    local function GetAbsoluteY(node)
        if not node then
            return nil
        end
        local localY = GetFlashNumberField(node, "y", "_y")
        local parent = node.parent
        if localY == nil then
            return nil
        end
        if parent == nil then
            return localY
        end
        local parentY = GetAbsoluteY(parent)
        if parentY == nil then
            return localY
        end
        return parentY + localY
    end

    local absoluteY = GetAbsoluteY(experiment)
    if absoluteY and experimentY then
        return absoluteY - experimentY
    end
    return nil
end

local function ApplyCraftPanelClip(root, cache)
    local panel = root and root.craftPanel_mc
    if not panel then
        return
    end

    local top = GetCraftClipTop(panel)
    if not top then
        return
    end

    local mask = panel.mask_mc or panel.mask
    if not mask then
        return
    end

    cache.Applied = true
    cache.Mask = mask
    cache.MaskY = GetFlashNumberField(mask, "y", "_y")
    cache.MaskHeight = GetFlashNumberField(mask, "height", "_height")

    if cache.MaskY then
        SetFlashNumberField(mask, top, "y", "_y")
    end
end

local function RestoreCraftPanelClip(root, cache)
    if not cache or not cache.Applied then
        return
    end

    local mask = cache.Mask
    if mask then
        if cache.MaskY then
            SetFlashNumberField(mask, cache.MaskY, "y", "_y")
        end
        if cache.MaskHeight then
            SetFlashNumberField(mask, cache.MaskHeight, "height", "_height")
        end
    end
end

local function GetElementAbsolutePosition(id)
    if not ctx or not ctx.uiInstance or not ctx.uiInstance.GetElementByID then
        return nil, nil
    end

    local element = ctx.uiInstance:GetElementByID(id)
    if not element then
        return nil, nil
    end

    local x, y = element:GetPosition()
    local current = element
    while current and current.ParentID and current.ParentID ~= "" do
        current = ctx.uiInstance:GetElementByID(current.ParentID)
        if not current then
            break
        end
        local parentX, parentY = current:GetPosition()
        x = x + parentX
        y = y + parentY
    end

    return x, y
end

local function GetCraftUISize(craft)
    if not craft then
        return nil, nil
    end

    local uiObj = craft.GetUI and craft:GetUI() or nil
    if uiObj and uiObj.SysPanelSize then
        return uiObj.SysPanelSize[1], uiObj.SysPanelSize[2]
    end

    local root = craft.GetRoot and craft:GetRoot() or nil
    if root then
        return root.width, root.height
    end
    return nil, nil
end

local function GetCraftSelectedFilter()
    local craft = GetCraftUI()
    local root = craft and craft.GetRoot and craft:GetRoot() or nil
    if not root then
        return nil
    end

    local panel = root.craftPanel_mc
    if panel and panel.tabs_mc and panel.tabs_mc.selectedTabID then
        return panel.tabs_mc.selectedTabID
    end
    return nil
end

local function ApplyCraftFilterVisibility(root, cache)
    local panel = root and root.craftPanel_mc or nil
    if not panel then
        return
    end

    local filterTabs = panel.modeTabs_mc or panel.modeTabList
    if not filterTabs then
        return
    end

    cache.FilterTabs = filterTabs
    cache.FilterTabsX = GetFlashNumberField(filterTabs, "x", "_x")
    cache.FilterTabsWidth = GetFlashNumberField(filterTabs, "width", "_width")
    cache.FilterTabsHeight = GetFlashNumberField(filterTabs, "height", "_height")
    if cache.FilterTabs then
        cache.FilterTabs.visible = true
    end
end

local function RestoreCraftFilterVisibility(root, cache)
    if not cache or not cache.FilterTabs then
        return
    end
    if cache.FilterTabsX then
        SetFlashNumberField(cache.FilterTabs, cache.FilterTabsX, "x", "_x")
    end
    if cache.FilterTabsWidth then
        SetFlashNumberField(cache.FilterTabs, cache.FilterTabsWidth, "width", "_width")
    end
    if cache.FilterTabsHeight then
        SetFlashNumberField(cache.FilterTabs, cache.FilterTabsHeight, "height", "_height")
    end
end

local function CenterCraftFilterTabs(root, cache)
    local panel = root and root.craftPanel_mc or nil
    if not panel then
        return
    end

    local filterTabs = panel.modeTabs_mc or panel.modeTabList
    if not filterTabs then
        return
    end

    local width = GetFlashNumberField(filterTabs, "width", "_width")
    if not width then
        return
    end

    local panelWidth = GetFlashNumberField(panel, "width", "_width") or 0
    if panelWidth <= 0 then
        return
    end

    cache.FilterTabsX = GetFlashNumberField(filterTabs, "x", "_x")
    SetFlashNumberField(filterTabs, math.floor((panelWidth - width) / 2), "x", "_x")
end

local function RestoreCraftFilterPositions(cache)
    if not cache or not cache.FilterTabs then
        return
    end
    if cache.FilterTabsX then
        SetFlashNumberField(cache.FilterTabs, cache.FilterTabsX, "x", "_x")
    end
end

local function ShiftCraftExperimentPanel(root, cache)
    local panel = root and root.craftPanel_mc or nil
    if not panel then
        return
    end

    local experiment = panel.experimentPanel_mc or panel.inventoryPanel_mc or panel.inventory_mc
    if not experiment then
        return
    end

    local y = GetFlashNumberField(experiment, "y", "_y")
    if not y then
        return
    end

    cache.ExperimentPanel = experiment
    cache.ExperimentY = y
    SetFlashNumberField(experiment, y - 30, "y", "_y")
end

local function RestoreCraftExperimentPanel(root, cache)
    if not cache or not cache.ExperimentPanel then
        return
    end

    if cache.ExperimentY then
        SetFlashNumberField(cache.ExperimentPanel, cache.ExperimentY, "y", "_y")
    end
end

local function EnsureCraftPositionLock()
    if State.LockInstalled or not GameState or not GameState.Events or not GameState.Events.RunningTick then
        return
    end

    GameState.Events.RunningTick:Subscribe(function ()
        if not State.LockedPosition or not State.PreviewActive or not (ctx and ctx.UIState and ctx.UIState.IsVisible) then
            return
        end

        local craft = GetCraftUI()
        if not craft or not craft.Exists or not craft:Exists() then
            return
        end

        if not craft.GetPosition or not craft.SetPosition then
            return
        end

        local x, y = craft:GetPosition()
        if x ~= State.LockedPosition.X or y ~= State.LockedPosition.Y then
            craft:SetPosition(V(State.LockedPosition.X, State.LockedPosition.Y))
        end
    end, {StringID = "ForgingUI_CraftLock"})

    State.LockInstalled = true
end

function Craft.SetPreviewSkin(enabled)
    if not ctx or not ctx.USE_VANILLA_COMBINE_PANEL then
        return
    end

    local craft = GetCraftUI()
    if not craft or not craft.GetRoot then
        return
    end

    local root = craft:GetRoot()
    if not root then
        return
    end

    local craftUI = craft.GetUI and craft:GetUI() or nil

    if enabled then
        if State.PreviewSkin and State.PreviewSkin.Active then
            if State.PreviewArea then
                local uiW, uiH = GetCraftUISize(craft)
                if uiW and uiH and uiW > 0 and uiH > 0 then
                    local scale = math.min(State.PreviewArea.W / uiW, State.PreviewArea.H / uiH)
                    if scale > 1 then
                        scale = 1
                    end
                    if scale > 0 then
                        root.scaleX = scale
                        root.scaleY = scale
                    end
                end
            end
            return
        end

        State.PreviewSkin = {
            Active = true,
            Hidden = {},
            Shown = {},
            Disabled = {},
            FilterTabs = {},
            FilterTabPositions = {},
            ExperimentPanel = {},
            PanelClip = {},
            PreviewBackground = {},
            Scale = {root.scaleX, root.scaleY},
        }

        if craftUI then
            State.PreviewSkin.Layer = craftUI.Layer
        end
        if craft.GetPosition then
            local x, y = craft:GetPosition()
            State.PreviewSkin.Position = {X = x or 0, Y = y or 0}
        end

        CacheAndSetVisibility(root, CRAFT_PREVIEW_HIDE_PATHS, false, State.PreviewSkin.Hidden)
        CacheAndSetVisibility(root, CRAFT_PREVIEW_SHOW_PATHS, true, State.PreviewSkin.Shown)
        CacheAndSetMouseEnabled(root, CRAFT_PREVIEW_DISABLE_MOUSE_PATHS, false, State.PreviewSkin.Disabled)
        ApplyCraftFilterVisibility(root, State.PreviewSkin.FilterTabs)
        CenterCraftFilterTabs(root, State.PreviewSkin.FilterTabPositions)
        ApplyCraftPanelClip(root, State.PreviewSkin.PanelClip)
        if not State.PreviewSkin.PanelClip.Applied then
            ShiftCraftExperimentPanel(root, State.PreviewSkin.ExperimentPanel)
        end

        if State.PreviewArea then
            local uiW, uiH = GetCraftUISize(craft)
            if uiW and uiH and uiW > 0 and uiH > 0 then
                local scale = math.min(State.PreviewArea.W / uiW, State.PreviewArea.H / uiH)
                if scale > 1 then
                    scale = 1
                end
                if scale > 0 then
                    root.scaleX = scale
                    root.scaleY = scale
                end
            end
        end
    else
        if not State.PreviewSkin or not State.PreviewSkin.Active then
            return
        end

        if State.PreviewSkin.Scale then
            root.scaleX = State.PreviewSkin.Scale[1] or root.scaleX
            root.scaleY = State.PreviewSkin.Scale[2] or root.scaleY
        end

        RestoreVisibility(root, State.PreviewSkin.Hidden)
        RestoreVisibility(root, State.PreviewSkin.Shown)
        RestoreMouseEnabled(root, State.PreviewSkin.Disabled)
        RestoreCraftFilterVisibility(root, State.PreviewSkin.FilterTabs)
        RestoreCraftFilterPositions(State.PreviewSkin.FilterTabPositions)
        RestoreCraftExperimentPanel(root, State.PreviewSkin.ExperimentPanel)
        RestoreCraftPanelClip(root, State.PreviewSkin.PanelClip)

        if State.PreviewSkin.Position and craft.GetPosition and craft.SetPosition then
            craft:SetPosition(V(State.PreviewSkin.Position.X, State.PreviewSkin.Position.Y))
        end
        if State.PreviewSkin.Layer and craftUI then
            craftUI.Layer = State.PreviewSkin.Layer
        end

        State.PreviewSkin = nil
    end
end

function Craft.SetPreviewMode(mode)
    State.PreviewMode = mode

    if not ctx or not ctx.USE_VANILLA_COMBINE_PANEL then
        if mode and ctx and ctx.SetPreviewInventoryMode then
            ctx.SetPreviewInventoryMode(mode)
        end
        return
    end

    local craft = GetCraftUI()
    if not craft or not craft.SelectFilter then
        return
    end

    if mode then
        if State.PreviousFilter == nil then
            State.PreviousFilter = State.LastFilter or GetCraftSelectedFilter()
        end

        local previewModes = GetPreviewModes()
        local filterValue = nil
        if mode == previewModes.Equipment then
            filterValue = "Equipment"
        elseif mode == previewModes.Magical then
            filterValue = "BooksAndKeys"
        end
        if filterValue ~= nil then
            craft.SelectFilter(filterValue)
        end
    else
        if State.PreviousFilter ~= nil then
            craft.SelectFilter(State.PreviousFilter)
            State.PreviousFilter = nil
        end
    end
end

local function GetCraftModeForSlot(id)
    local previewModes = GetPreviewModes()
    if id == "Donor_SkillbookSlot" then
        return previewModes.Magical
    end
    if id == "Main_ItemSlot" or id == "Donor_ItemSlot" then
        return previewModes.Equipment
    end
    return nil
end

function Craft.UpdatePreviewAnchor()
    if not ctx or not ctx.USE_VANILLA_COMBINE_PANEL or not State.PreviewAnchorID then
        return
    end

    local x, y = GetElementAbsolutePosition(State.PreviewAnchorID)
    if x and y then
        State.Anchor = {X = x, Y = y}
    end
    local element = ctx.uiInstance and ctx.uiInstance.GetElementByID and ctx.uiInstance:GetElementByID(State.PreviewAnchorID) or nil
    if element then
        local width, height = element:GetSize()
        State.PreviewArea = {
            W = width or 0,
            H = height or 0,
        }
    end
end

function Craft.DockUI(forceShow)
    if not ctx or not ctx.USE_VANILLA_COMBINE_PANEL or not ctx.uiInstance then
        return
    end

    local craft = GetCraftUI()
    if not craft or not craft.Exists or not craft:Exists() then
        return
    end

    if not State.Anchor then
        Craft.UpdatePreviewAnchor()
        if not State.Anchor then
            return
        end
    end

    local isCraftVisible = craft.IsVisible and craft:IsVisible() or false
    if forceShow or not isCraftVisible then
        State.WasVisible = isCraftVisible
        craft:Show()
    end

    local wasPreviewActive = State.PreviewActive
    State.PreviewActive = true
    if not wasPreviewActive and State.PreviewMode then
        Craft.SetPreviewMode(State.PreviewMode)
    end
    if State.PreviewMode and ctx.Timer and ctx.Timer.Start then
        ctx.Timer.Start(ctx.CRAFT_FILTER_TIMER_ID or "ForgingUI_CraftFilter", 0.05, function()
            if State.PreviewActive and State.PreviewMode then
                Craft.SetPreviewMode(State.PreviewMode)
            end
        end)
    end

    local uiObj = ctx.uiInstance:GetUI()
    local craftObj = craft:GetUI()
    if craftObj and uiObj then
        local targetLayer = (uiObj.Layer or 0) + 1
        if craftObj.Layer ~= targetLayer then
            craftObj.Layer = targetLayer
        end
    end

    local scale = ctx.uiInstance:GetUIScaleMultiplier()
    local uiX, uiY = ctx.uiInstance:GetPosition()
    local x = uiX + math.floor(State.Anchor.X * scale)
    local y = uiY + math.floor(State.Anchor.Y * scale)
    craft:SetPosition(V(x, y))
    State.LockedPosition = {X = x, Y = y}
    EnsureCraftPositionLock()
end

function Craft.HideUI()
    if not ctx or not ctx.USE_VANILLA_COMBINE_PANEL then
        return
    end

    local craft = GetCraftUI()
    if not craft or not craft.Exists or not craft:Exists() then
        return
    end

    if craft.IsVisible and craft:IsVisible() and not State.WasVisible then
        craft:Hide()
    end

    Craft.SetPreviewSkin(false)
    State.PreviewActive = false
    State.LockedPosition = nil
end

function Craft.RequestDock(id)
    local mode = GetCraftModeForSlot(id)
    if not mode then
        return
    end

    if ctx and ctx.USE_VANILLA_COMBINE_PANEL then
        State.DockRequested = true
        Craft.SetPreviewMode(mode)
        if ctx.SetDisplayMode then
            ctx.SetDisplayMode(GetDisplayModes().Combine)
        end
    else
        if ctx and ctx.SetPreviewInventoryMode then
            ctx.SetPreviewInventoryMode(mode)
        end
    end
end

function Craft.EnsureHooks()
    if State.HooksInstalled then
        return
    end

    local craft = GetCraftUI()
    if not craft or not craft.Events then
        return
    end

    if craft.Events.FilterSelected and craft.Events.FilterSelected.Subscribe then
        craft.Events.FilterSelected:Subscribe(function (ev)
            if not ev.Scripted then
                State.LastFilter = ev.Filter
            end
        end)
    end

    if craft.Events.CharacterSelected and craft.Events.CharacterSelected.Subscribe then
        craft.Events.CharacterSelected:Subscribe(function ()
            if not State.PreviewActive or not State.PreviewMode then
                return
            end
            if not ctx or not ctx.Timer or not ctx.Timer.Start then
                return
            end
            ctx.Timer.Start(ctx.CRAFT_FILTER_TIMER_ID or "ForgingUI_CraftFilter", 0.05, function()
                if State.PreviewActive and State.PreviewMode then
                    Craft.SetPreviewMode(State.PreviewMode)
                end
            end)
        end)
    end

    State.HooksInstalled = true
end

return Craft
