-- Client/ForgingUI/UI/SlotDetails.lua
-- Slot details rendering for Main/Donor panels.

local SlotDetails = {}
local getContextCallback = nil
local tooltipHooked = false
local RENAME_NET_CHANNEL = "ForgingUI_RenameItem"
local slotsRef = nil
local globalBlurHooked = false

local function GetContext()
    return getContextCallback and getContextCallback() or nil
end

local function NormalizePlainText(value)
    if value == nil then
        return ""
    end
    local text = tostring(value)
    if Text and Text.StripFontTags then
        text = Text.StripFontTags(text)
    end
    return text
end

local function TrimText(value)
    local text = NormalizePlainText(value)
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function ReplaceTooltipLabelText(label, text)
    if type(label) ~= "string" then
        return text
    end
    local pOpen, pInner, pClose = label:match("^(<p[^>]*>)(.*)(</p>)$")
    if pOpen and pClose then
        local fOpen, _, fClose = pInner:match("^(<font[^>]*>)(.*)(</font>)$")
        if fOpen and fClose then
            return pOpen .. fOpen .. text .. fClose .. pClose
        end
        return pOpen .. text .. pClose
    end
    local fOpen, _, fClose = label:match("^(<font[^>]*>)(.*)(</font>)$")
    if fOpen and fClose then
        return fOpen .. text .. fClose
    end
    return text
end

local function ApplyTooltipNameOverride(ev)
    local ctx = GetContext()
    local uiState = ctx and ctx.UIState or nil
    if not uiState or not uiState.ItemNameOverrides then
        return
    end
    local item = ev and ev.Item or nil
    local handle = item and item.Handle or nil
    if handle == nil then
        return
    end
    local override = uiState.ItemNameOverrides[handle]
    if override == nil or override == "" then
        return
    end
    local tooltip = ev and ev.Tooltip or nil
    if not tooltip or not tooltip.GetFirstElement then
        return
    end
    local itemName = tooltip:GetFirstElement("ItemName")
    if not itemName or not itemName.Label then
        return
    end
    local clean = NormalizePlainText(override)
    if clean == "" then
        return
    end
    itemName.Label = ReplaceTooltipLabelText(itemName.Label, clean)
end

local function EnsureTooltipHook()
    if tooltipHooked then
        return
    end
    if Client and Client.Tooltip and Client.Tooltip.Hooks and Client.Tooltip.Hooks.RenderItemTooltip then
        Client.Tooltip.Hooks.RenderItemTooltip:Subscribe(ApplyTooltipNameOverride, {StringID = "ForgingUI_NameOverrideTooltip"})
        tooltipHooked = true
    end
end

local function GetElementScreenBounds(element)
    if not element or not element.GetScreenPosition or not element.GetSize then
        return nil
    end
    local pos = element:GetScreenPosition(false)
    if not pos then
        return nil
    end
    local size = element:GetSize()
    local uiObj = element.UI and element.UI.GetUI and element.UI:GetUI() or nil
    local scale = uiObj and uiObj:GetUIScaleMultiplier() or 1
    return pos[1], pos[2], (size[1] or 0) * scale, (size[2] or 0) * scale
end

local function IsPointInsideElement(element, x, y)
    local ex, ey, ew, eh = GetElementScreenBounds(element)
    if not ex then
        return false
    end
    return x >= ex and x <= (ex + ew) and y >= ey and y <= (ey + eh)
end

local function HandleGlobalNameEditClick()
    local ctx = GetContext()
    local uiState = ctx and ctx.UIState or nil
    if not uiState or not uiState.IsVisible then
        return
    end
    local slotId = uiState.NameEditActiveSlotId
    if not slotId or not slotsRef then
        return
    end
    local slot = slotsRef[slotId]
    if not slot or not slot.NameInput or not slot.NameInput.SetFocused then
        return
    end
    local isFocused = slot.NameInput.IsFocused and slot.NameInput:IsFocused()
    if not isFocused then
        return
    end
    if not Client or not Client.GetMousePosition then
        slot.NameInput:SetFocused(false)
        return
    end
    local x, y = Client.GetMousePosition()
    if not x or not y then
        slot.NameInput:SetFocused(false)
        return
    end
    if IsPointInsideElement(slot.NameInput, x, y) then
        return
    end
    slot.NameInput:SetFocused(false)
