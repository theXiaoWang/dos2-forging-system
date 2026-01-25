-- Client/ForgingUI/Backend/PreviewInventory/ForgeSlotMapping.lua
-- Forge slot <-> item mapping helpers.

local ForgeSlotMapping = {}

---@param options table
function ForgeSlotMapping.Create(options)
    local opts = options or {}
    local state = opts.state
    local isValidHandle = opts.isValidHandle
    local getItemFromHandle = opts.getItemFromHandle
    local resolveSlotItemHandle = opts.resolveSlotItemHandle
    local canAcceptItem = opts.canAcceptItem
    local clearStaleHighlights = opts.clearStaleHighlights

    local function ClearSlotMapping(slotId)
        local handle = state.SlotItems[slotId]
        if handle then
            state.ItemToSlot[handle] = nil
        end
        state.SlotItems[slotId] = nil
    end

    local function SyncForgeSlots()
        state.SlotItems = {}
        state.ItemToSlot = {}
        for id, slot in pairs(state.ForgeSlots) do
            local cleared = false
            if slot and slot.Object and slot.Object.Type and slot.Object.Type ~= "None" then
                local obj = slot.Object
                local item = nil
                if obj.GetEntity then
                    item = obj:GetEntity()
                end
                if not item and obj.ItemHandle and (not isValidHandle or isValidHandle(obj.ItemHandle)) then
                    item = getItemFromHandle and getItemFromHandle(obj.ItemHandle) or nil
                end
                if canAcceptItem and not canAcceptItem(id, item, obj) then
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
                local handle = resolveSlotItemHandle and resolveSlotItemHandle(slot) or nil
                if handle then
                    state.SlotItems[id] = handle
                    state.ItemToSlot[handle] = id
                elseif slot and slot.Object and slot.Object.Type ~= "None" and slot.Clear then
                    slot:Clear()
                end
            end
        end
        if clearStaleHighlights then
            clearStaleHighlights()
        end
    end

    local function AssignSlotItem(slotId, slot, item)
        if not item or not item.Handle then
            ClearSlotMapping(slotId)
            return
        end

        local previousHandle = state.SlotItems[slotId]
        if previousHandle and previousHandle ~= item.Handle then
            state.ItemToSlot[previousHandle] = nil
        end

        local existingSlotId = state.ItemToSlot[item.Handle]
        if existingSlotId and existingSlotId ~= slotId then
            local existing = state.ForgeSlots[existingSlotId]
            if existing and existing.Clear then
                existing:Clear()
            end
            ClearSlotMapping(existingSlotId)
        end

        state.SlotItems[slotId] = item.Handle
        state.ItemToSlot[item.Handle] = slotId
    end

    local function ClearForgeSlot(slotId)
        local slot = state.ForgeSlots[slotId]
        if slot and slot.Clear then
            slot:Clear()
        end
        ClearSlotMapping(slotId)
    end

    return {
        ClearSlotMapping = ClearSlotMapping,
        SyncForgeSlots = SyncForgeSlots,
        AssignSlotItem = AssignSlotItem,
        ClearForgeSlot = ClearForgeSlot,
    }
end

return ForgeSlotMapping
