-- Client/ForgingUI/UI/PreviewInventory/FilterBar.lua
-- Filter bar builder for the preview inventory panel.

local SearchInput = Ext.Require("Client/ForgingUI/UI/PreviewInventory/SearchInput.lua")

local FilterBar = {}

---@param options table
function FilterBar.Build(options)
    local opts = options or {}
    local ctx = opts.ctx
    local previewInventory = opts.previewInventory
    local parent = opts.parent
    if not parent or not ctx or not previewInventory then
        return 0
    end

    local width = opts.width or 0
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
    local applySize = opts.applySize or function() end
    local normalizeScale = opts.normalizeScale or function() end
    local createButtonBox = opts.createButtonBox
    local buildButtonStyle = opts.buildButtonStyle
    local normalizeSearchQuery = opts.normalizeSearchQuery
    local registerPreviewSearchShortcuts = opts.registerPreviewSearchShortcuts
    local renderPreviewInventory = opts.renderPreviewInventory
    local applyPreviewSortMode = opts.applyPreviewSortMode
    local setSortByPanelOpen = opts.setSortByPanelOpen
    local createFrame = opts.createFrame
    local createSortOption = opts.createSortOption
    local resolveDefaultSortMode = opts.resolveDefaultSortMode
    local wirePreviewFilterButton = opts.wirePreviewFilterButton

    local filterButtonSize = clamp(scaleY(26), 22, 28)
    local buttonWidth = filterButtonSize
    local buttonHeight = filterButtonSize
    local buttonGap = scaleX(4)
    local rowPaddingY = clamp(scaleY(3), 2, 6)
    local rowGap = clamp(scaleY(4), 2, 8)
    local topRowHeight = buttonHeight + rowPaddingY * 2
    local bottomRowHeight = buttonHeight + rowPaddingY * 2
    local filterHeight = topRowHeight + bottomRowHeight + rowGap
    local filterBar = parent:AddChild("PreviewInventory_FilterBar", "GenericUI_Element_Empty")
    filterBar:SetPosition(0, 0)
    applySize(filterBar, width, filterHeight)
    normalizeScale(filterBar)

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
    normalizeScale(rowBG)
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
            applySize = applySize,
            normalizeScale = normalizeScale,
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
        parent,
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
    if parent.SetChildIndex then
        parent:SetChildIndex(sortFrame, 9998)
    end
    previewInventory.SortByPanel = sortFrame
    if not sortInner then
        sortInner = sortFrame:AddChild("PreviewInventory_SortPanel_Inner", "GenericUI_Element_Empty")
        sortInner:SetPosition(sortPanelPadding, sortPanelPadding)
        sortInnerWidth = math.max(0, sortPanelWidth - sortPanelPadding * 2)
        sortInnerHeight = math.max(0, sortPanelHeight - sortPanelPadding * 2)
        applySize(sortInner, sortInnerWidth, sortInnerHeight)
        normalizeScale(sortInner)
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

    return filterHeight
end

return FilterBar
