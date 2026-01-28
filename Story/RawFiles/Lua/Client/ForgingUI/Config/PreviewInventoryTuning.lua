-- Client/ForgingUI/Config/PreviewInventoryTuning.lua
-- Tuning knobs for the custom Preview Inventory panel (center column).
--
-- Notes:
-- - `*X` / `*Y` values are in base UI pixels and should be scaled via `Layout.ScaleX/Y()`.
-- - Clamp bounds are unscaled unless explicitly noted; they should match the existing UI behavior.

local PreviewInventoryTuning = {
    -- Grid layout
    -- Increase this to 10 if you want 10 slots per row.
    GridColumns = 10,
    -- Cap the auto-fit spacing between slots (scaled via Layout.Scale).
    -- This keeps gaps small without allowing overlap.
    GridSpacingMaxX = -11,
    -- Grid spacing between slots (scaled via Layout.Scale).
    -- Leave nil to auto-fit based on panel width.

    -- Search bar
    SearchPlaceholderText = "Type to search...",
    SearchMinWidthX = 90,
    SearchMinWidthMin = 70,
    SearchMinWidthMax = 120,
    SearchDesiredWidthX = 210,
    SearchDesiredWidthMax = 320,
    SearchTextPaddingX = 6,
    SearchTextPaddingMin = 4,
    SearchTextPaddingMax = 10,

    -- Sort/Filter buttons
    SortButtonWidthX = 88,
    SortButtonWidthMin = 70,
    SortButtonWidthMax = 110,

    -- Misc padding
    RowBackgroundPadX = 9,
    RowBackgroundPadMin = 8,
    RowBackgroundPadMax = 13,

    -- Scrollbar
    ScrollBarPaddingX = 6,
    ScrollBarPaddingMin = 4,
    ScrollBarPaddingMax = 10,
    ScrollHandleWidthX = 12,
    ScrollHandleWidthMin = 10,
    ScrollHandleWidthMax = 16,
    ScrollTrackPaddingX = 4,
    ScrollTrackPaddingMin = 2,
    ScrollTrackPaddingMax = 6,
}

return PreviewInventoryTuning
