-- Client/ForgingUI/Backend/PreviewInventory/Sorting.lua
-- Sorting logic for preview inventory items.

local Sorting = {}

---@param itemHelpers table
---@param sortModes table
---@param getDefaultSortMode function|nil
function Sorting.Create(itemHelpers, sortModes, getDefaultSortMode)
    local helpers = itemHelpers or {}
    local modes = sortModes or {}

    local GetItemSortHandle = helpers.GetItemSortHandle
    local GetItemAcquireValue = helpers.GetItemAcquireValue
    local GetItemRarityValue = helpers.GetItemRarityValue
    local GetItemTypeKey = helpers.GetItemTypeKey

    local function SortPreviewItems(items, mode)
        if not items then
            return items
        end
        local resolvedMode = mode
            or (getDefaultSortMode and getDefaultSortMode())
            or modes.Default
        if resolvedMode == modes.Default then
            return items
        end

        local sorted = {}
        local orderIndex = {}
        for i, item in ipairs(items) do
            sorted[i] = item
            local handle = GetItemSortHandle and GetItemSortHandle(item) or nil
            if handle then
                orderIndex[handle] = i
            end
        end

        local function GetOrderIndex(item, fallback)
            local handle = GetItemSortHandle and GetItemSortHandle(item) or nil
            return (handle and orderIndex[handle]) or fallback or 0
        end

        table.sort(sorted, function(a, b)
            local aFallback = GetOrderIndex(a, 0)
            local bFallback = GetOrderIndex(b, 0)
            if resolvedMode == modes.LastAcquired then
                local aKey = GetItemAcquireValue and GetItemAcquireValue(a, aFallback) or aFallback
                local bKey = GetItemAcquireValue and GetItemAcquireValue(b, bFallback) or bFallback
                if aKey ~= bKey then
                    return aKey > bKey
                end
            elseif resolvedMode == modes.Rarity then
                local aKey = GetItemRarityValue and GetItemRarityValue(a) or 0
                local bKey = GetItemRarityValue and GetItemRarityValue(b) or 0
                if aKey ~= bKey then
                    return aKey > bKey
                end
            elseif resolvedMode == modes.Type then
                local aKey = GetItemTypeKey and GetItemTypeKey(a) or ""
                local bKey = GetItemTypeKey and GetItemTypeKey(b) or ""
                if aKey ~= bKey then
                    return aKey < bKey
                end
            end
            return aFallback < bFallback
        end)

        return sorted
    end

    return {
        SortPreviewItems = SortPreviewItems,
    }
end

return Sorting
