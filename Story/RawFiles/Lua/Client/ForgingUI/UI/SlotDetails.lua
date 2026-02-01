-- Client/ForgingUI/UI/SlotDetails.lua
-- Slot details rendering for Main/Donor panels.

local SlotDetails = {}
local getContextCallback = nil
local tooltipHooked = false
local RENAME_NET_CHANNEL = "ForgingUI_RenameItem"

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
    EnsureTooltipHook()

    local function GetUIState()
        local ctx = GetContext()
        return ctx and ctx.UIState or nil
    end

    local function ShouldDebugSlotDetails(ctx)
        local tuning = ctx and ctx.LayoutTuning or nil
        return tuning and tuning.DebugSlotDetails == true
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
        if input.SetTextFormat then
            input:SetTextFormat({color = 0x000000, size = size or 12})
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
        slot.NameEditText = current
        SetNameInputText(slot, current, slot.NameTextSize or 12)
        SetNameEditVisible(slot, true)
        if uiState then
            uiState.NameEditActiveSlotId = slot.SlotId
        end
        if slot.NameInput.SetFocused then
            slot.NameInput:SetFocused(true)
        end
        QueueNameCaret(slot, current)
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
            SetNameOverride(handle, nil)
            local item = ApplyItemCustomName(handle, "")
            local baseName = item and GetItemDisplayName(item) or nil
            trimmed = baseName or slot.BaseNameText or ""
            slot.BaseNameText = trimmed
        else
            SetNameOverride(handle, trimmed)
            ApplyItemCustomName(handle, trimmed)
            slot.BaseNameText = trimmed
        end
        slot.CurrentNameText = trimmed
        SetLabelText(slot.NameLabel, trimmed, slot.NameTextSize or 12, 0x000000)
        SetNameEditVisible(slot, false)
        slot.NameEditText = nil
        local uiState = GetUIState()
        if uiState and uiState.NameEditActiveSlotId == slot.SlotId then
            uiState.NameEditActiveSlotId = nil
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
                    def.NameEditText = ev and ev.Text or ""
                end)
            end
            if def.NameInput.Events.Focused then
                def.NameInput.Events.Focused:Subscribe(function ()
                    def.IsEditingName = true
                end)
            end
            if def.NameInput.Events.Unfocused then
                def.NameInput.Events.Unfocused:Subscribe(function ()
                    if def.NameEditSkipCommit then
                        def.NameEditSkipCommit = false
                        SetNameEditVisible(def, false)
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
            local ctx = GetContext()
            if ShouldDebugSlotDetails(ctx) and Ext and Ext.Print then
                Ext.Print(string.format("[ForgingUI][SlotDetailsUI] Slot not registered: %s", tostring(slotId)))
            end
            return
        end
        local ctx = GetContext()
        local debug = ShouldDebugSlotDetails(ctx)
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
        SetLabelText(slot.RarityLabel, rarity, infoSize, rarityColorOverride)
        SetLabelText(slot.LevelLabel, levelText, infoSize, levelColorOverride)
        SetLabelText(slot.RuneLabel, runeText, bodySize, 0x000000)

        UpdateSectionText(slot.Sections and slot.Sections.Base, details and details.BaseValues or {})
        UpdateSectionText(slot.Sections and slot.Sections.Stats, details and details.Stats or {})
        UpdateSectionText(slot.Sections and slot.Sections.Extra, details and details.ExtraProperties or {})
        UpdateSectionText(slot.Sections and slot.Sections.Skills, details and details.Skills or {})
    end

    return {
        RegisterSlot = RegisterSlot,
        UpdateSlot = UpdateSlot,
    }
end

return SlotDetails
