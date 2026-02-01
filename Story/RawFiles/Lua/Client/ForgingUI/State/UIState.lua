-- Client/ForgingUI/State/UIState.lua
-- Runtime UI state for the Forging System UI (data-only).

local UIState = {}

function UIState.Create()
    return {
        IsVisible = false,
        PendingShowAfterBuild = false,
        ToggleUIInstance = nil,
        EscHooked = false,
        ViewportHooked = false,
        ToggleReady = false,
        TogglePositionRevision = 0,
        ToggleReadyRevision = 0,
        ToggleScale = nil,
        LastGameState = nil,
        WarningLabel = nil,
        WarningBackground = nil,
        DragBoundsWidth = 0,
        DragBoundsHeight = 0,
        ItemNameOverrides = {},
        NameEditActiveSlotId = nil,
    }
end

return UIState

