-- Client/ForgingUI/Widgets.lua
-- Reusable UI widget helpers for the forging panel.

local ForgingUI = Client.ForgingUI or {}
Client.ForgingUI = ForgingUI

local Widgets = {}
ForgingUI.Widgets = Widgets

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
local previewScrollTickRegistered = false

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

local function ResolveDefaultSortMode()
    if ctx and ctx.PreviewLogic and ctx.PreviewLogic.PREVIEW_SORT_MODES then
        return ctx.PreviewLogic.PREVIEW_SORT_MODES.Default
    end
    return "Default"
end

local function UnfocusPreviewSearch()
    local searchInput = previewInventory.SearchText
    if searchInput and searchInput.SetFocused then
        local isFocused = searchInput.IsFocused and searchInput:IsFocused()
        if isFocused then
            searchInput:SetFocused(false)
        end
    end
end

local function RegisterSearchBlur(element)
    if not element or not element.Events or not element.Events.MouseDown then
        return
    end
    if element._PreviewSearchBlurHooked then
        return
    end
    element._PreviewSearchBlurHooked = true
    element.Events.MouseDown:Subscribe(function ()
        UnfocusPreviewSearch()
    end)
end

local function GetPreviewScrollBar()
    local list = previewInventory.ScrollList
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
    local handle = previewInventory.ScrollHandle
    local track = previewInventory.ScrollTrack
    if not handle or not handle.Root or not track then
        return
    end

    local listHeight = previewInventory.ListHeight or 0
    local contentHeight = previewInventory.ScrollContentHeight or listHeight
    local trackHeight = previewInventory.ScrollTrackHeight or 0
    if listHeight <= 0 or trackHeight <= 0 or contentHeight <= listHeight then
        previewInventory.ScrollMaxOffset = 0
        if handle.Root.SetVisible then
            handle.Root:SetVisible(false)
        end
        if track.SetVisible then
            track:SetVisible(false)
        end
        return
    end

    local maxScroll = math.max(0, contentHeight - listHeight)
    previewInventory.ScrollMaxOffset = maxScroll

    local handleHeight = previewInventory.ScrollHandleHeight or 0
    if handle.Root and handle.Root.GetHeight then
        handleHeight = handle.Root:GetHeight()
    end
    if handleHeight <= 0 then
        handleHeight = previewInventory.ScrollHandleMinHeight or 0
    end
    previewInventory.ScrollHandleHeight = handleHeight

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
    local handleY = previewInventory.ScrollTrackY or 0
    if range > 0 and maxScroll > 0 then
        handleY = handleY + math.floor((scrolledY / maxScroll) * range + 0.5)
    end
    local offsetX = previewInventory.ScrollHandleOffsetX or 0
    local offsetY = previewInventory.ScrollHandleOffsetY or 0
    handle.Root:SetPosition((previewInventory.ScrollTrackX or 0) + offsetX, handleY + offsetY)
    if handle.Root.SetVisible then
        handle.Root:SetVisible(true)
    end
    if track.SetVisible then
        track:SetVisible(true)
    end
end

local function UpdatePreviewScrollFromMouse(mouseY)
    if not previewInventory.ScrollDragging then
        return
    end
    local handle = previewInventory.ScrollHandle
    if not handle or not handle.Root then
        return
    end
    local trackY = previewInventory.ScrollTrackY or 0
    local trackHeight = previewInventory.ScrollTrackHeight or 0
    local handleHeight = previewInventory.ScrollHandleHeight or 0
    local maxScroll = previewInventory.ScrollMaxOffset or 0
    if trackHeight <= handleHeight or maxScroll <= 0 then
        return
    end
    local minY = trackY
    local maxY = trackY + trackHeight - handleHeight
    local targetY = Clamp(mouseY - (previewInventory.ScrollDragOffset or 0), minY, maxY)
    local offsetX = previewInventory.ScrollHandleOffsetX or 0
    local offsetY = previewInventory.ScrollHandleOffsetY or 0
    handle.Root:SetPosition((previewInventory.ScrollTrackX or 0) + offsetX, targetY + offsetY)
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
        if previewInventory.ScrollDragging then
            return
        end
        local handle = previewInventory.ScrollHandle
        if not handle or not handle.Root then
            return
        end
        local root = previewInventory.Root
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

