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
    SlotPanelHeightMultiplier = 1.1,

    -- Extra height added to Main/Donor panels (scaled by ScaleY).
    SlotPanelHeightBoostY = 20,

    -- Base vertical offset for Main/Donor panels (scaled by ScaleY).
    -- Negative values move panels upward.
    SlotPanelOffsetYBase = 0,

    -- Vertical offset for Main/Donor header text (scaled by ScaleY).
    -- Smaller values move the label upward.
    SlotPanelHeaderOffsetY = 25,

    -- Base vertical offset for the Preview panel (scaled by ScaleY).
    -- Positive values move the Preview panel downward; negative values move it up.
    PreviewPanelOffsetY = 0,

    -- Override UI target width ratio (0-1). Lower values shrink the overall forge panel width.
    TargetWidthRatioOverride = 0.76,

    -- Hide the left info panel and collapse its space.
    HideInfoPanel = true,

    -- Adjust the left info panel width to free space for Main/Donor panels (scaled by ScaleX).
    -- Negative values make the info panel narrower.
    InfoPanelWidthAdjustX = -120,

    -- Width ratio for Main/Donor slot panels within the mid column (unitless).
    SlotPanelWidthRatio = 0.28,

    -- Gap between the inner sections inside Main/Donor panels (scaled by ScaleY).
    SlotSectionGapY = 6,

    -- Gap between item name/rarity/level lines (scaled by ScaleY).
    SlotItemInfoGapY = 0,

    -- Width reduction applied to inner sections inside Main/Donor panels (scaled by ScaleX).
    -- Positive values make sections narrower by reducing width from both sides.
    SlotSectionWidthReductionX = 70,

    -- Horizontal padding inside section bodies (scaled by ScaleX).
    SlotSectionInnerPaddingX = 8,

    -- Vertical padding inside section bodies (scaled by ScaleY).
    SlotSectionInnerPaddingY = 13,

    -- Trim applied to the total height budget for the four inner sections (scaled by ScaleY).
    -- Positive values make all four sections shorter.
    SlotSectionHeightTrimY = 80,

    -- Scale applied to the Granted Skills section height (unitless).
    -- Lower values make the Skills section shorter.
    SlotSectionSkillsHeightScale = 0.8,

    -- Max size for the Donor skillbook slot (scaled by ScaleY).
    SlotSectionSkillbookSlotMaxSizeY = 70,

    -- Vertical margin reserved around the Donor skillbook slot (scaled by ScaleY).
    SlotSectionSkillbookSlotMarginY = 16,

    -- Horizontal gap between Main/Preview/Donor panels (scaled by ScaleX).
    -- Negative values overlap panels to remove seams.
    ColumnGapX = -20,

    -- Main/Donor panel width expansion (scaled by ScaleX).
    -- This expands both sides by default to close the gaps between panels.
    SlotPanelWidthBoostX = 8,

    -- Extra width applied to the Donor panel only, on its outer (right) edge (scaled by ScaleX).
    -- Use this to close any remaining gap against the right-side container border.
    DonorRightEdgeBoostX = 4,

    -- Keep TopBar above other panels so buttons always receive input.
    RaiseTopBarToFront = true,

    -- Extra padding added below the lowest child panel when sizing the base frame (scaled by ScaleY).
    -- Negative values lift the bottom edge upward.
    BaseFrameBottomPaddingY = -25,

    -- Align the base frame bottom to the Main/Donor panels (padding still applies).
    BaseFrameAlignToSlotPanels = true,

    -- Extra height added to Main/Donor panels only (scaled by ScaleY).
    SlotPanelExtraBottomY = 20,

    -- Shrink (positive) or expand (negative) the base frame horizontally (scaled by ScaleX).
    BaseFrameTrimX = 0,

    -- Base panel texture key from Client.Textures.GenericUI.TEXTURES.PANELS.
    BasePanelTexture = "SETTINGS_RIGHT",

    -- Original SETTINGS_RIGHT texture aspect ratio (width / height).
    BasePanelAspectRatio = 988 / 1008,

    -- Hide the base panel/background entirely without changing child layout.
    HideBasePanel = true,

    -- Uniform scale applied to the base frame size (unitless).
    BaseFrameScale = 1.03,

    -- Use transparent button textures for the top bar (navbar).
    TopBarTransparentButtons = false,

    -- Sliced frame style for the top bar (see SlicedTexture.STYLES).
    TopBarFrameStyle = "SimpleTooltip",

    -- Debug logging for top bar frame construction.
    TopBarDebug = true,

    -- Debug logging for slot details updates (item name/sections).
    DebugSlotDetails = true,

    -- Text color for inner section bodies (Base/Stats/Extra/Skills).
    -- Hex string without alpha; e.g. "000000" for black.
    InnerSectionTextColorHex = "000000",

    -- Top bar background fill (navbar). Set alpha to 0 to disable.
    TopBarBackgroundColorHex = "000000",
    TopBarBackgroundAlpha = 0,

    -- Top bar sliced frame alpha (border/corners). Set alpha to 0 to hide the frame.
    TopBarFrameAlpha = 1,

    -- Top bar sliced frame center alpha. Set to 0 to make the center transparent.
    TopBarFrameCenterAlpha = 0,

    -- Top bar height (scaled by ScaleY).
    TopBarHeight = 55,

    -- Top bar button height (scaled by ScaleY).
    TopBarButtonHeight = 40,

    -- Top bar button padding from left/right edges (scaled by ScaleX).
    TopBarButtonPaddingX = 80,

    -- Extra inset for the close button (scaled by ScaleX). Defaults to TopBarButtonPaddingX.
    TopBarClosePaddingX = 10,

    -- Trim the top bar width on both sides (scaled by ScaleX).
    TopBarTrimX = 16,

    -- Shrink the draggable bounds horizontally (scaled by ScaleX).
    DragBoundsTrimX = 10,

    -- Offset the full canvas horizontally (scaled by ScaleX).
    CanvasOffsetX = -14,
}

return LayoutTuning
