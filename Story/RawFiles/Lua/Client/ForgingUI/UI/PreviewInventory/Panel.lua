
-- Client/ForgingUI/UI/PreviewInventory/Panel.lua
-- Builds the preview inventory panel UI.

local SearchInput = Ext.Require("Client/ForgingUI/UI/PreviewInventory/SearchInput.lua")

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

    local filterButtonSize = clamp(scaleY(26), 22, 28)
    local buttonWidth = filterButtonSize
    local buttonHeight = filterButtonSize
    local buttonGap = scaleX(4)
    local rowPaddingY = clamp(scaleY(3), 2, 6)
    local rowGap = clamp(scaleY(4), 2, 8)
    local topRowHeight = buttonHeight + rowPaddingY * 2
    local bottomRowHeight = buttonHeight + rowPaddingY * 2
    local filterHeight = topRowHeight + bottomRowHeight + rowGap
    local filterBar = previewInventory.Root:AddChild("PreviewInventory_FilterBar", "GenericUI_Element_Empty")
    filterBar:SetPosition(0, 0)
    ApplySize(filterBar, width, filterHeight)
    NormalizeScale(filterBar)

    local topRowY = 0
    local bottomRowY = topRowHeight + rowGap
    local topRowButtonY = topRowY + math.floor((topRowHeight - buttonHeight) / 2)

    local buttonClusterWidth = buttonWidth * 2 + buttonGap
    local startX = math.floor((width - buttonClusterWidth) / 2)

    local previewTuning = ctx and ctx.PreviewInventoryTuning or nil

    local sortButtonWidthBase = (previewTuning and previewTuning.SortButtonWidthX) or 88
    local sortButtonWidthMin = (previewTuning and previewTuning.SortButtonWidthMin) or 70
    local sortButtonWidthMax = (previewTuning and previewTuning.SortButtonWidthMax) or 110
    local sortButtonWidth = clamp(scaleX(sortButtonWidthBase), sortButtonWidthMin, sortButtonWidthMax)
    local sortButtonHeight = clamp(scaleY(22), 20, buttonHeight)
    local sortButtonGap = scaleX(4)
    local rowPadX = scaleX(6)
    local sortPad = rowPadX
    local rowBGPadXBase = (previewTuning and previewTuning.RowBackgroundPadX) or 9
    local rowBGPadXMin = (previewTuning and previewTuning.RowBackgroundPadMin) or 8
    local rowBGPadXMax = (previewTuning and previewTuning.RowBackgroundPadMax) or 13
    local rowBGPadX = clamp(scaleX(rowBGPadXBase), rowBGPadXMin, rowBGPadXMax)
    local rowBGPadY = clamp(scaleY(4), 2, 8)
    local rowBGHeight = bottomRowHeight + rowBGPadY * 2
    local rowBGTopY = bottomRowY - rowBGPadY
    local rowBGContentOffsetY = -clamp(scaleY(1), 2, 3)
    local sortClusterWidth = sortButtonWidth * 2 + sortButtonGap
    local sortStartX = width - rowPadX - sortClusterWidth
    if sortStartX < 0 then
        sortStartX = 0
    end
    local sortY = rowBGTopY + math.floor((rowBGHeight - sortButtonHeight) / 2) + rowBGContentOffsetY

    local searchGap = scaleX(8)
    local searchX = rowPadX
    local maxSearchWidth = sortStartX - searchX - searchGap
    if maxSearchWidth < 0 then
        maxSearchWidth = 0
    end
    local minSearchWidthBase = (previewTuning and previewTuning.SearchMinWidthX) or 90
    local minSearchWidthMin = (previewTuning and previewTuning.SearchMinWidthMin) or 70
    local minSearchWidthMax = (previewTuning and previewTuning.SearchMinWidthMax) or 120
    local minSearchWidth = clamp(scaleX(minSearchWidthBase), minSearchWidthMin, minSearchWidthMax)
    local desiredSearchWidthBase = (previewTuning and previewTuning.SearchDesiredWidthX) or 210
    local desiredSearchWidthMax = (previewTuning and previewTuning.SearchDesiredWidthMax) or 320
    local desiredSearchWidth = clamp(scaleX(desiredSearchWidthBase), minSearchWidth, desiredSearchWidthMax)
    local searchWidth = desiredSearchWidth
    if maxSearchWidth <= 0 then
        searchWidth = 0
    elseif searchWidth > maxSearchWidth then
        searchWidth = maxSearchWidth
    end
    local searchHeight = buttonHeight
    local searchY = rowBGTopY + math.floor((rowBGHeight - searchHeight) / 2) + rowBGContentOffsetY

    local rowTexture = nil
    if ctx and ctx.Client and ctx.Client.Textures and ctx.Client.Textures.GenericUI then
        local textures = ctx.Client.Textures.GenericUI.TEXTURES
        if textures and textures.FRAMES and textures.FRAMES.ENTRIES then
            rowTexture = textures.FRAMES.ENTRIES.DARK
        end
    end
    local rowBG = filterBar:AddChild("PreviewInventory_SearchRowBG", "GenericUI_Element_Texture")
    local rowBGWidth = width + rowBGPadX * 2
    if rowTexture then
        rowBG:SetTexture(rowTexture, vector(rowBGWidth, rowBGHeight))
    end
    rowBG:SetPosition(-rowBGPadX, rowBGTopY)
    rowBG:SetSize(rowBGWidth, rowBGHeight)
    NormalizeScale(rowBG)
    if rowBG.SetMouseEnabled then
        rowBG:SetMouseEnabled(false)
    end
    if rowBG.SetMouseChildren then
        rowBG:SetMouseChildren(false)
    end
    if filterBar.SetChildIndex then
        filterBar:SetChildIndex(rowBG, 0)
    end

    if searchWidth > 0 then
        SearchInput.Build({
            ctx = ctx,
            previewInventory = previewInventory,
            parent = filterBar,
            x = searchX,
            y = searchY,
            width = searchWidth,
            height = searchHeight,
            previewTuning = previewTuning,
            scaleX = scaleX,
            scaleY = scaleY,
            clamp = clamp,
            normalizeSearchQuery = normalizeSearchQuery,
            registerPreviewSearchShortcuts = registerPreviewSearchShortcuts,
            renderPreviewInventory = renderPreviewInventory,
            applyPreviewSortMode = applyPreviewSortMode,
            resolveDefaultSortMode = resolveDefaultSortMode,
            applySize = ApplySize,
            normalizeScale = NormalizeScale,
        })
    end

    local equipmentBtn = createButtonBox(filterBar, "PreviewFilter_Equipment", "", startX, topRowButtonY, buttonWidth, buttonHeight, false, ctx.styleSquareStone)
    local magicalBtn = createButtonBox(filterBar, "PreviewFilter_Magical", "", startX + buttonWidth + buttonGap, topRowButtonY, buttonWidth, buttonHeight, false, ctx.styleSquareStone)

    local smallBrown = ctx.buttonPrefab and ctx.buttonPrefab.STYLES and (ctx.buttonPrefab.STYLES.SmallBrown or ctx.buttonPrefab.STYLES.MenuSlate or ctx.buttonStyle) or ctx.buttonStyle
    local smallRed = ctx.buttonPrefab and ctx.buttonPrefab.STYLES and (ctx.buttonPrefab.STYLES.SmallRed or ctx.buttonPrefab.STYLES.MediumRed or smallBrown) or smallBrown
    local autoSortBtn = createButtonBox(filterBar, "PreviewInventory_AutoSort", "AUTOSORT", sortStartX, sortY, sortButtonWidth, sortButtonHeight, false, smallBrown)
    local sortByBtn = createButtonBox(filterBar, "PreviewInventory_SortBy", "SORT BY", sortStartX + sortButtonWidth + sortButtonGap, sortY, sortButtonWidth, sortButtonHeight, false, smallBrown)

    local buttonTextSize = clamp(math.floor(sortButtonHeight * 0.45), 8, 10)
    if Text and Text.Format then
        if autoSortBtn then
            autoSortBtn:SetLabel(Text.Format("AUTOSORT", {Size = buttonTextSize, Color = "FFFFFF"}), "Center")
        end
        if sortByBtn then
            sortByBtn:SetLabel(Text.Format("SORT BY", {Size = buttonTextSize, Color = "FFFFFF"}), "Center")
        end
    end

    previewInventory.AutoSortButton = autoSortBtn
    previewInventory.SortByButton = sortByBtn
    if buildButtonStyle then
        previewInventory.SortByStyles = {
            Closed = buildButtonStyle(sortButtonWidth, sortButtonHeight, smallBrown),
            Open = buildButtonStyle(sortButtonWidth, sortButtonHeight, smallRed),
        }
    end

    if equipmentBtn and equipmentBtn.SetIcon then
        local iconSize = math.floor(filterButtonSize * 0.65)
        equipmentBtn:SetIcon("PIP_UI_Icon_Tab_Equipment_Trade", vector(iconSize, iconSize))
    end
    if magicalBtn and magicalBtn.SetIcon then
        local iconSize = math.floor(filterButtonSize * 0.65)
        magicalBtn:SetIcon("PIP_UI_Icon_Tab_Magical", vector(iconSize, iconSize))
    end

    previewInventory.FilterButtons[ctx.CRAFT_PREVIEW_MODES.Equipment] = equipmentBtn
    previewInventory.FilterButtons[ctx.CRAFT_PREVIEW_MODES.Magical] = magicalBtn
    if wirePreviewFilterButton then
        wirePreviewFilterButton(equipmentBtn, ctx.CRAFT_PREVIEW_MODES.Equipment)
        wirePreviewFilterButton(magicalBtn, ctx.CRAFT_PREVIEW_MODES.Magical)
    end

    local sortModes = ctx.PreviewLogic and ctx.PreviewLogic.PREVIEW_SORT_MODES or {Default = "Default", LastAcquired = "LastAcquired", Rarity = "Rarity", Type = "Type"}
    if autoSortBtn and autoSortBtn.Events and autoSortBtn.Events.Pressed then
        autoSortBtn.Events.Pressed:Subscribe(function ()
            if applyPreviewSortMode then
                applyPreviewSortMode(sortModes.Default)
            end
            if setSortByPanelOpen then
                setSortByPanelOpen(false)
            end
        end)
    end
    if sortByBtn and sortByBtn.Events and sortByBtn.Events.Pressed then
        sortByBtn.Events.Pressed:Subscribe(function ()
            if setSortByPanelOpen then
                setSortByPanelOpen(not previewInventory.SortByOpen)
            end
        end)
    end

    local optionHeight = clamp(scaleY(34), 28, 38)
    local optionCount = 3
    local sortPanelPadding = scale(10)
    local sortPanelWidth = clamp(scaleX(160), 150, width - sortPad * 2)
    local sortPanelHeight = optionHeight * optionCount + scaleY(25)
    local sortPanelX = width - sortPanelWidth - sortPad
    local sortPanelY = filterHeight + scaleY(4)
    local contextMenuStyle = ctx and ctx.slicedTexturePrefab and ctx.slicedTexturePrefab.STYLES
        and ctx.slicedTexturePrefab.STYLES.ContextMenu
        or nil
    local baseFrameAlpha = ctx.FRAME_ALPHA or 1
    local sortPanelAlphaScale = ctx.SORT_PANEL_ALPHA_SCALE or 1
    local sortFrameAlpha = math.min(1, baseFrameAlpha + 0.15)
    local baseCenterAlpha = ctx.FRAME_TEXTURE_CENTER_ALPHA or baseFrameAlpha
    local sortCenterAlpha = math.min(1, (baseCenterAlpha + 0.2) * sortPanelAlphaScale)
    local baseInnerAlpha = ctx.PANEL_FILL_ALPHA or baseFrameAlpha
    local sortInnerAlpha = math.min(1, (baseInnerAlpha + 0.15) * sortPanelAlphaScale)
    local sortFrame, sortInner, sortInnerWidth, sortInnerHeight = createFrame(
        previewInventory.Root,
        "PreviewInventory_SortPanel",
        sortPanelX,
        sortPanelY,
        sortPanelWidth,
        sortPanelHeight,
        ctx.FILL_COLOR,
        sortFrameAlpha,
        sortPanelPadding,
        true,
        sortCenterAlpha,
        sortInnerAlpha,
        contextMenuStyle
    )
    if sortFrame and sortFrame.SetVisible then
        sortFrame:SetVisible(false)
    end
    if previewInventory.Root.SetChildIndex then
        previewInventory.Root:SetChildIndex(sortFrame, 9998)
    end
    previewInventory.SortByPanel = sortFrame
    if not sortInner then
        sortInner = sortFrame:AddChild("PreviewInventory_SortPanel_Inner", "GenericUI_Element_Empty")
        sortInner:SetPosition(sortPanelPadding, sortPanelPadding)
        sortInnerWidth = math.max(0, sortPanelWidth - sortPanelPadding * 2)
        sortInnerHeight = math.max(0, sortPanelHeight - sortPanelPadding * 2)
        ApplySize(sortInner, sortInnerWidth, sortInnerHeight)
        NormalizeScale(sortInner)
    end

    local sortList = sortInner:AddChild("PreviewInventory_SortList", "GenericUI_Element_VerticalList")
    sortList:SetPosition(0, 0)
    sortList:SetSize(sortInnerWidth, sortInnerHeight)
    sortList:SetElementSpacing(0, 0)
    sortList:SetTopSpacing(0)
    sortList:SetSideSpacing(0)
    sortList:SetRepositionAfterAdding(true)
    previewInventory.SortByList = sortList

    local options = {
        {Key = sortModes.LastAcquired, Label = "Last Picked Up"},
        {Key = sortModes.Rarity, Label = "Rarity"},
        {Key = sortModes.Type, Label = "Type"},
    }
    for i, option in ipairs(options) do
        local row = nil
        if createSortOption then
            row = createSortOption(sortList, "PreviewInventory_SortOption_" .. tostring(i), option.Label, option.Key, sortInnerWidth, optionHeight)
        end
        if row then
            table.insert(previewInventory.SortByOptions, row)
        end
    end
    if sortList.RepositionElements then
        sortList:RepositionElements()
    end

    local list = previewInventory.Root:AddChild("PreviewInventory_List", "GenericUI_Element_ScrollList")
    local listOffsetY = filterHeight
    local listHeight = math.max(0, height - listOffsetY)
    list:SetPosition(0, listOffsetY)
    ApplySize(list, width, listHeight)
    NormalizeScale(list)
    list:SetMouseWheelEnabled(true)
    previewInventory.ScrollList = list
    previewInventory.ListOffsetY = listOffsetY
    previewInventory.ListHeight = listHeight
    if registerSearchBlur then
        registerSearchBlur(list)
    end

    local grid = list:AddChild("PreviewInventory_Grid", "GenericUI_Element_Grid")
    local padding = scale(4)  -- Reduced padding to give more space for slots

    -- Fixed 8 columns per row for consistent layout.
    local columns = 8
    previewInventory.Columns = columns
    local gridWidth = math.max(0, width - padding * 2)
    local maxSlot = math.floor((gridWidth - previewInventory.GridSpacing * (columns - 1)) / columns)
    -- Use larger minimum (48) to ensure icons are fully visible
    previewInventory.SlotSize = math.max(48, math.min(previewInventory.SlotSize, maxSlot))

    -- Calculate actual grid content width and center it
    local gridContentWidth = columns * previewInventory.SlotSize + (columns - 1) * previewInventory.GridSpacing
    local gridX = math.floor((width - gridContentWidth) / 2)
    local gridY = padding

    grid:SetPosition(gridX, gridY)
    ApplySize(grid, gridContentWidth, math.max(0, listHeight - padding * 2))
    NormalizeScale(grid)
    grid:SetElementSpacing(previewInventory.GridSpacing, previewInventory.GridSpacing)
    previewInventory.Grid = grid
    previewInventory.GridPadding = padding
    previewInventory.GridOffsetY = gridY
    previewInventory.GridContentWidth = gridContentWidth
    if registerSearchBlur then
        registerSearchBlur(grid)
    end
    grid:SetGridSize(columns, 1)

    if useBuiltinScrollbar then
        local scrollBarPaddingBase = (previewTuning and previewTuning.ScrollBarPaddingX) or 6
        local scrollBarPaddingMin = (previewTuning and previewTuning.ScrollBarPaddingMin) or 4
        local scrollBarPaddingMax = (previewTuning and previewTuning.ScrollBarPaddingMax) or 10
        local scrollBarPadding = clamp(scaleX(scrollBarPaddingBase), scrollBarPaddingMin, scrollBarPaddingMax)
        local desiredScrollbarX = gridX + gridContentWidth + scrollBarPadding
        local scrollbarSpacing = desiredScrollbarX - width
        list:SetScrollbarSpacing(scrollbarSpacing)
        list:SetFrame(width, listHeight)
    else
        local scrollStyle = ctx.buttonPrefab and ctx.buttonPrefab.STYLES and ctx.buttonPrefab.STYLES.ScrollBarHorizontal or ctx.buttonStyle
        local ui = getUI and getUI() or nil
        local scrollHandle = ctx.buttonPrefab.Create(ui, "PreviewInventory_ScrollHandle", previewInventory.Root, scrollStyle)
        scrollHandle:SetLabel("")
        if scrollHandle.Root and scrollHandle.Root.SetVisible then
            scrollHandle.Root:SetVisible(false)
        end
        if registerSearchBlur then
            registerSearchBlur(scrollHandle.Root)
        end

        local scrollHandleWidth = 0
        local scrollHandleHeight = 0
        if scrollHandle.Root and scrollHandle.Root.GetWidth then
            scrollHandleWidth = scrollHandle.Root:GetWidth()
        end
        if scrollHandle.Root and scrollHandle.Root.GetHeight then
            scrollHandleHeight = scrollHandle.Root:GetHeight()
        end
        if scrollHandleWidth <= 0 then
            local scrollHandleWidthBase = (previewTuning and previewTuning.ScrollHandleWidthX) or 12
            local scrollHandleWidthMin = (previewTuning and previewTuning.ScrollHandleWidthMin) or 10
            local scrollHandleWidthMax = (previewTuning and previewTuning.ScrollHandleWidthMax) or 16
            scrollHandleWidth = clamp(scaleX(scrollHandleWidthBase), scrollHandleWidthMin, scrollHandleWidthMax)
        end
        if scrollHandleHeight <= 0 then
            scrollHandleHeight = clamp(scaleY(20), 16, 28)
        end

        local handleOffsetX = 0
        local handleOffsetY = 0
        local handleRotation = 90
        if scrollHandle.Root and scrollHandle.Root.SetRotation then
            scrollHandle.Root:SetRotation(handleRotation)
            handleOffsetX = scrollHandleHeight
            handleOffsetY = 0
            scrollHandleWidth, scrollHandleHeight = scrollHandleHeight, scrollHandleWidth
        else
            handleRotation = 0
        end

        local scrollTrackPaddingBase = (previewTuning and previewTuning.ScrollTrackPaddingX) or 4
        local scrollTrackPaddingMin = (previewTuning and previewTuning.ScrollTrackPaddingMin) or 2
        local scrollTrackPaddingMax = (previewTuning and previewTuning.ScrollTrackPaddingMax) or 6
        local scrollTrackPadding = clamp(scaleX(scrollTrackPaddingBase), scrollTrackPaddingMin, scrollTrackPaddingMax)
        local desiredTrackX = gridX + gridContentWidth + scrollTrackPadding
        local maxTrackX = width - scrollHandleWidth - scrollTrackPadding
        local scrollTrackX = math.min(desiredTrackX, maxTrackX)
        if scrollTrackX < 0 then
            scrollTrackX = 0
        end
        local scrollTrackY = listOffsetY + padding
        local scrollTrackHeight = math.max(0, listHeight - padding * 2)
        local scrollTrack = previewInventory.Root:AddChild("PreviewInventory_ScrollTrack", "GenericUI_Element_Color")
        scrollTrack:SetPosition(scrollTrackX, scrollTrackY)
        scrollTrack:SetSize(scrollHandleWidth, scrollTrackHeight)
        local trackColor = (ctx and (ctx.PREVIEW_FILL_COLOR or ctx.FILL_COLOR)) or 0x000000
        if scrollTrack.SetColor then
            scrollTrack:SetColor(trackColor)
        end
        if scrollTrack.SetAlpha then
            scrollTrack:SetAlpha(0.15)
        end
        if scrollTrack.SetMouseEnabled then
            scrollTrack:SetMouseEnabled(false)
        end
        if scrollTrack.SetMouseChildren then
            scrollTrack:SetMouseChildren(false)
        end
        if scrollTrack.SetVisible then
            scrollTrack:SetVisible(false)
        end

        if scrollHandle.Root and scrollHandle.Root.SetPosition then
            scrollHandle.Root:SetPosition(scrollTrackX + handleOffsetX, scrollTrackY + handleOffsetY)
        end
        if previewInventory.Root and previewInventory.Root.SetChildIndex and scrollHandle.Root then
            previewInventory.Root:SetChildIndex(scrollHandle.Root, 9998)
        end

        if scrollHandle.Root and scrollHandle.Root.Events then
            scrollHandle.Root.Events.MouseDown:Subscribe(function ()
                previewInventory.ScrollDragging = true
                local dragHeight = previewInventory.ScrollHandleHeight > 0 and previewInventory.ScrollHandleHeight or scrollHandleHeight
                previewInventory.ScrollDragOffset = math.floor(dragHeight / 2)
            end)
            scrollHandle.Root.Events.MouseUp:Subscribe(function ()
                previewInventory.ScrollDragging = false
            end)
        end

        if previewInventory.Root and previewInventory.Root.Events then
            if previewInventory.Root.SetMouseMoveEventEnabled then
                previewInventory.Root:SetMouseMoveEventEnabled(true)
            end
            previewInventory.Root.Events.MouseMove:Subscribe(function (ev)
                if previewInventory.ScrollDragging then
                    local mouseY = ev and ev.LocalPos and ev.LocalPos[2] or 0
                    if updatePreviewScrollFromMouse then
                        updatePreviewScrollFromMouse(mouseY)
                    end
                end
            end)
            previewInventory.Root.Events.MouseUp:Subscribe(function ()
                previewInventory.ScrollDragging = false
            end)
            previewInventory.Root.Events.MouseOut:Subscribe(function ()
                previewInventory.ScrollDragging = false
            end)
        end

        previewInventory.ScrollTrack = scrollTrack
        previewInventory.ScrollHandle = scrollHandle
        previewInventory.ScrollHandleStyle = scrollStyle
        previewInventory.ScrollHandleWidth = scrollHandleWidth
        previewInventory.ScrollHandleHeight = scrollHandleHeight
        previewInventory.ScrollHandleMinHeight = scrollHandleHeight
        previewInventory.ScrollHandleOffsetX = handleOffsetX
        previewInventory.ScrollHandleOffsetY = handleOffsetY
        previewInventory.ScrollHandleRotation = handleRotation
        previewInventory.ScrollTrackX = scrollTrackX
        previewInventory.ScrollTrackY = scrollTrackY
        previewInventory.ScrollTrackHeight = scrollTrackHeight
        if ensurePreviewScrollTick then
            ensurePreviewScrollTick()
        end
    end

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