function Widgets.CreateFrame(parent, id, x, y, width, height, fillColor, alpha, padding, useSliced, centerAlphaOverride, innerAlphaOverride, frameStyleOverride, frameOffset, frameSizeOverride)
    if not parent then
        return nil, nil
    end
    local function ApplySize(element, w, h)
        if not element then
            return
        end
        local skipSetSize = element.SetGridSize ~= nil
        if element.SetSize and not skipSetSize then
            element:SetSize(w, h)
        end
        if element.SetSizeOverride then
            element:SetSizeOverride(w, h)
        end
    end
    local function NormalizeScale(element)
        if element and element.SetScale then
            element:SetScale(V(1, 1))
        end
    end

    local frame = parent:AddChild(id, "GenericUI_Element_Empty")
    frame:SetPosition(x, y)
    ApplySize(frame, width or 0, height or 0)
    NormalizeScale(frame)
    if frame.SetMouseEnabled then
        frame:SetMouseEnabled(true)
    end
    if frame.SetMouseChildren then
        frame:SetMouseChildren(true)
    end

    local frameTex = nil
    local hasSlicedTexture = false
    local frameStyle = frameStyleOverride or (ctx and ctx.panelFrameStyle)
    if useSliced and ctx and ctx.USE_SLICED_FRAMES and ctx.slicedTexturePrefab and frameStyle then
        local sliceSize = frameSizeOverride
        if not sliceSize then
            sliceSize = V(width, height)
        elseif type(sliceSize) == "table" and sliceSize.unpack then
            sliceSize = V(sliceSize:unpack())
        elseif type(sliceSize) == "table" then
            sliceSize = V(sliceSize[1] or width, sliceSize[2] or height)
        end
        frameTex = ctx.slicedTexturePrefab.Create(GetUI(), id .. "_Frame", frame, frameStyle, sliceSize)
        if frameTex then
            local offset = frameOffset
            if offset == nil then
                offset = V(0, 0)
            elseif type(offset) == "number" then
                offset = V(offset, offset)
            elseif type(offset) == "table" or type(offset) == "userdata" then
                if offset.unpack then
                    offset = V(offset:unpack())
                else
                    offset = V(offset[1] or 0, offset[2] or 0)
                end
            else
                offset = V(0, 0)
            end
            if frameTex.Root and frameTex.Root.SetPosition then
                frameTex.Root:SetPosition(offset[1], offset[2])
            end
            if frameTex.Root and frameTex.Root.SetScale then
                frameTex.Root:SetScale(V(1, 1))
            end
            -- Apply configured alpha to sliced frames for consistent transparency.
            local frameAlpha = (alpha ~= nil and alpha)
                or (ctx and ctx.FRAME_TEXTURE_ALPHA)
                or (ctx and ctx.FRAME_ALPHA)
                or 1
            local centerAlpha = (centerAlphaOverride ~= nil and centerAlphaOverride)
                or (ctx and ctx.FRAME_TEXTURE_CENTER_ALPHA)
                or 0
            if frameTex.SetAlpha then
                frameTex:SetAlpha(frameAlpha)
            end
            if frameTex.Root and frameTex.Root.SetAlpha then
                frameTex.Root:SetAlpha(frameAlpha)
            end
            -- Ensure all sliced texture children receive the same alpha.
            if frameTex.GetChildren then
                for _, child in ipairs(frameTex:GetChildren() or {}) do
                    if child then
                        local childAlpha = frameAlpha
                        local isCenter = child.ID and child.ID:match("Center$") ~= nil
                        if isCenter then
                            childAlpha = centerAlpha
                        end
                        if child.SetAlpha then
                            child:SetAlpha(childAlpha)
                        end
                        if isCenter and child.SetVisible then
                            child:SetVisible(childAlpha > 0)
                        end
                    end
                end
            end
        end
        hasSlicedTexture = true
    end

    local innerWidth = width
    local innerHeight = height
    local inner = frame:AddChild(id .. "_Inner", "GenericUI_Element_Empty")
    inner:SetPosition(0, 0)
    NormalizeScale(inner)
    if inner.SetMouseEnabled then
        inner:SetMouseEnabled(true)
    end
    if inner.SetMouseChildren then
        inner:SetMouseChildren(true)
    end

    -- Only create innerBG if not using sliced textures (sliced textures have their own transparency)
    -- Similar to how CreateSkinnedPanel handles textures
    local innerBG = nil
    if not useSliced then
        local innerAlpha = innerAlphaOverride
        if innerAlpha == nil then
            innerAlpha = ctx and ctx.PANEL_FILL_ALPHA
            if innerAlpha == nil then
                innerAlpha = alpha or (ctx and ctx.FRAME_ALPHA) or 1
            end
        end
        innerBG = inner:AddChild(id .. "_InnerBG", "GenericUI_Element_Color")
        innerBG:SetPosition(0, 0)
        ApplySize(innerBG, width or 0, height or 0)
        innerBG:SetColor(fillColor or (ctx and ctx.FILL_COLOR))
        innerBG:SetAlpha(innerAlpha)
        if innerBG.SetVisible then
            innerBG:SetVisible(innerAlpha > 0)
        end
        if innerBG.SetMouseEnabled then
            innerBG:SetMouseEnabled(false)
        end
        if innerBG.SetMouseChildren then
            innerBG:SetMouseChildren(false)
        end
        NormalizeScale(innerBG)
    end

    if padding and padding > 0 then
        innerWidth = width - padding * 2
        innerHeight = height - padding * 2
        inner:SetPosition(padding, padding)
        ApplySize(inner, innerWidth, innerHeight)
        NormalizeScale(inner)
        if innerBG then
            innerBG:SetPosition(0, 0)
            ApplySize(innerBG, innerWidth, innerHeight)
            NormalizeScale(innerBG)
        end
    else
        ApplySize(inner, width or 0, height or 0)
        NormalizeScale(inner)
    end

    return frame, inner, innerWidth, innerHeight, frameTex
end

function Widgets.CreateTextElement(parent, id, text, x, y, width, height, align, wrap, format)
    if not parent then
        return nil
    end

    local label = parent:AddChild(id, "GenericUI_Element_Text")
    label:SetPosition(x or 0, y or 0)
    label:SetSize(width or 0, height or 0)
    label:SetType(align or "Left")
    local formatted = text or ""
    if Text and Text.Format then
        local formatData = {}
        if format then
            for key, value in pairs(format) do
                formatData[key] = value
            end
        end
        if formatData.Color == nil then
            formatData.Color = ctx and ctx.TEXT_COLOR or 0xFFFFFF
        end
        if formatData.Size == nil then
            formatData.Size = formatData.size or (ctx and ctx.BODY_TEXT_SIZE) or 12
        end
        formatted = Text.Format(text or "", formatData)
    end
    label:SetText(formatted)
    if label.SetWrap then
        label:SetWrap(wrap or false)
    end
    if label.SetMouseEnabled then
        label:SetMouseEnabled(false)
    end
    return label
end

function Widgets.CreatePanel(parent, id, x, y, width, height, title)
    local frame, inner, innerWidth, innerHeight = Widgets.CreateFrame(parent, id, x, y, width, height, ctx and ctx.FILL_COLOR, ctx and ctx.FRAME_ALPHA, 0)
    if title and title ~= "" and inner then
        Widgets.CreateTextElement(inner, id .. "_Title", title, 0, 0, innerWidth, 22, "Center", false, {size = ctx and ctx.HEADER_TEXT_SIZE or 13})
    end
    return frame, inner, innerWidth, innerHeight
end

function Widgets.BuildButtonStyle(width, height, baseStyle)
    if not baseStyle then
        return {Size = V(width, height)}
    end
    local style = {}
    for k, v in pairs(baseStyle) do
        style[k] = v
    end
    style.Size = V(width, height)
    return style
end

function Widgets.CreateSkinnedPanel(parent, id, x, y, width, height, texture, padding, frameStyleOverride, frameOffset, frameSizeOverride)
    if not parent then
        return nil, nil, 0, 0
    end

    local hasTexture = texture ~= nil
    local validTexture = hasTexture and (type(texture) ~= "table" or texture.GUID)
    local fillAlpha = ctx and ctx.FRAME_ALPHA or 1
    if validTexture then
        fillAlpha = 0 -- Allow the texture to render without being covered by the inner fill.
    end
    local centerAlphaOverride = nil
    if validTexture then
        -- Avoid dark overlay from sliced frame center when a panel texture is present.
        centerAlphaOverride = 0
    end
    local frame, inner, innerWidth, innerHeight = Widgets.CreateFrame(
        parent,
        id,
        x,
        y,
        width,
        height,
        ctx and ctx.FILL_COLOR,
        fillAlpha,
        padding or 0,
        ctx and ctx.USE_SLICED_PANELS,
        centerAlphaOverride,
        nil,
        frameStyleOverride,
        frameOffset,
        frameSizeOverride
    )

    if validTexture then
        local panel = frame:AddChild(id .. "_Panel", "GenericUI_Element_Texture")
        panel:SetTexture(texture, V(width, height))
        panel:SetSize(width, height)
        panel:SetPosition(0, 0)
        local panelAlpha = (ctx and ctx.PANEL_TEXTURE_ALPHA)
        if panelAlpha == nil then
            panelAlpha = 1
        end
        if ctx and ctx.SLOT_PANEL_TEXTURE_ALPHA ~= nil and texture == ctx.slotPanelTexture then
            panelAlpha = ctx.SLOT_PANEL_TEXTURE_ALPHA
        end
        if panel.SetAlpha then
            panel:SetAlpha(panelAlpha)
        end
        if panel.SetVisible then
            panel:SetVisible(panelAlpha > 0)
        end
        if panel.SetScale then
            panel:SetScale(V(1, 1))
        end
        if frame.SetChildIndex then
            frame:SetChildIndex(panel, 0)
        end
    end

    return frame, inner, innerWidth, innerHeight
