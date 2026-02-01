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
    local previewPanelOffsetY = opts.previewPanelOffsetY
    if previewPanelOffsetY == nil then
        previewPanelOffsetY = infoPanelOffsetY
    end
    local slotPanelHeight = opts.slotPanelHeight or 0
    local slotPanelOffsetY = opts.slotPanelOffsetY or 0
    local extraInfoBottomHeight = opts.extraInfoBottomHeight or 0
    local extraSlotBottomHeight = opts.extraSlotBottomHeight or 0
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
    local slotDetailsUI = opts.slotDetailsUI
    local scaleX = opts.scaleX or function(value) return value end
    local scaleY = opts.scaleY or function(value) return value end
    local vector = opts.vector or function(...) return Vector.Create(...) end

    for _, cfg in ipairs(columnConfigs) do
        -- Use separate height for Main/Donor panels, standard height for Preview
        local panelHeight = 0
        if cfg.Mode == "Main" or cfg.Mode == "Donor" then
            panelHeight = slotPanelHeight + extraSlotBottomHeight
        else
            panelHeight = (midTopHeight - scaleY(previewPanelOffsetY)) + extraInfoBottomHeight
        end
        if panelHeight < 0 then
            panelHeight = 0
        end
        -- Apply vertical offset: Main/Donor move up, Preview moves down
        local panelY = contentTop
        if cfg.Mode == "Main" or cfg.Mode == "Donor" then
            panelY = contentTop + scaleY(slotPanelOffsetY)
        elseif cfg.Mode == "Preview" then
            panelY = contentTop + scaleY(previewPanelOffsetY)
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
        local headerOffsetY = 0
        if cfg.Mode == "Main" or cfg.Mode == "Donor" then
            local tuningOffset = ctx and ctx.LayoutTuning and ctx.LayoutTuning.SlotPanelHeaderOffsetY
            if tuningOffset == nil then
                tuningOffset = 47
            end
            headerOffsetY = scaleY(tuningOffset)
        end
        if cfg.Title and cfg.Title ~= "" then
            local headerFormat = {size = ctx.HEADER_TEXT_SIZE}
            -- Make Main/Donor titles larger, white, and use bold font
            if cfg.Mode == "Main" or cfg.Mode == "Donor" then
                headerFormat = {Size = 14, Color = "FFFFFF", FontType = Text.FONTS.BOLD}
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
            local reducedGap = math.max(2, math.floor(columnGap * 0.5))
            local layoutTuning = ctx and ctx.LayoutTuning or nil
            if layoutTuning and layoutTuning.SlotSectionGapY ~= nil then
                reducedGap = scaleY(layoutTuning.SlotSectionGapY)
            end
            local sectionTextPaddingX = 0
            if layoutTuning and layoutTuning.SlotSectionInnerPaddingX ~= nil then
                sectionTextPaddingX = scaleX(layoutTuning.SlotSectionInnerPaddingX)
            end
            local sectionTextPaddingY = 16
            if layoutTuning and layoutTuning.SlotSectionInnerPaddingY ~= nil then
                sectionTextPaddingY = scaleY(layoutTuning.SlotSectionInnerPaddingY)
            end
            if sectionTextPaddingY < 0 then
                sectionTextPaddingY = 0
            end

            -- Width reduction for child panels (Stats, Extra Properties, Skills, Rune Slots)
            -- Positive values make panels narrower by reducing width from both sides
            local childPanelWidthReduction = scaleX(60)
            if layoutTuning and layoutTuning.SlotSectionWidthReductionX ~= nil then
                childPanelWidthReduction = scaleX(layoutTuning.SlotSectionWidthReductionX)
            end
            local childPanelWidth = panelInnerWidth - 12 - childPanelWidthReduction
            local childPanelX = 6 + math.floor(childPanelWidthReduction / 2)

            local cursorY = headerHeight + columnGap
            local socketSize = math.min(56, math.max(32, math.floor((panelInnerHeight - headerHeight) * 0.18)))
            local slotX = math.floor((panelInnerWidth - socketSize) / 2)
            local slotY = cursorY + 4
            createDropSlot(panel, cfg.ID .. "_ItemSlot", slotX, slotY, socketSize)
            local slotBottom = slotY + socketSize
            local infoBlockGap = scaleY(4)
            if layoutTuning and layoutTuning.SlotItemInfoBlockGapY ~= nil then
                infoBlockGap = scaleY(layoutTuning.SlotItemInfoBlockGapY)
            end
            local infoLineGap = scaleY(4)
            if layoutTuning and layoutTuning.SlotItemInfoLineGapY ~= nil then
                infoLineGap = scaleY(layoutTuning.SlotItemInfoLineGapY)
            end
            local infoLineHeight = scaleY(16)
            local nameLineHeight = infoLineHeight
            if layoutTuning and layoutTuning.SlotItemNameLineHeightY ~= nil then
                nameLineHeight = scaleY(layoutTuning.SlotItemNameLineHeightY)
            end
            local infoBlockHeight = nameLineHeight + (infoLineHeight * 2) + infoBlockGap + infoLineGap
            local infoToSectionsGap = 0
            if layoutTuning and layoutTuning.SlotItemInfoToSectionsGapY ~= nil then
                infoToSectionsGap = scaleY(layoutTuning.SlotItemInfoToSectionsGapY)
            end
            local infoNameOffset = 0
            if layoutTuning and layoutTuning.SlotItemNameOffsetY ~= nil then
                infoNameOffset = scaleY(layoutTuning.SlotItemNameOffsetY)
            end
            local infoLowerLinesOffset = 0
            if layoutTuning and layoutTuning.SlotItemInfoLowerLinesOffsetY ~= nil then
                infoLowerLinesOffset = scaleY(layoutTuning.SlotItemInfoLowerLinesOffsetY)
            end
            local infoY = slotBottom + scaleY(6)
            local nameButtonSize = math.max(scaleY(12), math.floor(nameLineHeight * 0.7))
            local nameButtonGap = math.max(scaleX(2), 1)
            local nameButtonsWidth = nameButtonSize * 2 + nameButtonGap
            local nameLabelWidth = math.max(0, childPanelWidth - nameButtonsWidth - scaleX(2))
            local nameLabelX = childPanelX
            local nameLabelY = infoY + infoNameOffset
            local itemNameLabel = createTextElement(panel, cfg.ID .. "_ItemName", "", nameLabelX, nameLabelY, nameLabelWidth, nameLineHeight, "Center", true, {Size = ctx.HEADER_TEXT_SIZE})
            local itemNameInput = panel:AddChild(cfg.ID .. "_ItemNameInput", "GenericUI_Element_Text")
            itemNameInput:SetPosition(nameLabelX, nameLabelY)
            itemNameInput:SetSize(nameLabelWidth, nameLineHeight)
            itemNameInput:SetType("Center")
            itemNameInput:SetText("")
            itemNameInput:SetEditable(true)
            if itemNameInput.SetMouseEnabled then
                itemNameInput:SetMouseEnabled(false)
            end
            if itemNameInput.SetMouseChildren then
                itemNameInput:SetMouseChildren(false)
            end
            if itemNameInput.SetWordWrap then
                itemNameInput:SetWordWrap(false)
            end
            if itemNameInput.SetTextFormat then
                itemNameInput:SetTextFormat({color = 0x000000, size = ctx.HEADER_TEXT_SIZE})
            end
            if itemNameInput.SetVisible then
                itemNameInput:SetVisible(false)
            end
            local nameInputMC = itemNameInput.GetMovieClip and itemNameInput:GetMovieClip() or nil
            if nameInputMC and nameInputMC.text_txt then
                nameInputMC.text_txt.type = "input"
                nameInputMC.text_txt.selectable = true
                nameInputMC.text_txt.alwaysShowSelection = true
                nameInputMC.text_txt.multiline = false
                nameInputMC.text_txt.wordWrap = false
            end
            local nameButtonsX = childPanelX + childPanelWidth - nameButtonsWidth
            local nameButtonsY = nameLabelY + math.floor((nameLineHeight - nameButtonSize) / 2)
            local editStyle = ctx and ctx.buttonPrefab and ctx.buttonPrefab.STYLES and ctx.buttonPrefab.STYLES.EditWide or ctx.buttonStyle
            local resetStyle = ctx and ctx.buttonPrefab and ctx.buttonPrefab.STYLES and ctx.buttonPrefab.STYLES.CloseBackgroundless or ctx.buttonStyle
            local itemNameEditButton = createButtonBox(panel, cfg.ID .. "_ItemNameEdit", nil, nameButtonsX, nameButtonsY, nameButtonSize, nameButtonSize, false, editStyle)
            local itemNameResetButton = createButtonBox(panel, cfg.ID .. "_ItemNameReset", nil, nameButtonsX + nameButtonSize + nameButtonGap, nameButtonsY, nameButtonSize, nameButtonSize, false, resetStyle)
            local rarityY = infoY + nameLineHeight + infoBlockGap + infoLowerLinesOffset
            local itemRarityLabel = createTextElement(panel, cfg.ID .. "_ItemRarity", "", childPanelX, rarityY, childPanelWidth, infoLineHeight, "Center", false, {Size = ctx.BODY_TEXT_SIZE})
            local levelY = rarityY + infoLineHeight + infoLineGap
            local itemLevelLabel = createTextElement(panel, cfg.ID .. "_ItemLevel", "", childPanelX, levelY, childPanelWidth, infoLineHeight, "Center", false, {Size = ctx.BODY_TEXT_SIZE})

            cursorY = infoY + infoBlockHeight + reducedGap + infoToSectionsGap

            local sectionHeightTrim = 0
            if layoutTuning and layoutTuning.SlotSectionHeightTrimY ~= nil then
                sectionHeightTrim = scaleY(layoutTuning.SlotSectionHeightTrimY)
            end
            local sectionAvailable = panelInnerHeight - cursorY - runeHeight - reducedGap * 4 - sectionHeightTrim
            if sectionAvailable < 0 then
                sectionAvailable = 0
            end
            local baseRatio = 2 / 3
            local statsRatio = 4 / 3
            local extraRatio = 4 / 3
            local skillsRatio = baseRatio
            local ratioSum = baseRatio + statsRatio + extraRatio + skillsRatio
            local baseHeight = math.floor(sectionAvailable * (baseRatio / ratioSum))
            local statsHeight = math.floor(sectionAvailable * (statsRatio / ratioSum))
            local extraHeight = math.floor(sectionAvailable * (extraRatio / ratioSum))
            local skillsHeight = sectionAvailable - baseHeight - statsHeight - extraHeight
            if layoutTuning and layoutTuning.SlotSectionSkillsHeightScale ~= nil then
                skillsHeight = math.floor(skillsHeight * layoutTuning.SlotSectionSkillsHeightScale)
                if skillsHeight < 0 then
                    skillsHeight = 0
                end
            end

            local function CreateScrollableSection(sectionId, sectionInner, innerWidth, innerHeight, bodyX, bodyWidth, clampContentHeight, textAlign)
                if not sectionInner then
                    return nil
                end
                local bodyY = sectionTextPaddingY
                local bodyHeight = innerHeight - bodyY
                if bodyHeight < 0 then
                    bodyHeight = 0
                end
                local padX = sectionTextPaddingX or 0
                local baseBodyWidth = bodyWidth or innerWidth
                local listX = (bodyX or 0) + padX
                local listWidth = baseBodyWidth - padX * 2
                if listWidth < 0 then
                    listWidth = 0
                end
                local align = textAlign or "Left"
                local text = createTextElement(sectionInner, sectionId .. "_BodyText", "", listX, bodyY, listWidth, bodyHeight, align, true, {Size = ctx.BODY_TEXT_SIZE})
                return {
                    Text = text,
                    BodyWidth = listWidth,
                    BodyHeight = bodyHeight,
                    ClampContentHeight = clampContentHeight == true,
                }
            end

            local baseBox, baseInnerW, baseInnerH = createSectionBox(panel, cfg.ID .. "_Base", childPanelX, cursorY, childPanelWidth, baseHeight, "Base Value", "", "")
            local baseSection = CreateScrollableSection(cfg.ID .. "_Base", baseBox, baseInnerW or childPanelWidth, baseInnerH or baseHeight, nil, nil, nil, "Center")
            cursorY = cursorY + baseHeight + reducedGap

            local statsBox, statsInnerW, statsInnerH = createSectionBox(panel, cfg.ID .. "_Stats", childPanelX, cursorY, childPanelWidth, statsHeight, "Stats", "", "")
            local statsSection = CreateScrollableSection(cfg.ID .. "_Stats", statsBox, statsInnerW or childPanelWidth, statsInnerH or statsHeight, nil, nil, nil, "Center")
            cursorY = cursorY + statsHeight + reducedGap

            local extraBox, extraInnerW, extraInnerH = createSectionBox(panel, cfg.ID .. "_Extra", childPanelX, cursorY, childPanelWidth, extraHeight, "Extra Properties", "", "")
            local extraSection = CreateScrollableSection(cfg.ID .. "_Extra", extraBox, extraInnerW or childPanelWidth, extraInnerH or extraHeight, nil, nil, nil, "Center")
            cursorY = cursorY + extraHeight + reducedGap

            local skillsTitle = cfg.Mode == "Donor" and "Granted Skill / Skillbook Protect" or "Granted Skills"
            local skillsBox, skillsInnerW, skillsInnerH = createSectionBox(panel, cfg.ID .. "_Skills", childPanelX, cursorY, childPanelWidth, skillsHeight, skillsTitle, "", "")
            local reservedWidth = 0
            if cfg.Mode == "Donor" then
                local slotMaxSize = 50
                local slotMarginY = 30
                if layoutTuning and layoutTuning.SlotSectionSkillbookSlotMaxSizeY ~= nil then
                    slotMaxSize = scaleY(layoutTuning.SlotSectionSkillbookSlotMaxSizeY)
                end
                if layoutTuning and layoutTuning.SlotSectionSkillbookSlotMarginY ~= nil then
                    slotMarginY = scaleY(layoutTuning.SlotSectionSkillbookSlotMarginY)
                end
                local slotSize = math.min(slotMaxSize, skillsHeight - slotMarginY)
                slotSize = math.floor(slotSize)
                if slotSize > 0 then
                    local skillsBoxWidth = childPanelWidth
                    local slotSlotX = skillsBoxWidth - slotSize - 8 - (sectionTextPaddingX or 0)
                    if slotSlotX < 0 then
                        slotSlotX = 0
                    end
                    local skillSlotY = math.floor((skillsHeight - slotSize) / 2)
                    createDropSlot(skillsBox, "Donor_SkillbookSlot", slotSlotX, skillSlotY, slotSize)
                    reservedWidth = slotSize + 12
                end
            end
            local skillsBodyWidth = (skillsInnerW or childPanelWidth) - reservedWidth
            if skillsBodyWidth < 0 then
                skillsBodyWidth = 0
            end
            local clampSkillsContent = cfg.Mode == "Donor"
            local skillsSection = CreateScrollableSection(cfg.ID .. "_Skills", skillsBox, skillsInnerW or childPanelWidth, skillsInnerH or skillsHeight, 0, skillsBodyWidth, clampSkillsContent, "Left")

            local runeY = cursorY + skillsHeight + reducedGap
            local runeLabel = createTextElement(panel, cfg.ID .. "_Runes", "Rune Slots:", childPanelX + 4, runeY, childPanelWidth - 8, runeHeight, "Left")

            if slotDetailsUI and slotDetailsUI.RegisterSlot then
                slotDetailsUI.RegisterSlot({
                    SlotId = cfg.ID .. "_ItemSlot",
                    NameLabel = itemNameLabel,
                    NameInput = itemNameInput,
                    NameEditButton = itemNameEditButton,
                    NameResetButton = itemNameResetButton,
                    RarityLabel = itemRarityLabel,
                    LevelLabel = itemLevelLabel,
                    RuneLabel = runeLabel,
                    Sections = {
                        Base = baseSection,
                        Stats = statsSection,
                        Extra = extraSection,
                        Skills = skillsSection,
                    },
                })
            end
        end
    end
end

return Columns
