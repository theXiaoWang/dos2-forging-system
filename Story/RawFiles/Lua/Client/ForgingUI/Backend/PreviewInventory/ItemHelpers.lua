-- Client/ForgingUI/Backend/PreviewInventory/ItemHelpers.lua
-- Item and template helper functions used by PreviewInventory logic.

local ItemHelpers = {}

---@param state table
function ItemHelpers.Create(state)
    local helpers = {}

    local function NormalizeItemType(value)
        if not value then
            return nil
        end
        return string.lower(tostring(value))
    end

    local function IsEquipmentStatsId(statsId)
        if not statsId then
            return false
        end
        local key = string.upper(tostring(statsId))
        return key:find("^WPN_") ~= nil
            or key:find("^ARM_") ~= nil
            or key:find("^ARMOR_") ~= nil
            or key:find("^SHD_") ~= nil
            or key:find("^SHIELD_") ~= nil
            or key:find("^EQP_") ~= nil
            or key:find("^RING_") ~= nil
            or key:find("^AMULET_") ~= nil
            or key:find("^BELT_") ~= nil
    end

    local function NormalizeItemSlot(value)
        if not value then
            return nil
        end
        return string.lower(tostring(value))
    end

    local function SafeStatsField(stats, field)
        if not stats then
            return nil
        end
        local ok, value = pcall(function()
            return stats[field]
        end)
        if ok then
            return value
        end
        return nil
    end

    local function GetStatsItemType(stats)
        if not stats then
            return nil
        end
        if Stats and Stats.GetType then
            local ok, statsType = pcall(Stats.GetType, stats)
            if ok and statsType then
                local normalized = NormalizeItemType(statsType)
                if normalized == "weapon" or normalized == "armor" or normalized == "shield" or normalized == "equipment" then
                    return normalized
                end
                if normalized == "skilldata" or normalized == "skillbook" then
                    return "skillbook"
                end
            end
        end
        local statsId = SafeStatsField(stats, "Name") or SafeStatsField(stats, "StatsId") or SafeStatsField(stats, "StatsID")
        if IsEquipmentStatsId(statsId) then
            return "equipment"
        end
        return nil
    end

    local function SafeTemplateField(template, field)
        if not template then
            return nil
        end
        local ok, value = pcall(function()
            return template[field]
        end)
        if ok then
            return value
        end
        return nil
    end

    local function SafeTemplateActions(template)
        local actions = SafeTemplateField(template, "OnUsePeaceActions")
        if not actions then
            actions = SafeTemplateField(template, "OnUseActions")
        end
        return actions
    end

    local function GetTemplateItemSlot(template)
        if not template then
            return nil
        end
        return SafeTemplateField(template, "ItemSlot")
            or SafeTemplateField(template, "Slot")
            or SafeTemplateField(template, "EquipmentSlot")
    end

    local function EnsureEquipmentSlotNames()
        if state and state.EquipmentSlotNames then
            return
        end
        local names = {}
        if Item and Item.ITEM_SLOTS and Item.ITEM_SLOTS.Iterator then
            for slotName in Item.ITEM_SLOTS:Iterator() do
                local key = NormalizeItemSlot(slotName)
                if key then
                    names[key] = true
                end
            end
        end
        if not next(names) then
            local fallback = {"helmet", "breast", "leggings", "boots", "gloves", "amulet", "ring", "ring2", "weapon", "weapon2", "offhand", "shield", "belt"}
            for _, slotName in ipairs(fallback) do
                names[slotName] = true
            end
        end
        if state then
            state.EquipmentSlotNames = names
        end
    end

    local function IsEquipmentSlotValue(slot)
        local key = NormalizeItemSlot(slot)
        if not key then
            return false
        end
        EnsureEquipmentSlotNames()
        return state and state.EquipmentSlotNames and state.EquipmentSlotNames[key] == true
    end

    local function GetItemStats(item)
        if not item then
            return nil
        end
        local okStats, stats = pcall(function()
            return item.Stats
        end)
        if okStats and stats then
            if type(stats) == "string" and Ext and Ext.Stats and Ext.Stats.Get then
                local ok, statsObj = pcall(Ext.Stats.Get, stats)
                if ok and statsObj then
                    return statsObj
                end
            end
            return stats
        end
        local statsId = item.StatsId or item.StatsID
        if statsId and Ext and Ext.Stats and Ext.Stats.Get then
            local ok, statsObj = pcall(Ext.Stats.Get, statsId)
            if ok then
                return statsObj
            end
        end
        return nil
    end

    local function IsSkillbook(item)
        if not item then
            return false
        end
        local stats = GetItemStats(item)
        if Stats and Stats.GetType then
            local ok, statsType = pcall(Stats.GetType, stats)
            if ok and statsType then
                local normalized = NormalizeItemType(statsType)
                if normalized == "weapon" or normalized == "armor" or normalized == "shield" or normalized == "equipment" then
                    return false
                end
            end
        end
        local template = item.RootTemplate
        local templateSlot = GetTemplateItemSlot(template)
        if IsEquipmentSlotValue(templateSlot) then
            return false
        end
        local actions = SafeTemplateActions(template)
        if actions then
            for _, action in ipairs(actions) do
                if action.Type == "SkillBook" then
                    return true
                end
            end
        end
        local itemType = GetStatsItemType(stats)
        if itemType == "skillbook" then
            return true
        end
        local statsName = SafeStatsField(stats, "Name") or item.StatsId or item.StatsID
        if statsName then
            local key = string.lower(tostring(statsName))
            if key:find("skillbook", 1, true) then
                return true
            end
        end
        return false
    end

    local function GetItemSortHandle(item)
        return item and (item.Handle or item.ItemHandle) or nil
    end

    local function GetItemRarityValue(item)
        local stats = GetItemStats(item)
        local statsId = item and (item.StatsId or item.StatsID) or nil
        if statsId then
            local key = string.upper(tostring(statsId))
            if key:find("^SKILLBOOK_") ~= nil then
                return 0
            end
        end

        local rarity = nil
        if not rarity and stats then
            local statsType = nil
            if Stats and Stats.GetType then
                local ok, statsTypeValue = pcall(Stats.GetType, stats)
                if ok and statsTypeValue then
                    statsType = NormalizeItemType(statsTypeValue)
                end
            end
            if statsType == "skilldata" or statsType == "skillbook" or statsType == "object" then
                return 0
            end
            if GetStatsItemType(stats) == "skillbook" then
                return 0
            end
        end
        if rarity == nil and item then
            local ok, value = pcall(function()
                return item.Rarity
            end)
            if ok then
                rarity = value
            end
        end
        if rarity == nil and stats then
            rarity = SafeStatsField(stats, "Rarity")
        end
        if not rarity then
            return 0
        end
        local map = {
            Common = 1,
            Uncommon = 2,
            Rare = 3,
            Epic = 4,
            Legendary = 5,
            Divine = 6,
            Unique = 7,
        }
        return map[rarity] or 0
    end

    local function GetItemTypeKey(item)
        local stats = GetItemStats(item)
        local itemType = item and item.ItemType or SafeStatsField(stats, "ItemType")
        if not itemType then
            local template = item and item.RootTemplate or nil
            itemType = SafeTemplateField(template, "ItemType")
        end
        if not itemType and Stats and Stats.GetType then
            local ok, statsType = pcall(Stats.GetType, stats)
            if ok and statsType then
                itemType = statsType
            end
        end
        if not itemType then
            return ""
        end
        return string.lower(tostring(itemType))
    end

    local function GetItemAcquireValue(item, fallback)
        local handle = GetItemSortHandle(item)
        if handle and state and state.ItemAcquireOrder[handle] then
            return state.ItemAcquireOrder[handle]
        end
        return fallback or 0
    end

    local function IsEquipmentItemType(itemType)
        return itemType == "armor"
            or itemType == "weapon"
            or itemType == "shield"
            or itemType == "equipment"
            or itemType == "ring"
            or itemType == "amulet"
            or itemType == "belt"
    end

    local function IsSkillbookItemType(itemType)
        return itemType == "skillbook"
    end

    local function IsEquipment(item)
        if not item then
            return false
        end
        if IsSkillbook(item) then
            return false
        end
        local stats = GetItemStats(item)
        if Stats and Stats.GetType then
            local ok, statsType = pcall(Stats.GetType, stats)
            if ok and statsType then
                local normalized = NormalizeItemType(statsType)
                if normalized and IsEquipmentItemType(normalized) then
                    return true
                end
            end
        end
        local itemType = GetStatsItemType(stats)
        if itemType and IsEquipmentItemType(itemType) then
            return true
        end
        local templateSlot = GetTemplateItemSlot(item.RootTemplate)
        if IsEquipmentSlotValue(templateSlot) then
            return true
        end
        return false
    end

    helpers.NormalizeItemType = NormalizeItemType
    helpers.IsEquipmentStatsId = IsEquipmentStatsId
    helpers.NormalizeItemSlot = NormalizeItemSlot
    helpers.SafeStatsField = SafeStatsField
    helpers.GetStatsItemType = GetStatsItemType
    helpers.SafeTemplateField = SafeTemplateField
    helpers.SafeTemplateActions = SafeTemplateActions
    helpers.GetTemplateItemSlot = GetTemplateItemSlot
    helpers.EnsureEquipmentSlotNames = EnsureEquipmentSlotNames
    helpers.IsEquipmentSlotValue = IsEquipmentSlotValue
    helpers.GetItemStats = GetItemStats
    helpers.IsSkillbook = IsSkillbook
    helpers.GetItemSortHandle = GetItemSortHandle
    helpers.GetItemRarityValue = GetItemRarityValue
    helpers.GetItemTypeKey = GetItemTypeKey
    helpers.GetItemAcquireValue = GetItemAcquireValue
    helpers.IsEquipmentItemType = IsEquipmentItemType
    helpers.IsSkillbookItemType = IsSkillbookItemType
    helpers.IsEquipment = IsEquipment

    return helpers
end

return ItemHelpers
