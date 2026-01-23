-- Backend interaction logic for preview inventory + forge slots.

local ForgingUI = Client.ForgingUI or {}
Client.ForgingUI = ForgingUI

local PreviewLogic = {}
ForgingUI.PreviewInventoryLogic = PreviewLogic

local ctx = nil

local State = {
    ForgeSlots = {},
    SlotItems = {},
    ItemToSlot = {},
    PreviewInventory = nil,
    PreviewSlotItems = {},
    PreviewItemToSlot = {},
    PreviewSlots = {},
    PreviewSlotItemsByFilter = {},
    PreviewItemToSlotByFilter = {},
    CurrentPreviewFilter = nil,
    PreviewDragItemHandle = nil,
    PreviewDragSourceIndex = nil,
    LastWarningTime = nil,
    LastPreviewHoverSlot = nil,
    LastForgeHoverSlot = nil,
    EquipmentSlotNames = nil,
}

PreviewLogic.State = State

local DEFAULT_DROP_SOUND = "UI_Game_PartyFormation_PickUp"
local WARNING_CLEAR_TIMER_ID = "ForgingUI_DropWarningClear"
local WARNING_SLOT_TIMER_PREFIX = "ForgingUI_DropSlotWarning_"
local WARNING_DISPLAY_SECONDS = 1.6
local WARNING_THROTTLE_MS = 250
local WARNING_TEXT_COLOR = "FFD27F"
local WARNING_TEXT_SIZE = 14
local PREVIEW_TOOLTIP_THROTTLE_MS = 150

local function V(...)
    return ctx and ctx.V and ctx.V(...) or Vector.Create(...)
end

function PreviewLogic.SetContext(nextCtx)
    ctx = nextCtx
end

function PreviewLogic.SetPreviewFilter(filterKey)
    local key = tostring(filterKey or "default")
    if State.CurrentPreviewFilter == key then
        return
    end
    if State.CurrentPreviewFilter ~= nil then
        State.PreviewSlotItemsByFilter[State.CurrentPreviewFilter] = State.PreviewSlotItems
        State.PreviewItemToSlotByFilter[State.CurrentPreviewFilter] = State.PreviewItemToSlot
    end
    State.PreviewSlotItems = State.PreviewSlotItemsByFilter[key] or {}
    State.PreviewItemToSlot = State.PreviewItemToSlotByFilter[key] or {}
    State.CurrentPreviewFilter = key
    State.PreviewDragItemHandle = nil
    State.PreviewDragSourceIndex = nil
end

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
    return State.PreviewDragItemHandle ~= nil
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
            local actions = SafeTemplateActions(item.RootTemplate) or {}
            for _, action in ipairs(actions) do
                local actionSkill = action.SkillID or action.SkillId or action.Skill or action.SkillName or action.LearnSkill
                if actionSkill == skillId then
                    return item
                end
            end
        end
    end
    return nil
