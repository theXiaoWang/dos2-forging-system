-- Client/ForgingUI/UI/SlotDetails.lua
-- Slot details rendering for Main/Donor panels.

local SlotDetails = {}

---@param options table
function SlotDetails.Create(options)
    local opts = options or {}
    local getContext = opts.getContext

    local slots = {}

    local function GetContext()
        return getContext and getContext() or nil
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

    local function FormatText(text, size, colorOverride)
        local ctx = GetContext()
        if Text and Text.Format then
            return Text.Format(text or "", {
                Color = colorOverride or (ctx and ctx.TEXT_COLOR) or 0xFFFFFF,
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
        slots[def.SlotId] = def
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
        local name = details and details.Name or ""
        local rarity = details and details.Rarity or ""
        local level = details and details.Level
        local levelText = level and ("Level " .. tostring(level)) or ""
        local runeSlots = details and details.RuneSlots or nil
        local runeText = runeSlots and ("Rune Slots: " .. tostring(runeSlots)) or "Rune Slots:"
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

        SetLabelText(slot.NameLabel, name, nameSize, 0x000000)
        SetLabelText(slot.RarityLabel, rarity, infoSize)
        SetLabelText(slot.LevelLabel, levelText, infoSize)
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
