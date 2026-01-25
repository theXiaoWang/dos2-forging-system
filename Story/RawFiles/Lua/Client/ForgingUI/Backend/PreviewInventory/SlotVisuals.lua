-- Client/ForgingUI/Backend/PreviewInventory/SlotVisuals.lua
-- Visual helpers for slot highlights/overlays.

local SlotVisuals = {}

---@param options table
function SlotVisuals.Create(options)
    local opts = options or {}
    local state = opts.state
    local getContext = opts.getContext
    local vector = opts.vector
    local showPreviewSlotTooltip = opts.showPreviewSlotTooltip

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
        if state and state.LastPreviewHoverSlot and state.LastPreviewHoverSlot ~= slot then
            ClearSlotHighlight(state.LastPreviewHoverSlot)
        end
        if state then
            state.LastPreviewHoverSlot = slot
        end
        if showPreviewSlotTooltip then
            showPreviewSlotTooltip(slot)
        end
    end

    local function HandlePreviewSlotHoverHighlight(slot)
        if state and state.LastPreviewHoverSlot and state.LastPreviewHoverSlot ~= slot then
            ClearSlotHighlight(state.LastPreviewHoverSlot)
        end
        if state then
            state.LastPreviewHoverSlot = slot
        end
        if slot and slot.SetHighlighted then
            slot:SetHighlighted(true)
        elseif slot and slot.SlotElement and slot.SlotElement.SetHighlighted then
            slot.SlotElement:SetHighlighted(true)
        end
    end

    local function HandleForgeSlotHover(slot)
        if state and state.LastForgeHoverSlot and state.LastForgeHoverSlot ~= slot then
            ClearSlotHighlight(state.LastForgeHoverSlot)
        end
        if state then
            state.LastForgeHoverSlot = slot
        end
    end

    local function ClearStaleHighlights()
        if not state then
            return
        end
        local preview = state.PreviewInventory
        if preview and preview.Slots then
            for _, slot in ipairs(preview.Slots) do
                if slot and slot ~= state.LastPreviewHoverSlot then
                    ClearSlotHighlight(slot)
                end
            end
        end
        for _, slot in pairs(state.ForgeSlots or {}) do
            if slot and slot ~= state.LastForgeHoverSlot then
                ClearSlotHighlight(slot)
            end
        end
    end

    local function EnsureOverlay(slot)
        local ctx = getContext and getContext() or nil
        if not slot or not slot.SlotElement or not ctx or not ctx.PREVIEW_USED_FRAME_TEXTURE then
            return nil
        end
        if slot._PreviewUsedOverlay then
            return slot._PreviewUsedOverlay
        end

        local root = slot.SlotElement
        local makeVector = vector or Vector.Create
        local size = root.GetSize and root:GetSize(true) or makeVector(0, 0)
        local overlay = root:AddChild(root.ID .. "_UsedOverlay", "GenericUI_Element_Texture")
        overlay:SetTexture(ctx.PREVIEW_USED_FRAME_TEXTURE, makeVector(size[1], size[2]))
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

    local function ResetSlotVisualState(slot)
        if not slot then
            return
        end
        local slotElement = slot.SlotElement or slot
        if slotElement and slotElement.GetMovieClip then
            local mc = slotElement:GetMovieClip()
            if mc then
                if mc.alpha ~= nil then
                    mc.alpha = 1
                end
                if mc.highlight_mc then
                    mc.highlight_mc.alpha = 0
                    mc.highlight_mc.visible = false
                end
                if mc.dropTarget_mc then
                    mc.dropTarget_mc.visible = false
                end
                if mc.dragOver_mc then
                    mc.dragOver_mc.visible = false
                end
                if mc.icon_mc and mc.icon_mc.alpha ~= nil then
                    mc.icon_mc.alpha = 1
                end
            end
        end
    end

    return {
        ClearSlotHighlight = ClearSlotHighlight,
        HandlePreviewSlotHover = HandlePreviewSlotHover,
        HandlePreviewSlotHoverHighlight = HandlePreviewSlotHoverHighlight,
        HandleForgeSlotHover = HandleForgeSlotHover,
        ClearStaleHighlights = ClearStaleHighlights,
        EnsureOverlay = EnsureOverlay,
        ResetSlotVisualState = ResetSlotVisualState,
    }
end

return SlotVisuals