end

function Widgets.CreateButtonBox(parent, id, label, x, y, width, height, wrap, styleOverride)
    if not parent or not ctx or not ctx.buttonPrefab then
        return nil
    end

    local baseStyle = styleOverride or ctx.buttonStyle
    local style = Widgets.BuildButtonStyle(width, height, baseStyle)
    local button = ctx.buttonPrefab.Create(GetUI(), id .. "_Button", parent, style)
    button.Root:SetPosition(x, y)
    if label then
        button:SetLabel(label, "Center")
        if wrap then
            local labelElement = button.Label and button.Label.Element
            if labelElement and labelElement.SetWrap and labelElement.SetSize then
                labelElement:SetWrap(true)
                labelElement:SetSize(width - 6, height - 4)
            end
        end
    end
    local buttonRoot = button.Root or (button.GetRootElement and button:GetRootElement() or nil)
    RegisterSearchBlur(buttonRoot)
    return button
end

local function SetPreviewFilterButtonActive(button, active)
    if not button then
        return
    end
    if button._IsStateButton and button:_IsStateButton() and button.SetActivated then
        button:SetActivated(active)
    elseif button.Root and button.Root.SetAlpha then
        button.Root:SetAlpha(active and 1 or 0.5)
    end
end

local function UpdatePreviewFilterButtons()
    if not ctx or not ctx.CRAFT_PREVIEW_MODES then
        return
    end
    SetPreviewFilterButtonActive(previewInventory.FilterButtons[ctx.CRAFT_PREVIEW_MODES.Equipment], previewInventory.Filter == ctx.CRAFT_PREVIEW_MODES.Equipment)
    SetPreviewFilterButtonActive(previewInventory.FilterButtons[ctx.CRAFT_PREVIEW_MODES.Magical], previewInventory.Filter == ctx.CRAFT_PREVIEW_MODES.Magical)
end

local function NormalizeSearchQuery(value)
    if value == nil then
        return nil
    end
    local trimmed = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return nil
    end
    return string.lower(trimmed)
end

local function GetItemSearchName(item)
    if not item then
        return nil
    end
    if Item and Item.GetDisplayName then
        local ok, name = pcall(Item.GetDisplayName, item)
        if ok and name and name ~= "" then
            return name
        end
    end
    if item.DisplayName and item.DisplayName ~= "" then
        return item.DisplayName
    end
    local stats = item.Stats
    if type(stats) == "string" and Ext and Ext.Stats and Ext.Stats.Get then
        local ok, statsObj = pcall(Ext.Stats.Get, stats)
        if ok and statsObj then
            stats = statsObj
        end
    end
    if stats and stats.Name and stats.Name ~= "" then
        return stats.Name
    end
    return item.StatsId or item.StatsID
end

local function ResetPreviewLayout()
    if ctx and ctx.PreviewLogic and ctx.PreviewLogic.GetPreviewSortMode and ctx.PreviewLogic.SetPreviewSortMode then
        local currentMode = ctx.PreviewLogic.GetPreviewSortMode()
        ctx.PreviewLogic.SetPreviewSortMode(currentMode, true)
    end
end

local function EnsurePreviewSlot(index)
    local slot = previewInventory.Slots[index]
    if slot then
        return slot
    end

    if not previewInventory.Grid or not ctx or not ctx.hotbarSlotPrefab then
        return nil
    end

    slot = ctx.hotbarSlotPrefab.Create(GetUI(), "PreviewItemSlot_" .. tostring(index), previewInventory.Grid)
    if slot.SlotElement and slot.SlotElement.SetSizeOverride then
        slot.SlotElement:SetSizeOverride(V(previewInventory.SlotSize, previewInventory.SlotSize))
    end
    slot:SetCanDrag(true, false)
    slot:SetCanDrop(true)
    slot:SetEnabled(true)
    previewInventory.Slots[index] = slot
    if slot.SlotElement then
        RegisterSearchBlur(slot.SlotElement)
    end
    if ctx and ctx.PreviewLogic and ctx.PreviewLogic.WirePreviewSlot then
        ctx.PreviewLogic.WirePreviewSlot(index, slot)
    end
    return slot
end

