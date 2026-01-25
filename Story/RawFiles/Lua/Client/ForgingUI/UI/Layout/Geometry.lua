-- Client/ForgingUI/UI/Layout/Geometry.lua
-- Calculates layout geometry values for the forging UI.

local Geometry = {}

---@param options table
function Geometry.Compute(options)
    local opts = options or {}
    local ctx = opts.ctx
    local canvasWidth = opts.canvasWidth
    local canvasHeight = opts.canvasHeight
    local scale = opts.scale or function(value) return value end
    local scaleX = opts.scaleX or function(value) return value end
    local scaleY = opts.scaleY or function(value) return value end
    local clamp = opts.clamp or function(value, minValue, maxValue)
        if value < minValue then
            return minValue
        end
        if value > maxValue then
            return maxValue
        end
        return value
    end

    if not ctx or not canvasWidth or not canvasHeight then
        return nil
    end

    local margin = scale(ctx.UI_OUTER_MARGIN or 0)
    local gap = scale(ctx.UI_PANEL_GAP or 0)
    -- Allow negative gap to close gaps between panels.
    local gapX = gap
    local topBarHeight = scaleY(40)
    local leftWidth = scaleX(400)
    local rightWidth = ctx.USE_SIDE_INVENTORY_PANEL and scaleX(480) or 0
    -- Height for Wiki + Result panels (positive increases height).
    local wikiResultHeightOffset = -30
    local bottomHeight = scaleY(260 + wikiResultHeightOffset)

    local topBarWidth = canvasWidth - margin * 2
    local contentTop = margin + topBarHeight + gap
    local contentHeight = canvasHeight - margin - contentTop
    local warningHeight = clamp(scaleY(24), 20, 28)
    local warningY = contentTop - warningHeight - scaleY(4)
    if warningY < (margin + topBarHeight) then
        warningY = margin + topBarHeight + scaleY(2)
    end
    local warningX = margin
    local warningWidth = canvasWidth - margin * 2

    local contentInsetX = scale(ctx.UI_CONTENT_INSET_X or 0)
    local rightXPos = canvasWidth - margin - rightWidth - contentInsetX
    local leftX = margin
    local midX = leftX + leftWidth + gapX + contentInsetX
    -- Don't subtract gapX from midWidth - already accounted for in midX.
    local midWidth = rightXPos - midX
    local midTopHeight = contentHeight - bottomHeight - gap
    local layoutTuning = ctx and ctx.LayoutTuning or nil
    -- Height multiplier for Main/Donor slot panels (1.0 = same as Preview, >1.0 = taller, <1.0 = shorter).
    local slotPanelHeightMultiplier = (layoutTuning and layoutTuning.SlotPanelHeightMultiplier) or 1.05
    local slotPanelHeightBoost = scaleY((layoutTuning and layoutTuning.SlotPanelHeightBoostY) or 20)
    local slotPanelHeight = math.floor(midTopHeight * slotPanelHeightMultiplier) + slotPanelHeightBoost
    -- Vertical offset to move Main/Donor panels up (negative values move up, positive move down).
    -- Keep the bottom edge steady while extending upward to close the top gap.
    local slotPanelOffsetY = ((layoutTuning and layoutTuning.SlotPanelOffsetYBase) or -11) - slotPanelHeightBoost
    -- Vertical offset for Info panel and Preview panel (positive moves down).
    local infoPanelOffsetY = 4
    local midBottomY = contentTop + midTopHeight + gap
    local columnGap = scale(ctx.UI_COLUMN_GAP or 0)
    local columnTotal = midWidth - columnGap * 2
    -- Main and Donor slots share the same width ratio (they use the same template).
    local slotPanelWidthRatio = 0.30
    local slotPanelWidth = math.floor(columnTotal * slotPanelWidthRatio)
    local previewWidth = columnTotal - slotPanelWidth * 2
    local baseMainX = midX
    local basePreviewX = baseMainX + slotPanelWidth + columnGap
    local baseDonorX = basePreviewX + previewWidth + columnGap
    local slotPanelWidthBoost = scaleX((layoutTuning and layoutTuning.SlotPanelWidthBoostX) or 16)
    local slotPanelWidthHalf = math.floor(slotPanelWidthBoost / 2)
    local donorRightEdgeBoost = scaleX((layoutTuning and layoutTuning.DonorRightEdgeBoostX) or 9)
    local mainWidth = slotPanelWidth + slotPanelWidthBoost
    local donorWidth = slotPanelWidth + slotPanelWidthBoost + donorRightEdgeBoost
    local mainX = baseMainX - slotPanelWidthHalf
    local previewX = basePreviewX
    local donorX = baseDonorX - slotPanelWidthHalf

    local columnConfigs = {
        {ID = "Main", Title = "Main Slot", Mode = "Main", X = mainX, Width = mainWidth, Texture = ctx.slotPanelTexture, Padding = scale(6)},
        {ID = "Donor", Title = "Donor Slot", Mode = "Donor", X = donorX, Width = donorWidth, Texture = ctx.slotPanelTexture, Padding = scale(6)},
        {ID = "Preview", Title = "", Mode = "Preview", X = previewX, Width = previewWidth, Texture = ctx.previewPanelTexture, Padding = scale(8)},
    }

    return {
        margin = margin,
        gap = gap,
        topBarHeight = topBarHeight,
        leftWidth = leftWidth,
        rightWidth = rightWidth,
        bottomHeight = bottomHeight,
        topBarWidth = topBarWidth,
        contentTop = contentTop,
        contentHeight = contentHeight,
        warningHeight = warningHeight,
        warningY = warningY,
        warningX = warningX,
        warningWidth = warningWidth,
        rightXPos = rightXPos,
        leftX = leftX,
        midX = midX,
        midWidth = midWidth,
        midTopHeight = midTopHeight,
        layoutTuning = layoutTuning,
        slotPanelHeight = slotPanelHeight,
        slotPanelOffsetY = slotPanelOffsetY,
        infoPanelOffsetY = infoPanelOffsetY,
        midBottomY = midBottomY,
        columnConfigs = columnConfigs,
    }
end

return Geometry
