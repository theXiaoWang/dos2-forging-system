-- Client/ForgingUI/Widgets.lua
-- Reusable UI widget helpers for the forging panel.

local ForgingUI = Client.ForgingUI or {}
Client.ForgingUI = ForgingUI

local Widgets = {}
ForgingUI.Widgets = Widgets

local PreviewSearchShortcuts = Ext.Require("Client/ForgingUI/Input/PreviewSearchShortcuts.lua")

local ctx = nil
local previewInventory = {
    Root = nil,
    Filter = nil,
    Slots = {},
    FilterButtons = {},
    SearchRoot = nil,
    SearchFrame = nil,
    SearchText = nil,
    SearchHint = nil,
    SearchQuery = nil,
    SearchFocused = false,
    SearchHistory = nil,
    SearchHistoryIndex = 0,
    SearchHistoryIgnore = false,
    SearchCtrlHeld = false,
    SearchClipboard = "",
    Grid = nil,
    ScrollList = nil,
    AutoSortButton = nil,
    SortByButton = nil,
    SortByPanel = nil,
    SortByList = nil,
    SortByOptions = {},
    SortByOpen = false,
    SortByStyles = nil,
    Columns = 0,
    GridSpacing = 0,
    SlotSize = 66,  -- Increased to fully show item frames
    ListOffsetY = 0,
    ListHeight = 0,
    GridPadding = 0,
    GridOffsetY = 0,
    GridContentWidth = 0,
    ScrollContentHeight = 0,
    ScrollTrack = nil,
    ScrollHandle = nil,
    ScrollHandleStyle = nil,
    ScrollHandleWidth = 0,
    ScrollHandleHeight = 0,
    ScrollHandleMinHeight = 0,
    ScrollHandleOffsetX = 0,
    ScrollHandleOffsetY = 0,
    ScrollHandleRotation = 0,
    ScrollTrackX = 0,
    ScrollTrackY = 0,
    ScrollTrackHeight = 0,
    ScrollMaxOffset = 0,
    ScrollDragging = false,
    ScrollDragOffset = 0,
}

local function GetUI()
    return ctx and ctx.uiInstance or nil
end

local function V(...)
    return ctx and ctx.V and ctx.V(...) or Vector.Create(...)
end

local function ScaleX(value)
    if ctx and ctx.ScaleX then
        return ctx.ScaleX(value)
    end
    return value
end

local function ScaleY(value)
    if ctx and ctx.ScaleY then
        return ctx.ScaleY(value)
    end
    return value
end

local function Scale(value)
    if ctx and ctx.Scale then
        return ctx.Scale(value)
    end
    return value
end

local function Clamp(value, minValue, maxValue)
    if ctx and ctx.Clamp then
        return ctx.Clamp(value, minValue, maxValue)
    end
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

local PreviewScroll = Ext.Require("Client/ForgingUI/UI/PreviewInventory/Scroll.lua").Create({
    previewInventory = previewInventory,
    clamp = Clamp,
})
local GetPreviewScrollBar = PreviewScroll.GetPreviewScrollBar
local ApplyPreviewScrollOffset = PreviewScroll.ApplyPreviewScrollOffset
local UpdatePreviewScrollHandle = PreviewScroll.UpdatePreviewScrollHandle
local UpdatePreviewScrollFromMouse = PreviewScroll.UpdatePreviewScrollFromMouse
local EnsurePreviewScrollTick = PreviewScroll.EnsurePreviewScrollTick

local PreviewSearch = Ext.Require("Client/ForgingUI/UI/PreviewInventory/Search.lua").Create({
    previewInventory = previewInventory,
    previewSearchShortcuts = PreviewSearchShortcuts,
})
local UnfocusPreviewSearch = PreviewSearch.UnfocusPreviewSearch
local RegisterSearchBlur = PreviewSearch.RegisterSearchBlur
local RegisterPreviewSearchShortcuts = PreviewSearch.RegisterPreviewSearchShortcuts
local NormalizeSearchQuery = PreviewSearch.NormalizeSearchQuery
local GetItemSearchName = PreviewSearch.GetItemSearchName

local Elements = Ext.Require("Client/ForgingUI/UI/Widgets/Elements.lua").Create({
    getContext = function()
        return ctx
    end,
    getUI = GetUI,
    vector = V,
    registerSearchBlur = RegisterSearchBlur,
})
Widgets.CreateFrame = Elements.CreateFrame
Widgets.CreateTextElement = Elements.CreateTextElement
Widgets.CreatePanel = Elements.CreatePanel
Widgets.BuildButtonStyle = Elements.BuildButtonStyle
Widgets.CreateSkinnedPanel = Elements.CreateSkinnedPanel
Widgets.CreateButtonBox = Elements.CreateButtonBox

local Blocks = Ext.Require("Client/ForgingUI/UI/Widgets/Blocks.lua").Create({
    getContext = function()
        return ctx
    end,
    createFrame = Widgets.CreateFrame,
    createTextElement = Widgets.CreateTextElement,
    scale = Scale,
})
Widgets.CreateSectionBox = Blocks.CreateSectionBox
Widgets.CreateItemCard = Blocks.CreateItemCard
Widgets.CreateSkillChip = Blocks.CreateSkillChip

local Slots = Ext.Require("Client/ForgingUI/UI/Widgets/Slots.lua").Create({
    getContext = function()
        return ctx
    end,
    getUI = GetUI,
    vector = V,
    registerSearchBlur = RegisterSearchBlur,
    unfocusPreviewSearch = UnfocusPreviewSearch,
    createFrame = Widgets.CreateFrame,
    createTextElement = Widgets.CreateTextElement,
    scale = Scale,
})
Widgets.WireButton = Slots.WireButton
Widgets.WireSlot = Slots.WireSlot
Widgets.CreateDropSlot = Slots.CreateDropSlot
Widgets.CreateItemSlotRow = Slots.CreateItemSlotRow
Widgets.CreateItemSlot = Slots.CreateItemSlot

