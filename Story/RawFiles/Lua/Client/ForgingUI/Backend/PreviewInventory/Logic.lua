-- Backend interaction logic for preview inventory + forge slots.

local ForgingUI = Client.ForgingUI or {}
Client.ForgingUI = ForgingUI

local PreviewLogic = {}
ForgingUI.PreviewInventoryLogic = PreviewLogic

local ctx = nil

local State = {
    ForgeSlots = {},
    SlotItems = {},
    ItemToSlot = {},
    PreviewInventory = nil,
    PreviewSlotItems = {},
    PreviewItemToSlot = {},
    PreviewSlots = {},
    PreviewSlotItemsByFilter = {},
    PreviewItemToSlotByFilter = {},
    CurrentPreviewFilter = nil,
    PreviewDragItemHandle = nil,
    PreviewDragSourceIndex = nil,
    LastWarningTime = nil,
    LastPreviewHoverSlot = nil,
    LastForgeHoverSlot = nil,
    EquipmentSlotNames = nil,
    PreviewSortMode = "Default",
    ItemAcquireOrder = {},
    ItemAcquireCounter = 0,
}

PreviewLogic.State = State

local ItemHelpers = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/ItemHelpers.lua").Create(State)
local SafeStatsField = ItemHelpers.SafeStatsField
local SafeTemplateActions = ItemHelpers.SafeTemplateActions
local GetItemStats = ItemHelpers.GetItemStats
local IsEquipmentItemType = ItemHelpers.IsEquipmentItemType
local IsSkillbookItemType = ItemHelpers.IsSkillbookItemType

local DEFAULT_DROP_SOUND = "UI_Game_PartyFormation_PickUp"
local WARNING_CLEAR_TIMER_ID = "ForgingUI_DropWarningClear"
local WARNING_SLOT_TIMER_PREFIX = "ForgingUI_DropSlotWarning_"
local WARNING_DISPLAY_SECONDS = 1.6
local WARNING_THROTTLE_MS = 250
local WARNING_TEXT_COLOR = "FFD27F"
local WARNING_TEXT_SIZE = 14
local PREVIEW_TOOLTIP_THROTTLE_MS = 150

local PREVIEW_SORT_MODES = {
    Default = "Default",
    LastAcquired = "LastAcquired",
    Rarity = "Rarity",
    Type = "Type",
}
PreviewLogic.PREVIEW_SORT_MODES = PREVIEW_SORT_MODES

local function V(...)
    return ctx and ctx.V and ctx.V(...) or Vector.Create(...)
end

function PreviewLogic.SetContext(nextCtx)
    ctx = nextCtx
end

function PreviewLogic.SetPreviewFilter(filterKey)
    local key = tostring(filterKey or "default")
    if State.CurrentPreviewFilter == key then
        return
    end
    if State.CurrentPreviewFilter ~= nil then
        State.PreviewSlotItemsByFilter[State.CurrentPreviewFilter] = State.PreviewSlotItems
        State.PreviewItemToSlotByFilter[State.CurrentPreviewFilter] = State.PreviewItemToSlot
    end
    State.PreviewSlotItems = State.PreviewSlotItemsByFilter[key] or {}
    State.PreviewItemToSlot = State.PreviewItemToSlotByFilter[key] or {}
    State.CurrentPreviewFilter = key
    State.PreviewDragItemHandle = nil
    State.PreviewDragSourceIndex = nil
end

function PreviewLogic.SetPreviewSortMode(mode, resetLayout)
    State.PreviewSortMode = mode or PREVIEW_SORT_MODES.Default
    if resetLayout then
        local key = State.CurrentPreviewFilter or "default"
        State.PreviewSlotItems = {}
        State.PreviewItemToSlot = {}
        State.PreviewSlotItemsByFilter[key] = State.PreviewSlotItems
        State.PreviewItemToSlotByFilter[key] = State.PreviewItemToSlot
    end
end

function PreviewLogic.GetPreviewSortMode()
    return State.PreviewSortMode or PREVIEW_SORT_MODES.Default
end

function PreviewLogic.TrackInventoryItems(items)
    if not items then
        return
    end
    for _, item in ipairs(items) do
        local handle = item and (item.Handle or item.ItemHandle)
        if handle and State.ItemAcquireOrder[handle] == nil then
            State.ItemAcquireCounter = State.ItemAcquireCounter + 1
            State.ItemAcquireOrder[handle] = State.ItemAcquireCounter
        end
    end
end

