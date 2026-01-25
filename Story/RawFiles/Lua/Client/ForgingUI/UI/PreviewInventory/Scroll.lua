-- Client/ForgingUI/UI/PreviewInventory/Scroll.lua
-- Scroll bar helpers for the preview inventory panel.

local Scroll = {}

---@param options table
function Scroll.Create(options)
    local opts = options or {}
    local preview = opts.previewInventory or {}
    local clampFn = opts.clamp

    local previewScrollTickRegistered = false

    local function Clamp(value, minValue, maxValue)
        if clampFn then
            return clampFn(value, minValue, maxValue)
        end
        if value < minValue then
            return minValue
        elseif value > maxValue then
            return maxValue
        end
        return value
    end

    local function GetPreviewScrollBar()
        local list = preview.ScrollList
        local mc = list and list.GetMovieClip and list:GetMovieClip() or nil
        if mc and mc.list and mc.list.m_scrollbar_mc then
            return mc.list.m_scrollbar_mc
        end
        if mc and mc.scrollBar_mc then
            return mc.scrollBar_mc
        end
        if mc and mc.list and mc.list.scrollBar_mc then
            return mc.list.scrollBar_mc
        end
        return nil
    end

    local function ApplyPreviewScrollOffset(offsetY)
        local scrollBar = GetPreviewScrollBar()
        if scrollBar and scrollBar.scrollTo then
            scrollBar.scrollTo(offsetY)
        end
    end

    local function UpdatePreviewScrollHandle()
        local handle = preview.ScrollHandle
        local track = preview.ScrollTrack
        if not handle or not handle.Root or not track then
            return
        end

        local listHeight = preview.ListHeight or 0
        local contentHeight = preview.ScrollContentHeight or listHeight
        local trackHeight = preview.ScrollTrackHeight or 0
        if listHeight <= 0 or trackHeight <= 0 or contentHeight <= listHeight then
            preview.ScrollMaxOffset = 0
            if handle.Root.SetVisible then
                handle.Root:SetVisible(false)
            end
            if track.SetVisible then
                track:SetVisible(false)
            end
            return
        end

        local maxScroll = math.max(0, contentHeight - listHeight)
        preview.ScrollMaxOffset = maxScroll

        local handleHeight = preview.ScrollHandleHeight or 0
        if handle.Root and handle.Root.GetHeight then
            handleHeight = handle.Root:GetHeight()
        end
        if handleHeight <= 0 then
            handleHeight = preview.ScrollHandleMinHeight or 0
        end
        preview.ScrollHandleHeight = handleHeight

        local scrollBar = GetPreviewScrollBar()
        local scrolledY = 0
        if scrollBar then
            scrolledY = scrollBar.scrolledY or scrollBar.m_scrolledY or 0
            if scrollBar.visible ~= nil then
                scrollBar.visible = false
            end
        end

        scrolledY = Clamp(scrolledY, 0, maxScroll)
        local range = trackHeight - handleHeight
        local handleY = preview.ScrollTrackY or 0
        if range > 0 and maxScroll > 0 then
            handleY = handleY + math.floor((scrolledY / maxScroll) * range + 0.5)
        end
        local offsetX = preview.ScrollHandleOffsetX or 0
        local offsetY = preview.ScrollHandleOffsetY or 0
        handle.Root:SetPosition((preview.ScrollTrackX or 0) + offsetX, handleY + offsetY)
        if handle.Root.SetVisible then
            handle.Root:SetVisible(true)
        end
        if track.SetVisible then
            track:SetVisible(true)
        end
    end

    local function UpdatePreviewScrollFromMouse(mouseY)
        if not preview.ScrollDragging then
            return
        end
        local handle = preview.ScrollHandle
        if not handle or not handle.Root then
            return
        end
        local trackY = preview.ScrollTrackY or 0
        local trackHeight = preview.ScrollTrackHeight or 0
        local handleHeight = preview.ScrollHandleHeight or 0
        local maxScroll = preview.ScrollMaxOffset or 0
        if trackHeight <= handleHeight or maxScroll <= 0 then
            return
        end
        local minY = trackY
        local maxY = trackY + trackHeight - handleHeight
        local targetY = Clamp(mouseY - (preview.ScrollDragOffset or 0), minY, maxY)
        local offsetX = preview.ScrollHandleOffsetX or 0
        local offsetY = preview.ScrollHandleOffsetY or 0
        handle.Root:SetPosition((preview.ScrollTrackX or 0) + offsetX, targetY + offsetY)
        local range = maxY - minY
        local ratio = range > 0 and (targetY - minY) / range or 0
        ApplyPreviewScrollOffset(ratio * maxScroll)
    end

    local function EnsurePreviewScrollTick()
        if previewScrollTickRegistered then
            return
        end
        previewScrollTickRegistered = true
        local function SyncHandle()
            if preview.ScrollDragging then
                return
            end
            local handle = preview.ScrollHandle
            if not handle or not handle.Root then
                return
            end
            local root = preview.Root
            if root and root.IsDestroyed and root:IsDestroyed() then
                return
            end
            local mc = root and root.GetMovieClip and root:GetMovieClip() or nil
            if mc and mc.visible then
                UpdatePreviewScrollHandle()
            end
        end
        if GameState and GameState.Events and GameState.Events.RunningTick then
            GameState.Events.RunningTick:Subscribe(SyncHandle, {StringID = "ForgingUI_PreviewScrollHandle"})
        elseif Ext and Ext.Events and Ext.Events.Tick then
            Ext.Events.Tick:Subscribe(SyncHandle, {StringID = "ForgingUI_PreviewScrollHandle"})
        end
    end

    return {
        GetPreviewScrollBar = GetPreviewScrollBar,
        ApplyPreviewScrollOffset = ApplyPreviewScrollOffset,
        UpdatePreviewScrollHandle = UpdatePreviewScrollHandle,
        UpdatePreviewScrollFromMouse = UpdatePreviewScrollFromMouse,
        EnsurePreviewScrollTick = EnsurePreviewScrollTick,
    }
end

return Scroll
