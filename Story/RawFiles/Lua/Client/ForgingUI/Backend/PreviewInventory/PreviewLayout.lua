-- Client/ForgingUI/Backend/PreviewInventory/PreviewLayout.lua
-- Preview inventory slot mapping + layout helpers.

local PreviewLayout = {}

---@param state table
---@param isValidHandle function|nil
function PreviewLayout.Create(state, isValidHandle)
    local function AssignPreviewSlot(index, item)
        if not item or not item.Handle then
            return
        end
        local previousIndex = state.PreviewItemToSlot[item.Handle]
        if previousIndex and previousIndex ~= index then
            state.PreviewSlotItems[previousIndex] = nil
        end

        local previousHandle = state.PreviewSlotItems[index]
        if previousHandle and previousHandle ~= item.Handle then
            state.PreviewItemToSlot[previousHandle] = nil
        end

        state.PreviewSlotItems[index] = item.Handle
        state.PreviewItemToSlot[item.Handle] = index
    end

    local function ClearPreviewSlot(index)
        local handle = state.PreviewSlotItems[index]
        if handle then
            state.PreviewItemToSlot[handle] = nil
        end
        state.PreviewSlotItems[index] = nil
    end

    local function BuildPreviewInventoryLayout(filteredItems, allItems, columns)
        columns = math.max(1, tonumber(columns) or 1)

        local allLookup = {}
        for _, item in ipairs(allItems or {}) do
            if item and item.Handle and (not isValidHandle or isValidHandle(item.Handle)) then
                allLookup[item.Handle] = item
            end
        end

        local filteredList = {}
        for _, item in ipairs(filteredItems or {}) do
            if item and item.Handle and allLookup[item.Handle] then
                table.insert(filteredList, item)
            end
        end

        local filteredLookup = {}
        for _, item in ipairs(filteredList) do
            filteredLookup[item.Handle] = item
        end

        local cleanedSlotItems = {}
        local cleanedItemToSlot = {}
        local maxIndex = 0
        for slotIndex, handle in pairs(state.PreviewSlotItems or {}) do
            if filteredLookup[handle] and cleanedItemToSlot[handle] == nil then
                cleanedSlotItems[slotIndex] = handle
                cleanedItemToSlot[handle] = slotIndex
                if slotIndex > maxIndex then
                    maxIndex = slotIndex
                end
            end
        end
        state.PreviewSlotItems = cleanedSlotItems
        state.PreviewItemToSlot = cleanedItemToSlot

        local nextSlot = maxIndex + 1
        for _, item in ipairs(filteredList) do
            if item and item.Handle and not cleanedItemToSlot[item.Handle] then
                while state.PreviewSlotItems[nextSlot] ~= nil do
                    nextSlot = nextSlot + 1
                end
                state.PreviewSlotItems[nextSlot] = item.Handle
                state.PreviewItemToSlot[item.Handle] = nextSlot
                cleanedItemToSlot[item.Handle] = nextSlot
                if nextSlot > maxIndex then
                    maxIndex = nextSlot
                end
                nextSlot = nextSlot + 1
            end
        end

        local display = {}
        for slotIndex, handle in pairs(state.PreviewSlotItems) do
            local item = filteredLookup[handle]
            if item then
                display[slotIndex] = item
            end
        end

        local rows = 1
        if maxIndex > 0 then
            rows = math.ceil(maxIndex / columns) + 1
        end
        local totalSlots = rows * columns

        return display, totalSlots
    end

    return {
        AssignPreviewSlot = AssignPreviewSlot,
        ClearPreviewSlot = ClearPreviewSlot,
        BuildPreviewInventoryLayout = BuildPreviewInventoryLayout,
    }
end

return PreviewLayout