local Sorting = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/Sorting.lua").Create(
    ItemHelpers,
    PREVIEW_SORT_MODES,
    function()
        return PreviewLogic.GetPreviewSortMode()
    end
)
PreviewLogic.SortPreviewItems = Sorting.SortPreviewItems

local DragDrop = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/DragDrop.lua").Create({
    state = State,
    getContext = function()
        return ctx
    end,
    safeTemplateActions = SafeTemplateActions,
})
local IsValidHandle = DragDrop.IsValidHandle
local IsItemObject = DragDrop.IsItemObject
local GetItemFromHandle = DragDrop.GetItemFromHandle
local ResolveItemFromDragObject = DragDrop.ResolveItemFromDragObject
local ResolveSlotItemHandle = DragDrop.ResolveSlotItemHandle
local GetDragDropState = DragDrop.GetDragDropState
local HasDragData = DragDrop.HasDragData
local FindItemByTemplateId = DragDrop.FindItemByTemplateId
local GetDraggedItem = DragDrop.GetDraggedItem
local ResolveDraggedItem = DragDrop.ResolveDraggedItem

local Classification = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/Classification.lua").Create({
    itemHelpers = ItemHelpers,
    getItemFromHandle = GetItemFromHandle,
    findItemByTemplateId = FindItemByTemplateId,
    isValidHandle = IsValidHandle,
})
local GetDropClassification = Classification.GetDropClassification

local PreviewLayout = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/PreviewLayout.lua").Create(State, IsValidHandle)
PreviewLogic.AssignPreviewSlot = PreviewLayout.AssignPreviewSlot
PreviewLogic.ClearPreviewSlot = PreviewLayout.ClearPreviewSlot
PreviewLogic.BuildPreviewInventoryLayout = PreviewLayout.BuildPreviewInventoryLayout

local ResolveForgeSlotMode = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/ForgeSlotRules.lua")
    .Create(State)
    .ResolveForgeSlotMode

local function PlaySound(soundId)
    if not soundId then
        return
    end
    if ctx and ctx.uiInstance and ctx.uiInstance.PlaySound then
        ctx.uiInstance:PlaySound(soundId)
    elseif ctx and ctx.uiInstance and ctx.uiInstance.GetUI then
        local ui = ctx.uiInstance:GetUI()
        if ui and ui.ExternalInterfaceCall then
            ui:ExternalInterfaceCall("PlaySound", soundId)
        end
    end
end

local function GetMonotonicTime()
    if Ext and Ext.MonotonicTime then
        return Ext.MonotonicTime()
    end
    if Ext and Ext.Utils and Ext.Utils.MonotonicTime then
        return Ext.Utils.MonotonicTime()
    end
    return nil
end

local function GetPreviewSlotItem(slot)
    if not slot then
        return nil
    end
    local obj = slot.Object
    if obj then
        if IsItemObject(obj) then
            return obj
        end
        if obj.GetEntity then
            local entity = obj:GetEntity()
            if entity then
                return entity
            end
        end
    end
    local handle = ResolveSlotItemHandle(slot)
    if handle then
        return GetItemFromHandle(handle)
    end
    return nil
end

local Tooltip = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/Tooltip.lua").Create(
    GetMonotonicTime,
    GetPreviewSlotItem,
    PREVIEW_TOOLTIP_THROTTLE_MS
)
local ShowPreviewSlotTooltip = Tooltip.ShowPreviewSlotTooltip
local HidePreviewSlotTooltip = Tooltip.HidePreviewSlotTooltip
local SlotVisuals = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/SlotVisuals.lua").Create({
    state = State,
    getContext = function()
        return ctx
    end,
    vector = V,
    showPreviewSlotTooltip = ShowPreviewSlotTooltip,
})
local ClearSlotHighlight = SlotVisuals.ClearSlotHighlight
local HandlePreviewSlotHover = SlotVisuals.HandlePreviewSlotHover
local HandlePreviewSlotHoverHighlight = SlotVisuals.HandlePreviewSlotHoverHighlight
local HandleForgeSlotHover = SlotVisuals.HandleForgeSlotHover
local ClearStaleHighlights = SlotVisuals.ClearStaleHighlights
local EnsureOverlay = SlotVisuals.EnsureOverlay
local ResetSlotVisualState = SlotVisuals.ResetSlotVisualState

local function GetItemDisplayNameSafe(item)
    if not item then
        return nil
    end
    if Item and Item.GetDisplayName and IsItemObject(item) then
        local ok, name = pcall(Item.GetDisplayName, item)
        if ok and name and name ~= "" then
            return name
        end
    end
    if not IsItemObject(item) then
        return nil
    end
    local displayName = item.DisplayName
    if displayName and displayName ~= "" then
        return displayName
    end
    local stats = GetItemStats(item)
    local statsId = item.StatsId or (stats and SafeStatsField(stats, "Name")) or nil
    return statsId
