-- Client/ForgingUI/UI/PreviewInventory/Renderer.lua
-- Render and slot creation helpers for the preview inventory panel.

local Renderer = {}

---@param options table
function Renderer.Create(options)
    local opts = options or {}
    local preview = opts.previewInventory or {}
    local getContext = opts.getContext
    local makeVector = opts.vector
    local normalizeSearchQuery = opts.normalizeSearchQuery
    local getItemSearchName = opts.getItemSearchName
    local resetPreviewLayout = opts.resetPreviewLayout
    local registerSearchBlur = opts.registerSearchBlur
    local updateScrollHandle = opts.updateScrollHandle
    local getScrollBar = opts.getScrollBar
    local getUI = opts.getUI

    local function EnsurePreviewSlot(index)
        local slot = preview.Slots[index]
        if slot then
            return slot
        end

        local ctx = getContext and getContext() or nil
        if not preview.Grid or not ctx or not ctx.hotbarSlotPrefab then
            return nil
        end

        slot = ctx.hotbarSlotPrefab.Create(getUI and getUI() or nil, "PreviewItemSlot_" .. tostring(index), preview.Grid)
        if slot.SlotElement and slot.SlotElement.SetSizeOverride then
            slot.SlotElement:SetSizeOverride(makeVector(preview.SlotSize, preview.SlotSize))
        end
        slot:SetCanDrag(true, false)
        slot:SetCanDrop(true)
        slot:SetEnabled(true)
        preview.Slots[index] = slot
        if slot.SlotElement and registerSearchBlur then
            registerSearchBlur(slot.SlotElement)
        end
        if ctx and ctx.PreviewLogic and ctx.PreviewLogic.WirePreviewSlot then
            ctx.PreviewLogic.WirePreviewSlot(index, slot)
        end
        return slot
    end

    local function RenderPreviewInventory()
        local ctx = getContext and getContext() or nil
        if not preview.Grid or not preview.ScrollList or not ctx or not ctx.Inventory then
            return
        end

        if ctx.PreviewLogic and ctx.PreviewLogic.SetPreviewFilter then
            ctx.PreviewLogic.SetPreviewFilter(preview.Filter)
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
                if preview.Filter == ctx.CRAFT_PREVIEW_MODES.Equipment then
                    ok = ctx.Inventory.IsEquipmentItem(item)
                elseif preview.Filter == ctx.CRAFT_PREVIEW_MODES.Magical then
                    ok = ctx.Inventory.IsMagicalItem(item)
                end
            end
            if ok then
                table.insert(filtered, item)
            end
        end

        local columns = preview.Columns or 1
        local filteredItems = {}
        for _, entry in ipairs(filtered) do
            local displayItem = ResolveEntryItem(entry)
            if displayItem then
                table.insert(filteredItems, displayItem)
            end
        end
        local searchQuery = normalizeSearchQuery and normalizeSearchQuery(preview.SearchQuery) or nil
        if searchQuery then
            local searchFiltered = {}
            for _, displayItem in ipairs(filteredItems) do
                local name = getItemSearchName and getItemSearchName(displayItem) or nil
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
        if searchQuery and resetPreviewLayout then
            resetPreviewLayout()
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
        if preview.Grid.SetGridSize and columns > 0 then
            preview.Grid:SetGridSize(columns, rows)
        end
        local listHeight = preview.ListHeight or 0
        local padding = preview.GridPadding or 0
        local gridContentHeight = rows * (preview.SlotSize or 0)
        if rows > 1 then
            gridContentHeight = gridContentHeight + (rows - 1) * (preview.GridSpacing or 0)
        end
        local gridMinHeight = math.max(0, listHeight - padding * 2)
        local gridHeight = math.max(gridMinHeight, gridContentHeight)
        preview.ScrollContentHeight = (preview.GridOffsetY or padding) + gridHeight
        local gridWidth = preview.GridContentWidth or 0
        if gridWidth > 0 then
            if preview.Grid.SetSize and not preview.Grid.SetGridSize then
                preview.Grid:SetSize(gridWidth, gridHeight)
            end
            if preview.Grid.SetSizeOverride then
                preview.Grid:SetSizeOverride(makeVector(gridWidth, gridHeight))
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

        for index = totalSlots + 1, #preview.Slots do
            local slot = preview.Slots[index]
            if slot then
                slot:Clear()
                slot:SetEnabled(true)
                slot.SlotElement:SetVisible(false)
            end
        end

        if preview.Grid.RepositionElements then
            preview.Grid:RepositionElements()
        end
        if preview.ScrollList.RepositionElements then
            preview.ScrollList:RepositionElements()
        end

        if preview.ScrollHandle and preview.ScrollHandle.Root then
            if updateScrollHandle then
                updateScrollHandle()
            end
        else
            local scrollBar = getScrollBar and getScrollBar() or nil
            if scrollBar then
                scrollBar.visible = true
            end
        end

        if ctx and ctx.PreviewLogic and ctx.PreviewLogic.RefreshInventoryHighlights then
            ctx.PreviewLogic.RefreshInventoryHighlights()
        end
    end

    return {
        EnsurePreviewSlot = EnsurePreviewSlot,
        RenderPreviewInventory = RenderPreviewInventory,
    }
end

return Renderer