end

local function EnsureGlobalBlurHook()
    if globalBlurHooked then
        return
    end
    if Ext and Ext.Events and Ext.Events.RawInput then
        Ext.Events.RawInput:Subscribe(function(ev)
            local inputEvent = ev and ev.Input or nil
            local input = inputEvent and inputEvent.Input or nil
            local value = inputEvent and inputEvent.Value or nil
            if not input or not value then
                return
            end
            if value.State ~= "Pressed" then
                return
            end
            local id = tostring(input.InputId or "")
            if id == "" then
                return
            end
            if id == "left2" or id == "right2" or id == "middle" then
                HandleGlobalNameEditClick()
            end
        end, {StringID = "ForgingUI_NameEditGlobalBlur"})
        globalBlurHooked = true
    end
end

local function EstimateTextWidth(text, size)
    local plain = NormalizePlainText(text)
    local approxCharWidth = math.max(5, math.floor((size or 12) * 0.6))
    return #plain * approxCharWidth
end

local function GetElementTextWidth(element, text, size, forceEstimate)
    if not forceEstimate and element and element.GetMovieClip then
        local mc = element:GetMovieClip()
        local field = mc and mc.text_txt or nil
        if field then
            local width = field.textWidth or field._width or field.width
            if type(width) == "number" and width > 0 then
                return width
            end
        end
    end
    return EstimateTextWidth(text, size)
end

local function GetNameEditWindowChars(slot, size)
    local windowChars = 20
    local ctx = GetContext()
    local tuning = ctx and ctx.LayoutTuning or nil
    if tuning and tuning.SlotItemNameEditWindowChars ~= nil then
        local tuned = tonumber(tuning.SlotItemNameEditWindowChars)
        if tuned and tuned > 0 then
            windowChars = math.floor(tuned)
        end
    end
    if not slot or not slot.NameLineWidth then
        return windowChars
    end
    local gap = slot.NameButtonGap or 2
    local buttonSize = slot.NameButtonSize or 12
    local maxWidth = slot.NameLineWidth - (buttonSize * 2 + gap) - gap
    if maxWidth > 0 then
        local approxCharWidth = math.max(5, math.floor((size or 12) * 0.6))
        local maxChars = math.max(1, math.floor(maxWidth / approxCharWidth))
        if windowChars > maxChars then
            windowChars = maxChars
        end
    end
    if windowChars < 1 then
        windowChars = 1
    end
    return windowChars
end

local function GetNameEditMaxChars(slot)
    local maxChars = 40
    local ctx = GetContext()
    local tuning = ctx and ctx.LayoutTuning or nil
    if tuning and tuning.SlotItemNameEditMaxChars ~= nil then
        local tuned = tonumber(tuning.SlotItemNameEditMaxChars)
        if tuned and tuned > 0 then
            maxChars = math.floor(tuned)
        end
    end
    if maxChars < 1 then
        maxChars = 1
    end
    return maxChars
end

