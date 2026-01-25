-- Client/ForgingUI/UI/Layout/Columns.lua
-- Main/Donor/Preview column builders.

local Columns = {}

---@param options table
function Columns.Build(options)
    local opts = options or {}
    local ctx = opts.ctx
    local canvas = opts.canvas
    local columnConfigs = opts.columnConfigs or {}
    if not ctx or not canvas or not columnConfigs then
        return
    end

    local contentTop = opts.contentTop or 0
    local midTopHeight = opts.midTopHeight or 0
    local infoPanelOffsetY = opts.infoPanelOffsetY or 0
    local slotPanelHeight = opts.slotPanelHeight or 0
    local slotPanelOffsetY = opts.slotPanelOffsetY or 0
    local craftState = opts.craftState

    local createSkinnedPanel = opts.createSkinnedPanel
    local createTextElement = opts.createTextElement
    local createButtonBox = opts.createButtonBox
    local createPreviewInventoryPanel = opts.createPreviewInventoryPanel
    local createSectionBox = opts.createSectionBox
    local createDropSlot = opts.createDropSlot
    local registerSearchBlur = opts.registerSearchBlur
    local wireButton = opts.wireButton
    local applyElementSize = opts.applyElementSize
    local scaleX = opts.scaleX or function(value) return value end
    local scaleY = opts.scaleY or function(value) return value end
    local vector = opts.vector or function(...) return Vector.Create(...) end

    for _, cfg in ipairs(columnConfigs) do
        -- Use separate height for Main/Donor panels, standard height for Preview
        local panelHeight = (cfg.Mode == "Main" or cfg.Mode == "Donor") and slotPanelHeight or (midTopHeight - scaleY(infoPanelOffsetY))
        -- Apply vertical offset: Main/Donor move up, Preview moves down
        local panelY = contentTop
        if cfg.Mode == "Main" or cfg.Mode == "Donor" then
            panelY = contentTop + scaleY(slotPanelOffsetY)
        elseif cfg.Mode == "Preview" then
            panelY = contentTop + scaleY(infoPanelOffsetY)
        end
        local panelFrame, panel, panelInnerWidth, panelInnerHeight = createSkinnedPanel(
            canvas,
            "Column_" .. cfg.ID,
            cfg.X,
            panelY,
            cfg.Width,
            panelHeight,
            cfg.Texture,
            cfg.Padding
        )
        if registerSearchBlur and cfg.Mode ~= "Preview" then
            registerSearchBlur(panelFrame)
            registerSearchBlur(panel)
        end
        local headerHeight = 0
        -- Vertical offset to push header and slot lower in Main/Donor panels
        local headerOffsetY = (cfg.Mode == "Main" or cfg.Mode == "Donor") and 47 or 0
        if cfg.Title and cfg.Title ~= "" then
            local headerFormat = {size = ctx.HEADER_TEXT_SIZE}
            -- Make Main/Donor titles larger, black, and use bold font
            if cfg.Mode == "Main" or cfg.Mode == "Donor" then
                headerFormat = {Size = 14, Color = "000000", FontType = Text.FONTS.BOLD}
            end
            createTextElement(panel, cfg.ID .. "_HeaderText", cfg.Title, 0, headerOffsetY, panelInnerWidth, 26, "Center", false, headerFormat)
            headerHeight = 26 + headerOffsetY
        end

        local columnGap = 6
        if cfg.Mode == "Preview" then
            -- Use a fixed width to prevent stretching of GreenMediumTextured style
            -- Alternatively, use a style designed for wide buttons like styleTabCharacterSheetWide
            local primaryStyle = ctx.styleGreenMediumTextured or ctx.buttonStyle
            local previewButtonHeight = 35
            local previewButtonGap = 6
            -- Fixed width prevents texture stretching; button will be centered
            local previewButtonWidth = scaleX(260)  -- Fixed width that maintains aspect ratio
            local previewButtonX = math.floor((panelInnerWidth - previewButtonWidth) / 2)  -- Center the button
            local previewButtonY = headerHeight + columnGap
            local previewButton = createButtonBox(panel, "Preview_PreviewButton", "Click to Preview", previewButtonX, previewButtonY, previewButtonWidth, previewButtonHeight, false, primaryStyle)
            if wireButton then
                wireButton(previewButton, "ClickToPreview")
            end
            local previewY = previewButtonY + previewButtonHeight + previewButtonGap
            local previewHeight = panelInnerHeight - previewY - columnGap
            local previewInner = panel:AddChild(cfg.ID .. "_PreviewArea_Inner", "GenericUI_Element_Empty")
            previewInner:SetPosition(6, previewY)
            if applyElementSize then
                applyElementSize(previewInner, panelInnerWidth - 12, previewHeight)
            end
            if previewInner.SetScale then
                previewInner:SetScale(vector(1, 1))
            end
            local innerWidth = panelInnerWidth - 12
            local innerHeight = previewHeight

            if ctx.USE_CUSTOM_PREVIEW_PANEL then
                if createPreviewInventoryPanel then
                    createPreviewInventoryPanel(previewInner, innerWidth, innerHeight, 0, 0)
                end
            elseif ctx.USE_VANILLA_COMBINE_PANEL and craftState then
                craftState.PreviewAnchorID = cfg.ID .. "_PreviewArea_Inner"
                craftState.PreviewArea = {W = innerWidth, H = innerHeight}
                previewInner:SetMouseEnabled(false)
                previewInner:SetMouseChildren(false)
            else
                previewInner:SetMouseEnabled(false)
                previewInner:SetMouseChildren(false)
            end
        else
            local runeHeight = 18
            local available = panelInnerHeight - headerHeight - runeHeight - columnGap * 4
            local itemHeight = math.floor(available * 0.28)
            local statsHeight = math.floor(available * 0.32)
            local extraHeight = math.floor(available * 0.28)
            local skillsHeight = available - itemHeight - statsHeight - extraHeight

            -- Width reduction for child panels (Stats, Extra Properties, Skills, Rune Slots)
            -- Positive values make panels narrower by reducing width from both sides
            local childPanelWidthReduction = scaleX(60)
            local childPanelWidth = panelInnerWidth - 12 - childPanelWidthReduction
            local childPanelX = 6 + math.floor(childPanelWidthReduction / 2)

            local cursorY = headerHeight + columnGap
            local socketSize = math.min(56, itemHeight - 8)
            local slotX = math.floor((panelInnerWidth - socketSize) / 2)
            local slotY = cursorY + 4
            createDropSlot(panel, cfg.ID .. "_ItemSlot", slotX, slotY, socketSize)
            local slotBottom = slotY + socketSize
            local slotToPanelGap = 60
            local reducedGap = math.max(2, math.floor(columnGap * 0.5))
            cursorY = slotBottom + slotToPanelGap

            createSectionBox(panel, cfg.ID .. "_Stats", childPanelX, cursorY, childPanelWidth, statsHeight, "Stats", "", "")
            cursorY = cursorY + statsHeight + reducedGap

            createSectionBox(panel, cfg.ID .. "_Extra", childPanelX, cursorY, childPanelWidth, extraHeight, "Extra Properties", "", "")
            cursorY = cursorY + extraHeight + reducedGap

            local skillsTitle = cfg.Mode == "Donor" and "Granted Skill / Skillbook Protect" or "Granted Skills"
            local skillsBox = createSectionBox(panel, cfg.ID .. "_Skills", childPanelX, cursorY, childPanelWidth, skillsHeight, skillsTitle, "", "")
            if cfg.Mode == "Donor" then
                local slotSize = math.min(50, skillsHeight - 30)
                if slotSize > 0 then
                    local skillsBoxWidth = childPanelWidth
                    local slotSlotX = skillsBoxWidth - slotSize - 8
                    local skillSlotY = math.floor((skillsHeight - slotSize) / 2)
                    createDropSlot(skillsBox, "Donor_SkillbookSlot", slotSlotX, skillSlotY, slotSize)
                end
            end

            local runeY = cursorY + skillsHeight + reducedGap
            createTextElement(panel, cfg.ID .. "_Runes", "Rune Slots:", childPanelX + 4, runeY, childPanelWidth - 8, runeHeight, "Left")
        end
    end
end

return Columns