end

local Warnings = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/Warnings.lua").Create({
    state = State,
    getContext = function()
        return ctx
    end,
    getMonotonicTime = GetMonotonicTime,
    resolveForgeSlotMode = ResolveForgeSlotMode,
    getItemDisplayNameSafe = GetItemDisplayNameSafe,
    warningTextColor = WARNING_TEXT_COLOR,
    warningTextSize = WARNING_TEXT_SIZE,
    warningDisplaySeconds = WARNING_DISPLAY_SECONDS,
    warningThrottleMs = WARNING_THROTTLE_MS,
    warningClearTimerId = WARNING_CLEAR_TIMER_ID,
    warningSlotTimerPrefix = WARNING_SLOT_TIMER_PREFIX,
})
local ShowWarning = Warnings.ShowWarning
local ShowDropWarning = Warnings.ShowDropWarning
local FlashSlotWarning = Warnings.FlashSlotWarning

function PreviewLogic.ShowWarning(message)
    ShowWarning(message)
end

function PreviewLogic.ShowDropWarning(slotId, item)
    ShowDropWarning(slotId, item)
end

function PreviewLogic.CanAcceptItem(slotId, item, obj)
    local itemType, isEquipment, isSkillbook = GetDropClassification(item, obj)

    local slotMode = ResolveForgeSlotMode(slotId)
    
    -- Skillbook slot - only accepts skillbooks
    if slotMode == "Skillbook" then
        if itemType and IsSkillbookItemType(itemType) then
            return true
        end
        return isSkillbook == true
    end
    
    -- Equipment slots - reject skillbooks first, then check for equipment
    if slotMode == "Equipment" then
        -- Always reject skillbooks from equipment slots
        if isSkillbook then
            return false
        end
        if itemType and IsSkillbookItemType(itemType) then
            return false
        end
        -- Accept only equipment types
        if itemType and IsEquipmentItemType(itemType) then
            return true
        end
        return isEquipment == true
    end
    
    return true
end

local ForgeDropValidation = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/ForgeDropValidation.lua").Create({
    state = State,
    resolveForgeSlotMode = ResolveForgeSlotMode,
    hasDragData = HasDragData,
    getDraggedItem = GetDraggedItem,
    getDragDropState = GetDragDropState,
    resolveItemFromDragObject = ResolveItemFromDragObject,
    isValidHandle = IsValidHandle,
    canAcceptItem = function(slotId, item, obj)
        return PreviewLogic.CanAcceptItem(slotId, item, obj)
    end,
    showDropWarning = PreviewLogic.ShowDropWarning,
    flashSlotWarning = FlashSlotWarning,
})
local ResolveForgeSlotId = ForgeDropValidation.ResolveForgeSlotId
local ShouldBlockDrop = ForgeDropValidation.ShouldBlockDrop
local ValidateForgeSlotDrop = ForgeDropValidation.ValidateForgeSlotDrop

local ForgeSlotMapping = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/ForgeSlotMapping.lua").Create({
    state = State,
    isValidHandle = IsValidHandle,
    getItemFromHandle = GetItemFromHandle,
    resolveSlotItemHandle = ResolveSlotItemHandle,
    canAcceptItem = function(slotId, item, obj)
        return PreviewLogic.CanAcceptItem(slotId, item, obj)
    end,
    clearStaleHighlights = ClearStaleHighlights,
})
local ClearSlotMapping = ForgeSlotMapping.ClearSlotMapping
PreviewLogic.SyncForgeSlots = ForgeSlotMapping.SyncForgeSlots
PreviewLogic.AssignSlotItem = ForgeSlotMapping.AssignSlotItem
PreviewLogic.ClearForgeSlot = ForgeSlotMapping.ClearForgeSlot

