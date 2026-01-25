-- Client/ForgingUI/Config/LayoutTuning.lua
-- UI layout tuning knobs for the Forging System UI.
--
-- These values are intentionally centralized and documented so future UI iteration
-- can be done without spelunking through the full layout builder.
--
-- Notes:
-- - Values ending in `X` or `Y` are in "base UI pixels" and should be scaled using
--   `Layout.ScaleX()` / `Layout.ScaleY()` in the layout builder.
-- - Ratios/multipliers are unitless and should not be scaled.
--
-- If you are adjusting spacing:
-- - Prefer small increments (2–6) and test in-game at multiple resolutions.
-- - When increasing `SlotPanelHeightBoostY`, the code keeps the bottom edge stable
--   by moving the panel up by the same amount.

local LayoutTuning = {
    -- Main/Donor panel height behavior:
    -- 1.0 = same height as Preview panel (before boost).
    SlotPanelHeightMultiplier = 1.05,

    -- Extra height added to Main/Donor panels (scaled by ScaleY).
    SlotPanelHeightBoostY = 20,

    -- Base vertical offset for Main/Donor panels (scaled by ScaleY).
    -- Negative values move panels upward.
    SlotPanelOffsetYBase = -11,

    -- Main/Donor panel width expansion (scaled by ScaleX).
    -- This expands both sides by default to close the gaps between panels.
    SlotPanelWidthBoostX = 16,

    -- Extra width applied to the Donor panel only, on its outer (right) edge (scaled by ScaleX).
    -- Use this to close any remaining gap against the right-side container border.
    DonorRightEdgeBoostX = 9,

    -- Keep TopBar above other panels so buttons always receive input.
    RaiseTopBarToFront = true,
}

return LayoutTuning
