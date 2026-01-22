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
}

PreviewLogic.State = State

local DEFAULT_DROP_SOUND = "UI_Game_PartyFormation_PickUp"

local function V(...)
    return ctx and ctx.V and ctx.V(...) or Vector.Create(...)
end

function PreviewLogic.SetContext(nextCtx)
    ctx = nextCtx
end

local function IsValidHandle(handle)
    return Ext and Ext.Utils and Ext.Utils.IsValidHandle and Ext.Utils.IsValidHandle(handle)
end

local function GetItemFromHandle(handle)
    if not handle or not Item or not Item.Get then
        return nil
    end
    local ok, item = pcall(Item.Get, handle)
    if ok then
        return item
    end
    return nil
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

local function IsSkillbook(item)
    if not item then
        return false
    end
    if Item and Item.IsSkillbook then
        local ok, result = pcall(Item.IsSkillbook, item)
        if ok then
            return result == true
        end
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

local function IsEquipment(item)
    if not item then
        return false
    end
    if Item and Item.IsEquipment then
        local ok, result = pcall(Item.IsEquipment, item)
        if ok then
            return result == true
        end
    end
    local entity = item.Entity or item
    local stats = entity and entity.Stats or nil
    if stats then
        return stats.ItemType == "Armor" or stats.ItemType == "Weapon" or stats.ItemType == "Shield"
    end
    return false
end

local function ClearSlotMapping(slotId)
    local handle = State.SlotItems[slotId]
    if handle then
        State.ItemToSlot[handle] = nil
    end
    State.SlotItems[slotId] = nil
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
    if not Ext or not Ext.UI or not Ext.UI.GetDragDrop then
        return nil
    end
    local dragDrop = Ext.UI.GetDragDrop()
    local data = dragDrop and dragDrop.PlayerDragDrops and dragDrop.PlayerDragDrops[1]
    if not data then
        return nil
    end
    if data.DragObject and IsValidHandle(data.DragObject) then
        return GetItemFromHandle(data.DragObject)
    end
    return nil
end

local function GetDraggedItemFromEvent(ev)
    if not ev or not ev.Object then
        return nil
    end
    local obj = ev.Object
    if obj.ItemHandle and IsValidHandle(obj.ItemHandle) then
        return GetItemFromHandle(obj.ItemHandle)
    end
    return nil
end

local function IsItemAllowed(slotId, item)
    if PreviewLogic.CanAcceptItem then
        return PreviewLogic.CanAcceptItem(slotId, item)
    end
    return item ~= nil
end

function PreviewLogic.CanAcceptItem(slotId, item)
    if not item then
        return false
    end
    local isEquipment = IsEquipment(item)
    local isSkillbook = IsSkillbook(item)
    if slotId == "Donor_SkillbookSlot" then
        return isSkillbook
    end
    if slotId == "Main_ItemSlot" or slotId == "Donor_ItemSlot" then
        return isEquipment and not isSkillbook
    end
    return true
end

function PreviewLogic.SyncForgeSlots()
    State.SlotItems = {}
    State.ItemToSlot = {}
    for id, slot in pairs(State.ForgeSlots) do
        local handle = ResolveSlotItemHandle(slot)
        if handle then
            State.SlotItems[id] = handle
            State.ItemToSlot[handle] = id
        elseif slot and slot.Object and slot.Object.Type ~= "None" and slot.Clear then
            slot:Clear()
        end
    end
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

function PreviewLogic.HandleForgeSlotDrop(slotId, slot, ev)
    local previousHandle = State.SlotItems[slotId]
    local item = GetDraggedItemFromEvent(ev) or GetDraggedItem()
    if not IsItemAllowed(slotId, item) then
        if previousHandle and IsValidHandle(previousHandle) and slot and slot.SetItem then
            local previousItem = GetItemFromHandle(previousHandle)
            if previousItem then
                slot:SetItem(previousItem)
                slot:SetEnabled(true)
            elseif slot.Clear then
                slot:Clear()
            end
        elseif slot and slot.Clear then
            slot:Clear()
        end
        PreviewLogic.RefreshInventoryHighlights()
        return
    end

    if item and slot and slot.SetItem then
        slot:SetItem(item)
        slot:SetEnabled(true)
        PreviewLogic.AssignSlotItem(slotId, slot, item)
    end
    PreviewLogic.RefreshInventoryHighlights()
    if item then
        PlaySound((ctx and ctx.PREVIEW_DROP_SOUND) or DEFAULT_DROP_SOUND)
    end
end

function PreviewLogic.HandleForgeSlotDragStarted(slotId, _)
    ClearSlotMapping(slotId)
    if slotId and State.ForgeSlots[slotId] and State.ForgeSlots[slotId].SetEnabled then
        State.ForgeSlots[slotId]:SetEnabled(true)
    end
    PreviewLogic.RefreshInventoryHighlights()
end

function PreviewLogic.HandleForgeSlotClicked(slotId, slot)
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
                if slotRef.SetValidObjectTypes then
                    slotRef:SetValidObjectTypes({Item = true})
                end
                if slotRef.Events and slotRef.Events.ObjectDraggedIn then
                    slotRef.Events.ObjectDraggedIn:Subscribe(function (ev)
                        PreviewLogic.HandleForgeSlotDrop(slotId, slotRef, ev)
                    end)
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

function PreviewLogic.Bind(slots, previewInventory)
    State.PreviewInventory = previewInventory
    PreviewLogic.RegisterForgeSlots(slots)
end

return PreviewLogic
