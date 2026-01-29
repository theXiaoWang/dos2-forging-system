-- Client/ForgingUI/UI/PreviewInventory/ScrollbarLayout.lua
-- Scroll bar layout builder for the preview inventory panel.

local ScrollbarLayout = {}

---@param options table
function ScrollbarLayout.Build(options)
    local opts = options or {}
    local ctx = opts.ctx
    local previewInventory = opts.previewInventory
    local parent = opts.parent
    if not previewInventory or not parent then
        return
    end

    local listMetrics = opts.listMetrics or {}
    local width = opts.width or 0
    local useBuiltinScrollbar = opts.useBuiltinScrollbar == true
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
    local getUI = opts.getUI
    local registerSearchBlur = opts.registerSearchBlur
    local updatePreviewScrollFromMouse = opts.updatePreviewScrollFromMouse
    local ensurePreviewScrollTick = opts.ensurePreviewScrollTick

    local list = listMetrics.list or previewInventory.ScrollList
    if not list then
        return
    end

    local gridX = listMetrics.gridX or 0
    local gridContentWidth = listMetrics.gridContentWidth or 0
    local padding = listMetrics.padding or 0
    local listHeight = listMetrics.listHeight or previewInventory.ListHeight or 0
    local listOffsetY = listMetrics.listOffsetY or previewInventory.ListOffsetY or 0
    local previewTuning = ctx and ctx.PreviewInventoryTuning or nil

    if useBuiltinScrollbar then
        local scrollBarPaddingBase = (previewTuning and previewTuning.ScrollBarPaddingX) or 6
        local scrollBarPaddingMin = (previewTuning and previewTuning.ScrollBarPaddingMin) or 4
        local scrollBarPaddingMax = (previewTuning and previewTuning.ScrollBarPaddingMax) or 10
        local scrollBarPadding = clamp(scaleX(scrollBarPaddingBase), scrollBarPaddingMin, scrollBarPaddingMax)
        local desiredScrollbarX = gridX + gridContentWidth + scrollBarPadding
        local scrollbarSpacing = desiredScrollbarX - width
        list:SetScrollbarSpacing(scrollbarSpacing)
        list:SetFrame(width, listHeight)
        return
    end

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
        if previewInventory.ScrollHandleEventsRoot ~= scrollHandle.Root then
            previewInventory.ScrollHandleEventsRoot = scrollHandle.Root
            scrollHandle.Root.Events.MouseDown:Subscribe(function ()
                previewInventory.ScrollDragging = true
                local dragHeight = previewInventory.ScrollHandleHeight > 0 and previewInventory.ScrollHandleHeight or scrollHandleHeight
                previewInventory.ScrollDragOffset = math.floor(dragHeight / 2)
            end)
            scrollHandle.Root.Events.MouseUp:Subscribe(function ()
                previewInventory.ScrollDragging = false
            end)
        end
    end

    if previewInventory.Root and previewInventory.Root.Events then
        if previewInventory.ScrollRootEventsRoot ~= previewInventory.Root then
            previewInventory.ScrollRootEventsRoot = previewInventory.Root
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

return ScrollbarLayout
