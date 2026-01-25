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

    local function GetFlashNumber(obj, ...)
        if not obj then
            return nil
        end
        for i = 1, select("#", ...) do
            local key = select(i, ...)
            local value = obj[key]
            if type(value) == "number" then
                return value
            end
        end
        return nil
    end

    local function ResolveOverlayBounds(root, ctx, makeVector)
        local size = root.GetSize and root:GetSize(true) or makeVector(0, 0)
        local x = 0
        local y = 0
        local width = size[1]
        local height = size[2]
        local mc = root.GetMovieClip and root:GetMovieClip() or nil
        local highlight = mc and (mc.highlight_mc or mc.frame_mc or mc.dragOver_mc or mc.dropTarget_mc) or nil
        if highlight then
            local hWidth = GetFlashNumber(highlight, "width", "_width")
            local hHeight = GetFlashNumber(highlight, "height", "_height")
            if hWidth and hHeight and hWidth > 0 and hHeight > 0 then
                width = hWidth
                height = hHeight
                x = GetFlashNumber(highlight, "x", "_x") or x
                y = GetFlashNumber(highlight, "y", "_y") or y
            end
        end
        local offsetX = (ctx and ctx.PREVIEW_USED_FRAME_OFFSET_X) or 0
        local offsetY = (ctx and ctx.PREVIEW_USED_FRAME_OFFSET_Y) or 0
        local sizeDelta = (ctx and ctx.PREVIEW_USED_FRAME_SIZE_DELTA) or 0
        if sizeDelta ~= 0 then
            local half = sizeDelta / 2
            x = x - half
            y = y - half
            width = width + sizeDelta
            height = height + sizeDelta
        end
        x = x + offsetX
        y = y + offsetY
        return x, y, width, height
    end

    local function EnsureOverlay(slot)
        local ctx = getContext and getContext() or nil
        if not slot or not slot.SlotElement or not ctx or not ctx.PREVIEW_USED_FRAME_TEXTURE then
            return nil
        end

        local root = slot.SlotElement
        local makeVector = vector or Vector.Create
        local overlay = slot._PreviewUsedOverlay
        local x, y, width, height = ResolveOverlayBounds(root, ctx, makeVector)
        if not overlay then
            overlay = root:AddChild(root.ID .. "_UsedOverlay", "GenericUI_Element_Texture")
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
        end
        if overlay.SetTexture then
            overlay:SetTexture(ctx.PREVIEW_USED_FRAME_TEXTURE, makeVector(width, height))
        end
        if overlay.SetSize then
            overlay:SetSize(width, height)
        end
        if overlay.SetPosition then
            overlay:SetPosition(x, y)
        end
        if overlay.SetAlpha and ctx.PREVIEW_USED_FRAME_ALPHA ~= nil then
            overlay:SetAlpha(ctx.PREVIEW_USED_FRAME_ALPHA)
        end
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
