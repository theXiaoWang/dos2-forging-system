-- Client/ForgingUI/Backend/PreviewInventory/ForgeSlotHandlers.lua
-- Forge slot handlers and registration.

local ForgeSlotHandlers = {}

---@param options table
function ForgeSlotHandlers.Create(options)
    local opts = options or {}
    local state = opts.state
    local getContext = opts.getContext
    local resolveForgeSlotId = opts.resolveForgeSlotId
    local resolveForgeSlotMode = opts.resolveForgeSlotMode
    local resolveDraggedItem = opts.resolveDraggedItem
    local canAcceptItem = opts.canAcceptItem
    local clearSlotMapping = opts.clearSlotMapping
    local resetSlotVisualState = opts.resetSlotVisualState
    local getItemFromHandle = opts.getItemFromHandle
    local isValidHandle = opts.isValidHandle
    local assignSlotItem = opts.assignSlotItem
    local refreshInventoryHighlights = opts.refreshInventoryHighlights
    local clearSlotHighlight = opts.clearSlotHighlight
    local handleForgeSlotHover = opts.handleForgeSlotHover
    local showDropWarning = opts.showDropWarning
    local flashSlotWarning = opts.flashSlotWarning
    local shouldBlockDrop = opts.shouldBlockDrop
    local getDraggedItem = opts.getDraggedItem
    local validateForgeSlotDrop = opts.validateForgeSlotDrop
    local playSound = opts.playSound
    local defaultDropSound = opts.defaultDropSound
    local updateSlotDetails = opts.updateSlotDetails

    local function HandleForgeSlotDrop(slotId, slot, ev)
        slotId = resolveForgeSlotId and resolveForgeSlotId(slotId, slot) or slotId
        if not slotId then
            return
        end
        local previousHandle = state and state.SlotItems and state.SlotItems[slotId] or nil
        local item = resolveDraggedItem and resolveDraggedItem(ev) or nil
        local dropObj = ev and ev.Object or nil
        local dropHandle = (item and item.Handle) or (dropObj and dropObj.ItemHandle)
        if not dropHandle then
            if clearSlotMapping then
                clearSlotMapping(slotId)
            end
            if slot then
                if resetSlotVisualState then
                    resetSlotVisualState(slot)
                end
                if slot.Clear then
                    slot:Clear()
                end
                if slot.SetObject then
                    slot:SetObject(nil)
                end
                if slot.SetEnabled then
                    slot:SetEnabled(true)
                end
                if resetSlotVisualState then
                    resetSlotVisualState(slot)
                end
            end
            local restored = false
            if previousHandle and (not isValidHandle or isValidHandle(previousHandle)) and slot and slot.SetItem then
                local previousItem = getItemFromHandle and getItemFromHandle(previousHandle) or nil
                if previousItem then
                    slot:SetItem(previousItem)
                    slot:SetEnabled(true)
                    if assignSlotItem then
                        assignSlotItem(slotId, slot, previousItem)
                    end
                    if updateSlotDetails then
                        updateSlotDetails(slotId, previousItem)
                    end
                    restored = true
                end
            end
            if updateSlotDetails and not restored then
                updateSlotDetails(slotId, nil)
            end
            if refreshInventoryHighlights then
                refreshInventoryHighlights()
            end
            if state then
                state.PreviewDragItemHandle = nil
                state.PreviewDragSourceIndex = nil
            end
            return
        end

        if canAcceptItem and not canAcceptItem(slotId, item, dropObj) then
            if showDropWarning then
                showDropWarning(slotId, item)
            end
            if flashSlotWarning then
                flashSlotWarning(slotId, slot)
            end
            if clearSlotMapping then
                clearSlotMapping(slotId)
            end
            local function immediateReject()
                if slot then
                    if resetSlotVisualState then
                        resetSlotVisualState(slot)
                    end
                    if slot.Clear then
                        slot:Clear()
                    end
                    if slot.SetObject then
                        slot:SetObject(nil)
                    end
                    if slot.SetEnabled then
                        slot:SetEnabled(true)
                    end
                    if resetSlotVisualState then
                        resetSlotVisualState(slot)
                    end
                end
                local restored = false
                if previousHandle and (not isValidHandle or isValidHandle(previousHandle)) and slot and slot.SetItem then
                    local previousItem = getItemFromHandle and getItemFromHandle(previousHandle) or nil
                    if previousItem then
                        slot:SetItem(previousItem)
                        slot:SetEnabled(true)
                        if assignSlotItem then
                            assignSlotItem(slotId, slot, previousItem)
                        end
                        if updateSlotDetails then
                            updateSlotDetails(slotId, previousItem)
                        end
                        restored = true
                    end
                end
                if updateSlotDetails and not restored then
                    updateSlotDetails(slotId, nil)
                end
                if refreshInventoryHighlights then
                    refreshInventoryHighlights()
                end
            end
            immediateReject()
            local ctx = getContext and getContext() or nil
            if ctx and ctx.Timer and ctx.Timer.Start then
                ctx.Timer.Start("ForgeSlotReject_" .. tostring(slotId), 0, immediateReject)
                ctx.Timer.Start("ForgeSlotReject2_" .. tostring(slotId), 16, immediateReject)
                ctx.Timer.Start("ForgeSlotReject3_" .. tostring(slotId), 50, immediateReject)
            end
            if state then
                state.PreviewDragItemHandle = nil
                state.PreviewDragSourceIndex = nil
            end
            return
        end

        if item and slot and slot.SetItem then
            slot:SetItem(item)
            slot:SetEnabled(true)
            if assignSlotItem then
                assignSlotItem(slotId, slot, item)
            end
            if updateSlotDetails then
                updateSlotDetails(slotId, item)
            end
        elseif dropHandle then
            if assignSlotItem then
                assignSlotItem(slotId, slot, {Handle = dropHandle})
            end
        end
        if clearSlotHighlight then
            clearSlotHighlight(slot)
        end
        if refreshInventoryHighlights then
            refreshInventoryHighlights()
        end
        if item and playSound then
            local ctx = getContext and getContext() or nil
            playSound((ctx and ctx.PREVIEW_DROP_SOUND) or defaultDropSound)
        end
        if state then
            state.PreviewDragItemHandle = nil
            state.PreviewDragSourceIndex = nil
        end
    end

    local function HandleForgeSlotDragStarted(slotId, _)
        slotId = resolveForgeSlotId and resolveForgeSlotId(slotId, state and state.ForgeSlots and state.ForgeSlots[slotId]) or slotId
        if clearSlotMapping then
            clearSlotMapping(slotId)
        end
        if updateSlotDetails then
            updateSlotDetails(slotId, nil)
        end
        if slotId and state and state.ForgeSlots and state.ForgeSlots[slotId] and state.ForgeSlots[slotId].SetEnabled then
            state.ForgeSlots[slotId]:SetEnabled(true)
        end
        if state and state.ForgeSlots and state.ForgeSlots[slotId] then
            if clearSlotHighlight then
                clearSlotHighlight(state.ForgeSlots[slotId])
            end
            if state.LastForgeHoverSlot == state.ForgeSlots[slotId] then
                state.LastForgeHoverSlot = nil
            end
        end
        if refreshInventoryHighlights then
            refreshInventoryHighlights()
        end
    end

    local function HandleForgeSlotClicked(slotId, slot)
        slotId = resolveForgeSlotId and resolveForgeSlotId(slotId, slot) or slotId
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
        if clearSlotMapping then
            clearSlotMapping(slotId)
        end
        if updateSlotDetails then
            updateSlotDetails(slotId, nil)
        end
        if clearSlotHighlight then
            clearSlotHighlight(slot)
        end
        if refreshInventoryHighlights then
            refreshInventoryHighlights()
        end
    end

    local function RegisterForgeSlots(slots)
        if state then
            state.ForgeSlots = {}
            state.SlotItems = {}
            state.ItemToSlot = {}
        end

        if not slots then
            return
        end

        for id, slot in pairs(slots) do
            if slot and slot.SetCanDrop then
                local slotId = id
                local slotRef = slot
                if not slot._PreviewLogicBound then
                    if slotRef.SetValidObjectTypes then
                        local slotMode = resolveForgeSlotMode and resolveForgeSlotMode(slotId) or nil
                        if slotMode == "Equipment" or slotMode == "Skillbook" then
                            slotRef:SetValidObjectTypes({Item = true})
                        else
                            slotRef:SetValidObjectTypes({Item = true, Skill = true})
                        end
                    end
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
                            local resolvedSlotId = resolveForgeSlotId and resolveForgeSlotId(slotId, slotRef) or slotId
                            return validateForgeSlotDrop and validateForgeSlotDrop(resolvedSlotId, slotRef, dropContext)
                        end)
                    end

                    if slotRef.SlotElement and slotRef.SlotElement.Events then
                        if slotRef.SlotElement.Events.MouseOver then
                            slotRef.SlotElement.Events.MouseOver:Subscribe(function ()
                                if handleForgeSlotHover then
                                    handleForgeSlotHover(slotRef)
                                end
                            end, {Priority = 150, StringID = "ForgingUI_ForgeHover"})
                        end
                        if slotRef.SlotElement.Events.MouseOut then
                            slotRef.SlotElement.Events.MouseOut:Subscribe(function ()
                                if clearSlotHighlight then
                                    clearSlotHighlight(slotRef)
                                end
                                if state and state.LastForgeHoverSlot == slotRef then
                                    state.LastForgeHoverSlot = nil
                                end
                            end, {Priority = 150, StringID = "ForgingUI_ForgeHoverOut"})
                        end
                    end

                    if (not slotRef.SetDropValidator) and slotRef.SlotElement and slotRef.SlotElement.Events and slotRef.SlotElement.Events.MouseUp then
                        slotRef.SlotElement.Events.MouseUp:Subscribe(function (ev)
                            if shouldBlockDrop and shouldBlockDrop(slotId) then
                                if showDropWarning then
                                    showDropWarning(slotId, getDraggedItem and getDraggedItem() or nil)
                                end
                                if flashSlotWarning then
                                    flashSlotWarning(slotId, slotRef)
                                end
                                if ev and ev.StopPropagation then
                                    ev:StopPropagation()
                                end
                            end
                        end, {Priority = 300})
                    end

                    if slotRef.Events and slotRef.Events.ObjectDraggedIn then
                        slotRef.Events.ObjectDraggedIn:Subscribe(function (ev)
                            HandleForgeSlotDrop(slotId, slotRef, ev)
                        end, {Priority = 200})
                    end

                    if slotRef.Events and slotRef.Events.Clicked then
                        slotRef.Events.Clicked:Subscribe(function ()
                            HandleForgeSlotClicked(slotId, slotRef)
                        end)
                    end
                    if slotRef.SlotElement and slotRef.SlotElement.Events and slotRef.SlotElement.Events.DragStarted then
                        slotRef.SlotElement.Events.DragStarted:Subscribe(function ()
                            HandleForgeSlotDragStarted(slotId, slotRef)
                        end)
                    end
                    slotRef._PreviewLogicBound = true
                end
                if state and state.ForgeSlots then
                    state.ForgeSlots[slotId] = slotRef
                end
            end
        end

        if refreshInventoryHighlights then
            refreshInventoryHighlights()
        end
    end

    return {
        HandleForgeSlotDrop = HandleForgeSlotDrop,
        HandleForgeSlotDragStarted = HandleForgeSlotDragStarted,
        HandleForgeSlotClicked = HandleForgeSlotClicked,
        RegisterForgeSlots = RegisterForgeSlots,
    }
end

return ForgeSlotHandlers
