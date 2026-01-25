
-- Client/ForgingUI/UI/PreviewInventory/Panel.lua
-- Builds the preview inventory panel UI.

local FilterBar = Ext.Require("Client/ForgingUI/UI/PreviewInventory/FilterBar.lua")
local ListGrid = Ext.Require("Client/ForgingUI/UI/PreviewInventory/ListGrid.lua")
local ScrollbarLayout = Ext.Require("Client/ForgingUI/UI/PreviewInventory/ScrollbarLayout.lua")

local Panel = {}

---@param options table
function Panel.Build(options)
    local opts = options or {}
    local ctx = opts.ctx
    local previewInventory = opts.previewInventory
    local parent = opts.parent
    if not parent or not ctx or not previewInventory then
        return
    end

    local width = opts.width or 0
    local height = opts.height or 0
    local offsetX = opts.offsetX or 0
    local offsetY = opts.offsetY or 0
    local scale = opts.scale or function(value) return value end
    local scaleX = opts.scaleX or function(value) return value end
    local scaleY = opts.scaleY or function(value) return value end
    local clamp = opts.clamp or function(value, minValue, maxValue)
        if value < minValue then
            return minValue
        end
        if value > maxValue then
            return maxValue
        end
        return value
    end
    local vector = opts.vector or function(...) return Vector.Create(...) end
    local getUI = opts.getUI
    local createButtonBox = opts.createButtonBox
    local createFrame = opts.createFrame
    local buildButtonStyle = opts.buildButtonStyle
    local normalizeSearchQuery = opts.normalizeSearchQuery
    local registerSearchBlur = opts.registerSearchBlur
    local registerPreviewSearchShortcuts = opts.registerPreviewSearchShortcuts
    local renderPreviewInventory = opts.renderPreviewInventory
    local updatePreviewFilterButtons = opts.updatePreviewFilterButtons
    local wirePreviewFilterButton = opts.wirePreviewFilterButton
    local applyPreviewSortMode = opts.applyPreviewSortMode
    local setSortByPanelOpen = opts.setSortByPanelOpen
    local createSortOption = opts.createSortOption
    local updatePreviewScrollFromMouse = opts.updatePreviewScrollFromMouse
    local ensurePreviewScrollTick = opts.ensurePreviewScrollTick
    local resolveDefaultSortMode = opts.resolveDefaultSortMode

    local function ApplySize(element, w, h)
        if not element then
            return
        end
        if element.SetSize then
            element:SetSize(w, h)
        end
        if element.SetSizeOverride then
            element:SetSizeOverride(w, h)
        end
    end
    local function NormalizeScale(element)
        if element and element.SetScale then
            element:SetScale(vector(1, 1))
        end
    end

    previewInventory.Slots = {}
    previewInventory.FilterButtons = {}
    previewInventory.SearchRoot = nil
    previewInventory.SearchFrame = nil
    previewInventory.SearchText = nil
    previewInventory.SearchHint = nil
    previewInventory.SearchQuery = previewInventory.SearchQuery or ""
    previewInventory.SearchFocused = false
    previewInventory.SearchHistory = nil
    previewInventory.SearchHistoryIndex = 0
    previewInventory.SearchHistoryIgnore = false
    previewInventory.SearchCtrlHeld = false
    previewInventory.SearchClipboard = ""
    previewInventory.ApplySearchText = nil
    previewInventory.Grid = nil
    previewInventory.ScrollList = nil
    previewInventory.AutoSortButton = nil
    previewInventory.SortByButton = nil
    previewInventory.SortByPanel = nil
    previewInventory.SortByList = nil
    previewInventory.SortByOptions = {}
    previewInventory.SortByOpen = false
    previewInventory.SortByStyles = nil
    previewInventory.ListOffsetY = 0
    previewInventory.ListHeight = 0
    previewInventory.GridPadding = 0
    previewInventory.GridOffsetY = 0
    previewInventory.GridContentWidth = 0
    previewInventory.ScrollContentHeight = 0
    previewInventory.ScrollTrack = nil
    previewInventory.ScrollHandle = nil
    previewInventory.ScrollHandleStyle = nil
    previewInventory.ScrollHandleWidth = 0
    previewInventory.ScrollHandleHeight = 0
    previewInventory.ScrollHandleMinHeight = 0
    previewInventory.ScrollHandleOffsetX = 0
    previewInventory.ScrollHandleOffsetY = 0
    previewInventory.ScrollHandleRotation = 0
    previewInventory.ScrollTrackX = 0
    previewInventory.ScrollTrackY = 0
    previewInventory.ScrollTrackHeight = 0
    previewInventory.ScrollMaxOffset = 0
    previewInventory.ScrollDragging = false
    previewInventory.ScrollDragOffset = 0
    if not previewInventory.Filter and ctx.CRAFT_PREVIEW_MODES then
        previewInventory.Filter = ctx.CRAFT_PREVIEW_MODES.Equipment
    end

    local useBuiltinScrollbar = true

    previewInventory.Root = parent:AddChild("PreviewInventoryPanel", "GenericUI_Element_Empty")
    previewInventory.Root:SetPosition(offsetX, offsetY)
    ApplySize(previewInventory.Root, width, height)
    NormalizeScale(previewInventory.Root)
    if previewInventory.Root.SetVisible then
        previewInventory.Root:SetVisible(true)
    end
    if parent.SetChildIndex then
        parent:SetChildIndex(previewInventory.Root, 9999)
    end

    local previewFillAlpha = ctx and ctx.PANEL_FILL_ALPHA
    if previewFillAlpha and previewFillAlpha > 0 then
        local previewBG = previewInventory.Root:AddChild("PreviewInventory_BG", "GenericUI_Element_Color")
        previewBG:SetPosition(0, 0)
        ApplySize(previewBG, width, height)
        previewBG:SetColor(ctx.PREVIEW_FILL_COLOR or ctx.FILL_COLOR)
        if previewBG.SetAlpha then
            previewBG:SetAlpha(previewFillAlpha)
        end
        NormalizeScale(previewBG)
        if previewInventory.Root.SetChildIndex then
            previewInventory.Root:SetChildIndex(previewBG, 0)
        end
    end

    local filterHeight = FilterBar.Build({
        ctx = ctx,
        previewInventory = previewInventory,
        parent = previewInventory.Root,
        width = width,
        scale = scale,
        scaleX = scaleX,
        scaleY = scaleY,
        clamp = clamp,
        vector = vector,
        applySize = ApplySize,
        normalizeScale = NormalizeScale,
        createButtonBox = createButtonBox,
        buildButtonStyle = buildButtonStyle,
        normalizeSearchQuery = normalizeSearchQuery,
        registerPreviewSearchShortcuts = registerPreviewSearchShortcuts,
        renderPreviewInventory = renderPreviewInventory,
        applyPreviewSortMode = applyPreviewSortMode,
        setSortByPanelOpen = setSortByPanelOpen,
        createFrame = createFrame,
        createSortOption = createSortOption,
        resolveDefaultSortMode = resolveDefaultSortMode,
        wirePreviewFilterButton = wirePreviewFilterButton,
    }) or 0

    local listMetrics = ListGrid.Build({
        ctx = ctx,
        previewInventory = previewInventory,
        parent = previewInventory.Root,
        width = width,
        height = height,
        filterHeight = filterHeight,
        scale = scale,
        applySize = ApplySize,
        normalizeScale = NormalizeScale,
        registerSearchBlur = registerSearchBlur,
    })

    ScrollbarLayout.Build({
        ctx = ctx,
        previewInventory = previewInventory,
        parent = previewInventory.Root,
        width = width,
        height = height,
        listMetrics = listMetrics,
        useBuiltinScrollbar = useBuiltinScrollbar,
        scaleX = scaleX,
        scaleY = scaleY,
        clamp = clamp,
        getUI = getUI,
        registerSearchBlur = registerSearchBlur,
        updatePreviewScrollFromMouse = updatePreviewScrollFromMouse,
        ensurePreviewScrollTick = ensurePreviewScrollTick,
    })

    if previewInventory.SortByPanel and previewInventory.Root and previewInventory.Root.SetChildIndex then
        previewInventory.Root:SetChildIndex(previewInventory.SortByPanel, 9999)
    end

    if updatePreviewFilterButtons then
        updatePreviewFilterButtons()
    end
    if renderPreviewInventory then
        renderPreviewInventory()
    end
end

return Panel