end

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
    local ok, value = pcall(function ()
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
    local ok, value = pcall(function ()
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
    if State.EquipmentSlotNames then
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
    State.EquipmentSlotNames = names
end

local function IsEquipmentSlotValue(slot)
    local key = NormalizeItemSlot(slot)
    if not key then
        return false
    end
    EnsureEquipmentSlotNames()
    return State.EquipmentSlotNames and State.EquipmentSlotNames[key] == true
end

local function GetItemStats(item)
    if not item then
        return nil
    end
    local okStats, stats = pcall(function ()
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
    if not item and obj and obj.ItemHandle and IsValidHandle(obj.ItemHandle) then
        item = GetItemFromHandle(obj.ItemHandle)
    end
    if not item and obj and obj.TemplateID then
        item = FindItemByTemplateId(obj.TemplateID)
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

local function ClearSlotMapping(slotId)
    local handle = State.SlotItems[slotId]
    if handle then
        State.ItemToSlot[handle] = nil
    end
    State.SlotItems[slotId] = nil
end

local function IsEquipmentSlotId(slotId)
    local key = tostring(slotId or ""):lower()
    if key == "" then
        return false
    end
    if key:find("skillbook", 1, true) ~= nil then
        return false
    end
    return key:find("itemslot", 1, true) ~= nil
end

local function IsSkillbookSlotId(slotId)
    local key = tostring(slotId or ""):lower()
    if key == "" then
        return false
    end
    return key:find("skillbook", 1, true) ~= nil
end

local function ResolveForgeSlotMode(slotId)
    if IsSkillbookSlotId(slotId) then
        return "Skillbook"
    end
    if IsEquipmentSlotId(slotId) then
        return "Equipment"
    end
    if State and State.ForgeSlots and slotId and State.ForgeSlots[slotId] then
        return "Equipment"
    end
    return nil
end

local function ShouldBlockDrop(slotId)
    local slotMode = ResolveForgeSlotMode(slotId)
    if not slotMode then
        return false
    end
    if not HasDragData() then
        return false
    end
    local item = GetDraggedItem()
    if item then
        return not PreviewLogic.CanAcceptItem(slotId, item)
    end
    local data = GetDragDropState()
    if data and data.DragId and data.DragId ~= "" and Stats then
        if (Stats.Get and Stats.Get("SkillData", data.DragId))
            or (Stats.GetAction and Stats.GetAction(data.DragId)) then
            return true
        end
    end
    return false
end

local function ResolveForgeSlotId(slotId, slot)
    if slotId and slot and State.ForgeSlots[slotId] == slot then
        return slotId
    end
    if slot then
        for id, forgeSlot in pairs(State.ForgeSlots) do
            if forgeSlot == slot then
                return id
            end
        end
        local rawId = slot.ID or (slot.SlotElement and slot.SlotElement.ID) or nil
        if rawId then
            if State.ForgeSlots[rawId] == slot then
                return rawId
            end
            return rawId
        end
    end
    return slotId
end

local function PlaySound(soundId)
    if not soundId then
        return
    end
    if ctx and ctx.uiInstance and ctx.uiInstance.PlaySound then
        ctx.uiInstance:PlaySound(soundId)
    elseif ctx and ctx.uiInstance and ctx.uiInstance.GetUI then
        local ui = ctx.uiInstance:GetUI()
        if ui and ui.ExternalInterfaceCall then
            ui:ExternalInterfaceCall("PlaySound", soundId)
        end
    end
end

local function GetMonotonicTime()
    if Ext and Ext.MonotonicTime then
        return Ext.MonotonicTime()
    end
    if Ext and Ext.Utils and Ext.Utils.MonotonicTime then
        return Ext.Utils.MonotonicTime()
    end
    return nil
end

local function GetPreviewSlotItem(slot)
    if not slot then
        return nil
    end
    local obj = slot.Object
    if obj then
        if IsItemObject(obj) then
            return obj
        end
        if obj.GetEntity then
            local entity = obj:GetEntity()
            if entity then
                return entity
            end
        end
    end
    local handle = ResolveSlotItemHandle(slot)
    if handle then
        return GetItemFromHandle(handle)
    end
    return nil
end

local function GetInventoryTooltipUI()
    if Ext and Ext.UI and Ext.UI.GetByType and Ext.UI.TypeID and Ext.UI.TypeID.containerInventory then
        local ui = Ext.UI.GetByType(Ext.UI.TypeID.containerInventory.Pickpocket)
        if not ui then
            ui = Ext.UI.GetByType(Ext.UI.TypeID.containerInventory.Default)
        end
        return ui
    end
    return nil
end

local function ShowItemTooltipWithFallback(item)
    if not item then
        return false
    end
    if Client and Client.Tooltip and Client.Tooltip.ShowItemTooltip then
        pcall(Client.Tooltip.ShowItemTooltip, item)
    end
    local ui = GetInventoryTooltipUI()
    if not ui or not ui.ExternalInterfaceCall then
        return false
    end
    local handle = item.Handle or item.ItemHandle
    if not handle or not Client or not Client.GetMousePosition or not Ext or not Ext.UI or not Ext.UI.HandleToDouble then
        return false
    end
    local mouseX, mouseY = Client.GetMousePosition()
    local ok = pcall(ui.ExternalInterfaceCall, ui, "showItemTooltip", Ext.UI.HandleToDouble(handle), mouseX, mouseY, 100, 100, -1, "left")
    return ok == true
end

local function HideItemTooltipWithFallback()
    local hidden = false
    if Client and Client.Tooltip and Client.Tooltip.HideTooltip then
        hidden = pcall(Client.Tooltip.HideTooltip) == true or hidden
    end
    local ui = GetInventoryTooltipUI()
    if ui and ui.ExternalInterfaceCall then
        pcall(ui.ExternalInterfaceCall, ui, "hideTooltip")
        hidden = true
    end
    return hidden
end

local function ShowPreviewSlotTooltip(slot)
    if not slot then
        return
    end
    local item = GetPreviewSlotItem(slot)
    if not item then
        return
    end
    local handle = item.Handle or item.ItemHandle
    if slot._PreviewTooltipVisible and slot._PreviewTooltipHandle == handle then
        return
    end
    local now = GetMonotonicTime()
    if now and slot._PreviewTooltipLastTime and (now - slot._PreviewTooltipLastTime) < PREVIEW_TOOLTIP_THROTTLE_MS then
        return
    end
    slot._PreviewTooltipLastTime = now or slot._PreviewTooltipLastTime
    local shown = ShowItemTooltipWithFallback(item)
    slot._PreviewTooltipHandle = shown and handle or slot._PreviewTooltipHandle
    slot._PreviewTooltipVisible = shown == true
end

local function HidePreviewSlotTooltip(slot)
    if not slot then
        return
    end
    HideItemTooltipWithFallback()
    slot._PreviewTooltipHandle = nil
    slot._PreviewTooltipVisible = false
end

local function ClearSlotHighlight(slot)
    local element = slot and (slot.SlotElement or slot)
    if slot and slot.SetHighlighted then
        slot:SetHighlighted(false)
    end
    if element and element.SetHighlighted then
        element:SetHighlighted(false)
    end
    local mc = element and element.GetMovieClip and element:GetMovieClip() or nil
    if mc and mc.highlight_mc then
        mc.highlight_mc.alpha = 0
        mc.highlight_mc.visible = false
    end
end

local function HandlePreviewSlotHover(slot)
    if State.LastPreviewHoverSlot and State.LastPreviewHoverSlot ~= slot then
        ClearSlotHighlight(State.LastPreviewHoverSlot)
    end
    State.LastPreviewHoverSlot = slot
    ShowPreviewSlotTooltip(slot)
end

local function HandleForgeSlotHover(slot)
    if State.LastForgeHoverSlot and State.LastForgeHoverSlot ~= slot then
        ClearSlotHighlight(State.LastForgeHoverSlot)
    end
    State.LastForgeHoverSlot = slot
end

local function ClearStaleHighlights()
    local preview = State.PreviewInventory
    if preview and preview.Slots then
        for _, slot in ipairs(preview.Slots) do
            if slot and slot ~= State.LastPreviewHoverSlot then
                ClearSlotHighlight(slot)
            end
        end
    end
    for _, slot in pairs(State.ForgeSlots or {}) do
        if slot and slot ~= State.LastForgeHoverSlot then
            ClearSlotHighlight(slot)
        end
    end
end

local function GetItemDisplayNameSafe(item)
    if not item then
        return nil
    end
    if Item and Item.GetDisplayName and IsItemObject(item) then
        local ok, name = pcall(Item.GetDisplayName, item)
        if ok and name and name ~= "" then
            return name
        end
    end
    if not IsItemObject(item) then
        return nil
    end
    local displayName = item.DisplayName
    if displayName and displayName ~= "" then
        return displayName
    end
    local stats = GetItemStats(item)
    local statsId = item.StatsId or (stats and SafeStatsField(stats, "Name")) or nil
    return statsId
end

local function FormatWarningText(message)
    if Text and Text.Format then
        local formatData = {Color = WARNING_TEXT_COLOR, Size = WARNING_TEXT_SIZE}
        if Text.FONTS and Text.FONTS.BOLD then
            formatData.FontType = Text.FONTS.BOLD
        end
        return Text.Format(message, formatData)
    end
    return message
end

local function SetWarningVisible(visible)
    local uiState = ctx and ctx.UIState or nil
    if not uiState then
        return
    end
    local label = uiState.WarningLabel
    if label and label.SetVisible then
        label:SetVisible(visible)
    end
    local bg = uiState.WarningBackground
    if bg and bg.SetVisible then
        bg:SetVisible(visible)
    end
end

local function UpdateWarningText(message)
    local uiState = ctx and ctx.UIState or nil
    if not uiState then
        return false
    end
    local label = uiState.WarningLabel
    if not label or not label.SetText then
        return false
    end
    label:SetText(FormatWarningText(message))
    return true
end

function PreviewLogic.ShowWarning(message)
    if not message or message == "" then
        return
    end
    if not ctx or not ctx.UIState or not ctx.UIState.IsVisible then
        return
    end
    local now = GetMonotonicTime()
    if now and State.LastWarningTime and (now - State.LastWarningTime) < WARNING_THROTTLE_MS then
        return
    end
    State.LastWarningTime = now or State.LastWarningTime or 0
    if not UpdateWarningText(message) then
        return
    end
    SetWarningVisible(true)
    if ctx and ctx.Timer and ctx.Timer.Start then
        ctx.Timer.Start(WARNING_CLEAR_TIMER_ID, WARNING_DISPLAY_SECONDS, function ()
            SetWarningVisible(false)
        end)
    end
end

local function BuildDropWarningMessage(slotId, item)
    local slotMode = ResolveForgeSlotMode(slotId)
    local itemName = GetItemDisplayNameSafe(item)
    if slotMode == "Skillbook" then
        if itemName and itemName ~= "" then
            return string.format("%s is not a skillbook", itemName)
        end
        return "Only skillbooks can be placed in this slot"
    end
    if slotMode == "Equipment" then
        if itemName and itemName ~= "" then
            return string.format("%s is not equipment", itemName)
        end
        return "Only equipment can be placed in this slot"
    end
    if itemName and itemName ~= "" then
        return string.format("%s cannot be placed here", itemName)
    end
    return "That item cannot be placed here"
end

function PreviewLogic.ShowDropWarning(slotId, item)
    local message = BuildDropWarningMessage(slotId, item)
    if message then
        PreviewLogic.ShowWarning(message)
    end
end

local function FlashSlotWarning(slotId, slot)
    local element = slot and (slot.SlotElement or slot)
    if not element or not element.SetWarning then
        return
    end
    element:SetWarning(true)
    if ctx and ctx.Timer and ctx.Timer.Start then
        ctx.Timer.Start(WARNING_SLOT_TIMER_PREFIX .. tostring(slotId), 0.6, function ()
            if element.SetWarning then
                element:SetWarning(false)
            end
        end)
    end
end

local function ValidateForgeSlotDrop(slotId, slot, context)
    local slotMode = ResolveForgeSlotMode(slotId)
    if not slotMode then
        return true
    end
    local item = context and context.Item or nil

    local dropObj = nil
    local dragData = (context and context.DragData) or GetDragDropState()
    if dragData then
        if not item and dragData.DragObject then
            item = ResolveItemFromDragObject(dragData.DragObject)
        end
        if not item and dragData.DragId and dragData.DragId ~= "" then
            if Ext and Ext.Template and Ext.Template.GetTemplate and Ext.Template.GetTemplate(dragData.DragId) then
                dropObj = {TemplateID = dragData.DragId}
            elseif Stats and Stats.Get and Stats.Get("SkillData", dragData.DragId) then
                PreviewLogic.ShowDropWarning(slotId, nil)
                FlashSlotWarning(slotId, slot)
                return false
            elseif Stats and Stats.GetAction and Stats.GetAction(dragData.DragId) then
                PreviewLogic.ShowDropWarning(slotId, nil)
                FlashSlotWarning(slotId, slot)
                return false
            end
        end
        if not item and not dropObj and dragData.DragObject and IsValidHandle(dragData.DragObject) then
            dropObj = {ItemHandle = dragData.DragObject}
        end
    end

    if not item and not dropObj then
        return true
    end
    if PreviewLogic.CanAcceptItem(slotId, item, dropObj) then
        return true
    end
    PreviewLogic.ShowDropWarning(slotId, item)
    FlashSlotWarning(slotId, slot)
    return false
end

local function EnsureOverlay(slot)
    if not slot or not slot.SlotElement or not ctx or not ctx.PREVIEW_USED_FRAME_TEXTURE then
        return nil
    end
    if slot._PreviewUsedOverlay then
        return slot._PreviewUsedOverlay
    end

    local root = slot.SlotElement
    local size = root.GetSize and root:GetSize(true) or V(0, 0)
    local overlay = root:AddChild(root.ID .. "_UsedOverlay", "GenericUI_Element_Texture")
    overlay:SetTexture(ctx.PREVIEW_USED_FRAME_TEXTURE, V(size[1], size[2]))
    overlay:SetSize(size[1], size[2])
    overlay:SetPosition(0, 0)
    if overlay.SetAlpha and ctx.PREVIEW_USED_FRAME_ALPHA ~= nil then
        overlay:SetAlpha(ctx.PREVIEW_USED_FRAME_ALPHA)
    end
    if overlay.SetMouseEnabled then
        overlay:SetMouseEnabled(false)
    end
    if overlay.SetMouseChildren then
        overlay:SetMouseChildren(false)
    end
    if overlay.SetVisible then
        overlay:SetVisible(false)
    end
    if root.SetChildIndex then
        root:SetChildIndex(overlay, 999)
    end
    slot._PreviewUsedOverlay = overlay
    return overlay
end

local function GetDraggedItem()
    local data = GetDragDropState()
    if not data then
        return nil
    end
    if data.DragObject then
        local item, source = ResolveItemFromDragObject(data.DragObject)
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
    if not item and State.PreviewDragItemHandle then
        item = GetItemFromHandle(State.PreviewDragItemHandle)
    end
    return item
end

local function IsItemAllowed(slotId, item)
    if PreviewLogic.CanAcceptItem then
        return PreviewLogic.CanAcceptItem(slotId, item)
    end
    return item ~= nil
end

function PreviewLogic.CanAcceptItem(slotId, item, obj)
    local itemType, isEquipment, isSkillbook = GetDropClassification(item, obj)

    local slotMode = ResolveForgeSlotMode(slotId)
    
    -- Skillbook slot - only accepts skillbooks
    if slotMode == "Skillbook" then
        if itemType and IsSkillbookItemType(itemType) then
            return true
        end
        return isSkillbook == true
    end
    
    -- Equipment slots - reject skillbooks first, then check for equipment
    if slotMode == "Equipment" then
        -- Always reject skillbooks from equipment slots
        if isSkillbook then
            return false
        end
        if itemType and IsSkillbookItemType(itemType) then
            return false
        end
        -- Accept only equipment types
        if itemType and IsEquipmentItemType(itemType) then
            return true
        end
        return isEquipment == true
    end
    
    return true
end

function PreviewLogic.SyncForgeSlots()
    State.SlotItems = {}
    State.ItemToSlot = {}
    for id, slot in pairs(State.ForgeSlots) do
        local cleared = false
        if slot and slot.Object and slot.Object.Type and slot.Object.Type ~= "None" then
            local obj = slot.Object
            local item = nil
            if obj.GetEntity then
                item = obj:GetEntity()
            end
            if not item and obj.ItemHandle and IsValidHandle(obj.ItemHandle) then
                item = GetItemFromHandle(obj.ItemHandle)
            end
            if not PreviewLogic.CanAcceptItem(id, item, obj) then
                ClearSlotMapping(id)
                if slot.Clear then
                    slot:Clear()
                end
                if slot.SetObject then
                    slot:SetObject(nil)
                end
                if slot.SetEnabled then
                    slot:SetEnabled(true)
                end
                cleared = true
            end
        end
        if not cleared then
            local handle = ResolveSlotItemHandle(slot)
            if handle then
                State.SlotItems[id] = handle
                State.ItemToSlot[handle] = id
            elseif slot and slot.Object and slot.Object.Type ~= "None" and slot.Clear then
                slot:Clear()
            end
        end
    end
    ClearStaleHighlights()
end

function PreviewLogic.AssignSlotItem(slotId, slot, item)
    if not item or not item.Handle then
        ClearSlotMapping(slotId)
        return
    end

    local previousHandle = State.SlotItems[slotId]
    if previousHandle and previousHandle ~= item.Handle then
        State.ItemToSlot[previousHandle] = nil
    end

    local existingSlotId = State.ItemToSlot[item.Handle]
    if existingSlotId and existingSlotId ~= slotId then
        local existing = State.ForgeSlots[existingSlotId]
        if existing and existing.Clear then
            existing:Clear()
        end
        ClearSlotMapping(existingSlotId)
    end

    State.SlotItems[slotId] = item.Handle
    State.ItemToSlot[item.Handle] = slotId
end

function PreviewLogic.ClearForgeSlot(slotId)
    local slot = State.ForgeSlots[slotId]
    if slot and slot.Clear then
        slot:Clear()
    end
    ClearSlotMapping(slotId)
end

function PreviewLogic.AssignPreviewSlot(index, item)
    if not item or not item.Handle then
        return
    end
    local previousIndex = State.PreviewItemToSlot[item.Handle]
    if previousIndex and previousIndex ~= index then
        State.PreviewSlotItems[previousIndex] = nil
    end

    local previousHandle = State.PreviewSlotItems[index]
    if previousHandle and previousHandle ~= item.Handle then
        State.PreviewItemToSlot[previousHandle] = nil
    end

    State.PreviewSlotItems[index] = item.Handle
    State.PreviewItemToSlot[item.Handle] = index
end

function PreviewLogic.ClearPreviewSlot(index)
    local handle = State.PreviewSlotItems[index]
    if handle then
        State.PreviewItemToSlot[handle] = nil
    end
    State.PreviewSlotItems[index] = nil
end

function PreviewLogic.BuildPreviewInventoryLayout(filteredItems, allItems, columns)
    columns = math.max(1, tonumber(columns) or 1)

    local allLookup = {}
    local filteredList = {}
    for _, item in ipairs(allItems or {}) do
        if item and item.Handle and IsValidHandle(item.Handle) then
            allLookup[item.Handle] = item
        end
    end

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
    for slotIndex, handle in pairs(State.PreviewSlotItems or {}) do
        if filteredLookup[handle] and cleanedItemToSlot[handle] == nil then
            cleanedSlotItems[slotIndex] = handle
            cleanedItemToSlot[handle] = slotIndex
            if slotIndex > maxIndex then
                maxIndex = slotIndex
            end
        end
    end
    State.PreviewSlotItems = cleanedSlotItems
    State.PreviewItemToSlot = cleanedItemToSlot

    local nextSlot = maxIndex + 1
    for _, item in ipairs(filteredList) do
        if item and item.Handle and not cleanedItemToSlot[item.Handle] then
            while State.PreviewSlotItems[nextSlot] ~= nil do
                nextSlot = nextSlot + 1
            end
            State.PreviewSlotItems[nextSlot] = item.Handle
            State.PreviewItemToSlot[item.Handle] = nextSlot
            cleanedItemToSlot[item.Handle] = nextSlot
            if nextSlot > maxIndex then
                maxIndex = nextSlot
            end
            nextSlot = nextSlot + 1
        end
    end

    local display = {}
    for slotIndex, handle in pairs(State.PreviewSlotItems) do
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

function PreviewLogic.HandlePreviewSlotDrop(index, slot, ev)
    local item = ResolveDraggedItem(ev)
    local dropObj = ev and ev.Object or nil
    local dropHandle = (item and item.Handle) or (dropObj and dropObj.ItemHandle)
    if not dropHandle then
        State.PreviewDragItemHandle = nil
        State.PreviewDragSourceIndex = nil
        return
    end

    -- Only accept items matching the active preview filter (or both if unknown)
    local filter = State.CurrentPreviewFilter
    local isValidItem = false
    local itemType, isEquipment, isSkillbook = GetDropClassification(item, dropObj)
    if filter == "Equipment" then
        isValidItem = isEquipment and not isSkillbook
    elseif filter == "Magical" then
        isValidItem = isSkillbook
    else
        isValidItem = isEquipment or isSkillbook
    end
    if not isValidItem then
        -- Use immediate timer to clear in the next frame for instant rejection
        local function immediateClear()
            if slot and slot.Clear then
                slot:Clear()
            end
            PreviewLogic.ClearPreviewSlot(index)
            if ctx and ctx.Widgets and ctx.Widgets.RenderPreviewInventory then
                ctx.Widgets.RenderPreviewInventory()
            end
        end
        if ctx and ctx.Timer and ctx.Timer.Start then
            ctx.Timer.Start("PreviewSlotReject_" .. tostring(index), 0, immediateClear)
        else
            immediateClear()
        end
        State.PreviewDragItemHandle = nil
        State.PreviewDragSourceIndex = nil
        return
    end

    if item and item.Handle then
        PreviewLogic.AssignPreviewSlot(index, item)
    else
        PreviewLogic.AssignPreviewSlot(index, {Handle = dropHandle})
    end
    State.PreviewDragItemHandle = nil
    State.PreviewDragSourceIndex = nil
    if ctx and ctx.Widgets and ctx.Widgets.RenderPreviewInventory then
        ctx.Widgets.RenderPreviewInventory()
    end
    PlaySound((ctx and ctx.PREVIEW_DROP_SOUND) or DEFAULT_DROP_SOUND)
end

function PreviewLogic.WirePreviewSlot(index, slot)
    if not slot or slot._PreviewInventoryBound then
        return
    end
    if slot.SetCanDrop then
        slot:SetCanDrop(true)
    end
    if slot.SetValidObjectTypes then
        slot:SetValidObjectTypes({Item = true, Skill = true})
    end
    if slot.SetUpdateDelay then
        slot:SetUpdateDelay(-1)
    end
    if slot.SetUsable then
        slot:SetUsable(false)
    end
    if slot.SetEnabled then
        slot:SetEnabled(true)
    end
    if slot.SlotElement and slot.SlotElement.SetMouseMoveEventEnabled then
        slot.SlotElement:SetMouseMoveEventEnabled(true)
    end
    if slot.Events and slot.Events.ObjectDraggedIn then
        slot.Events.ObjectDraggedIn:Subscribe(function (ev)
            PreviewLogic.HandlePreviewSlotDrop(index, slot, ev)
        end)
    end
    if slot.SlotElement and slot.SlotElement.Events and slot.SlotElement.Events.DragStarted then
        slot.SlotElement.Events.DragStarted:Subscribe(function ()
            local handle = State.PreviewSlotItems[index] or ResolveSlotItemHandle(slot)
            State.PreviewDragItemHandle = handle
            State.PreviewDragSourceIndex = index
            ClearSlotHighlight(slot)
            if State.LastPreviewHoverSlot == slot then
                State.LastPreviewHoverSlot = nil
            end
        end)
    end
    if slot.SlotElement and slot.SlotElement.Events then
        if slot.Events and slot.Events.MouseOver then
            slot.Events.MouseOver:Subscribe(function ()
                HandlePreviewSlotHover(slot)
            end, {Priority = 200, StringID = "ForgingUI_PreviewTooltipOver"})
        end
        if slot.SlotElement.Events.MouseMove then
            slot.SlotElement.Events.MouseMove:Subscribe(function ()
                if not slot._PreviewTooltipVisible then
                    ShowPreviewSlotTooltip(slot)
                end
            end, {Priority = 200, StringID = "ForgingUI_PreviewTooltipMove"})
        end
        if slot.Events and slot.Events.MouseOut then
            slot.Events.MouseOut:Subscribe(function ()
                HidePreviewSlotTooltip(slot)
                ClearSlotHighlight(slot)
                if State.LastPreviewHoverSlot == slot then
                    State.LastPreviewHoverSlot = nil
                end
            end, {Priority = 200, StringID = "ForgingUI_PreviewTooltipOut"})
        end
    end
    slot._PreviewInventoryBound = true
    State.PreviewSlots[index] = slot
end

function PreviewLogic.RefreshInventoryHighlights()
    PreviewLogic.SyncForgeSlots()

    local preview = State.PreviewInventory
    if not preview or not preview.Slots then
        return
    end

    for _, slot in ipairs(preview.Slots) do
        if slot then
            local handle = ResolveSlotItemHandle(slot)
            local overlay = EnsureOverlay(slot)
            if overlay and overlay.SetVisible then
                overlay:SetVisible(handle ~= nil and State.ItemToSlot[handle] ~= nil)
            end
        end
    end
end

-- Helper to reset slot movieclip visual state (clear drag overlays, etc.)
local function ResetSlotVisualState(slot)
    if not slot then return end
    local slotElement = slot.SlotElement or slot
    if slotElement and slotElement.GetMovieClip then
        local mc = slotElement:GetMovieClip()
        if mc then
            -- Reset any drag-related alpha/visibility states
            if mc.alpha ~= nil then mc.alpha = 1 end
            -- Reset highlight if it got stuck
            if mc.highlight_mc then
                mc.highlight_mc.alpha = 0
                mc.highlight_mc.visible = false
            end
            -- Reset any "drag over" or "drop target" indicators
            if mc.dropTarget_mc then mc.dropTarget_mc.visible = false end
            if mc.dragOver_mc then mc.dragOver_mc.visible = false end
            if mc.icon_mc and mc.icon_mc.alpha ~= nil then mc.icon_mc.alpha = 1 end
        end
    end
end

function PreviewLogic.HandleForgeSlotDrop(slotId, slot, ev)
    slotId = ResolveForgeSlotId(slotId, slot)
    if not slotId then
        return
    end
    local previousHandle = State.SlotItems[slotId]
    local item = ResolveDraggedItem(ev)
    local dropObj = ev and ev.Object or nil
    local dropHandle = (item and item.Handle) or (dropObj and dropObj.ItemHandle)
    if not dropHandle then
        ClearSlotMapping(slotId)
        if slot then
            ResetSlotVisualState(slot)
            if slot.Clear then
                slot:Clear()
            end
            if slot.SetObject then
                slot:SetObject(nil)
            end
            if slot.SetEnabled then
                slot:SetEnabled(true)
            end
            ResetSlotVisualState(slot)
        end
        if previousHandle and IsValidHandle(previousHandle) and slot and slot.SetItem then
            local previousItem = GetItemFromHandle(previousHandle)
            if previousItem then
                slot:SetItem(previousItem)
                slot:SetEnabled(true)
                PreviewLogic.AssignSlotItem(slotId, slot, previousItem)
            end
        end
        PreviewLogic.RefreshInventoryHighlights()
        State.PreviewDragItemHandle = nil
        State.PreviewDragSourceIndex = nil
        return
    end

    if not PreviewLogic.CanAcceptItem(slotId, item, dropObj) then
        PreviewLogic.ShowDropWarning(slotId, item)
        FlashSlotWarning(slotId, slot)
        -- Clear internal state mapping immediately
        ClearSlotMapping(slotId)
        -- Use aggressive clearing for instant visual rejection
        local function immediateReject()
            if slot then
                -- Reset visual state first (clear drag overlays)
                ResetSlotVisualState(slot)
                -- Try multiple clearing methods
                if slot.Clear then
                    slot:Clear()
                end
                if slot.SetObject then
                    slot:SetObject(nil)
                end
                if slot.SetEnabled then
                    slot:SetEnabled(true)
                end
                -- Reset visual state again after clear
                ResetSlotVisualState(slot)
            end
            -- Restore previous item if there was one
            if previousHandle and IsValidHandle(previousHandle) and slot and slot.SetItem then
                local previousItem = GetItemFromHandle(previousHandle)
                if previousItem then
                    slot:SetItem(previousItem)
                    slot:SetEnabled(true)
                    PreviewLogic.AssignSlotItem(slotId, slot, previousItem)
                end
            end
            PreviewLogic.RefreshInventoryHighlights()
        end
        -- Execute immediately + schedule for next frames to ensure visual update
        immediateReject()
        if ctx and ctx.Timer and ctx.Timer.Start then
            ctx.Timer.Start("ForgeSlotReject_" .. tostring(slotId), 0, immediateReject)
            ctx.Timer.Start("ForgeSlotReject2_" .. tostring(slotId), 16, immediateReject)
            ctx.Timer.Start("ForgeSlotReject3_" .. tostring(slotId), 50, immediateReject)
        end
        State.PreviewDragItemHandle = nil
        State.PreviewDragSourceIndex = nil
        return
    end

    if item and slot and slot.SetItem then
        slot:SetItem(item)
        slot:SetEnabled(true)
        PreviewLogic.AssignSlotItem(slotId, slot, item)
    elseif dropHandle then
        PreviewLogic.AssignSlotItem(slotId, slot, {Handle = dropHandle})
    end
    ClearSlotHighlight(slot)
    PreviewLogic.RefreshInventoryHighlights()
    if item then
        PlaySound((ctx and ctx.PREVIEW_DROP_SOUND) or DEFAULT_DROP_SOUND)
    end
    State.PreviewDragItemHandle = nil
    State.PreviewDragSourceIndex = nil
end

function PreviewLogic.HandleForgeSlotDragStarted(slotId, _)
    slotId = ResolveForgeSlotId(slotId, State.ForgeSlots[slotId])
    ClearSlotMapping(slotId)
    if slotId and State.ForgeSlots[slotId] and State.ForgeSlots[slotId].SetEnabled then
        State.ForgeSlots[slotId]:SetEnabled(true)
    end
    if State.ForgeSlots[slotId] then
        ClearSlotHighlight(State.ForgeSlots[slotId])
        if State.LastForgeHoverSlot == State.ForgeSlots[slotId] then
            State.LastForgeHoverSlot = nil
        end
    end
    PreviewLogic.RefreshInventoryHighlights()
end

function PreviewLogic.HandleForgeSlotClicked(slotId, slot)
    slotId = ResolveForgeSlotId(slotId, slot)
    if not slot then
        return
    end
    local wasEmpty = slot.IsEmpty and slot:IsEmpty() or false
    if not wasEmpty and slot.Clear then
        slot:Clear()
        if slot.SetEnabled then
            slot:SetEnabled(true)
        end
    end
    ClearSlotMapping(slotId)
    ClearSlotHighlight(slot)
    PreviewLogic.RefreshInventoryHighlights()
end

function PreviewLogic.RegisterForgeSlots(slots)
    State.ForgeSlots = {}
    State.SlotItems = {}
    State.ItemToSlot = {}

    if not slots then
        return
    end

    for id, slot in pairs(slots) do
        if slot and slot.SetCanDrop then
            local slotId = id
            local slotRef = slot
            if not slot._PreviewLogicBound then
                if slotRef.SetValidObjectTypes then
                    local slotMode = ResolveForgeSlotMode(slotId)
                    if slotMode == "Equipment" or slotMode == "Skillbook" then
                        slotRef:SetValidObjectTypes({Item = true})
                    else
                        slotRef:SetValidObjectTypes({Item = true, Skill = true})
                    end
                end
                -- We still need CanDrop true for drag visual feedback
                slotRef:SetCanDrop(true)
                if slotRef.SetCanDrag then
                    slotRef:SetCanDrag(true, true)
                end
                if slotRef.SetUsable then
                    slotRef:SetUsable(false)
                end
                if slotRef.SetUpdateDelay then
                    slotRef:SetUpdateDelay(-1)
                end
                if slotRef.SetEnabled then
                    slotRef:SetEnabled(true)
                end

                if slotRef.SetDropValidator then
                    slotRef:SetDropValidator(function (_, dropContext)
                        local resolvedSlotId = ResolveForgeSlotId(slotId, slotRef)
                        return ValidateForgeSlotDrop(resolvedSlotId, slotRef, dropContext)
                    end)
                end

                if slotRef.SlotElement and slotRef.SlotElement.Events then
                    if slotRef.SlotElement.Events.MouseOver then
                        slotRef.SlotElement.Events.MouseOver:Subscribe(function ()
                            HandleForgeSlotHover(slotRef)
                        end, {Priority = 150, StringID = "ForgingUI_ForgeHover"})
                    end
                    if slotRef.SlotElement.Events.MouseOut then
                        slotRef.SlotElement.Events.MouseOut:Subscribe(function ()
                            ClearSlotHighlight(slotRef)
                            if State.LastForgeHoverSlot == slotRef then
                                State.LastForgeHoverSlot = nil
                            end
                        end, {Priority = 150, StringID = "ForgingUI_ForgeHoverOut"})
                    end
                end
                
                if (not slotRef.SetDropValidator) and slotRef.SlotElement and slotRef.SlotElement.Events and slotRef.SlotElement.Events.MouseUp then
                    slotRef.SlotElement.Events.MouseUp:Subscribe(function (ev)
                        if ShouldBlockDrop(slotId) then
                            PreviewLogic.ShowDropWarning(slotId, GetDraggedItem())
                            FlashSlotWarning(slotId, slotRef)
                            if ev and ev.StopPropagation then
                                ev:StopPropagation()
                            end
                        end
                    end, {Priority = 300})
                end

                if slotRef.Events and slotRef.Events.ObjectDraggedIn then
                    slotRef.Events.ObjectDraggedIn:Subscribe(function (ev)
                        PreviewLogic.HandleForgeSlotDrop(slotId, slotRef, ev)
                    end, {Priority = 200})
                end
                
                if slotRef.Events and slotRef.Events.Clicked then
                    slotRef.Events.Clicked:Subscribe(function ()
                        PreviewLogic.HandleForgeSlotClicked(slotId, slotRef)
                    end)
                end
                if slotRef.SlotElement and slotRef.SlotElement.Events and slotRef.SlotElement.Events.DragStarted then
                    slotRef.SlotElement.Events.DragStarted:Subscribe(function ()
                        PreviewLogic.HandleForgeSlotDragStarted(slotId, slotRef)
                    end)
                end
                slotRef._PreviewLogicBound = true
            end
            State.ForgeSlots[slotId] = slotRef
        end
    end

    PreviewLogic.RefreshInventoryHighlights()
end

function PreviewLogic.EnsureForgeSlotValidator()
    if PreviewLogic._ForgeSlotValidatorInstalled then
        return
    end

    local function ValidateSlots()
        if not ctx or not ctx.UIState or not ctx.UIState.IsVisible then
            return
        end
        if not State or not State.ForgeSlots then
            return
        end
        PreviewLogic.SyncForgeSlots()
    end

    if GameState and GameState.Events and GameState.Events.RunningTick then
        GameState.Events.RunningTick:Subscribe(ValidateSlots, {StringID = "ForgingUI_ForgeSlotValidator"})
    elseif Ext and Ext.Events and Ext.Events.Tick then
        Ext.Events.Tick:Subscribe(ValidateSlots)
    elseif ctx and ctx.Timer and ctx.Timer.Start then
        local timer = ctx.Timer.Start("ForgingUI_ForgeSlotValidator", 0.05, function ()
            ValidateSlots()
        end)
        if timer and timer.SetRepeatCount then
            timer:SetRepeatCount(-1)
        end
    end

    PreviewLogic._ForgeSlotValidatorInstalled = true
end

function PreviewLogic.Bind(slots, previewInventory)
    if previewInventory ~= State.PreviewInventory then
        State.PreviewSlotItems = {}
        State.PreviewItemToSlot = {}
        State.PreviewSlots = {}
        State.PreviewSlotItemsByFilter = {}
        State.PreviewItemToSlotByFilter = {}
        State.CurrentPreviewFilter = nil
        State.PreviewDragItemHandle = nil
        State.PreviewDragSourceIndex = nil
    end
    State.PreviewInventory = previewInventory
    PreviewLogic.RegisterForgeSlots(slots)
    PreviewLogic.EnsureForgeSlotValidator()
end

return PreviewLogic
