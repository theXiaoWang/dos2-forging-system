-- Client/ForgingUI/Backend/PreviewInventory/PreviewSlotHandlers.lua
-- Preview inventory slot handlers + highlight refresh.

local PreviewSlotHandlers = {}

---@param options table
function PreviewSlotHandlers.Create(options)
    local opts = options or {}
    local state = opts.state
    local getContext = opts.getContext
    local getDropClassification = opts.getDropClassification
    local assignPreviewSlot = opts.assignPreviewSlot
    local clearPreviewSlot = opts.clearPreviewSlot
    local assignSlotItem = opts.assignSlotItem
    local getItemFromHandle = opts.getItemFromHandle
    local canAcceptItem = opts.canAcceptItem
    local updateSlotDetails = opts.updateSlotDetails
    local resolveDraggedItem = opts.resolveDraggedItem
    local resolveSlotItemHandle = opts.resolveSlotItemHandle
    local syncForgeSlots = opts.syncForgeSlots
    local ensureOverlay = opts.ensureOverlay
    local clearSlotHighlight = opts.clearSlotHighlight
    local handlePreviewSlotHover = opts.handlePreviewSlotHover
    local handlePreviewSlotHoverHighlight = opts.handlePreviewSlotHoverHighlight
    local showPreviewSlotTooltip = opts.showPreviewSlotTooltip
    local hidePreviewSlotTooltip = opts.hidePreviewSlotTooltip
    local playSound = opts.playSound
    local defaultDropSound = opts.defaultDropSound

    local function HandlePreviewSlotDrop(index, slot, ev)
        local item = resolveDraggedItem and resolveDraggedItem(ev) or nil
        local dropObj = ev and ev.Object or nil
        local dropHandle = (item and item.Handle) or (dropObj and dropObj.ItemHandle)
        if not dropHandle then
            if state then
                state.PreviewDragItemHandle = nil
                state.PreviewDragSourceIndex = nil
                state.ForgeDragItemHandle = nil
                state.ForgeDragSourceSlotId = nil
            end
            return
        end

        local filter = state and state.CurrentPreviewFilter or nil
        local isValidItem = false
        local itemType = nil
        local isEquipment = nil
        local isSkillbook = nil
        if getDropClassification then
            itemType, isEquipment, isSkillbook = getDropClassification(item, dropObj)
        end
        if filter == "Equipment" then
            isValidItem = isEquipment and not isSkillbook
        elseif filter == "Magical" then
            isValidItem = isSkillbook
        else
            isValidItem = isEquipment or isSkillbook
        end
        if not isValidItem then
            local function immediateClear()
                if slot and slot.Clear then
                    slot:Clear()
                end
                if clearPreviewSlot then
                    clearPreviewSlot(index)
                end
                local ctx = getContext and getContext() or nil
                if ctx and ctx.Widgets and ctx.Widgets.RenderPreviewInventory then
                    ctx.Widgets.RenderPreviewInventory()
                end
            end
            local ctx = getContext and getContext() or nil
            if ctx and ctx.Timer and ctx.Timer.Start then
                ctx.Timer.Start("PreviewSlotReject_" .. tostring(index), 0, immediateClear)
            else
                immediateClear()
            end
            if state then
                state.PreviewDragItemHandle = nil
                state.PreviewDragSourceIndex = nil
                state.ForgeDragItemHandle = nil
                state.ForgeDragSourceSlotId = nil
            end
            return
        end

        local sourceIndex = state and state.PreviewDragSourceIndex or nil
        local sourceHandle = state and state.PreviewDragItemHandle or nil
        local isPreviewDrag = sourceIndex ~= nil and sourceHandle ~= nil and sourceHandle == dropHandle
        local forgeSourceSlotId = state and state.ForgeDragSourceSlotId or nil
        local forgeSourceHandle = state and state.ForgeDragItemHandle or nil
        local isForgeDrag = forgeSourceSlotId ~= nil and forgeSourceHandle ~= nil and forgeSourceHandle == dropHandle
        if isPreviewDrag and sourceIndex ~= index then
            local targetHandle = state and state.PreviewSlotItems and state.PreviewSlotItems[index] or nil
            if targetHandle and targetHandle ~= dropHandle then
                if assignPreviewSlot then
                    assignPreviewSlot(index, item or {Handle = dropHandle})
                    assignPreviewSlot(sourceIndex, {Handle = targetHandle})
                end
            else
                if assignPreviewSlot then
                    assignPreviewSlot(index, item or {Handle = dropHandle})
                end
            end
        elseif isForgeDrag then
            local targetHandle = state and state.PreviewSlotItems and state.PreviewSlotItems[index] or nil
            local sourcePreviewIndex = state and state.PreviewItemToSlot and state.PreviewItemToSlot[dropHandle] or nil
            if assignPreviewSlot then
                assignPreviewSlot(index, item or {Handle = dropHandle})
                if targetHandle and sourcePreviewIndex and sourcePreviewIndex ~= index and targetHandle ~= dropHandle then
                    assignPreviewSlot(sourcePreviewIndex, {Handle = targetHandle})
                end
            end
            local sourceSlot = state and state.ForgeSlots and state.ForgeSlots[forgeSourceSlotId] or nil
            if sourceSlot then
                if targetHandle and targetHandle ~= dropHandle then
                    local targetItem = getItemFromHandle and getItemFromHandle(targetHandle) or nil
                    local canSwap = targetItem ~= nil
                    if canSwap and canAcceptItem and not canAcceptItem(forgeSourceSlotId, targetItem, nil) then
                        canSwap = false
                    end
                    if canSwap then
                        if sourceSlot.SetItem then
                            sourceSlot:SetItem(targetItem)
                            if sourceSlot.SetEnabled then
                                sourceSlot:SetEnabled(true)
                            end
                        end
                        if assignSlotItem then
                            assignSlotItem(forgeSourceSlotId, sourceSlot, targetItem)
                        end
                        if updateSlotDetails then
                            updateSlotDetails(forgeSourceSlotId, targetItem)
                        end
                    else
                        if sourceSlot.Clear then
                            sourceSlot:Clear()
                            if sourceSlot.SetEnabled then
                                sourceSlot:SetEnabled(true)
                            end
                        end
                        if assignSlotItem then
                            assignSlotItem(forgeSourceSlotId, sourceSlot, nil)
                        end
                        if updateSlotDetails then
                            updateSlotDetails(forgeSourceSlotId, nil)
                        end
                    end
                else
                    if sourceSlot.Clear then
                        sourceSlot:Clear()
                        if sourceSlot.SetEnabled then
                            sourceSlot:SetEnabled(true)
                        end
                    end
                    if assignSlotItem then
                        assignSlotItem(forgeSourceSlotId, sourceSlot, nil)
                    end
                    if updateSlotDetails then
                        updateSlotDetails(forgeSourceSlotId, nil)
                    end
                end
            end
        else
            if assignPreviewSlot then
                if item and item.Handle then
                    assignPreviewSlot(index, item)
                else
                    assignPreviewSlot(index, {Handle = dropHandle})
                end
            end
        end
        if state then
            state.PreviewDragItemHandle = nil
            state.PreviewDragSourceIndex = nil
            state.ForgeDragItemHandle = nil
            state.ForgeDragSourceSlotId = nil
        end
        local ctx = getContext and getContext() or nil
        if ctx and ctx.Widgets and ctx.Widgets.RenderPreviewInventory then
            ctx.Widgets.RenderPreviewInventory()
        end
        if playSound then
            playSound((ctx and ctx.PREVIEW_DROP_SOUND) or defaultDropSound)
        end
    end

    local function WirePreviewSlot(index, slot)
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
                HandlePreviewSlotDrop(index, slot, ev)
            end)
        end
        if slot.SlotElement and slot.SlotElement.Events and slot.SlotElement.Events.DragStarted then
            slot.SlotElement.Events.DragStarted:Subscribe(function ()
                local handle = (state and state.PreviewSlotItems and state.PreviewSlotItems[index])
                    or (resolveSlotItemHandle and resolveSlotItemHandle(slot))
                if state then
                    state.PreviewDragItemHandle = handle
                    state.PreviewDragSourceIndex = index
                    state.ForgeDragItemHandle = nil
                    state.ForgeDragSourceSlotId = nil
                end
                if clearSlotHighlight then
                    clearSlotHighlight(slot)
                end
                if state and state.LastPreviewHoverSlot == slot then
                    state.LastPreviewHoverSlot = nil
                end
            end)
        end
        if slot.SlotElement and slot.SlotElement.Events then
            if slot.Events and slot.Events.MouseOver then
                slot.Events.MouseOver:Subscribe(function ()
                    if handlePreviewSlotHover then
                        handlePreviewSlotHover(slot)
                    end
                end, {Priority = 200, StringID = "ForgingUI_PreviewTooltipOver"})
            end
            if slot.SlotElement.Events.MouseMove then
                slot.SlotElement.Events.MouseMove:Subscribe(function ()
                    if not slot._PreviewTooltipVisible and showPreviewSlotTooltip then
                        showPreviewSlotTooltip(slot)
                    end
                end, {Priority = 200, StringID = "ForgingUI_PreviewTooltipMove"})
            end
            if slot.Events and slot.Events.MouseOut then
                slot.Events.MouseOut:Subscribe(function ()
                    if hidePreviewSlotTooltip then
                        hidePreviewSlotTooltip(slot)
                    end
                    if clearSlotHighlight then
                        clearSlotHighlight(slot)
                    end
                    if state and state.LastPreviewHoverSlot == slot then
                        state.LastPreviewHoverSlot = nil
                    end
                end, {Priority = 200, StringID = "ForgingUI_PreviewTooltipOut"})
            end
            if slot.SlotElement.Events.MouseOver then
                slot.SlotElement.Events.MouseOver:Subscribe(function ()
                    if handlePreviewSlotHoverHighlight then
                        handlePreviewSlotHoverHighlight(slot)
                    end
                end, {Priority = 190, StringID = "ForgingUI_PreviewHoverHighlight"})
            end
            if slot.SlotElement.Events.MouseOut then
                slot.SlotElement.Events.MouseOut:Subscribe(function ()
                    if clearSlotHighlight then
                        clearSlotHighlight(slot)
                    end
                    if state and state.LastPreviewHoverSlot == slot then
                        state.LastPreviewHoverSlot = nil
                    end
                end, {Priority = 190, StringID = "ForgingUI_PreviewHoverHighlightOut"})
            end
        end
        slot._PreviewInventoryBound = true
        if state and state.PreviewSlots then
            state.PreviewSlots[index] = slot
        end
    end

    local function RefreshInventoryHighlights()
        if syncForgeSlots then
            syncForgeSlots()
        end

        local preview = state and state.PreviewInventory or nil
        if not preview or not preview.Slots then
            return
        end

        for _, slot in ipairs(preview.Slots) do
            if slot then
                local handle = resolveSlotItemHandle and resolveSlotItemHandle(slot) or nil
                local overlay = ensureOverlay and ensureOverlay(slot) or nil
                if overlay and overlay.SetVisible then
                    overlay:SetVisible(handle ~= nil and state.ItemToSlot[handle] ~= nil)
                end
            end
        end
    end

    return {
        HandlePreviewSlotDrop = HandlePreviewSlotDrop,
        WirePreviewSlot = WirePreviewSlot,
        RefreshInventoryHighlights = RefreshInventoryHighlights,
    }
end

return PreviewSlotHandlers
