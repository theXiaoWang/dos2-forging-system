-- Client/ForgingUI/Backend/PreviewInventory/ForgeDropValidation.lua
-- Forge slot drag/drop validation helpers.

local ForgeDropValidation = {}

---@param options table
function ForgeDropValidation.Create(options)
    local opts = options or {}
    local state = opts.state
    local resolveForgeSlotMode = opts.resolveForgeSlotMode
    local hasDragData = opts.hasDragData
    local getDraggedItem = opts.getDraggedItem
    local getDragDropState = opts.getDragDropState
    local resolveItemFromDragObject = opts.resolveItemFromDragObject
    local isValidHandle = opts.isValidHandle
    local canAcceptItem = opts.canAcceptItem
    local showDropWarning = opts.showDropWarning
    local flashSlotWarning = opts.flashSlotWarning

    local function ResolveForgeSlotId(slotId, slot)
        if slotId and slot and state and state.ForgeSlots and state.ForgeSlots[slotId] == slot then
            return slotId
        end
        if slot and state and state.ForgeSlots then
            for id, forgeSlot in pairs(state.ForgeSlots) do
                if forgeSlot == slot then
                    return id
                end
            end
            local rawId = slot.ID or (slot.SlotElement and slot.SlotElement.ID) or nil
            if rawId then
                if state.ForgeSlots[rawId] == slot then
                    return rawId
                end
                return rawId
            end
        end
        return slotId
    end

    local function ShouldBlockDrop(slotId)
        local slotMode = resolveForgeSlotMode and resolveForgeSlotMode(slotId) or nil
        if not slotMode then
            return false
        end
        if not (hasDragData and hasDragData()) then
            return false
        end
        local item = getDraggedItem and getDraggedItem() or nil
        if item and canAcceptItem then
            return not canAcceptItem(slotId, item)
        end
        local data = getDragDropState and getDragDropState() or nil
        if data and data.DragId and data.DragId ~= "" and Stats then
            if (Stats.Get and Stats.Get("SkillData", data.DragId))
                or (Stats.GetAction and Stats.GetAction(data.DragId)) then
                return true
            end
        end
        return false
    end

    local function ValidateForgeSlotDrop(slotId, slot, context)
        local slotMode = resolveForgeSlotMode and resolveForgeSlotMode(slotId) or nil
        if not slotMode then
            return true
        end
        local item = context and context.Item or nil

        local dropObj = nil
        local dragData = (context and context.DragData) or (getDragDropState and getDragDropState())
        if dragData then
            if not item and dragData.DragObject then
                item = resolveItemFromDragObject and resolveItemFromDragObject(dragData.DragObject) or nil
            end
            if not item and dragData.DragId and dragData.DragId ~= "" then
                if Ext and Ext.Template and Ext.Template.GetTemplate and Ext.Template.GetTemplate(dragData.DragId) then
                    dropObj = {TemplateID = dragData.DragId}
                elseif Stats and Stats.Get and Stats.Get("SkillData", dragData.DragId) then
                    if showDropWarning then
                        showDropWarning(slotId, nil)
                    end
                    if flashSlotWarning then
                        flashSlotWarning(slotId, slot)
                    end
                    return false
                elseif Stats and Stats.GetAction and Stats.GetAction(dragData.DragId) then
                    if showDropWarning then
                        showDropWarning(slotId, nil)
                    end
                    if flashSlotWarning then
                        flashSlotWarning(slotId, slot)
                    end
                    return false
                end
            end
            if not item and not dropObj and dragData.DragObject and (not isValidHandle or isValidHandle(dragData.DragObject)) then
                dropObj = {ItemHandle = dragData.DragObject}
            end
        end

        if not item and not dropObj then
            return true
        end
        if canAcceptItem and canAcceptItem(slotId, item, dropObj) then
            return true
        end
        if showDropWarning then
            showDropWarning(slotId, item)
        end
        if flashSlotWarning then
            flashSlotWarning(slotId, slot)
        end
        return false
    end

    return {
        ResolveForgeSlotId = ResolveForgeSlotId,
        ShouldBlockDrop = ShouldBlockDrop,
        ValidateForgeSlotDrop = ValidateForgeSlotDrop,
    }
end

return ForgeDropValidation
