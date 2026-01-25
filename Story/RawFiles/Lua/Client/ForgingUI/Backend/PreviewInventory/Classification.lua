-- Client/ForgingUI/Backend/PreviewInventory/Classification.lua
-- Item/template classification helpers for drop rules.

local Classification = {}

---@param options table
function Classification.Create(options)
    local opts = options or {}
    local helpers = opts.itemHelpers or {}
    local getItemFromHandle = opts.getItemFromHandle
    local findItemByTemplateId = opts.findItemByTemplateId
    local isValidHandle = opts.isValidHandle

    local NormalizeItemType = helpers.NormalizeItemType
    local SafeTemplateField = helpers.SafeTemplateField
    local SafeTemplateActions = helpers.SafeTemplateActions
    local GetTemplateItemSlot = helpers.GetTemplateItemSlot
    local GetStatsItemType = helpers.GetStatsItemType
    local IsEquipmentItemType = helpers.IsEquipmentItemType
    local IsEquipmentSlotValue = helpers.IsEquipmentSlotValue
    local GetItemStats = helpers.GetItemStats
    local IsSkillbook = helpers.IsSkillbook
    local IsEquipment = helpers.IsEquipment

    local function GetTemplateStats(template)
        if not template then
            return nil
        end
        local statsId = SafeTemplateField(template, "StatsId")
            or SafeTemplateField(template, "StatsID")
            or SafeTemplateField(template, "Stats")
        if statsId and Ext and Ext.Stats and Ext.Stats.Get then
            local ok, stats = pcall(Ext.Stats.Get, statsId)
            if ok then
                return stats
            end
        end
        return nil
    end

    local function GetTemplateItemType(template, stats)
        local itemType = GetStatsItemType(stats)
        if not itemType and template then
            local templateItemType = SafeTemplateField(template, "ItemType")
            if templateItemType then
                itemType = NormalizeItemType(templateItemType)
            end
        end
        return itemType
    end

    local function IsTemplateSkillbook(template, stats, itemType)
        if itemType == "skillbook" then
            return true
        end
        local actions = SafeTemplateActions(template)
        if actions then
            for _, action in ipairs(actions) do
                if action.Type == "SkillBook" then
                    return true
                end
            end
        end
        return false
    end

    local function IsTemplateEquipment(template, stats, itemType)
        if IsEquipmentItemType(itemType) then
            return true
        end
        local slot = GetTemplateItemSlot(template)
        if IsEquipmentSlotValue(slot) then
            return true
        end
        return false
    end

    local function GetDropClassification(item, obj)
        if not item and obj and obj.ItemHandle and getItemFromHandle then
            if (not isValidHandle) or isValidHandle(obj.ItemHandle) then
                item = getItemFromHandle(obj.ItemHandle)
            end
        end
        if not item and obj and obj.TemplateID and findItemByTemplateId then
            item = findItemByTemplateId(obj.TemplateID)
        end
        local stats = GetItemStats(item)
        if not stats and obj then
            local statsId = obj.StatsID or obj.StatsId or obj.StatsName
            if statsId and Ext and Ext.Stats and Ext.Stats.Get then
                local ok, statsObj = pcall(Ext.Stats.Get, statsId)
                if ok and statsObj then
                    stats = statsObj
                end
            end
        end
        local itemType = GetStatsItemType(stats)
        local isSkillbook = nil
        local isEquipment = nil
        if item then
            isSkillbook = IsSkillbook(item)
            isEquipment = IsEquipment(item)
        end

        local template = nil
        local templateStats = nil
        local templateItemType = nil
        local templateIsSkillbook = nil
        local templateIsEquipment = nil
        if obj and obj.TemplateID and Ext and Ext.Template and Ext.Template.GetTemplate then
            template = Ext.Template.GetTemplate(obj.TemplateID)
            templateStats = GetTemplateStats(template)
            templateItemType = GetTemplateItemType(template, templateStats)
            templateIsSkillbook = IsTemplateSkillbook(template, templateStats, templateItemType)
            templateIsEquipment = IsTemplateEquipment(template, templateStats, templateItemType)
        end

        if not itemType and templateItemType then
            itemType = templateItemType
        end
        if templateIsSkillbook ~= nil then
            if templateIsSkillbook then
                isSkillbook = true
                isEquipment = false
            elseif isSkillbook == nil then
                isSkillbook = false
            end
        end
        if templateIsEquipment ~= nil and isSkillbook ~= true then
            if templateIsEquipment then
                isEquipment = true
            elseif isEquipment == nil then
                isEquipment = false
            end
        end

        if isSkillbook == nil then
            isSkillbook = false
        end
        if isEquipment == nil then
            isEquipment = false
        end
        return itemType, isEquipment, isSkillbook, template, templateItemType, templateIsEquipment, templateIsSkillbook
    end

    return {
        GetDropClassification = GetDropClassification,
    }
end

return Classification
