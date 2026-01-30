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

    local function FormatText(text, size)
        local ctx = GetContext()
        if Text and Text.Format then
            return Text.Format(text or "", {
                Color = ctx and ctx.TEXT_COLOR or 0xFFFFFF,
                Size = size or (ctx and ctx.BODY_TEXT_SIZE) or 12,
            })
        end
        return text or ""
    end

    local function SetLabelText(label, text, size)
        if not label or not label.SetText then
            return
        end
        label:SetText(FormatText(text, size))
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
        local content = table.concat(lines or {}, "\n")
        SetLabelText(text, content, textSize)

        local lineCount = EstimateLineCount(lines or {}, bodyWidth, textSize)
        local lineHeight = math.max(12, textSize + 3)
        local contentHeight = math.max(bodyHeight, lineCount * lineHeight)
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

        SetLabelText(slot.NameLabel, name, headerSize)
        SetLabelText(slot.RarityLabel, rarity, bodySize)
        SetLabelText(slot.LevelLabel, levelText, bodySize)
        SetLabelText(slot.RuneLabel, runeText, bodySize)

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