local PreviewSlotHandlers = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/PreviewSlotHandlers.lua").Create({
    state = State,
    getContext = function()
        return ctx
    end,
    getDropClassification = GetDropClassification,
    assignPreviewSlot = PreviewLogic.AssignPreviewSlot,
    clearPreviewSlot = PreviewLogic.ClearPreviewSlot,
    resolveDraggedItem = ResolveDraggedItem,
    resolveSlotItemHandle = ResolveSlotItemHandle,
    syncForgeSlots = function()
        if PreviewLogic.SyncForgeSlots then
            PreviewLogic.SyncForgeSlots()
        end
    end,
    ensureOverlay = EnsureOverlay,
    clearSlotHighlight = ClearSlotHighlight,
    handlePreviewSlotHover = HandlePreviewSlotHover,
    handlePreviewSlotHoverHighlight = HandlePreviewSlotHoverHighlight,
    showPreviewSlotTooltip = ShowPreviewSlotTooltip,
    hidePreviewSlotTooltip = HidePreviewSlotTooltip,
    playSound = PlaySound,
    defaultDropSound = DEFAULT_DROP_SOUND,
})
PreviewLogic.HandlePreviewSlotDrop = PreviewSlotHandlers.HandlePreviewSlotDrop
PreviewLogic.WirePreviewSlot = PreviewSlotHandlers.WirePreviewSlot
PreviewLogic.RefreshInventoryHighlights = PreviewSlotHandlers.RefreshInventoryHighlights

local ForgeSlotHandlers = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/ForgeSlotHandlers.lua").Create({
    state = State,
    getContext = function()
        return ctx
    end,
    resolveForgeSlotId = ResolveForgeSlotId,
    resolveForgeSlotMode = ResolveForgeSlotMode,
    resolveDraggedItem = ResolveDraggedItem,
    canAcceptItem = function(slotId, item, obj)
        return PreviewLogic.CanAcceptItem(slotId, item, obj)
    end,
    clearSlotMapping = ClearSlotMapping,
    resetSlotVisualState = ResetSlotVisualState,
    getItemFromHandle = GetItemFromHandle,
    isValidHandle = IsValidHandle,
    assignSlotItem = PreviewLogic.AssignSlotItem,
    refreshInventoryHighlights = function()
        if PreviewLogic.RefreshInventoryHighlights then
            PreviewLogic.RefreshInventoryHighlights()
        end
    end,
    clearSlotHighlight = ClearSlotHighlight,
    handleForgeSlotHover = HandleForgeSlotHover,
    showDropWarning = PreviewLogic.ShowDropWarning,
    flashSlotWarning = FlashSlotWarning,
    shouldBlockDrop = ShouldBlockDrop,
    getDraggedItem = GetDraggedItem,
    validateForgeSlotDrop = ValidateForgeSlotDrop,
    playSound = PlaySound,
    defaultDropSound = DEFAULT_DROP_SOUND,
})
PreviewLogic.HandleForgeSlotDrop = ForgeSlotHandlers.HandleForgeSlotDrop
PreviewLogic.HandleForgeSlotDragStarted = ForgeSlotHandlers.HandleForgeSlotDragStarted
PreviewLogic.HandleForgeSlotClicked = ForgeSlotHandlers.HandleForgeSlotClicked
PreviewLogic.RegisterForgeSlots = ForgeSlotHandlers.RegisterForgeSlots

function PreviewLogic.EnsureForgeSlotValidator()
    if PreviewLogic._ForgeSlotValidatorInstalled then
        return
    end

    local function ValidateSlots()
        if not ctx or not ctx.UIState or not ctx.UIState.IsVisible then
            return
        end
        if not State or not State.ForgeSlots then
            return
        end
        PreviewLogic.SyncForgeSlots()
    end

    if GameState and GameState.Events and GameState.Events.RunningTick then
        GameState.Events.RunningTick:Subscribe(ValidateSlots, {StringID = "ForgingUI_ForgeSlotValidator"})
    elseif Ext and Ext.Events and Ext.Events.Tick then
        Ext.Events.Tick:Subscribe(ValidateSlots)
    elseif ctx and ctx.Timer and ctx.Timer.Start then
        local timer = ctx.Timer.Start("ForgingUI_ForgeSlotValidator", 0.05, function ()
            ValidateSlots()
        end)
        if timer and timer.SetRepeatCount then
            timer:SetRepeatCount(-1)
        end
    end

    PreviewLogic._ForgeSlotValidatorInstalled = true
end

function PreviewLogic.Bind(slots, previewInventory)
    if previewInventory ~= State.PreviewInventory then
        State.PreviewSlotItems = {}
        State.PreviewItemToSlot = {}
        State.PreviewSlots = {}
        State.PreviewSlotItemsByFilter = {}
        State.PreviewItemToSlotByFilter = {}
        State.CurrentPreviewFilter = nil
        State.PreviewDragItemHandle = nil
        State.PreviewDragSourceIndex = nil
    end
    State.PreviewInventory = previewInventory
    PreviewLogic.RegisterForgeSlots(slots)
    PreviewLogic.EnsureForgeSlotValidator()
end

return PreviewLogic
