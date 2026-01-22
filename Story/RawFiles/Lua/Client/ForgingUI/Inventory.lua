-- Client/ForgingUI/Inventory.lua
-- Inventory helpers for the Forge UI preview panel.

local ForgingUI = Client.ForgingUI
local Inventory = {}
Inventory.DEBUG = true

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
    if entity and entity.Stats then
        return entity.Stats.ItemType == "Armor"
            or entity.Stats.ItemType == "Weapon"
            or entity.Stats.ItemType == "Shield"
    end
    local eclItem = item.Item or item.Entity or item
    if Item and Item.IsEquipment then
        local ok, result = pcall(Item.IsEquipment, eclItem)
        if ok then
            return result == true
        end
    end
    return false
end

function Inventory.IsMagicalItem(item)
    if not item then
        return false
    end
    local entity = item.Entity or item
    if entity and entity.Stats and entity.Stats.ItemType == "SkillBook" then
        return true
    end
    local template = entity and entity.RootTemplate or nil
    local actions = template and template.OnUsePeaceActions or nil
    if actions then
        for _, action in ipairs(actions) do
            if action.Type == "SkillBook" then
                return true
            end
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
            if entity and Item and Item.IsContainer and Item.IsContainer(entity) and entity.GetInventoryItems then
                local contents = entity:GetInventoryItems()
                for _, childGuid in ipairs(contents or {}) do
                    AddGuid(childGuid)
                end
            end
        end
    end

    if Item and Item.ITEM_SLOTS and Item.GetEquippedItem then
        for slot in Item.ITEM_SLOTS:Iterator() do
            local ok, equipped = pcall(Item.GetEquippedItem, char, slot)
            if ok and equipped then
                AddEntity(equipped)
                equippedCount = equippedCount + 1
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
        DebugPrint(string.format("[ForgingUI] Inventory debug: party=%d raw=%d equipped=%d total=%d", partyItemsCount, rawItemsCount, equippedCount, #items))
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