local PreviewRenderer = Ext.Require("Client/ForgingUI/UI/PreviewInventory/Renderer.lua").Create({
    previewInventory = previewInventory,
    getContext = function()
        return ctx
    end,
    vector = V,
    normalizeSearchQuery = NormalizeSearchQuery,
    getItemSearchName = GetItemSearchName,
    resetPreviewLayout = function()
        if ctx and ctx.PreviewLogic and ctx.PreviewLogic.GetPreviewSortMode and ctx.PreviewLogic.SetPreviewSortMode then
            local currentMode = ctx.PreviewLogic.GetPreviewSortMode()
            ctx.PreviewLogic.SetPreviewSortMode(currentMode, true)
        end
    end,
    registerSearchBlur = RegisterSearchBlur,
    updateScrollHandle = UpdatePreviewScrollHandle,
    getScrollBar = GetPreviewScrollBar,
    getUI = GetUI,
})
local EnsurePreviewSlot = PreviewRenderer.EnsurePreviewSlot
local RenderPreviewInventory = PreviewRenderer.RenderPreviewInventory

local PreviewPanel = Ext.Require("Client/ForgingUI/UI/PreviewInventory/Panel.lua")

local PreviewControls = Ext.Require("Client/ForgingUI/UI/PreviewInventory/Controls.lua").Create({
    previewInventory = previewInventory,
    getContext = function()
        return ctx
    end,
    getUI = GetUI,
    buildButtonStyle = function(width, height, baseStyle)
        if Widgets.BuildButtonStyle then
            return Widgets.BuildButtonStyle(width, height, baseStyle)
        end
        return nil
    end,
    renderPreviewInventory = function()
        if RenderPreviewInventory then
            RenderPreviewInventory()
        end
    end,
})
local UpdatePreviewFilterButtons = PreviewControls.UpdatePreviewFilterButtons
local WirePreviewFilterButton = PreviewControls.WirePreviewFilterButton
local ApplyPreviewSortMode = PreviewControls.ApplyPreviewSortMode
local SetSortByPanelOpen = PreviewControls.SetSortByPanelOpen
local CreateSortOption = PreviewControls.CreateSortOption
local SetPreviewInventoryMode = PreviewControls.SetPreviewInventoryMode

local function ResolveDefaultSortMode()
    if ctx and ctx.PreviewLogic and ctx.PreviewLogic.PREVIEW_SORT_MODES then
        return ctx.PreviewLogic.PREVIEW_SORT_MODES.Default
    end
    return "Default"
end

function Widgets.SetContext(nextCtx)
    ctx = nextCtx
end

function Widgets.GetPreviewInventory()
    return previewInventory
end

function Widgets.UnfocusPreviewSearch()
    UnfocusPreviewSearch()
end

function Widgets.RegisterSearchBlur(element)
    RegisterSearchBlur(element)
end

function Widgets.SetPreviewInventoryMode(mode)
    if SetPreviewInventoryMode then
        SetPreviewInventoryMode(mode)
    end
end
Widgets.RenderPreviewInventory = RenderPreviewInventory

function Widgets.ClearPreviewSearch()
    previewInventory.SearchQuery = ""
    if previewInventory.SearchText and previewInventory.SearchText.SetText then
        previewInventory.SearchText:SetText("")
    end
    if previewInventory.SearchText and previewInventory.SearchText.SetFocused then
        previewInventory.SearchText:SetFocused(false)
    end
    if previewInventory.SearchHint and previewInventory.SearchHint.SetVisible then
        previewInventory.SearchHint:SetVisible(true)
    end
    previewInventory.SearchFocused = false
    previewInventory.SearchCtrlHeld = false
    previewInventory.SearchHistory = {""}
    previewInventory.SearchHistoryIndex = 1
    previewInventory.SearchClipboard = ""
    ApplyPreviewSortMode(ResolveDefaultSortMode())
end

function Widgets.CreatePreviewInventoryPanel(parent, width, height, offsetX, offsetY)
    return PreviewPanel.Build({
        ctx = ctx,
        previewInventory = previewInventory,
        parent = parent,
        width = width,
        height = height,
        offsetX = offsetX,
        offsetY = offsetY,
        scale = Scale,
        scaleX = ScaleX,
        scaleY = ScaleY,
        clamp = Clamp,
        vector = V,
        getUI = GetUI,
        createButtonBox = Widgets.CreateButtonBox,
        createFrame = Widgets.CreateFrame,
        buildButtonStyle = Widgets.BuildButtonStyle,
        normalizeSearchQuery = NormalizeSearchQuery,
        registerSearchBlur = RegisterSearchBlur,
        registerPreviewSearchShortcuts = RegisterPreviewSearchShortcuts,
        renderPreviewInventory = RenderPreviewInventory,
        updatePreviewFilterButtons = UpdatePreviewFilterButtons,
        wirePreviewFilterButton = WirePreviewFilterButton,
        applyPreviewSortMode = ApplyPreviewSortMode,
        setSortByPanelOpen = SetSortByPanelOpen,
        createSortOption = CreateSortOption,
        updatePreviewScrollFromMouse = UpdatePreviewScrollFromMouse,
        ensurePreviewScrollTick = EnsurePreviewScrollTick,
        resolveDefaultSortMode = ResolveDefaultSortMode,
    })
end

return Widgets