local function UpdateNameButtonsLayout(slot)
    if not slot then
        return
    end
    local editRoot = slot.NameEditButton and (slot.NameEditButton.Root or (slot.NameEditButton.GetRootElement and slot.NameEditButton:GetRootElement()) or nil) or nil
    local resetRoot = slot.NameResetButton and (slot.NameResetButton.Root or (slot.NameResetButton.GetRootElement and slot.NameResetButton:GetRootElement()) or nil) or nil
    if not editRoot or not resetRoot or not editRoot.SetPosition or not resetRoot.SetPosition then
        return
    end
    local lineX = slot.NameLineX
    local lineWidth = slot.NameLineWidth
    if lineX == nil or lineWidth == nil then
        return
    end
    local lineHeight = slot.NameLineHeight or 0
    local size = slot.NameTextSize or 12
    local textValue = nil
    if slot.IsEditingName and slot.EditBaseText ~= nil then
        textValue = slot.EditBaseText
    else
        textValue = slot.CurrentNameText or ""
    end
    if textValue == "" then
        textValue = slot.BaseNameText or ""
    end
    local sourceElement = slot.IsEditingName and slot.NameInput or slot.NameLabel
    local forceEstimate = slot.IsEditingName == true
    local textWidth = GetElementTextWidth(sourceElement, textValue, size, forceEstimate)
    local gap = slot.NameButtonGap or 2
    local buttonSize = slot.NameButtonSize or 12
    local buttonsWidth = buttonSize * 2 + gap
    if slot.IsEditingName and slot.NameButtonsLocked and slot.NameButtonsLockedX ~= nil and slot.NameButtonsLockedY ~= nil then
        editRoot:SetPosition(slot.NameButtonsLockedX, slot.NameButtonsLockedY)
        resetRoot:SetPosition(slot.NameButtonsLockedX + buttonSize + gap, slot.NameButtonsLockedY)
        return
    end
    local centerX = lineX + lineWidth / 2
    local targetX = math.floor(centerX + (textWidth / 2) + gap)
    local maxX = lineX + lineWidth - buttonsWidth
    if targetX > maxX then
        targetX = maxX
    end
    if targetX < lineX then
        targetX = lineX
    end
    local lineY = slot.NameLineY or 0
    local targetY = lineY + math.floor((lineHeight - buttonSize) / 2)
    if not slot.IsEditingName then
        slot.NameButtonsX = targetX
        slot.NameButtonsY = targetY
    end
    editRoot:SetPosition(targetX, targetY)
    resetRoot:SetPosition(targetX + buttonSize + gap, targetY)
end

local function GetItemByHandle(handle)
    if handle == nil then
        return nil
    end
    if Item and Item.Get then
        local ok, item = pcall(Item.Get, handle)
        if ok and item then
            return item
        end
    end
    if Ext and Ext.Entity and Ext.Entity.GetItem then
        local ok, item = pcall(Ext.Entity.GetItem, handle)
        if ok and item then
            return item
        end
    end
    return nil
end

local function GetItemDisplayName(item)
    if not item then
        return nil
    end
    if Item and Item.GetDisplayName then
        local ok, name = pcall(Item.GetDisplayName, item)
        if ok and name and name ~= "" then
            return name
        end
    end
    local displayName = item.DisplayName
    if displayName and displayName ~= "" then
        return displayName
    end
    return nil
end

local function SetClientCustomDisplayName(item, text)
    if not item then
        return false
    end
    local custom = item.CustomDisplayName
    if custom and custom.Handle then
        if Text and Text.UNKNOWN_HANDLE then
            custom.Handle.Handle = Text.UNKNOWN_HANDLE
        end
        custom.Handle.ReferenceString = text or ""
        return true
    end
    local ok = pcall(function()
        item.CustomDisplayName = text or ""
    end)
    return ok == true
end

local function SendRenameToServer(item, text)
    if not item or not item.NetID then
        return
    end
    if Ext and Ext.Net and Ext.Net.PostMessageToServer and Ext.Json and Ext.Json.Stringify then
        local payload = Ext.Json.Stringify({
            ItemNetID = item.NetID,
            NewName = text or "",
        })
        Ext.Net.PostMessageToServer(RENAME_NET_CHANNEL, payload)
    end
end

local function ApplyItemCustomName(handle, text)
    local item = GetItemByHandle(handle)
    if not item then
        return nil
    end
    SetClientCustomDisplayName(item, text)
    SendRenameToServer(item, text)
    return item
end

