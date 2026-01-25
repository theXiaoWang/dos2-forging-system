-- Client/ForgingUI/UI/Layout/BottomPanels.lua
-- Wiki and result panels at the bottom of the forging UI.

local BottomPanels = {}

---@param options table
function BottomPanels.Build(options)
    local opts = options or {}
    local ctx = opts.ctx
    local canvas = opts.canvas
    local createSkinnedPanel = opts.createSkinnedPanel
    local createTextElement = opts.createTextElement
    local createButtonBox = opts.createButtonBox
    local registerSearchBlur = opts.registerSearchBlur
    local wireButton = opts.wireButton
    if not ctx or not canvas or not createSkinnedPanel or not createTextElement or not createButtonBox then
        return nil
    end

    local midX = opts.midX or 0
    local midBottomY = opts.midBottomY or 0
    local midWidth = opts.midWidth or 0
    local bottomHeight = opts.bottomHeight or 0
    local gap = opts.gap or 0
    local panelPadding = opts.panelPadding or 0
    local scaleX = opts.scaleX or function(value) return value end
    local scaleY = opts.scaleY or function(value) return value end
    local clamp = opts.clamp or function(value, minValue, maxValue)
        if value < minValue then
            return minValue
        end
        if value > maxValue then
            return maxValue
        end
        return value
    end

    local wikiWidth = math.floor(midWidth * 0.55)
    local resultWidth = midWidth - wikiWidth - gap
    local wikiFrame, wikiPanel, wikiInnerWidth, wikiInnerHeight = createSkinnedPanel(
        canvas,
        "ForgeWiki",
        midX,
        midBottomY,
        wikiWidth,
        bottomHeight,
        ctx.wikiPanelTexture,
        panelPadding
    )
    local resultFrame, resultPanel, resultInnerWidth, resultInnerHeight = createSkinnedPanel(
        canvas,
        "ForgeResult",
        midX + wikiWidth + gap,
        midBottomY,
        resultWidth,
        bottomHeight,
        ctx.resultPanelTexture,
        panelPadding
    )
    if registerSearchBlur then
        registerSearchBlur(wikiFrame)
        registerSearchBlur(wikiPanel)
        registerSearchBlur(resultFrame)
        registerSearchBlur(resultPanel)
    end

    local wikiEntries = {
        {Label = "Rarity", Text = "Rarity determines the quality and power of forged equipment."},
        {Label = "Base Value", Text = "Base Value represents the base worth of an item before modifiers."},
        {Label = "Weapon Boost", Text = "Weapon Boost increases the base damage or effectiveness of a weapon."},
        {Label = "Stats Modifiers", Text = "Stats Modifiers add attribute bonuses or penalties to the result."},
        {Label = "Rune Slots", Text = "Rune Slots determine how many runes can be socketed into the item."},
    }
    local wikiLookup = {}
    for _, entry in ipairs(wikiEntries) do
        wikiLookup[entry.Label] = entry.Text
    end

    local dropdownButtonWidth = math.min(scaleX(220), wikiInnerWidth - 16)
    local dropdownButtonHeight = clamp(scaleY(24), 20, 24)
    local dropdownStyle = ctx.styleComboBox or ctx.buttonStyle
    local wikiDropdown = createButtonBox(wikiPanel, "ForgeWikiDropdown", "Rarity", 8, 6, dropdownButtonWidth, dropdownButtonHeight, false, dropdownStyle)

    local dropdownHeight = dropdownButtonHeight * #wikiEntries + 12
    local dropdownFrame, dropdownInner = nil, nil
    if ctx.dropdownPanelTexture then
        dropdownFrame, dropdownInner = createSkinnedPanel(
            wikiPanel,
            "ForgeWikiDropdownPanel",
            8,
            dropdownButtonHeight + 10,
            dropdownButtonWidth,
            dropdownHeight,
            ctx.dropdownPanelTexture,
            8
        )
        dropdownFrame:SetVisible(false)
    end

    local wikiTextY = dropdownButtonHeight + 16
    local wikiText = createTextElement(
        wikiPanel,
        "ForgeWikiText",
        wikiLookup["Rarity"],
        12,
        wikiTextY,
        wikiInnerWidth - 24,
        wikiInnerHeight - wikiTextY - 12,
        "Left",
        true
    )

    if dropdownInner then
        local optionY = 6
        for _, entry in ipairs(wikiEntries) do
            local optionId = entry.Label:gsub("%s+", "_")
            local option = createButtonBox(
                dropdownInner,
                "ForgeWikiOption_" .. optionId,
                entry.Label,
                0,
                optionY,
                dropdownButtonWidth - 16,
                dropdownButtonHeight,
                false,
                dropdownStyle
            )
            if option.Events and option.Events.Pressed then
                option.Events.Pressed:Subscribe(function()
                    wikiDropdown:SetLabel(entry.Label)
                    wikiText:SetText(wikiLookup[entry.Label] or "")
                    dropdownFrame:SetVisible(false)
                end)
            end
            optionY = optionY + dropdownButtonHeight
        end
    end

    if wikiDropdown.Events and wikiDropdown.Events.Pressed and dropdownFrame then
        wikiDropdown.Events.Pressed:Subscribe(function()
            dropdownFrame:SetVisible(not dropdownFrame:IsVisible())
        end)
    end

    createTextElement(resultPanel, "ForgeResultHeader", "Forge Result", 0, 6, resultInnerWidth, 18, "Center", false, {size = ctx.HEADER_TEXT_SIZE})
    local primaryStyle = ctx.styleLargeRedWithArrows or ctx.buttonStyle
    local forgeButtonWidth = 110
    local forgeButtonHeight = clamp(scaleY(24), 20, 24)
    local forgeButtonX = resultInnerWidth - forgeButtonWidth - 12
    local forgeButtonY = resultInnerHeight - forgeButtonHeight - 6
    local forgeActionBtn = createButtonBox(resultPanel, "ForgeActionButton", "Forge", forgeButtonX, forgeButtonY, forgeButtonWidth, forgeButtonHeight, false, primaryStyle)
    if wireButton then
        wireButton(forgeActionBtn, "ForgeAction")
    end

    return {
        WikiFrame = wikiFrame,
        ResultFrame = resultFrame,
    }
end

return BottomPanels
