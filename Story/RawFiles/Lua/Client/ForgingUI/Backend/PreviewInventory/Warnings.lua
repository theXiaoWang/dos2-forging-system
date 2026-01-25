-- Client/ForgingUI/Backend/PreviewInventory/Warnings.lua
-- Warning text + slot flash helpers.

local Warnings = {}

---@param options table
function Warnings.Create(options)
    local opts = options or {}
    local state = opts.state
    local getContext = opts.getContext
    local getMonotonicTime = opts.getMonotonicTime
    local resolveForgeSlotMode = opts.resolveForgeSlotMode
    local getItemDisplayNameSafe = opts.getItemDisplayNameSafe
    local warningTextColor = opts.warningTextColor
    local warningTextSize = opts.warningTextSize
    local warningDisplaySeconds = opts.warningDisplaySeconds or 0
    local warningThrottleMs = opts.warningThrottleMs or 0
    local warningClearTimerId = opts.warningClearTimerId or "DropWarningClear"
    local warningSlotTimerPrefix = opts.warningSlotTimerPrefix or "DropSlotWarning_"

    local function FormatWarningText(message)
        if Text and Text.Format then
            local formatData = {Color = warningTextColor, Size = warningTextSize}
            if Text.FONTS and Text.FONTS.BOLD then
                formatData.FontType = Text.FONTS.BOLD
            end
            return Text.Format(message, formatData)
        end
        return message
    end

    local function SetWarningVisible(visible)
        local ctx = getContext and getContext() or nil
        local uiState = ctx and ctx.UIState or nil
        if not uiState then
            return
        end
        local label = uiState.WarningLabel
        if label and label.SetVisible then
            label:SetVisible(visible)
        end
        local bg = uiState.WarningBackground
        if bg and bg.SetVisible then
            bg:SetVisible(visible)
        end
    end

    local function UpdateWarningText(message)
        local ctx = getContext and getContext() or nil
        local uiState = ctx and ctx.UIState or nil
        if not uiState then
            return false
        end
        local label = uiState.WarningLabel
        if not label or not label.SetText then
            return false
        end
        label:SetText(FormatWarningText(message))
        return true
    end

    local function ShowWarning(message)
        if not message or message == "" then
            return
        end
        local ctx = getContext and getContext() or nil
        if not ctx or not ctx.UIState or not ctx.UIState.IsVisible then
            return
        end
        local now = getMonotonicTime and getMonotonicTime() or nil
        if state and now and state.LastWarningTime and (now - state.LastWarningTime) < warningThrottleMs then
            return
        end
        if state then
            state.LastWarningTime = now or state.LastWarningTime or 0
        end
        if not UpdateWarningText(message) then
            return
        end
        SetWarningVisible(true)
        if ctx and ctx.Timer and ctx.Timer.Start then
            ctx.Timer.Start(warningClearTimerId, warningDisplaySeconds, function ()
                SetWarningVisible(false)
            end)
        end
    end

    local function BuildDropWarningMessage(slotId, item)
        local slotMode = resolveForgeSlotMode and resolveForgeSlotMode(slotId) or nil
        local itemName = getItemDisplayNameSafe and getItemDisplayNameSafe(item) or nil
        if slotMode == "Skillbook" then
            if itemName and itemName ~= "" then
                return string.format("%s is not a skillbook", itemName)
            end
            return "Only skillbooks can be placed in this slot"
        end
        if slotMode == "Equipment" then
            if itemName and itemName ~= "" then
                return string.format("%s is not equipment", itemName)
            end
            return "Only equipment can be placed in this slot"
        end
        if itemName and itemName ~= "" then
            return string.format("%s cannot be placed here", itemName)
        end
        return "That item cannot be placed here"
    end

    local function ShowDropWarning(slotId, item)
        local message = BuildDropWarningMessage(slotId, item)
        if message then
            ShowWarning(message)
        end
    end

    local function FlashSlotWarning(slotId, slot)
        local element = slot and (slot.SlotElement or slot)
        if not element or not element.SetWarning then
            return
        end
        element:SetWarning(true)
        local ctx = getContext and getContext() or nil
        if ctx and ctx.Timer and ctx.Timer.Start then
            ctx.Timer.Start(warningSlotTimerPrefix .. tostring(slotId), 0.6, function ()
                if element.SetWarning then
                    element:SetWarning(false)
                end
            end)
        end
    end

    return {
        ShowWarning = ShowWarning,
        ShowDropWarning = ShowDropWarning,
        FlashSlotWarning = FlashSlotWarning,
    }
end

return Warnings