local function RenderPreviewInventory()
    if not previewInventory.Grid or not previewInventory.ScrollList or not ctx or not ctx.Inventory then
        return
    end

    if ctx.PreviewLogic and ctx.PreviewLogic.SetPreviewFilter then
        ctx.PreviewLogic.SetPreviewFilter(previewInventory.Filter)
    end

    local function ResolveEntryItem(entry)
        if not entry then
            return nil
        end
        local displayItem = entry.Item or entry.Entity
        if not displayItem and entry.Guid and Item and Item.Get then
            local ok, result = pcall(Item.Get, entry.Guid)
            if ok then
                displayItem = result
            end
        end
        if not displayItem and entry.Entity and entry.Entity.Handle and Item and Item.Get then
            local ok, result = pcall(Item.Get, entry.Entity.Handle)
            if ok then
                displayItem = result
            end
        end
        return displayItem
    end

    local items = ctx.Inventory.GetInventoryItems()
    local filtered = {}
    for _, item in ipairs(items or {}) do
        local ok = true
        if ctx.CRAFT_PREVIEW_MODES then
            if previewInventory.Filter == ctx.CRAFT_PREVIEW_MODES.Equipment then
                ok = ctx.Inventory.IsEquipmentItem(item)
            elseif previewInventory.Filter == ctx.CRAFT_PREVIEW_MODES.Magical then
                ok = ctx.Inventory.IsMagicalItem(item)
            end
        end
        if ok then
            table.insert(filtered, item)
        end
    end

    local columns = previewInventory.Columns or 1
    local filteredItems = {}
    for _, entry in ipairs(filtered) do
        local displayItem = ResolveEntryItem(entry)
        if displayItem then
            table.insert(filteredItems, displayItem)
        end
    end
    local searchQuery = NormalizeSearchQuery(previewInventory.SearchQuery)
    if searchQuery then
        local searchFiltered = {}
        for _, displayItem in ipairs(filteredItems) do
            local name = GetItemSearchName(displayItem)
            if name then
                local normalizedName = string.lower(tostring(name))
                if normalizedName:find(searchQuery, 1, true) then
                    table.insert(searchFiltered, displayItem)
                end
            end
        end
        filteredItems = searchFiltered
    end
    local allItems = {}
    for _, entry in ipairs(items or {}) do
        local displayItem = ResolveEntryItem(entry)
        if displayItem then
            table.insert(allItems, displayItem)
        end
    end

    if ctx.PreviewLogic and ctx.PreviewLogic.TrackInventoryItems then
        ctx.PreviewLogic.TrackInventoryItems(allItems)
    end
    if ctx.PreviewLogic and ctx.PreviewLogic.SortPreviewItems then
        filteredItems = ctx.PreviewLogic.SortPreviewItems(filteredItems)
    end

    local displayItems = filteredItems
    local totalSlots = 0
    if searchQuery then
        ResetPreviewLayout()
    end
    if ctx.PreviewLogic and ctx.PreviewLogic.BuildPreviewInventoryLayout then
        displayItems, totalSlots = ctx.PreviewLogic.BuildPreviewInventoryLayout(filteredItems, allItems, columns)
    else
        local rows = math.max(1, math.ceil(#filteredItems / columns) + 1)
        totalSlots = rows * columns
    end
    if not totalSlots or totalSlots <= 0 then
        local rows = math.max(1, math.ceil(#filteredItems / columns) + 1)
        totalSlots = rows * columns
        displayItems = displayItems or filteredItems
    end

    local rows = math.max(1, math.ceil(totalSlots / columns))
    if previewInventory.Grid.SetGridSize and columns > 0 then
        previewInventory.Grid:SetGridSize(columns, rows)
    end
    local listHeight = previewInventory.ListHeight or 0
    local padding = previewInventory.GridPadding or 0
    local gridContentHeight = rows * (previewInventory.SlotSize or 0)
    if rows > 1 then
        gridContentHeight = gridContentHeight + (rows - 1) * (previewInventory.GridSpacing or 0)
    end
    local gridMinHeight = math.max(0, listHeight - padding * 2)
    local gridHeight = math.max(gridMinHeight, gridContentHeight)
    previewInventory.ScrollContentHeight = (previewInventory.GridOffsetY or padding) + gridHeight
    local gridWidth = previewInventory.GridContentWidth or 0
    if gridWidth > 0 then
        if previewInventory.Grid.SetSize and not previewInventory.Grid.SetGridSize then
            previewInventory.Grid:SetSize(gridWidth, gridHeight)
        end
        if previewInventory.Grid.SetSizeOverride then
            previewInventory.Grid:SetSizeOverride(V(gridWidth, gridHeight))
        end
    end

    for index = 1, totalSlots do
        local slot = EnsurePreviewSlot(index)
        if slot then
            local displayItem = displayItems and displayItems[index] or nil
            if displayItem then
                slot:SetItem(displayItem)
                slot:SetEnabled(true)
            else
                slot:Clear()
                slot:SetEnabled(true)
            end
            slot.SlotElement:SetVisible(true)
        end
    end

    for index = totalSlots + 1, #previewInventory.Slots do
        local slot = previewInventory.Slots[index]
        if slot then
            slot:Clear()
            slot:SetEnabled(true)
            slot.SlotElement:SetVisible(false)
        end
    end

    if previewInventory.Grid.RepositionElements then
        previewInventory.Grid:RepositionElements()
    end
    if previewInventory.ScrollList.RepositionElements then
        previewInventory.ScrollList:RepositionElements()
    end

    if previewInventory.ScrollHandle and previewInventory.ScrollHandle.Root then
        UpdatePreviewScrollHandle()
    else
        local scrollBar = GetPreviewScrollBar()
        if scrollBar then
            scrollBar.visible = true
        end
    end

    if ctx and ctx.PreviewLogic and ctx.PreviewLogic.RefreshInventoryHighlights then
        ctx.PreviewLogic.RefreshInventoryHighlights()
    end
end

Widgets.RenderPreviewInventory = RenderPreviewInventory

function Widgets.SetPreviewInventoryMode(mode)
    previewInventory.Filter = mode
    UpdatePreviewFilterButtons()
    RenderPreviewInventory()
end

local function WirePreviewFilterButton(button, mode)
    if not button or not button.Events or not button.Events.Pressed then
        return
    end
    button.Events.Pressed:Subscribe(function ()
        Widgets.SetPreviewInventoryMode(mode)
    end)
end

local function ApplyPreviewSortMode(mode)
    if ctx and ctx.PreviewLogic and ctx.PreviewLogic.SetPreviewSortMode then
        ctx.PreviewLogic.SetPreviewSortMode(mode, true)
    end
    if Widgets.RenderPreviewInventory then
        Widgets.RenderPreviewInventory()
    end
end

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
    ApplyPreviewSortMode(ResolveDefaultSortMode())
end

local function SetSortByPanelOpen(open)
    previewInventory.SortByOpen = open == true
    if previewInventory.SortByPanel and previewInventory.SortByPanel.SetVisible then
        previewInventory.SortByPanel:SetVisible(previewInventory.SortByOpen)
        if previewInventory.Root and previewInventory.Root.SetChildIndex then
            previewInventory.Root:SetChildIndex(previewInventory.SortByPanel, 9999)
        end
    end
    if previewInventory.SortByButton and previewInventory.SortByStyles then
        local style = previewInventory.SortByOpen and previewInventory.SortByStyles.Open or previewInventory.SortByStyles.Closed
        previewInventory.SortByButton:SetStyle(style)
    end
end

local function CreateSortOption(list, id, label, sortMode, width, height)
    if not list or not ctx or not ctx.buttonPrefab then
        return nil
    end
    local style = ctx.buttonPrefab.STYLES
        and (ctx.buttonPrefab.STYLES.LabelPointy or ctx.buttonPrefab.STYLES.MenuSlate or ctx.buttonStyle)
        or ctx.buttonStyle
    local button = ctx.buttonPrefab.Create(GetUI(), id .. "_Button", list, Widgets.BuildButtonStyle(width, height, style))
    button.Root:SetPosition(0, 0)
    if button.Root.SetAlpha then
        button.Root:SetAlpha(0.7)
    end

    local labelText = label
    if Text and Text.Format then
        local labelSize = math.max(10, math.floor(height * 0.4))
        labelText = Text.Format(label or "", {Color = "FFFFFF", Size = labelSize})
    end
    button:SetLabel(labelText, "Center")

    if button.Events and button.Events.Pressed then
        button.Events.Pressed:Subscribe(function ()
            ApplyPreviewSortMode(sortMode)
            SetSortByPanelOpen(false)
        end)
    end

    return button
end

function Widgets.CreatePreviewInventoryPanel(parent, width, height, offsetX, offsetY)
    if not parent or not ctx then
        return
    end

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
            element:SetScale(V(1, 1))
        end
    end

    previewInventory.Slots = {}
    previewInventory.FilterButtons = {}
    previewInventory.SearchRoot = nil
    previewInventory.SearchFrame = nil
    previewInventory.SearchText = nil
    previewInventory.SearchHint = nil
    previewInventory.SearchQuery = previewInventory.SearchQuery or ""
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
    previewInventory.Root:SetPosition(offsetX or 0, offsetY or 0)
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

    local filterButtonSize = Clamp(ScaleY(26), 22, 28)
    local buttonWidth = filterButtonSize
    local buttonHeight = filterButtonSize
    local buttonGap = ScaleX(4)
    local rowPaddingY = Clamp(ScaleY(3), 2, 6)
    local rowGap = Clamp(ScaleY(4), 2, 8)
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

    local sortButtonWidth = Clamp(ScaleX(88), 70, 110)
    local sortButtonHeight = Clamp(ScaleY(22), 20, buttonHeight)
    local sortButtonGap = ScaleX(4)
    local rowPadX = ScaleX(6)
    local sortPad = rowPadX
    local rowBGPadX = Clamp(ScaleX(9), 8, 13)
    local rowBGPadY = Clamp(ScaleY(4), 2, 8)
    local rowBGHeight = bottomRowHeight + rowBGPadY * 2
    local rowBGTopY = bottomRowY - rowBGPadY
    local rowBGContentOffsetY = -Clamp(ScaleY(1), 2, 3)
    local sortClusterWidth = sortButtonWidth * 2 + sortButtonGap
    local sortStartX = width - rowPadX - sortClusterWidth
    if sortStartX < 0 then
        sortStartX = 0
    end
    local sortY = rowBGTopY + math.floor((rowBGHeight - sortButtonHeight) / 2) + rowBGContentOffsetY

    local searchGap = ScaleX(8)
    local searchX = rowPadX
    local maxSearchWidth = sortStartX - searchX - searchGap
    if maxSearchWidth < 0 then
        maxSearchWidth = 0
    end
    local minSearchWidth = Clamp(ScaleX(90), 70, 120)
    local desiredSearchWidth = Clamp(ScaleX(160), minSearchWidth, 240)
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
        rowBG:SetTexture(rowTexture, V(rowBGWidth, rowBGHeight))
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
        local searchRoot = filterBar:AddChild("PreviewInventory_Search", "GenericUI_Element_Empty")
        searchRoot:SetPosition(searchX, searchY)
        ApplySize(searchRoot, searchWidth, searchHeight)
        NormalizeScale(searchRoot)

        local searchTexture = nil
        if ctx and ctx.Client and ctx.Client.Textures and ctx.Client.Textures.GenericUI then
            local textures = ctx.Client.Textures.GenericUI.TEXTURES
            if textures and textures.FRAMES and textures.FRAMES.ENTRIES then
                searchTexture = textures.FRAMES.ENTRIES.GRAY
            end
        end

        local searchFrame = searchRoot:AddChild("PreviewInventory_Search_Frame", "GenericUI_Element_Texture")
        if searchTexture then
            searchFrame:SetTexture(searchTexture, V(searchWidth, searchHeight))
        end
        searchFrame:SetPosition(0, 0)
        searchFrame:SetSize(searchWidth, searchHeight)
        NormalizeScale(searchFrame)

        local textPadding = Clamp(ScaleX(6), 4, 10)
        local iconPadding = Clamp(ScaleX(6), 4, 10)
        local iconSize = Clamp(math.floor(searchHeight * 0.6), 10, 16)
        local iconBlockWidth = iconSize + iconPadding
        local textWidth = math.max(0, searchWidth - textPadding * 2 - iconBlockWidth)
        local inputTextSize = Clamp(math.floor(searchHeight * 0.6), 11, 14)
        local hintTextSize = Clamp(inputTextSize + 2, 12, 15)
        local inputTextLiftY = Clamp(ScaleY(7), 6, 8)
        local hintTextLiftY = Clamp(ScaleY(5), 4, 6)
        local inputTextOffsetY = math.floor((searchHeight - inputTextSize) / 2) - inputTextLiftY
        local hintTextOffsetY = math.floor((searchHeight - hintTextSize) / 2) - hintTextLiftY
        local textHeight = searchHeight

        local inputBGPadX = Clamp(ScaleX(1), 1, 3)
        local inputBGPadY = Clamp(ScaleY(2), 1, 4)
        local inputBGX = textPadding - inputBGPadX
        local inputBGY = inputBGPadY
        local inputBGWidth = math.max(0, textWidth + inputBGPadX * 2)
        local inputBGHeight = math.max(0, searchHeight - inputBGPadY * 2)
        local searchInputBG = searchRoot:AddChild("PreviewInventory_Search_InputBG", "GenericUI_Element_Color")
        searchInputBG:SetPosition(inputBGX, inputBGY)
        searchInputBG:SetSize(inputBGWidth, inputBGHeight)
        local inputBGColor = (ctx and ctx.PREVIEW_FILL_COLOR) or (Color and Color.CreateFromHex and Color.CreateFromHex("000000")) or (ctx and ctx.FILL_COLOR)
        if inputBGColor and searchInputBG.SetColor then
            searchInputBG:SetColor(inputBGColor)
        end
        if searchInputBG.SetAlpha then
            searchInputBG:SetAlpha(0.85)
        end
        if searchInputBG.SetMouseEnabled then
            searchInputBG:SetMouseEnabled(false)
        end
        if searchInputBG.SetMouseChildren then
            searchInputBG:SetMouseChildren(false)
        end

        local searchInput = searchRoot:AddChild("PreviewInventory_Search_Input", "GenericUI_Element_Text")
        searchInput:SetPosition(textPadding, 0)
        searchInput:SetSize(textWidth, textHeight)
        searchInput:SetType("Left")
        searchInput:SetText(previewInventory.SearchQuery or "")
        searchInput:SetEditable(true)
        if searchInput.SetMouseEnabled then
            searchInput:SetMouseEnabled(true)
        end
        if searchInput.SetMouseChildren then
            searchInput:SetMouseChildren(true)
        end
        if searchInput.SetWordWrap then
            searchInput:SetWordWrap(false)
        end
        if searchInput.SetTextFormat then
            searchInput:SetTextFormat({color = 0xFFFFFF, size = inputTextSize})
        end

        local searchHint = searchRoot:AddChild("PreviewInventory_Search_Hint", "GenericUI_Element_Text")
        searchHint:SetPosition(textPadding, 0)
        searchHint:SetSize(textWidth, textHeight)
        searchHint:SetType("Left")
        searchHint:SetText("Search...")
        if searchHint.SetTextFormat then
            searchHint:SetTextFormat({color = 0xB0B0B0, size = hintTextSize})
        end
        if searchHint.SetMouseEnabled then
            searchHint:SetMouseEnabled(false)
        end

        local function CenterSearchText(element, offsetY)
            local mc = element and element.GetMovieClip and element:GetMovieClip() or nil
            if mc and mc.text_txt then
                mc.text_txt.y = offsetY
            end
        end

        CenterSearchText(searchInput, inputTextOffsetY)
        CenterSearchText(searchHint, hintTextOffsetY)

        local iconId = "magnifier-searchbar-2"
        local iconOffsetX = searchWidth - iconBlockWidth + math.floor((iconBlockWidth - iconSize) / 2)
        local iconOffsetY = math.floor((searchHeight - iconSize) / 2)
        if iconId then
            local searchIcon = searchRoot:AddChild("PreviewInventory_Search_Icon", "GenericUI_Element_IggyIcon")
            searchIcon:SetPosition(iconOffsetX, iconOffsetY)
            searchIcon:SetIcon(iconId, iconSize, iconSize)
            if searchIcon.SetAlpha then
                searchIcon:SetAlpha(0.9)
            end
            if searchIcon.SetMouseEnabled then
                searchIcon:SetMouseEnabled(false)
            end
        end

        local function UpdateSearchHint(rawText)
            local hasText = NormalizeSearchQuery(rawText) ~= nil
            local isFocused = searchInput.IsFocused and searchInput:IsFocused()
            if searchHint.SetVisible then
                searchHint:SetVisible((not hasText) and not isFocused)
            end
        end

        UpdateSearchHint(previewInventory.SearchQuery or "")

        if searchInput.Events and searchInput.Events.Changed then
            searchInput.Events.Changed:Subscribe(function (ev)
                local previousActive = NormalizeSearchQuery(previewInventory.SearchQuery) ~= nil
                previewInventory.SearchQuery = ev and ev.Text or ""
                local nextActive = NormalizeSearchQuery(previewInventory.SearchQuery) ~= nil
                UpdateSearchHint(previewInventory.SearchQuery)
                if previousActive and not nextActive then
                    ApplyPreviewSortMode(ResolveDefaultSortMode())
                else
                    RenderPreviewInventory()
                end
            end)
        end
        if searchInput.Events and searchInput.Events.Focused then
            searchInput.Events.Focused:Subscribe(function ()
                if searchHint.SetVisible then
                    searchHint:SetVisible(false)
                end
            end)
        end
        if searchInput.Events and searchInput.Events.Unfocused then
            searchInput.Events.Unfocused:Subscribe(function ()
                UpdateSearchHint(previewInventory.SearchQuery)
            end)
        end

        previewInventory.SearchRoot = searchRoot
        previewInventory.SearchFrame = searchFrame
        previewInventory.SearchText = searchInput
        previewInventory.SearchHint = searchHint
    end

    local equipmentBtn = Widgets.CreateButtonBox(filterBar, "PreviewFilter_Equipment", "", startX, topRowButtonY, buttonWidth, buttonHeight, false, ctx.styleSquareStone)
    local magicalBtn = Widgets.CreateButtonBox(filterBar, "PreviewFilter_Magical", "", startX + buttonWidth + buttonGap, topRowButtonY, buttonWidth, buttonHeight, false, ctx.styleSquareStone)

    local smallBrown = ctx.buttonPrefab and ctx.buttonPrefab.STYLES and (ctx.buttonPrefab.STYLES.SmallBrown or ctx.buttonPrefab.STYLES.MenuSlate or ctx.buttonStyle) or ctx.buttonStyle
    local smallRed = ctx.buttonPrefab and ctx.buttonPrefab.STYLES and (ctx.buttonPrefab.STYLES.SmallRed or ctx.buttonPrefab.STYLES.MediumRed or smallBrown) or smallBrown
    local autoSortBtn = Widgets.CreateButtonBox(filterBar, "PreviewInventory_AutoSort", "AUTOSORT", sortStartX, sortY, sortButtonWidth, sortButtonHeight, false, smallBrown)
    local sortByBtn = Widgets.CreateButtonBox(filterBar, "PreviewInventory_SortBy", "SORT BY", sortStartX + sortButtonWidth + sortButtonGap, sortY, sortButtonWidth, sortButtonHeight, false, smallBrown)

    local buttonTextSize = Clamp(math.floor(sortButtonHeight * 0.45), 8, 10)
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
    previewInventory.SortByStyles = {
        Closed = Widgets.BuildButtonStyle(sortButtonWidth, sortButtonHeight, smallBrown),
        Open = Widgets.BuildButtonStyle(sortButtonWidth, sortButtonHeight, smallRed),
    }

    if equipmentBtn and equipmentBtn.SetIcon then
        local iconSize = math.floor(filterButtonSize * 0.65)
        equipmentBtn:SetIcon("PIP_UI_Icon_Tab_Equipment_Trade", V(iconSize, iconSize))
    end
    if magicalBtn and magicalBtn.SetIcon then
        local iconSize = math.floor(filterButtonSize * 0.65)
        magicalBtn:SetIcon("PIP_UI_Icon_Tab_Magical", V(iconSize, iconSize))
    end

    previewInventory.FilterButtons[ctx.CRAFT_PREVIEW_MODES.Equipment] = equipmentBtn
    previewInventory.FilterButtons[ctx.CRAFT_PREVIEW_MODES.Magical] = magicalBtn
    WirePreviewFilterButton(equipmentBtn, ctx.CRAFT_PREVIEW_MODES.Equipment)
    WirePreviewFilterButton(magicalBtn, ctx.CRAFT_PREVIEW_MODES.Magical)

    local sortModes = ctx.PreviewLogic and ctx.PreviewLogic.PREVIEW_SORT_MODES or {Default = "Default", LastAcquired = "LastAcquired", Rarity = "Rarity", Type = "Type"}
    if autoSortBtn and autoSortBtn.Events and autoSortBtn.Events.Pressed then
        autoSortBtn.Events.Pressed:Subscribe(function ()
            ApplyPreviewSortMode(sortModes.Default)
            SetSortByPanelOpen(false)
        end)
    end
    if sortByBtn and sortByBtn.Events and sortByBtn.Events.Pressed then
        sortByBtn.Events.Pressed:Subscribe(function ()
            SetSortByPanelOpen(not previewInventory.SortByOpen)
        end)
    end

    local optionHeight = Clamp(ScaleY(34), 28, 38)
    local optionCount = 3
    local sortPanelPadding = Scale(10)
    local sortPanelWidth = Clamp(ScaleX(160), 150, width - sortPad * 2)
    local sortPanelHeight = optionHeight * optionCount + ScaleY(25)
    local sortPanelX = width - sortPanelWidth - sortPad
    local sortPanelY = filterHeight + ScaleY(4)
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
    local sortFrame, sortInner, sortInnerWidth, sortInnerHeight = Widgets.CreateFrame(
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
        local row = CreateSortOption(sortList, "PreviewInventory_SortOption_" .. tostring(i), option.Label, option.Key, sortInnerWidth, optionHeight)
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
    RegisterSearchBlur(list)

    local grid = list:AddChild("PreviewInventory_Grid", "GenericUI_Element_Grid")
    local padding = Scale(4)  -- Reduced padding to give more space for slots
    
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
    RegisterSearchBlur(grid)
    grid:SetGridSize(columns, 1)

    if useBuiltinScrollbar then
        local scrollBarPadding = Clamp(ScaleX(6), 4, 10)
        local desiredScrollbarX = gridX + gridContentWidth + scrollBarPadding
        local scrollbarSpacing = desiredScrollbarX - width
        list:SetScrollbarSpacing(scrollbarSpacing)
        list:SetFrame(width, listHeight)
    else
        local scrollStyle = ctx.buttonPrefab and ctx.buttonPrefab.STYLES and ctx.buttonPrefab.STYLES.ScrollBarHorizontal or ctx.buttonStyle
        local scrollHandle = ctx.buttonPrefab.Create(GetUI(), "PreviewInventory_ScrollHandle", previewInventory.Root, scrollStyle)
        scrollHandle:SetLabel("")
        if scrollHandle.Root and scrollHandle.Root.SetVisible then
            scrollHandle.Root:SetVisible(false)
        end
        RegisterSearchBlur(scrollHandle.Root)

        local scrollHandleWidth = 0
        local scrollHandleHeight = 0
        if scrollHandle.Root and scrollHandle.Root.GetWidth then
            scrollHandleWidth = scrollHandle.Root:GetWidth()
        end
        if scrollHandle.Root and scrollHandle.Root.GetHeight then
            scrollHandleHeight = scrollHandle.Root:GetHeight()
        end
        if scrollHandleWidth <= 0 then
            scrollHandleWidth = Clamp(ScaleX(12), 10, 16)
        end
        if scrollHandleHeight <= 0 then
            scrollHandleHeight = Clamp(ScaleY(20), 16, 28)
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

        local scrollTrackPadding = Clamp(ScaleX(4), 2, 6)
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
                    UpdatePreviewScrollFromMouse(mouseY)
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
        EnsurePreviewScrollTick()
    end

    if previewInventory.SortByPanel and previewInventory.Root and previewInventory.Root.SetChildIndex then
        previewInventory.Root:SetChildIndex(previewInventory.SortByPanel, 9999)
    end

    UpdatePreviewFilterButtons()
    RenderPreviewInventory()
end

function Widgets.CreateSectionBox(parent, id, x, y, width, height, title, bodyText, footerText)
    local frameAlpha = ctx and (ctx.SECTION_FRAME_ALPHA or ctx.FRAME_ALPHA) or nil
    local centerAlpha = ctx and ctx.SECTION_TEXTURE_CENTER_ALPHA or nil
    local fillAlpha = ctx and ctx.SECTION_FILL_ALPHA or nil
    local sectionStyle = ctx and ctx.sectionFrameStyle
    local frame, inner, innerWidth, innerHeight = Widgets.CreateFrame(
        parent,
        id,
        x,
        y,
        width,
        height,
        ctx and ctx.FILL_COLOR,
        frameAlpha,
        Scale(4),
        ctx and ctx.USE_SLICED_PANELS,
        centerAlpha,
        fillAlpha,
        sectionStyle
    )
    if inner then
        Widgets.CreateTextElement(inner, id .. "_Header", title or "", 0, 0, innerWidth, 16, "Left", false, {size = ctx.HEADER_TEXT_SIZE})
        Widgets.CreateTextElement(inner, id .. "_Body", bodyText or "", 0, 16, innerWidth, innerHeight - 32, "Left", true, {size = ctx.BODY_TEXT_SIZE})
        Widgets.CreateTextElement(inner, id .. "_Footer", footerText or "", 0, innerHeight - 16, innerWidth, 16, "Left", false, {size = ctx.BODY_TEXT_SIZE})
    end
    return inner or frame
end

function Widgets.CreateItemCard(parent, id, x, y, width, height, iconLabel, bodyText, levelText)
    local frame, inner, innerWidth, innerHeight = Widgets.CreateFrame(parent, id, x, y, width, height, ctx.FILL_COLOR, ctx.FRAME_ALPHA, Scale(6))
    if inner then
        Widgets.CreateTextElement(inner, id .. "_Icon", iconLabel or "", 0, 0, innerWidth, 20, "Left", false, {size = ctx.HEADER_TEXT_SIZE})
        Widgets.CreateTextElement(inner, id .. "_Body", bodyText or "", 0, 20, innerWidth, innerHeight - 40, "Left", true, {size = ctx.BODY_TEXT_SIZE})
        Widgets.CreateTextElement(inner, id .. "_Level", levelText or "", 0, innerHeight - 20, innerWidth, 20, "Right", false, {size = ctx.BODY_TEXT_SIZE})
    end
    return inner or frame
end

function Widgets.CreateSkillChip(parent, id, x, y, width, height, label, empty)
    local frame, inner, innerWidth, innerHeight = Widgets.CreateFrame(parent, id, x, y, width, height, ctx.FILL_COLOR, ctx.FRAME_ALPHA, Scale(2))
    if inner then
        local text = empty and "" or (label or "")
        Widgets.CreateTextElement(inner, id .. "_Label", text, 0, 0, innerWidth, innerHeight, "Center", false, {size = ctx.BODY_TEXT_SIZE})
    end
    return inner or frame
end

function Widgets.WireButton(button, id, requestDisplay)
    if not button or not ctx or not ctx.ForgingUI then
        return
    end
    ctx.ForgingUI.Buttons[id] = button
    local buttonRoot = button.Root or (button.GetRootElement and button:GetRootElement() or nil)
    RegisterSearchBlur(buttonRoot or button)
    if button.Events and button.Events.Pressed then
        button.Events.Pressed:Subscribe(function ()
            UnfocusPreviewSearch()
            if requestDisplay and ctx.RequestCraftDock then
                ctx.RequestCraftDock(id)
            elseif ctx.ForgingUI.OnForgeButtonClicked and id == "ForgeAction" then
                ctx.ForgingUI.OnForgeButtonClicked()
            end
        end)
    end
end

function Widgets.WireSlot(slot, id)
    if not slot or not ctx then
        return
    end
    if slot.SlotElement then
        RegisterSearchBlur(slot.SlotElement)
    end
    slot.Events.Clicked:Subscribe(function ()
        UnfocusPreviewSearch()
        if ctx.RequestCraftDock then
            ctx.RequestCraftDock(id)
        end
    end)
    slot.Events.ObjectDraggedIn:Subscribe(function ()
        UnfocusPreviewSearch()
        if ctx.RequestCraftDock then
            ctx.RequestCraftDock(id)
        end
    end)
end

function Widgets.CreateDropSlot(parent, id, x, y, size, useFancyFrame)
    if not parent or not ctx then
        return nil
    end

    -- Default to fancy frame for Main/Donor item slots
    if useFancyFrame == nil then
        useFancyFrame = id and (id:find("Main_ItemSlot") or id:find("Donor_ItemSlot"))
    end

    if ctx.hotbarSlotPrefab and ctx.hotbarSlotPrefab.Create then
        -- For fancy frame slots, create the frame background first
        -- Frame is larger than slot to contain the hover highlight
        local frameBackground = nil
        local framePadding = 12  -- Extra padding to contain highlight
        if useFancyFrame and ctx.mainSlotFrameTexture then
            local frameSize = size + framePadding * 2
            local frameX = x - framePadding
            local frameY = y - framePadding
            frameBackground = parent:AddChild(id .. "_FancyFrame", "GenericUI_Element_Texture")
            frameBackground:SetTexture(ctx.mainSlotFrameTexture, V(frameSize, frameSize))
            frameBackground:SetPosition(frameX, frameY)
            frameBackground:SetSize(frameSize, frameSize)
            if frameBackground.SetMouseEnabled then
                frameBackground:SetMouseEnabled(false)
            end
        end

        local slot = ctx.hotbarSlotPrefab.Create(GetUI(), id, parent)
        slot:SetPosition(x, y)
        slot:SetSize(size, size)
        slot:SetCanDrop(true)
        slot:SetEnabled(true)
        if slot.SlotElement then
            if slot.SlotElement.SetMouseEnabled then
                slot.SlotElement:SetMouseEnabled(true)
            end
            if slot.SlotElement.SetMouseChildren then
                slot.SlotElement:SetMouseChildren(true)
            end
        end

        -- Hide the original slot's frame elements and center the highlight for fancy frame slots
        if useFancyFrame and ctx.mainSlotFrameTexture then
            local slotElement = slot.SlotElement or slot
            if slotElement and slotElement.GetMovieClip then
                local mc = slotElement:GetMovieClip()
                if mc then
                    -- Hide internal frame elements
                    if mc.frame_mc then mc.frame_mc.visible = false end
                    if mc.source_frame_mc then mc.source_frame_mc.visible = false end
                    if mc.bg_mc then mc.bg_mc.visible = false end
                    -- Center and resize the highlight
                    if mc.highlight_mc then
                        -- Adjust x and y to center the highlight
                        mc.highlight_mc.x = (mc.highlight_mc.x or 0) -2
                        mc.highlight_mc.y = (mc.highlight_mc.y or 0) -2
                        -- Adjust width and height to resize the highlight
                        mc.highlight_mc.width = size + 1  -- Match frame size (size + framePadding*2)
                        mc.highlight_mc.height = size + 1
                    end
                end
            end
        end

        if ctx.ForgingUI and ctx.ForgingUI.Slots then
            ctx.ForgingUI.Slots[id] = slot
        end
        Widgets.WireSlot(slot, id)

        return slot
    end

    local cell = parent:AddChild(id .. "_Fallback", "GenericUI_Element_Texture")
    cell:SetTexture(ctx.gridCellTexture, V(size, size))
    cell:SetPosition(x, y)
    Widgets.WireButton(cell, id, true)
    return cell
end

function Widgets.CreateItemSlotRow(parent, id, x, y, width, height, slotID)
    local frame, inner, innerWidth, innerHeight = Widgets.CreateFrame(parent, id, x, y, width, height, ctx.FILL_COLOR, ctx.FRAME_ALPHA, Scale(4))
    if inner then
        local slotSize = math.min(innerHeight - 8, 56)
        local slotY = math.floor((innerHeight - slotSize) / 2)
        Widgets.CreateDropSlot(inner, slotID, 6, slotY, slotSize)
    end
    return frame, inner
end

function Widgets.CreateItemSlot(id, parent, x, y, width, height, title)
    if not ctx or not ctx.uiInstance or not parent then
        return nil
    end

    local slot, inner, innerWidth = Widgets.CreateFrame(parent, id, x, y, width, height, ctx.FILL_COLOR, ctx.FRAME_ALPHA)

    local titleBar = inner:AddChild(id .. "_TitleBar", "GenericUI_Element_Color")
    titleBar:SetSize(innerWidth, 42)
    titleBar:SetColor(ctx.HEADER_FILL_COLOR)
    titleBar:SetPosition(0, 0)

    Widgets.CreateTextElement(titleBar, id .. "_Title", title, 0, 0, innerWidth, 42, "Center")

    local hotbarSlot = nil
    if ctx.hotbarSlotPrefab and ctx.hotbarSlotPrefab.Create then
        hotbarSlot = ctx.hotbarSlotPrefab.Create(ctx.uiInstance, id .. "_Slot", inner)
        hotbarSlot:SetPosition(16, 45)
        hotbarSlot:SetSize(67, 67)
        hotbarSlot:SetCanDrop(true)
        hotbarSlot:SetEnabled(true)
        if ctx.ForgingUI and ctx.ForgingUI.Slots then
            ctx.ForgingUI.Slots[id] = hotbarSlot
        end
    else
        local icon = inner:AddChild(id .. "_Icon", "GenericUI_Element_Color")
        icon:SetSize(67, 67)
        icon:SetColor(ctx.HEADER_FILL_COLOR)
        icon:SetPosition(16, 45)
    end

    return hotbarSlot or slot
end

return Widgets