---@param options table
function SlotDetails.Create(options)
    local opts = options or {}
    getContextCallback = opts.getContext or getContextCallback

    local slots = {}
    slotsRef = slots
    EnsureTooltipHook()
    EnsureGlobalBlurHook()

    local function GetUIState()
        local ctx = GetContext()
        return ctx and ctx.UIState or nil
    end

    local function ParseHexColor(value, fallback)
        if not value then
            return fallback
        end
        if type(value) == "number" then
            return value
        end
        local hex = tostring(value):gsub("#", "")
        local num = tonumber("0x" .. hex)
        if num then
            return num
        end
        return fallback
    end

    local function NormalizeColorValue(value)
        if value == nil then
            return nil
        end
        if type(value) == "number" then
            return string.format("%06X", math.floor(value))
        end
        local text = tostring(value)
        text = text:gsub("^0x", ""):gsub("^0X", ""):gsub("#", "")
        return text
    end

    local function FormatText(text, size, colorOverride)
        local ctx = GetContext()
        if Text and Text.Format then
            local colorValue = NormalizeColorValue(colorOverride or (ctx and ctx.TEXT_COLOR) or 0xFFFFFF)
            return Text.Format(text or "", {
                Color = colorValue,
                Size = size or (ctx and ctx.BODY_TEXT_SIZE) or 12,
            })
        end
        return text or ""
    end

    local function SetLabelText(label, text, size, colorOverride)
        if not label or not label.SetText then
            return
        end
        label:SetText(FormatText(text, size, colorOverride))
    end

    local function GetButtonRoot(button)
        if not button then
            return nil
        end
        if button.Root then
            return button.Root
        end
        if button.GetRootElement then
            return button:GetRootElement()
        end
        return nil
    end

    local function GetNameOverride(handle)
        local uiState = GetUIState()
        if not uiState or not uiState.ItemNameOverrides or handle == nil then
            return nil
        end
        return uiState.ItemNameOverrides[handle]
    end

    local function SetNameOverride(handle, value)
        local uiState = GetUIState()
        if not uiState or handle == nil then
            return
        end
        uiState.ItemNameOverrides = uiState.ItemNameOverrides or {}
        if value == nil then
            uiState.ItemNameOverrides[handle] = nil
        else
            uiState.ItemNameOverrides[handle] = value
        end
    end

    local function SetNameInputText(slot, text, size)
        local input = slot and slot.NameInput
        if not input then
            return
        end
        local plain = NormalizePlainText(text)
        if input.SetText then
            input:SetText(plain)
        end
        local textSize = size or slot.NameTextSize or (GetContext() and GetContext().HEADER_TEXT_SIZE) or 12
        if input.SetTextFormat then
            input:SetTextFormat({color = 0x000000, size = textSize})
        end
        local mc = input.GetMovieClip and input:GetMovieClip() or nil
        if mc and mc.text_txt then
            mc.text_txt.textColor = 0x000000
        end
    end

    local function ApplyNameInputFormat(slot)
        local input = slot and slot.NameInput
        if not input then
            return
        end
        local textSize = slot.NameTextSize or (GetContext() and GetContext().HEADER_TEXT_SIZE) or 12
        if input.SetTextFormat then
            input:SetTextFormat({color = 0x000000, size = textSize})
        end
        local mc = input.GetMovieClip and input:GetMovieClip() or nil
        if mc and mc.text_txt then
            mc.text_txt.textColor = 0x000000
        end
    end

    local function SetNameEditVisible(slot, editing)
        if not slot then
            return
        end
        slot.IsEditingName = editing == true
        if slot.NameLabel and slot.NameLabel.SetVisible then
            slot.NameLabel:SetVisible(not slot.IsEditingName)
        end
        if slot.NameInput then
            if slot.NameInput.SetVisible then
                slot.NameInput:SetVisible(slot.IsEditingName)
            end
            if slot.NameInput.SetMouseEnabled then
                slot.NameInput:SetMouseEnabled(slot.IsEditingName)
            end
            if slot.NameInput.SetMouseChildren then
                slot.NameInput:SetMouseChildren(slot.IsEditingName)
            end
        end
    end

    local function QueueNameCaret(slot, text)
        local input = slot and slot.NameInput
        if not input or not input.GetMovieClip then
            return
        end
        local textValue = NormalizePlainText(text)
        local function ApplyCaret()
            local mc = input.GetMovieClip and input:GetMovieClip() or nil
            if mc and mc.text_txt and mc.text_txt.setSelection then
                local index = #textValue
                mc.text_txt.setSelection(index, index)
            end
        end
        ApplyCaret()
        if Timer and Timer.Start then
            Timer.Start("ForgingUI_NameEditCaret_" .. tostring(slot.SlotId or ""), 0.01, ApplyCaret)
        end
    end

    local function ApplyNameEditBounds(slot)
        local input = slot and slot.NameInput
        if not input or not input.SetSize or not input.SetPosition then
            return
        end
        local lineX = slot.NameLineX or 0
        local lineY = slot.NameLineY or 0
        local lineHeight = slot.NameLineHeight or 0
        local gap = slot.NameButtonGap or 2
        local buttonSize = slot.NameButtonSize or 12
        local buttonsWidth = buttonSize * 2 + gap
        local buttonX = slot.NameButtonsLockedX
        if buttonX == nil then
            local lineWidth = slot.NameLineWidth or 0
            buttonX = lineX + lineWidth - buttonsWidth
        end
        local rightEdge = buttonX - gap
        if rightEdge < lineX then
            rightEdge = lineX
        end
        local textSize = slot.NameTextSize or 12
        local windowChars = GetNameEditWindowChars(slot, textSize)
        local approxCharWidth = math.max(5, math.floor(textSize * 0.6))
        local desiredWidth = windowChars * approxCharWidth
        local maxWidth = rightEdge - lineX
        if maxWidth < 0 then
            maxWidth = 0
        end
        local width = desiredWidth
        if width > maxWidth then
            width = maxWidth
        end
        if width < 0 then
            width = 0
        end
        local inputX = rightEdge - width
        if inputX < lineX then
            inputX = lineX
        end
        input:SetPosition(inputX, lineY)
        input:SetSize(width, lineHeight)
        if input.SetType then
            input:SetType("Right")
        end
        slot.NameEditWindowWidth = width
    end

    local function ApplyNameEditWindow(slot)
        if not slot or not slot.NameInput then
            return
        end
        local fullText = NormalizePlainText(slot.NameEditText or "")
        local textSize = slot.NameTextSize or 12
        local windowChars = GetNameEditWindowChars(slot, textSize)
        if slot.NameEditWindowWidth and slot.NameEditWindowWidth > 0 then
            local approxCharWidth = math.max(5, math.floor(textSize * 0.6))
            local maxChars = math.max(1, math.floor(slot.NameEditWindowWidth / approxCharWidth))
            if windowChars > maxChars then
                windowChars = maxChars
            end
        end
        local visibleText = fullText
        if windowChars and windowChars > 0 and #fullText > windowChars then
            visibleText = fullText:sub(#fullText - windowChars + 1)
        end
        slot.NameEditVisibleText = visibleText
        slot.NameEditUpdating = true
        SetNameInputText(slot, visibleText, slot.NameTextSize or 12)
        slot.NameEditUpdating = false
        QueueNameCaret(slot, visibleText)
    end

    local function BeginNameEdit(slot)
        if not slot or not slot.NameInput or not slot.LastHandle then
            return
        end
        local ctx = GetContext()
        if ctx and ctx.Widgets and ctx.Widgets.UnfocusPreviewSearch then
            ctx.Widgets.UnfocusPreviewSearch()
        end
        local uiState = GetUIState()
        if uiState and uiState.NameEditActiveSlotId and uiState.NameEditActiveSlotId ~= slot.SlotId then
            local other = slots[uiState.NameEditActiveSlotId]
            if other and other.NameInput and other.NameInput.SetFocused then
                other.NameInput:SetFocused(false)
            end
        end
        local current = slot.CurrentNameText or slot.BaseNameText or ""
        slot.EditBaseText = current
        slot.NameEditText = current
        local maxChars = GetNameEditMaxChars(slot)
        if maxChars and #slot.NameEditText > maxChars then
            slot.NameEditText = slot.NameEditText:sub(1, maxChars)
        end
        if slot.NameButtonsX == nil or slot.NameButtonsY == nil then
            UpdateNameButtonsLayout(slot)
        end
        slot.NameButtonsLocked = true
        slot.NameButtonsLockedX = slot.NameButtonsX
        slot.NameButtonsLockedY = slot.NameButtonsY
        SetNameEditVisible(slot, true)
        ApplyNameEditBounds(slot)
        ApplyNameEditWindow(slot)
        if uiState then
            uiState.NameEditActiveSlotId = slot.SlotId
        end
        if slot.NameInput.SetFocused then
            slot.NameInput:SetFocused(true)
        end
        UpdateNameButtonsLayout(slot)
    end

    local function CommitNameEdit(slot)
        if not slot then
            return
        end
        local handle = slot.LastHandle
        if handle == nil then
            SetNameEditVisible(slot, false)
            slot.NameEditText = nil
            return
        end
        local trimmed = TrimText(slot.NameEditText or "")
        if trimmed == "" then
            trimmed = slot.EditBaseText or slot.CurrentNameText or slot.BaseNameText or ""
        end
        local maxChars = GetNameEditMaxChars(slot)
        if maxChars and #trimmed > maxChars then
            trimmed = trimmed:sub(1, maxChars)
        end
        SetNameOverride(handle, trimmed)
        if trimmed ~= "" then
            ApplyItemCustomName(handle, trimmed)
        end
        slot.BaseNameText = trimmed
        slot.CurrentNameText = trimmed
        SetLabelText(slot.NameLabel, trimmed, slot.NameTextSize or 12, 0x000000)
        SetNameEditVisible(slot, false)
        slot.NameEditText = nil
        slot.EditBaseText = nil
        slot.NameEditVisibleText = nil
        slot.NameEditUpdating = false
        slot.NameEditWindowWidth = nil
        slot.NameButtonsLocked = false
        slot.NameButtonsLockedX = nil
        slot.NameButtonsLockedY = nil
        UpdateNameButtonsLayout(slot)
        local uiState = GetUIState()
        if uiState and uiState.NameEditActiveSlotId == slot.SlotId then
            uiState.NameEditActiveSlotId = nil
        end
    end

    local function UnfocusNameEdit()
        for _, slot in pairs(slots) do
            if slot and slot.IsEditingName and slot.NameInput and slot.NameInput.SetFocused then
                local isFocused = slot.NameInput.IsFocused and slot.NameInput:IsFocused()
                if isFocused == false then
                    CommitNameEdit(slot)
                else
                    slot.NameInput:SetFocused(false)
                end
            end
        end
    end

    local function ResetNameOverride(slot)
        if not slot or slot.LastHandle == nil then
            return
        end
        SetNameOverride(slot.LastHandle, nil)
        local item = ApplyItemCustomName(slot.LastHandle, "")
        local baseName = item and GetItemDisplayName(item) or nil
        slot.CurrentNameText = baseName or slot.BaseNameText or ""
        slot.BaseNameText = slot.CurrentNameText
        SetLabelText(slot.NameLabel, slot.CurrentNameText, slot.NameTextSize or 12, 0x000000)
        slot.NameEditText = nil
        slot.EditBaseText = nil
        slot.NameEditVisibleText = nil
        slot.NameEditUpdating = false
        slot.NameEditWindowWidth = nil
        slot.NameButtonsLocked = false
        slot.NameButtonsLockedX = nil
        slot.NameButtonsLockedY = nil
        UpdateNameButtonsLayout(slot)
        if slot.IsEditingName and slot.NameInput and slot.NameInput.SetFocused then
            slot.NameEditSkipCommit = true
            slot.NameInput:SetFocused(false)
        end
    end

    local function EstimateLineCount(lines, bodyWidth, textSize)
        local width = bodyWidth or 200
        local size = textSize or 11
        local approxCharWidth = math.max(5, math.floor(size * 0.6))
        local maxChars = math.max(20, math.floor(width / approxCharWidth))
        local count = 0
        for _, line in ipairs(lines or {}) do
            local raw = tostring(line or "")
            local chunks = math.max(1, math.ceil(#raw / maxChars))
            count = count + chunks
        end
        return count
    end

    local function UpdateSectionText(section, lines)
        if not section or not section.Text then
            return
        end
        local ctx = GetContext()
        local textSize = ctx and ctx.BODY_TEXT_SIZE or 11
        local bodyWidth = section.BodyWidth or 0
        local bodyHeight = section.BodyHeight or 0
        local list = section.List
        local text = section.Text
        local tuning = ctx and ctx.LayoutTuning or nil
        local sectionColor = tuning and tuning.InnerSectionTextColorHex or nil
        local colorOverride = ParseHexColor(sectionColor, ctx and ctx.TEXT_COLOR or 0xFFFFFF)
        local content = table.concat(lines or {}, "\n")
        SetLabelText(text, content, textSize, colorOverride)

        local lineCount = EstimateLineCount(lines or {}, bodyWidth, textSize)
        local lineHeight = math.max(12, textSize + 3)
        local contentHeight = math.max(bodyHeight, lineCount * lineHeight)
        if section.ClampContentHeight or section.List == nil then
            contentHeight = bodyHeight
        end
        if text.SetSize then
            text:SetSize(bodyWidth, contentHeight)
        end
        if text.SetSizeOverride then
            text:SetSizeOverride(bodyWidth, contentHeight)
        end
        if list and list.RepositionElements then
            list:RepositionElements()
        end
    end

    local function RegisterSlot(def)
        if not def or not def.SlotId then
            return
        end
        def.SlotId = def.SlotId
        slots[def.SlotId] = def

        if def.NameInput and def.NameInput.Events then
            if def.NameInput.Events.Changed then
                def.NameInput.Events.Changed:Subscribe(function (ev)
                    if def.NameEditUpdating then
                        return
                    end
                    local newText = NormalizePlainText(ev and ev.Text or "")
                    if not def.IsEditingName then
                        def.NameEditText = newText
                        ApplyNameInputFormat(def)
                        return
                    end
                    if newText == "" then
                        def.NameEditText = ""
                        ApplyNameEditWindow(def)
                        return
                    end
                    local fullText = NormalizePlainText(def.NameEditText or "")
                    local prevVisible = def.NameEditVisibleText or ""
                    local windowChars = GetNameEditWindowChars(def, def.NameTextSize or 12)
                    local wasWindowing = windowChars and windowChars > 0 and #fullText > windowChars
                    if not wasWindowing then
                        fullText = newText
                    else
                        if #newText >= #prevVisible then
                            local appended = newText:sub(#prevVisible + 1)
                            if appended ~= "" then
                                fullText = fullText .. appended
                            end
                        else
                            local removed = #prevVisible - #newText
                            if removed > 0 then
                                fullText = fullText:sub(1, math.max(0, #fullText - removed))
                            end
                        end
                    end
                    def.NameEditText = fullText
                    local maxChars = GetNameEditMaxChars(def)
                    if maxChars and #def.NameEditText > maxChars then
                        def.NameEditText = def.NameEditText:sub(1, maxChars)
                    end
                    ApplyNameEditWindow(def)
                end)
            end
            if def.NameInput.Events.Focused then
                def.NameInput.Events.Focused:Subscribe(function ()
                    def.IsEditingName = true
                    ApplyNameInputFormat(def)
                end)
            end
            if def.NameInput.Events.Unfocused then
                def.NameInput.Events.Unfocused:Subscribe(function ()
                    if def.NameEditSkipCommit then
                        def.NameEditSkipCommit = false
                        SetNameEditVisible(def, false)
                        def.NameEditText = nil
                        def.EditBaseText = nil
                        def.NameEditVisibleText = nil
                        def.NameEditUpdating = false
                        def.NameEditWindowWidth = nil
                        def.NameButtonsLocked = false
                        def.NameButtonsLockedX = nil
                        def.NameButtonsLockedY = nil
                        local uiState = GetUIState()
                        if uiState and uiState.NameEditActiveSlotId == def.SlotId then
                            uiState.NameEditActiveSlotId = nil
                        end
                        return
                    end
                    CommitNameEdit(def)
                end)
            end
        end

        if def.NameEditButton and def.NameEditButton.Events and def.NameEditButton.Events.Pressed then
            def.NameEditButton.Events.Pressed:Subscribe(function ()
                BeginNameEdit(def)
            end)
        end

        if def.NameResetButton and def.NameResetButton.Events and def.NameResetButton.Events.Pressed then
            def.NameResetButton.Events.Pressed:Subscribe(function ()
                ResetNameOverride(def)
            end)
        end
    end

    local function UpdateSlot(slotId, details)
        local slot = slots[slotId]
        if not slot then
            return
        end
        local ctx = GetContext()
        local headerSize = ctx and ctx.HEADER_TEXT_SIZE or 13
        local bodySize = ctx and ctx.BODY_TEXT_SIZE or 11
        local tuning = ctx and ctx.LayoutTuning or nil
        local nameSize = headerSize
        if tuning and tuning.SlotItemNameTextSize ~= nil then
            nameSize = tuning.SlotItemNameTextSize
        end
        local infoSize = bodySize
        if tuning and tuning.SlotItemInfoTextSize ~= nil then
            infoSize = tuning.SlotItemInfoTextSize
        end
        local baseName = details and details.Name or ""
        local handle = details and details.Handle or nil
        local overrideName = GetNameOverride(handle)
        local name = overrideName or baseName
        local rarity = details and details.Rarity or ""
        local rarityId = details and (details.RarityId or details.Rarity) or ""
        if Text and Text.StripFontTags then
            rarity = Text.StripFontTags(rarity)
        end
        local level = details and details.Level
        local levelText = level and ("Level " .. tostring(level)) or ""
        local runeSlots = details and details.RuneSlots or nil
        local runeText = runeSlots and ("Rune Slots: " .. tostring(runeSlots)) or "Rune Slots:"
        local rarityColorOverride = nil
        if tuning and tuning.SlotItemRarityTextColors and rarityId ~= nil and rarityId ~= "" then
            local colors = tuning.SlotItemRarityTextColors
            local key = tostring(rarityId)
            local color = colors[key] or colors[string.upper(key)] or colors[string.lower(key)]
            rarityColorOverride = color or nil
        end
        local levelColorOverride = nil
        if tuning and tuning.SlotItemLevelTextColorHex then
            levelColorOverride = tuning.SlotItemLevelTextColorHex
        end
        if debug and Ext and Ext.Print then
            local baseCount = details and details.BaseValues and #details.BaseValues or 0
            local statCount = details and details.Stats and #details.Stats or 0
            local extraCount = details and details.ExtraProperties and #details.ExtraProperties or 0
            local skillCount = details and details.Skills and #details.Skills or 0
            Ext.Print(string.format(
                "[ForgingUI][SlotDetailsUI] slot=%s name='%s' rarity='%s' level='%s' base=%s stats=%s extra=%s skills=%s",
                tostring(slotId),
                tostring(name),
                tostring(rarity),
                tostring(levelText),
                tostring(baseCount),
                tostring(statCount),
                tostring(extraCount),
                tostring(skillCount)
            ))
        end

        slot.LastDetails = details
        slot.LastHandle = handle
        slot.BaseNameText = baseName
        slot.CurrentNameText = name
        slot.NameTextSize = nameSize

        local hasItem = handle ~= nil
        if not hasItem and slot.IsEditingName and slot.NameInput and slot.NameInput.SetFocused then
            slot.NameEditSkipCommit = true
            slot.NameInput:SetFocused(false)
        end

        local editRoot = GetButtonRoot(slot.NameEditButton)
        if editRoot and editRoot.SetVisible then
            editRoot:SetVisible(hasItem)
        end
        local resetRoot = GetButtonRoot(slot.NameResetButton)
        if resetRoot and resetRoot.SetVisible then
            resetRoot:SetVisible(hasItem)
        end

        SetLabelText(slot.NameLabel, name, nameSize, 0x000000)
        if slot.NameInput and not slot.IsEditingName then
            SetNameInputText(slot, name, nameSize)
            SetNameEditVisible(slot, false)
        end
        UpdateNameButtonsLayout(slot)
        SetLabelText(slot.RarityLabel, rarity, infoSize, rarityColorOverride)
        SetLabelText(slot.LevelLabel, levelText, infoSize, levelColorOverride)
        SetLabelText(slot.RuneLabel, runeText, bodySize, 0x000000)

        UpdateSectionText(slot.Sections and slot.Sections.Base, details and details.BaseValues or {})
        UpdateSectionText(slot.Sections and slot.Sections.Stats, details and details.Stats or {})
        UpdateSectionText(slot.Sections and slot.Sections.Extra, details and details.ExtraProperties or {})
        UpdateSectionText(slot.Sections and slot.Sections.Skills, details and details.Skills or {})
    end

    local ctx = GetContext()
    if ctx and ctx.Widgets then
        ctx.Widgets.UnfocusNameEdit = UnfocusNameEdit
    end

    return {
        RegisterSlot = RegisterSlot,
        UpdateSlot = UpdateSlot,
    }
end

return SlotDetails
