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
    Grid = nil,
    ScrollList = nil,
    Columns = 0,
    GridSpacing = 0,
    SlotSize = 66,  -- Increased to fully show item frames
    EmptyLabel = nil,
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

function Widgets.SetContext(nextCtx)
    ctx = nextCtx
end

function Widgets.GetPreviewInventory()
    return previewInventory
end

function Widgets.CreateFrame(parent, id, x, y, width, height, fillColor, alpha, padding, useSliced, centerAlphaOverride, innerAlphaOverride, frameStyleOverride, frameOffset, frameSizeOverride)
    if not parent then
        return nil, nil
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
    local allItems = {}
    for _, entry in ipairs(items or {}) do
        local displayItem = ResolveEntryItem(entry)
        if displayItem then
            table.insert(allItems, displayItem)
        end
    end

    local displayItems = filteredItems
    local totalSlots = 0
    if ctx.PreviewLogic and ctx.PreviewLogic.BuildPreviewInventoryLayout then
        displayItems, totalSlots = ctx.PreviewLogic.BuildPreviewInventoryLayout(filteredItems, allItems, columns)
    else
        local rows = math.max(1, math.ceil(#filteredItems / columns) + 1)
        totalSlots = rows * columns
    end

    local rows = math.max(1, math.ceil(totalSlots / columns))
    if previewInventory.Grid.SetGridSize and columns > 0 then
        previewInventory.Grid:SetGridSize(columns, rows)
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

    local mc = previewInventory.ScrollList.GetMovieClip and previewInventory.ScrollList:GetMovieClip() or nil
    if mc and mc.scrollBar_mc then
        mc.scrollBar_mc.visible = true
    end

    if previewInventory.EmptyLabel then
        local hasItems = false
        for _, entry in pairs(displayItems or {}) do
            if entry then
                hasItems = true
                break
            end
        end
        previewInventory.EmptyLabel:SetVisible(not hasItems)
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
    previewInventory.Grid = nil
    previewInventory.ScrollList = nil
    previewInventory.EmptyLabel = nil
    if not previewInventory.Filter and ctx.CRAFT_PREVIEW_MODES then
        previewInventory.Filter = ctx.CRAFT_PREVIEW_MODES.Equipment
    end

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
    local filterHeight = filterButtonSize + 8
    local filterBar = previewInventory.Root:AddChild("PreviewInventory_FilterBar", "GenericUI_Element_Empty")
    filterBar:SetPosition(0, 0)
    ApplySize(filterBar, width, filterHeight)
    NormalizeScale(filterBar)

    local buttonWidth = filterButtonSize
    local buttonHeight = filterButtonSize
    local buttonGap = ScaleX(4)
    local startX = math.floor((width - (buttonWidth * 2 + buttonGap)) / 2)
    local startY = math.floor((filterHeight - buttonHeight) / 2)

    local equipmentBtn = Widgets.CreateButtonBox(filterBar, "PreviewFilter_Equipment", "", startX, startY, buttonWidth, buttonHeight, false, ctx.styleSquareStone)
    local magicalBtn = Widgets.CreateButtonBox(filterBar, "PreviewFilter_Magical", "", startX + buttonWidth + buttonGap, startY, buttonWidth, buttonHeight, false, ctx.styleSquareStone)

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

    local list = previewInventory.Root:AddChild("PreviewInventory_List", "GenericUI_Element_ScrollList")
    list:SetPosition(0, filterHeight)
    ApplySize(list, width, height - filterHeight)
    NormalizeScale(list)
    list:SetMouseWheelEnabled(true)
    list:SetScrollbarSpacing(4)
    previewInventory.ScrollList = list

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
    ApplySize(grid, gridContentWidth, height - filterHeight - padding * 2)
    NormalizeScale(grid)
    grid:SetElementSpacing(previewInventory.GridSpacing, previewInventory.GridSpacing)
    previewInventory.Grid = grid
    grid:SetGridSize(columns, 1)

    previewInventory.EmptyLabel = Widgets.CreateTextElement(previewInventory.Root, "PreviewInventory_EmptyLabel", "No items found", 0, filterHeight + 6, width, 18, "Center", false, {size = 13})
    previewInventory.EmptyLabel:SetVisible(false)

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
    if button.Events and button.Events.Pressed then
        button.Events.Pressed:Subscribe(function ()
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
    slot.Events.Clicked:Subscribe(function ()
        if ctx.RequestCraftDock then
            ctx.RequestCraftDock(id)
        end
    end)
    slot.Events.ObjectDraggedIn:Subscribe(function ()
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
