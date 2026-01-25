-- Client/ForgingUI/Backend/InventoryService.lua
-- Inventory scanning and item classification for the Forging UI (backend logic).

local ForgingUI = Client.ForgingUI or {}
Client.ForgingUI = ForgingUI

local Inventory = {}
Inventory.DEBUG = true

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

local function GetLocalCharacter()
    if Client and Client.GetCharacter then
        return Client.GetCharacter()
    end
    if Client and Client.GetCharacterByID and Client.GetLocalCharacterID then
        return Client.GetCharacterByID(Client.GetLocalCharacterID())
    end
    return nil
end

function Inventory.IsEquipmentItem(item)
    if not item then
        return false
    end
    local entity = item.Entity or item
    local stats = entity and entity.Stats or nil
    if stats and type(stats) == "string" and Ext and Ext.Stats and Ext.Stats.Get then
        local ok, statsObj = pcall(Ext.Stats.Get, stats)
        if ok and statsObj then
            stats = statsObj
        end
    end
    if (not stats or not stats.ModifierListIndex)
        and entity
        and (entity.StatsId or entity.StatsID)
        and Ext
        and Ext.Stats
        and Ext.Stats.Get then
        local ok, statsObj = pcall(Ext.Stats.Get, entity.StatsId or entity.StatsID)
        if ok and statsObj then
            stats = statsObj
        end
    end
    if stats and Stats and Stats.GetType then
        local ok, statsType = pcall(Stats.GetType, stats)
        if ok and statsType then
            local normalized = string.lower(tostring(statsType))
            if normalized == "armor" or normalized == "weapon" or normalized == "shield" or normalized == "equipment" then
                return true
            end
        end
    end
    local statsId = entity and (entity.StatsId or entity.StatsID) or SafeStatsField(stats, "Name")
    if IsEquipmentStatsId(statsId) then
        return true
    end
    local template = entity and entity.RootTemplate or nil
    local templateType = SafeTemplateField(template, "ItemType")
    if templateType then
        local normalized = string.lower(tostring(templateType))
        if normalized == "armor" or normalized == "weapon" or normalized == "shield" or normalized == "equipment" then
            return true
        end
    end
    local slot = SafeTemplateField(template, "ItemSlot")
        or SafeTemplateField(template, "Slot")
        or SafeTemplateField(template, "EquipmentSlot")
    if slot and slot ~= "" then
        return true
    end
    return false
end

function Inventory.IsMagicalItem(item)
    if not item then
        return false
    end
    local entity = item.Entity or item
    local template = entity and entity.RootTemplate or nil
    local actions = SafeTemplateField(template, "OnUsePeaceActions")
    if actions then
        for _, action in ipairs(actions) do
            if action.Type == "SkillBook" then
                return true
            end
        end
    end
    if not actions then
        actions = SafeTemplateField(template, "OnUseActions")
        if actions then
            for _, action in ipairs(actions) do
                if action.Type == "SkillBook" then
                    return true
                end
            end
        end
    end
    local stats = entity and entity.Stats or nil
    local statsName = stats and (stats.Name or stats.StatsId or stats.StatsID) or (entity.StatsId or entity.StatsID)
    if statsName then
        local key = string.lower(tostring(statsName))
        if key:find("skillbook", 1, true) then
            return true
        end
    end
    return false
end

function Inventory.IsItemEquipped(item)
    if not item then
        return false
    end
    local eclItem = item.Item or item.Entity or item
    if Item and Item.IsEquipped then
        local ok, result = pcall(Item.IsEquipped, eclItem)
        if ok then
            return result == true
        end
    end
    return false
end

function Inventory.GetInventoryItems()
    local char = GetLocalCharacter()
    if not char then
        return {}
    end

    local items = {}
    local partyItemsCount = 0
    local rawItemsCount = 0
    local equippedCount = 0
    local visited = {}

    local function ResolveGuid(entity, fallback)
        if not entity then
            return fallback
        end
        return entity.MyGuid or entity.Guid or entity.UUID or entity.NetID or entity.Handle or fallback
    end

    local function AddEntity(entity)
        if not entity then
            return
        end
        local guid = ResolveGuid(entity, entity.Handle)
        if not guid or visited[guid] then
            return
        end
        visited[guid] = true
        table.insert(items, {
            Guid = guid,
            Entity = entity,
            Item = entity,
        })
    end

    local function AddGuid(guid)
        if not guid then
            return
        end
        if visited[guid] then
            return
        end
        local entity = Ext.Entity.GetItem(guid)
        if not entity then
            return
        end
        AddEntity(entity)
    end

    if Item and Item.GetItemsInPartyInventory then
        local ok, partyItems = pcall(Item.GetItemsInPartyInventory, char, nil, true)
        if ok and partyItems then
            partyItemsCount = #partyItems
            for _, entity in ipairs(partyItems) do
                AddEntity(entity)
            end
        end
    end

    if #items == 0 and char.GetInventoryItems then
        local rawItems = char:GetInventoryItems()
        rawItemsCount = #rawItems
        for _, guid in ipairs(rawItems or {}) do
            AddGuid(guid)
            local entity = Ext.Entity.GetItem(guid)
            if entity then
                local equipped = false
                if Item and Item.IsEquipped then
                    local ok, isEquipped = pcall(Item.IsEquipped, entity)
                    if ok and isEquipped then
                        equipped = true
                    end
                end
                if equipped then
                    equippedCount = equippedCount + 1
                end
            end
        end
    end

    if Inventory.DEBUG then
        local function DebugPrint(msg)
            if Ext and Ext.Print then
                Ext.Print(msg)
            else
                print(msg)
            end
        end
        DebugPrint(string.format(
            "[ForgingUI] Inventory debug: party=%d raw=%d equipped=%d total=%d",
            partyItemsCount,
            rawItemsCount,
            equippedCount,
            #items
        ))
        Inventory.DEBUG = false
    end

    return items
end

function Inventory.DebugDump()
    local function DebugPrint(msg)
        if Ext and Ext.Print then
            Ext.Print(msg)
        else
            print(msg)
        end
    end

    local char = GetLocalCharacter()
    if not char then
        DebugPrint("[ForgingUI] Inventory debug: local character not available")
        return
    end

    local rawCount = 0
    if char.GetInventoryItems then
        rawCount = #char:GetInventoryItems()
    end

    local items = Inventory.GetInventoryItems()
    local equip = 0
    local magical = 0
    for _, item in ipairs(items) do
        if Inventory.IsEquipmentItem(item) then
            equip = equip + 1
        end
        if Inventory.IsMagicalItem(item) then
            magical = magical + 1
        end
    end

    DebugPrint(string.format(
        "[ForgingUI] Inventory debug: raw=%d total=%d equipment=%d magical=%d char=%s",
        rawCount,
        #items,
        equip,
        magical,
        tostring(char.MyGuid or char.Guid or char.NetID or char.Handle or "n/a")
    ))
end

ForgingUI.Inventory = Inventory
return Inventory

