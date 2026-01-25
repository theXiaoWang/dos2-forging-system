-- Client/ForgingUI/State/LayoutState.lua
-- Runtime layout state for the Forging System UI (data-only).

local LayoutState = {}

function LayoutState.Create(baseWidth, baseHeight)
    return {
        Width = baseWidth,
        Height = baseHeight,
        ScaleX = 1,
        ScaleY = 1,
    }
end

return LayoutState

