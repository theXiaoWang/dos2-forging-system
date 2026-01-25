-- Client/ForgingUI/Config/UIConstants.lua
-- Global UI constants for the Forging System UI.
--
-- This file is intentionally "data-only":
-- - Use plain numbers/strings/booleans.
-- - Do not call into `Ext`, `Color`, `Vector`, or UI APIs here.
--
-- All values are interpreted in "base UI pixels" unless noted otherwise.

local UIConstants = {
    -- Base UI size (used as the reference resolution for scaling).
    BaseWidth = 1710,
    BaseHeight = 950,

    -- Target size relative to viewport (before UI scale multiplier).
    TargetWidthRatio = 0.80,
    TargetHeightRatio = 0.95,

    -- Global spacing.
    OuterMargin = 8,
    PanelGap = -10,
    ColumnGap = -10,
    ContentInsetX = 0,

    -- Toggle button positioning (screen-space; scaled by viewport scale).
    ToggleOffsetX = -70,
    ToggleOffsetY = 0,

    -- Feature flags.
    UseTextureBackground = false,
    UseBaseBackground = false,
    UseSlicedBase = true,
    UseSlicedFrames = true,
    UseSlicedPanels = true,
    UseVanillaCombinePanel = false,
    UseSideInventoryPanel = false,
    UseCustomPreviewPanel = true,

    -- Rendering/refresh.
    PreviewRefreshInterval = 0.5,

    -- Visual tuning.
    BorderSize = 1,
    FrameAlpha = 1,
    FrameTextureAlpha = 1,
    FrameTextureCenterAlpha = 0.85,
    PanelFillAlpha = 0,
    PanelTextureAlpha = 0.5,
    SlotPanelTextureAlpha = 1,
    PreviewUsedFrameAlpha = 1,
    BasePanelAlpha = 0.85,
    SectionFrameAlpha = 0.5,
    SectionTextureCenterAlpha = 0.2,
    SectionFillAlpha = 0.25,

    -- Colors (hex strings).
    Colors = {
        Border = "2F2720",
        Fill = "1A1613",
        HeaderFill = "24201B",
        Grid = "1E1A16",
        PreviewFill = "000000",
    },

    -- Text styling.
    TextColor = 0xFFD700,
    HeaderTextSize = 13,
    BodyTextSize = 11,

    -- Audio.
    PreviewDropSound = "UI_Game_PartyFormation_PickUp",
}

return UIConstants

