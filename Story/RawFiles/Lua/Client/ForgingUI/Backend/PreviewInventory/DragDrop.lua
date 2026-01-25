-- Client/ForgingUI/Backend/PreviewInventory/DragDrop.lua
-- Drag/drop state + item resolution helpers.

local DragDrop = {}

---@param options table
function DragDrop.Create(options)
    local opts = options or {}
    local state = opts.state
    local getContext = opts.getContext
    local safeTemplateActions = opts.safeTemplateActions

    local function IsValidHandle(handle)
        return Ext and Ext.Utils and Ext.Utils.IsValidHandle and Ext.Utils.IsValidHandle(handle)
    end

    local function IsItemObject(obj)
        if not obj then
            return false
        end
        if Entity and Entity.IsItem then
            local ok, result = pcall(Entity.IsItem, obj)
            if ok then
                return result == true
            end
        end
        if GetExtType then
            local ok, extType = pcall(GetExtType, obj)
            if ok and extType then
                return extType == "ecl::Item" or extType == "esv::Item"
            end
        end
        return false
    end

    local function GetItemFromHandle(handle)
        if not handle or not Item or not Item.Get then
            return nil
        end
        local ok, item = pcall(Item.Get, handle)
        if ok and item then
            return item
        end
        if Ext and Ext.Entity and Ext.Entity.GetItem then
            local okEntity, entity = pcall(Ext.Entity.GetItem, handle)
            if okEntity and entity then
                return entity
            end
        end
        return nil
    end

    local function ResolveItemFromDragObject(dragObject)
        if not dragObject then
            return nil, "no-dragobject"
        end
        if IsValidHandle(dragObject) then
            local item = GetItemFromHandle(dragObject)
            if item then
                return item, "valid-handle"
            end
        end
        if Item and Item.Get then
            local ok, item = pcall(Item.Get, dragObject)
            if ok and item then
                return item, "item.get"
            end
        end
        if Ext and Ext.Entity and Ext.Entity.GetItem then
            local ok, entity = pcall(Ext.Entity.GetItem, dragObject)
            if ok and entity then
                local handle = entity.Handle or entity.ItemHandle
                if handle then
                    local item = GetItemFromHandle(handle)
                    if item then
                        return item, "entity.getitem"
                    end
                end
            end
        end
        return nil, "unresolved"
    end

    local function ResolveSlotItemHandle(slot)
        if not slot or not slot.Object then
            return nil
        end
        local obj = slot.Object
        if obj.Type == "Item" and obj.ItemHandle and IsValidHandle(obj.ItemHandle) then
            return obj.ItemHandle
        end
        if obj.ItemHandle and IsValidHandle(obj.ItemHandle) then
            return obj.ItemHandle
        end
        if obj.GetEntity then
            local entity = obj:GetEntity()
            if entity and entity.Handle and IsValidHandle(entity.Handle) then
                return entity.Handle
            end
        end
        return nil
    end

    local function GetDragDropState()
        if not Ext or not Ext.UI or not Ext.UI.GetDragDrop then
            return nil
        end
        local dragDrop = Ext.UI.GetDragDrop()
        return dragDrop and dragDrop.PlayerDragDrops and dragDrop.PlayerDragDrops[1] or nil
    end

    local function HasDragData()
        local data = GetDragDropState()
        if data and (data.DragId ~= "" or IsValidHandle(data.DragObject)) then
            return true
        end
        return state and state.PreviewDragItemHandle ~= nil
    end

    local function IsDraggingAnything()
        local data = GetDragDropState()
        if not data then
            return false
        end
        if data.IsDragging ~= nil then
            return data.IsDragging == true
        end
        return (data.DragId ~= "" or IsValidHandle(data.DragObject))
    end

    local function FindItemByTemplateId(templateId)
        if not templateId or not Item or not Item.GetItemsInPartyInventory or not Client or not Client.GetCharacter then
            return nil
        end
        local ok, items = pcall(Item.GetItemsInPartyInventory, Client.GetCharacter(), function (i)
            return i and i.RootTemplate and i.RootTemplate.Id == templateId
        end, true)
        if ok and items and items[1] then
            return items[1]
        end
        return nil
    end

    local function ResolveEntryItem(entry)
        if not entry then
            return nil
        end
        if IsItemObject(entry) then
            return entry
        end
        if type(entry) == "table" then
            local item = entry.Item or entry.Entity
            if IsItemObject(item) then
                return item
            end
            local handle = entry.ItemHandle or entry.Handle
            if handle and IsValidHandle(handle) then
                return GetItemFromHandle(handle)
            end
        end
        return nil
    end

    local function FindSkillbookBySkillId(skillId)
        local ctx = getContext and getContext() or nil
        if not skillId or not ctx or not ctx.Inventory or not ctx.Inventory.GetInventoryItems then
            return nil
        end
        for _, entry in ipairs(ctx.Inventory.GetInventoryItems() or {}) do
            local item = ResolveEntryItem(entry)
            if item and Item and Item.IsSkillbook and Item.IsSkillbook(item) then
                local stats = item.Stats
                local statsSkill = stats and (stats.Skill or stats.SkillID or stats.SkillId or stats.SkillName or stats.LearnSkill or stats.LearnedSkill)
                if statsSkill == skillId then
                    return item
                end
                local actions = safeTemplateActions and safeTemplateActions(item.RootTemplate) or nil
                for _, action in ipairs(actions or {}) do
                    local actionSkill = action.SkillID or action.SkillId or action.Skill or action.SkillName or action.LearnSkill
                    if actionSkill == skillId then
                        return item
                    end
                end
            end
        end
        return nil
    end

    local function GetDraggedItem()
        local data = GetDragDropState()
        if not data then
            return nil
        end
        if data.DragObject then
            local item, _ = ResolveItemFromDragObject(data.DragObject)
            if item then
                return item
            end
        end
        if data.DragId ~= "" then
            local dragId = data.DragId
            if Ext and Ext.Template and Ext.Template.GetTemplate then
                local template = Ext.Template.GetTemplate(dragId)
                if template then
                    local item = FindItemByTemplateId(dragId)
                    if item then
                        return item
                    end
                end
            end
            local ctx = getContext and getContext() or nil
            if ctx and ctx.Inventory and ctx.Inventory.GetInventoryItems then
                for _, entry in ipairs(ctx.Inventory.GetInventoryItems() or {}) do
                    local entity = ResolveEntryItem(entry)
                    if entity and entity.Stats then
                        local statsName = entity.Stats.Name or nil
                        local statsId = entity.StatsId or entity.StatsID or nil
                        if dragId == statsName or dragId == statsId then
                            return entity
                        end
                    end
                end
            end
            if Stats and Stats.Get and Stats.Get("SkillData", dragId) then
                local skillbook = FindSkillbookBySkillId(dragId)
                if skillbook then
                    return skillbook
                end
            end
        end
        return nil
    end

    local function HasDraggedItem()
        return IsDraggingAnything()
    end

    local function GetItemFromSlotObject(obj)
        if not obj then
            return nil
        end
        if obj.GetEntity then
            local ok, entity = pcall(obj.GetEntity, obj)
            if ok and entity and IsItemObject(entity) then
                return entity
            end
        end
        if obj.ItemHandle then
            local item = GetItemFromHandle(obj.ItemHandle)
            if item then
                return item
            end
            local fallback, _ = ResolveItemFromDragObject(obj.ItemHandle)
            if fallback then
                return fallback
            end
        end
        if obj.TemplateID then
            local item = FindItemByTemplateId(obj.TemplateID)
            if item then
                return item
            end
        end
        if obj.StatsID and Stats and Stats.Get and Stats.Get("SkillData", obj.StatsID) then
            local skillbook = FindSkillbookBySkillId(obj.StatsID)
            if skillbook then
                return skillbook
            end
        end
        return nil
    end

    local function GetDraggedItemFromEvent(ev)
        if not ev or not ev.Object then
            return nil
        end
        return GetItemFromSlotObject(ev.Object)
    end

    local function ResolveDraggedItem(ev)
        local item = GetDraggedItemFromEvent(ev) or GetDraggedItem()
        if not item and state and state.PreviewDragItemHandle then
            item = GetItemFromHandle(state.PreviewDragItemHandle)
        end
        return item
    end

    return {
        IsValidHandle = IsValidHandle,
        IsItemObject = IsItemObject,
        GetItemFromHandle = GetItemFromHandle,
        ResolveItemFromDragObject = ResolveItemFromDragObject,
        ResolveSlotItemHandle = ResolveSlotItemHandle,
        GetDragDropState = GetDragDropState,
        HasDragData = HasDragData,
        IsDraggingAnything = IsDraggingAnything,
        FindItemByTemplateId = FindItemByTemplateId,
        ResolveEntryItem = ResolveEntryItem,
        FindSkillbookBySkillId = FindSkillbookBySkillId,
        GetDraggedItem = GetDraggedItem,
        HasDraggedItem = HasDraggedItem,
        GetItemFromSlotObject = GetItemFromSlotObject,
        GetDraggedItemFromEvent = GetDraggedItemFromEvent,
        ResolveDraggedItem = ResolveDraggedItem,
    }
end

return DragDrop
