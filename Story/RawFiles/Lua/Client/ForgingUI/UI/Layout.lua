-- Client/ForgingUI/Layout.lua
-- Layout, sizing, and input/toggle helpers for the forging UI.

local ForgingUI = Client.ForgingUI or {}
Client.ForgingUI = ForgingUI

local Layout = {}
ForgingUI.Layout = Layout

local ctx = nil

function Layout.SetContext(nextCtx)
    ctx = nextCtx
end

local function GetContext()
    return ctx
end

local function V(...)
    return ctx and ctx.V and ctx.V(...) or Vector.Create(...)
end

local function GetLayoutState()
    return ctx and ctx.LayoutState or nil
end

local function GetUIState()
    return ctx and ctx.UIState or nil
end

local function GetDisplayMode()
    if ctx and ctx.GetDisplayMode then
        return ctx.GetDisplayMode()
    end
    return nil
end

local function GetDisplayModes()
    return ctx and ctx.DISPLAY_MODES or {Combine = "Combine", Preview = "Preview"}
end

local Diagnostics = Ext.Require("Client/ForgingUI/UI/Layout/Diagnostics.lua")
local Viewport = Ext.Require("Client/ForgingUI/UI/Layout/Viewport.lua")

local diagnostics = Diagnostics.Create({
    getContext = GetContext,
})
Layout.PrintUIState = diagnostics.PrintUIState
Layout.PrintElementInfo = diagnostics.PrintElementInfo
Layout.DumpElementTree = diagnostics.DumpElementTree
Layout.DumpFillElements = diagnostics.DumpFillElements

local viewport = Viewport.Create({
    getContext = GetContext,
    getLayoutState = GetLayoutState,
})
Layout.GetViewportScale = viewport.GetViewportScale
Layout.GetViewportSize = viewport.GetViewportSize
Layout.GetUIScaleMultiplier = viewport.GetUIScaleMultiplier
Layout.UpdateUISizeFromViewport = viewport.UpdateUISizeFromViewport
Layout.ScaleX = viewport.ScaleX
Layout.ScaleY = viewport.ScaleY
Layout.Scale = viewport.Scale
Layout.Clamp = viewport.Clamp

function Layout.HasLayout()
    if not ctx or not ctx.uiInstance or not ctx.uiInstance.GetElementByID then
        return false
    end

    local root = ctx.uiInstance:GetElementByID(ctx.ROOT_ID)
    if not root then
        return false
    end

    return ctx.uiInstance:GetElementByID("TopBar") ~= nil
end

function Layout.PositionUI()
    if not ctx or not ctx.uiInstance then
        return
    end

    local state = GetLayoutState()
    if ctx.uiInstance.SetPanelSize and state then
        ctx.uiInstance:SetPanelSize(V(state.Width, state.Height))
    end
    if ctx.uiInstance.SetPositionRelativeToViewport then
        ctx.uiInstance:SetPositionRelativeToViewport("center", "center", "screen", 0.1)
    elseif ctx.uiInstance.ExternalInterfaceCall then
        ctx.uiInstance:ExternalInterfaceCall("setPosition", "center", "screen", "center")
    elseif ctx.uiInstance.SetPosition then
        ctx.uiInstance:SetPosition(V(0, 0))
    end

    if ctx.Craft and ctx.Craft.UpdatePreviewAnchor then
        ctx.Craft.UpdatePreviewAnchor()
    end

    local uiState = GetUIState()
    if uiState and uiState.IsVisible and ctx.Craft and ctx.Craft.State then
        local displayModes = GetDisplayModes()
        if ctx.Craft.State.DockRequested and GetDisplayMode() == displayModes.Combine and ctx.Craft.DockUI then
            ctx.Craft.DockUI(false)
        end
    end
end

function Layout.GetClientGameState()
    if ctx and ctx.Ext and ctx.Ext.Client and ctx.Ext.Client.GetGameState then
        return ctx.Ext.Client.GetGameState()
    end
    if ctx and ctx.Ext and ctx.Ext.GetGameState then
        return ctx.Ext.GetGameState()
    end
    return nil
end

function Layout.IsGameStateRunning()
    local state = Layout.GetClientGameState()
    return state == "Running"
end

function Layout.ShouldShowToggleButton()
    local uiState = GetUIState()
    return uiState and uiState.ToggleReady and Layout.IsGameStateRunning()
end

function Layout.PositionToggleButton(ui)
    if not ui then
        return false
    end

    if not Layout.ShouldShowToggleButton() then
        if ui.Hide then
            ui:Hide()
        end
        return false
    end

    local viewportW, viewportH = Layout.GetViewportSize()
    if not viewportW or not viewportH or viewportW <= 0 or viewportH <= 0 then
        if ui.Hide then
            ui:Hide()
        end
        return false
    end

    local scale = Layout.GetViewportScale()
    local width = math.floor(76 * scale)
    local height = math.floor(24 * scale)
    local offsetX = math.floor((ctx.TOGGLE_OFFSET_X or 0) * scale)
    local offsetY = math.floor((ctx.TOGGLE_OFFSET_Y or 0) * scale)

    if ui.SetPanelSize then
        ui:SetPanelSize(V(width, height))
    end
    if ui.SetPosition then
        ui:SetPosition(V(viewportW - width + offsetX, offsetY))
    elseif ui.SetPositionRelativeToViewport then
        ui:SetPositionRelativeToViewport("topright", "topright", "screen", 0)
        if ui.Move then
            ui:Move(V(offsetX, offsetY))
        end
    elseif ui.ExternalInterfaceCall then
        ui:ExternalInterfaceCall("setPosition", "topright", "screen", "topright")
        if ui.Move then
            ui:Move(V(offsetX, offsetY))
        end
    end
    return true
end

function Layout.ScheduleTogglePosition(delay)
    local uiState = GetUIState()
    if not uiState or not uiState.ToggleUIInstance then
        return
    end

    uiState.TogglePositionRevision = (uiState.TogglePositionRevision or 0) + 1
    local revision = uiState.TogglePositionRevision
    local function apply()
        if revision ~= uiState.TogglePositionRevision then
            return
        end
        if Layout.PositionToggleButton(uiState.ToggleUIInstance) then
            if uiState.ToggleUIInstance.Show then
                uiState.ToggleUIInstance:Show()
            end
        end
    end

    if ctx and ctx.Timer and ctx.Timer.Start and delay and delay > 0 then
        ctx.Timer.Start("ForgingUI_TogglePos", delay, apply)
    else
        apply()
    end
end

function Layout.EnsureToggleButton()
    if not ctx or not ctx.genericUI or not ctx.buttonPrefab then
        return
    end

    local uiState = GetUIState()
    if not uiState then
        return
    end

    local existing = ctx.genericUI.GetInstance and ctx.genericUI.GetInstance(ctx.TOGGLE_UI_ID) or nil
    if existing and existing.GetUI and existing:GetUI() then
        uiState.ToggleUIInstance = existing
    elseif uiState.ToggleUIInstance and uiState.ToggleUIInstance.GetUI and uiState.ToggleUIInstance:GetUI() then
        existing = uiState.ToggleUIInstance
    else
        if ctx.Ext and ctx.Ext.UI and ctx.Ext.UI.GetByName and ctx.Ext.UI.GetByName(ctx.TOGGLE_UI_ID) then
            pcall(ctx.Ext.UI.Destroy, ctx.TOGGLE_UI_ID)
        end
        local baseLayer = ctx.genericUI.DEFAULT_LAYER or 15
        local uiLayer = math.max(1, baseLayer - 8)
        uiState.ToggleUIInstance = ctx.genericUI.Create(ctx.TOGGLE_UI_ID, {Layer = uiLayer + 1, Visible = false})
        existing = uiState.ToggleUIInstance
    end

    if not existing then
        return
    end

    if not ctx or not ctx.buttonPrefab or not ctx.BuildButtonStyle then
        return
    end

    if not Layout.ShouldShowToggleButton() then
        if existing.Hide then
            existing:Hide()
        end
        return
    end

    if existing.Hide then
        existing:Hide()
    end

    local scale = Layout.GetViewportScale()
    local root = existing:GetElementByID(ctx.TOGGLE_ROOT_ID)
    local rebuild = false
    if not root then
        rebuild = true
    elseif not uiState.ToggleScale or math.abs(scale - uiState.ToggleScale) > 0.01 then
        rebuild = true
    end

    if rebuild then
        if root then
            existing:DestroyElement(root)
        end

        root = existing:CreateElement(ctx.TOGGLE_ROOT_ID, "GenericUI_Element_Empty")
        root:SetPosition(0, 0)

        local style = ctx.buttonPrefab.STYLES and (ctx.buttonPrefab.STYLES.SmallRed or ctx.buttonPrefab.STYLES.MediumRed or ctx.buttonPrefab.STYLES.SmallBrown or ctx.buttonPrefab.STYLES.MenuSlate) or nil
        local button = ctx.buttonPrefab.Create(existing, "ForgeToggleButton", root, ctx.BuildButtonStyle(math.floor(76 * scale), math.floor(24 * scale), style))
        button:SetLabel("Forge")

        local buttonRoot = button.Root or (button.GetRootElement and button:GetRootElement() or nil)
        if buttonRoot then
            buttonRoot:SetPosition(0, 0)
        end

        local function HandleToggle()
            if ctx and ctx.Ext then
                local uiState = GetUIState()
                local hasLayout = Layout.HasLayout()
                local visible = ctx.uiInstance and ctx.uiInstance.IsVisible and ctx.uiInstance:IsVisible() or false
                ctx.Ext.Print(string.format(
                    "[ForgingUI] Toggle pressed: uiInstance=%s hasLayout=%s visible=%s pending=%s",
                    tostring(ctx.uiInstance ~= nil),
                    tostring(hasLayout),
                    tostring(visible),
                    tostring(uiState and uiState.PendingShowAfterBuild)
                ))
            end

            if ctx and ctx.ForgingUI and ctx.ForgingUI.Toggle then
                local ok, err = pcall(ctx.ForgingUI.Toggle)
                if not ok and ctx and ctx.Ext then
                    ctx.Ext.Print(string.format("[ForgingUI] Toggle error: %s", tostring(err)))
                end
            else
                if ctx and ctx.Ext then
                    ctx.Ext.Print("[ForgingUI] Toggle handler unavailable; UI not initialized.")
                end
            end
        end

        if button.Events and button.Events.Pressed then
            button.Events.Pressed:Subscribe(function()
                HandleToggle()
            end)
        elseif button.Events and button.Events.MouseUp then
            button.Events.MouseUp:Subscribe(function()
                HandleToggle()
            end)
        end

        uiState.ToggleScale = scale
    end

    Layout.ScheduleTogglePosition(0.05)
    if existing.TogglePlayerInput then
        existing:TogglePlayerInput(true)
    end
end

function Layout.EnsureViewportListener()
    local uiState = GetUIState()
    if not uiState or uiState.ViewportHooked then
        return
    end
    if Client and Client.Events and Client.Events.ViewportChanged then
        Client.Events.ViewportChanged:Subscribe(function()
            if uiState.ToggleUIInstance then
                Layout.ScheduleTogglePosition(0.1)
            end
            if ctx and ctx.uiInstance then
                local state = GetLayoutState()
                local prevW, prevH = state.Width, state.Height
                Layout.UpdateUISizeFromViewport()
                if prevW ~= state.Width or prevH ~= state.Height then
                    local wasVisible = uiState.IsVisible
                    ctx.ForgingUI.Rebuild()
                    if wasVisible then
                        ctx.ForgingUI.Show()
                    end
                elseif uiState.IsVisible then
                    Layout.PositionUI()
                end
            end
        end)
        uiState.ViewportHooked = true
    end
end

function Layout.EnsureEscListener()
    local uiState = GetUIState()
    if uiState and (uiState.EscHooked or not ctx or not ctx.uiInstance or not ctx.uiInstance.Events or not ctx.uiInstance.SetIggyEventCapture) then
        return
    end

    ctx.uiInstance.Events.IggyEventUpCaptured:Subscribe(function(ev)
        if ev.EventID == "UICancel" and uiState and uiState.IsVisible then
            ctx.ForgingUI.Hide()
        end
    end)
    uiState.EscHooked = true
end

function Layout.ApplyUIInputState(enabled)
    if not ctx or not ctx.uiInstance then
        return
    end

    if ctx.uiInstance.TogglePlayerInput then
        ctx.uiInstance:TogglePlayerInput(enabled)
    end
    if ctx.uiInstance.SetFlag and ctx.uiInstance.UI_FLAGS then
        ctx.uiInstance:SetFlag(ctx.uiInstance.UI_FLAGS.PLAYER_INPUT_1, enabled)
        ctx.uiInstance:SetFlag(ctx.uiInstance.UI_FLAGS.ACTIVATED, enabled)
    end
    if ctx.uiInstance.SetIggyEventCapture then
        ctx.uiInstance:SetIggyEventCapture("UICancel", enabled)
        ctx.uiInstance:SetIggyEventCapture("ToggleCraft", enabled)
    end
end

function Layout.ScheduleUIInputRefresh()
    if not ctx or not ctx.Timer or not ctx.Timer.Start then
        return
    end
    ctx.Timer.Start("ForgingUI_InputRefresh_1", 0.05, function()
        Layout.ApplyUIInputState(true)
    end)
    ctx.Timer.Start("ForgingUI_InputRefresh_2", 0.2, function()
        Layout.ApplyUIInputState(true)
    end)
    ctx.Timer.Start("ForgingUI_InputRefresh_3", 0.6, function()
        Layout.ApplyUIInputState(true)
    end)
end

function Layout.ScheduleToggleReady()
    local uiState = GetUIState()
    if not uiState then
        return
    end
    if uiState.ToggleReady then
        Layout.EnsureToggleButton()
        return
    end

    uiState.ToggleReady = false
    uiState.ToggleReadyRevision = (uiState.ToggleReadyRevision or 0) + 1
    local revision = uiState.ToggleReadyRevision

    if not ctx or not ctx.Timer or not ctx.Timer.Start then
        uiState.ToggleReady = true
        Layout.EnsureToggleButton()
        return
    end
    ctx.Timer.Start("ForgingUI_ToggleReady", 0.8, function()
        if revision ~= uiState.ToggleReadyRevision then
            return
        end
        uiState.ToggleReady = true
        Layout.EnsureToggleButton()
    end)
end

local function GetWidgets()
    if ctx and ctx.Widgets then
        return ctx.Widgets
    end
    if ctx and ctx.ForgingUI and ctx.ForgingUI.Widgets then
        return ctx.ForgingUI.Widgets
    end
    return nil
end

function Layout.BuildUI()
    if not ctx or not ctx.uiInstance then
        return false
    end

    local widgets = GetWidgets()
    if not widgets then
        return false
    end

    local CreateFrame = widgets.CreateFrame
    local CreateTextElement = widgets.CreateTextElement
    local CreateSkinnedPanel = widgets.CreateSkinnedPanel
    local CreateButtonBox = widgets.CreateButtonBox
    local CreatePreviewInventoryPanel = widgets.CreatePreviewInventoryPanel
    local CreateSectionBox = widgets.CreateSectionBox
    local CreateDropSlot = widgets.CreateDropSlot
    local WireButton = widgets.WireButton
    local RegisterSearchBlur = widgets.RegisterSearchBlur
    local function ApplyElementSize(element, width, height)
        if not element then
            return
        end
        if element.SetSize then
            element:SetSize(width, height)
        end
        if element.SetSizeOverride then
            element:SetSizeOverride(width, height)
        end
    end

    local layout = GetLayoutState()
    local borderSize = ctx.BORDER_SIZE or 0
    local canvasWidth = layout.Width - borderSize * 2
    local canvasHeight = layout.Height - borderSize * 2

    local existingRoot = ctx.uiInstance:GetElementByID(ctx.ROOT_ID)
    if existingRoot then
        ctx.uiInstance:DestroyElement(existingRoot)
    end

    local root = nil
    if ctx.USE_BASE_BACKGROUND and (ctx.USE_TEXTURE_BACKGROUND and ctx.backgroundTexture) then
        root = ctx.uiInstance:CreateElement(ctx.ROOT_ID, "GenericUI_Element_Texture")
        root:SetTexture(ctx.backgroundTexture, V(layout.Width, layout.Height))
        root:SetSize(layout.Width, layout.Height)
    elseif ctx.USE_BASE_BACKGROUND then
        root = ctx.uiInstance:CreateElement(ctx.ROOT_ID, "GenericUI_Element_TiledBackground")
        root:SetBackground("Note", layout.Width, layout.Height)
    else
        root = ctx.uiInstance:CreateElement(ctx.ROOT_ID, "GenericUI_Element_Empty")
        root:SetSize(layout.Width, layout.Height)
    end

    if ctx.USE_SLICED_BASE then
        CreateFrame(root, "BaseFrame", 0, 0, layout.Width, layout.Height, ctx.FILL_COLOR, ctx.BASE_PANEL_ALPHA, Layout.Scale(10), true)
    end
    if root.SetScale then
        root:SetScale(V(1, 1))
    end
    if root.SetSizeOverride then
        root:SetSizeOverride(layout.Width, layout.Height)
    end
    root:SetPosition(0, 0)

    local canvas = root:AddChild("ForgingUI_Content", "GenericUI_Element_Empty")
    canvas:SetPosition(borderSize, borderSize)
    -- Only create opaque canvas background if not using sliced base (which has its own transparency)
    if not (ctx.USE_TEXTURE_BACKGROUND and ctx.backgroundTexture) and not ctx.USE_SLICED_BASE then
        local canvasBG = canvas:AddChild("ForgingUI_ContentBG", "GenericUI_Element_Color")
        canvasBG:SetSize(canvasWidth, canvasHeight)
        canvasBG:SetColor(ctx.FILL_COLOR)
        canvasBG:SetAlpha(1)
        canvasBG:SetPosition(0, 0)
    end

    local margin = Layout.Scale(ctx.UI_OUTER_MARGIN or 0)
    local gap = Layout.Scale(ctx.UI_PANEL_GAP or 0)
    -- Allow negative gap to close gaps between panels
    local gapX = gap
    local topBarHeight = Layout.ScaleY(40)
    local leftWidth = Layout.ScaleX(400)
    local rightWidth = ctx.USE_SIDE_INVENTORY_PANEL and Layout.ScaleX(480) or 0
    -- Height for Wiki + Result panels (positive increases height)
    local wikiResultHeightOffset = -30
    local bottomHeight = Layout.ScaleY(260 + wikiResultHeightOffset)

    local topBarWidth = canvasWidth - margin * 2
    local topBar = canvas:AddChild("TopBar", "GenericUI_Element_Empty")
    topBar:SetPosition(margin, margin)
    if RegisterSearchBlur then
        RegisterSearchBlur(topBar)
    end
    local dragArea = topBar:AddChild("ForgeUIDragArea", "GenericUI_Element_Color")
    dragArea:SetSize(topBarWidth, topBarHeight)
    dragArea:SetColor(ctx.HEADER_FILL_COLOR)
    dragArea:SetAlpha(0)
    dragArea:SetAsDraggableArea()
    if RegisterSearchBlur then
        RegisterSearchBlur(dragArea)
    end

    local topButtonHeight = Layout.Clamp(Layout.ScaleY(32), 40, 50)
    local topButtonY = math.floor((topBarHeight - topButtonHeight) / 2)
    local topBarPaddingX = Layout.ScaleX(8)
    local forgeTabBtn = CreateButtonBox(topBar, "Btn_ForgeTab", "Forge", topBarPaddingX, topButtonY, 100, topButtonHeight, false, ctx.styleDOS1Blue or ctx.styleLargeRed)
    WireButton(forgeTabBtn, "ForgeTab")
    local uniqueTabBtn = CreateButtonBox(topBar, "Btn_UniqueTab", "Unique Forge", topBarPaddingX + 100, topButtonY, 175, topButtonHeight, false, ctx.styleDOS1Blue or ctx.styleLargeRed)
    WireButton(uniqueTabBtn, "UniqueForgeTab")

    local rightX = topBarWidth - topBarPaddingX
    local closeSize = topBarHeight
    local closeBtn = CreateButtonBox(topBar, "Btn_Close", "", topBarWidth - closeSize, 0, closeSize, closeSize, false, ctx.styleCloseDOS1Square or ctx.styleClose)
    if closeBtn and closeBtn.Events and closeBtn.Events.Pressed then
        closeBtn.Events.Pressed:Subscribe(function()
            if ctx.ForgingUI and ctx.ForgingUI.Hide then
                ctx.ForgingUI.Hide()
            end
        end)
    end
    rightX = rightX - closeSize - 6

    local rightButtons = {
        {Label = "Level Up", Width = 80},
        {Label = "Level Up All", Width = 100},
        {Label = "Toggle Auto\nLevel Up", Width = 110, Wrap = true},
    }
    for i = #rightButtons, 1, -1 do
        local button = rightButtons[i]
        rightX = rightX - button.Width
        local topBtn = CreateButtonBox(topBar, "Btn_TopRight_" .. i, button.Label, rightX, topButtonY, button.Width, topButtonHeight, button.Wrap, ctx.styleTabCharacterSheetWide)
        WireButton(topBtn, button.Label)
        rightX = rightX - 6
    end

    local contentTop = margin + topBarHeight + gap
    local contentHeight = canvasHeight - margin - contentTop
    local warningHeight = Layout.Clamp(Layout.ScaleY(24), 20, 28)
    local warningY = contentTop - warningHeight - Layout.ScaleY(4)
    if warningY < (margin + topBarHeight) then
        warningY = margin + topBarHeight + Layout.ScaleY(2)
    end
    local warningX = margin
    local warningWidth = canvasWidth - margin * 2
    local warningBG = canvas:AddChild("ForgeWarning_BG", "GenericUI_Element_Color")
    warningBG:SetPosition(warningX, warningY)
    warningBG:SetSize(warningWidth, warningHeight)
    warningBG:SetColor(Color.CreateFromHex("2E1D12"))
    warningBG:SetAlpha(0.75)
    if warningBG.SetVisible then
        warningBG:SetVisible(false)
    end
    local warningLabel = CreateTextElement(canvas, "ForgeWarning_Label", "", warningX + 8, warningY + 2, warningWidth - 16, warningHeight, "Left", false, {Size = 14, Color = "FFD27F", FontType = Text.FONTS.BOLD})
    if warningLabel and warningLabel.SetVisible then
        warningLabel:SetVisible(false)
    end
    local uiState = GetUIState()
    if uiState then
        uiState.WarningLabel = warningLabel
        uiState.WarningBackground = warningBG
    end
    local contentInsetX = Layout.Scale(ctx.UI_CONTENT_INSET_X or 0)
    local rightXPos = canvasWidth - margin - rightWidth - contentInsetX
    local leftX = margin
    local midX = leftX + leftWidth + gapX + contentInsetX
    -- Don't subtract gapX from midWidth - already accounted for in midX
    local midWidth = rightXPos - midX
    local midTopHeight = contentHeight - bottomHeight - gap
    local layoutTuning = ctx and ctx.LayoutTuning or nil
    -- Height multiplier for Main/Donor slot panels (1.0 = same as Preview, >1.0 = taller, <1.0 = shorter)
    local slotPanelHeightMultiplier = (layoutTuning and layoutTuning.SlotPanelHeightMultiplier) or 1.05
    local slotPanelHeightBoost = Layout.ScaleY((layoutTuning and layoutTuning.SlotPanelHeightBoostY) or 20)
    local slotPanelHeight = math.floor(midTopHeight * slotPanelHeightMultiplier) + slotPanelHeightBoost
    -- Vertical offset to move Main/Donor panels up (negative values move up, positive move down)
    -- Keep the bottom edge steady while extending upward to close the top gap.
    local slotPanelOffsetY = ((layoutTuning and layoutTuning.SlotPanelOffsetYBase) or -11) - slotPanelHeightBoost
    -- Vertical offset for Info panel and Preview panel (positive moves down)
    local infoPanelOffsetY = 4
    local midBottomY = contentTop + midTopHeight + gap
    local columnGap = Layout.Scale(ctx.UI_COLUMN_GAP or 0)
    local columnTotal = midWidth - columnGap * 2
    -- Main and Donor slots share the same width ratio (they use the same template)
    local slotPanelWidthRatio = 0.30
    local slotPanelWidth = math.floor(columnTotal * slotPanelWidthRatio)
    local previewWidth = columnTotal - slotPanelWidth * 2
    local baseMainX = midX
    local basePreviewX = baseMainX + slotPanelWidth + columnGap
    local baseDonorX = basePreviewX + previewWidth + columnGap
    local slotPanelWidthBoost = Layout.ScaleX((layoutTuning and layoutTuning.SlotPanelWidthBoostX) or 16)
    local slotPanelWidthHalf = math.floor(slotPanelWidthBoost / 2)
    local donorRightEdgeBoost = Layout.ScaleX((layoutTuning and layoutTuning.DonorRightEdgeBoostX) or 9)
    local mainWidth = slotPanelWidth + slotPanelWidthBoost
    local donorWidth = slotPanelWidth + slotPanelWidthBoost + donorRightEdgeBoost
    local mainX = baseMainX - slotPanelWidthHalf
    local previewX = basePreviewX
    local donorX = baseDonorX - slotPanelWidthHalf

    local craftState = ctx.Craft and ctx.Craft.State or nil
    if craftState then
        craftState.Anchor = nil
        craftState.PreviewAnchorID = nil
        craftState.PreviewArea = nil
    end

    local infoHeight = contentHeight - Layout.ScaleY(infoPanelOffsetY)
    local infoPanelY = contentTop + Layout.ScaleY(infoPanelOffsetY)
    local leftInfoFrame, leftInfo, leftInfoWidth, leftInfoHeight = CreateSkinnedPanel(canvas, "LeftInfo", leftX, infoPanelY, leftWidth, infoHeight, ctx.introPanelTexture, Layout.Scale(10))
    if RegisterSearchBlur then
        RegisterSearchBlur(leftInfoFrame)
        RegisterSearchBlur(leftInfo)
    end
    local leftHeaderHeight = 0
    if leftInfo then
        CreateTextElement(leftInfo, "LeftInfo_Header", "Forge / Unique Forge", 0, 0, leftInfoWidth, 22, "Center", false, {size = ctx.HEADER_TEXT_SIZE})
        leftHeaderHeight = 22
    end
    local infoText = table.concat({
        "Only the items that are at or greater than",
        "the player's level can be used for forge.",
        "",
        "Higher quality materials yield better",
        "results.",
        "",
        "Combine different materials to create",
        "unique properties and enchantments.",
        "",
        "Use materials and items to craft powerful",
        "equipment.",
    }, "\n")
    CreateTextElement(leftInfo, "LeftInfo_Text", infoText, 12, leftHeaderHeight + 10, leftInfoWidth - 24, infoHeight - leftHeaderHeight - 20, "Left", true)

    local columnConfigs = {
        {ID = "Main", Title = "Main Slot", Mode = "Main", X = mainX, Width = mainWidth, Texture = ctx.slotPanelTexture, Padding = Layout.Scale(6)},
        {ID = "Donor", Title = "Donor Slot", Mode = "Donor", X = donorX, Width = donorWidth, Texture = ctx.slotPanelTexture, Padding = Layout.Scale(6)},
        {ID = "Preview", Title = "", Mode = "Preview", X = previewX, Width = previewWidth, Texture = ctx.previewPanelTexture, Padding = Layout.Scale(8)},
    }

    for _, cfg in ipairs(columnConfigs) do
        -- Use separate height for Main/Donor panels, standard height for Preview
        local panelHeight = (cfg.Mode == "Main" or cfg.Mode == "Donor") and slotPanelHeight or (midTopHeight - Layout.ScaleY(infoPanelOffsetY))
        -- Apply vertical offset: Main/Donor move up, Preview moves down
        local panelY = contentTop
        if cfg.Mode == "Main" or cfg.Mode == "Donor" then
            panelY = contentTop + Layout.ScaleY(slotPanelOffsetY)
        elseif cfg.Mode == "Preview" then
            panelY = contentTop + Layout.ScaleY(infoPanelOffsetY)
        end
        local panelFrame, panel, panelInnerWidth, panelInnerHeight = CreateSkinnedPanel(
            canvas,
            "Column_" .. cfg.ID,
            cfg.X,
            panelY,
            cfg.Width,
            panelHeight,
            cfg.Texture,
            cfg.Padding
        )
        if RegisterSearchBlur and cfg.Mode ~= "Preview" then
            RegisterSearchBlur(panelFrame)
            RegisterSearchBlur(panel)
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
            CreateTextElement(panel, cfg.ID .. "_HeaderText", cfg.Title, 0, headerOffsetY, panelInnerWidth, 26, "Center", false, headerFormat)
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
            local previewButtonWidth = Layout.ScaleX(260)  -- Fixed width that maintains aspect ratio
            local previewButtonX = math.floor((panelInnerWidth - previewButtonWidth) / 2)  -- Center the button
            local previewButtonY = headerHeight + columnGap
            local previewButton = CreateButtonBox(panel, "Preview_PreviewButton", "Click to Preview", previewButtonX, previewButtonY, previewButtonWidth, previewButtonHeight, false, primaryStyle)
            WireButton(previewButton, "ClickToPreview")
            local previewY = previewButtonY + previewButtonHeight + previewButtonGap
            local previewHeight = panelInnerHeight - previewY - columnGap
            local previewInner = panel:AddChild(cfg.ID .. "_PreviewArea_Inner", "GenericUI_Element_Empty")
            previewInner:SetPosition(6, previewY)
            ApplyElementSize(previewInner, panelInnerWidth - 12, previewHeight)
            if previewInner.SetScale then
                previewInner:SetScale(V(1, 1))
            end
            local innerWidth = panelInnerWidth - 12
            local innerHeight = previewHeight

            if ctx.USE_CUSTOM_PREVIEW_PANEL then
                CreatePreviewInventoryPanel(previewInner, innerWidth, innerHeight, 0, 0)
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
            local childPanelWidthReduction = Layout.ScaleX(60)
            local childPanelWidth = panelInnerWidth - 12 - childPanelWidthReduction
            local childPanelX = 6 + math.floor(childPanelWidthReduction / 2)

            local cursorY = headerHeight + columnGap
            local socketSize = math.min(56, itemHeight - 8)
            local slotX = math.floor((panelInnerWidth - socketSize) / 2)
            local slotY = cursorY + 4
            CreateDropSlot(panel, cfg.ID .. "_ItemSlot", slotX, slotY, socketSize)
            local slotBottom = slotY + socketSize
            local slotToPanelGap = 60
            local reducedGap = math.max(2, math.floor(columnGap * 0.5))
            cursorY = slotBottom + slotToPanelGap

            CreateSectionBox(panel, cfg.ID .. "_Stats", childPanelX, cursorY, childPanelWidth, statsHeight, "Stats", "", "")
            cursorY = cursorY + statsHeight + reducedGap

            CreateSectionBox(panel, cfg.ID .. "_Extra", childPanelX, cursorY, childPanelWidth, extraHeight, "Extra Properties", "", "")
            cursorY = cursorY + extraHeight + reducedGap

            local skillsTitle = cfg.Mode == "Donor" and "Granted Skill / Skillbook Protect" or "Granted Skills"
            local skillsBox = CreateSectionBox(panel, cfg.ID .. "_Skills", childPanelX, cursorY, childPanelWidth, skillsHeight, skillsTitle, "", "")
            if cfg.Mode == "Donor" then
                local slotSize = math.min(50, skillsHeight - 30)
                if slotSize > 0 then
                    local skillsBoxWidth = childPanelWidth
                    local slotSlotX = skillsBoxWidth - slotSize - 8
                    local skillSlotY = math.floor((skillsHeight - slotSize) / 2)
                    CreateDropSlot(skillsBox, "Donor_SkillbookSlot", slotSlotX, skillSlotY, slotSize)
                end
            end

            local runeY = cursorY + skillsHeight + reducedGap
            CreateTextElement(panel, cfg.ID .. "_Runes", "Rune Slots:", childPanelX + 4, runeY, childPanelWidth - 8, runeHeight, "Left")
        end
    end

    if ctx.USE_SIDE_INVENTORY_PANEL then
        local inventoryFrame, inventoryPanel, inventoryInnerWidth = CreateFrame(canvas, "InventoryPanel", rightXPos, contentTop, rightWidth, contentHeight, ctx.FILL_COLOR, ctx.FRAME_ALPHA)
        if RegisterSearchBlur then
            RegisterSearchBlur(inventoryFrame)
            RegisterSearchBlur(inventoryPanel)
        end
        local inventoryHeaderHeight = 22
        local _, inventoryHeaderInner, headerInnerWidth, headerInnerHeight = CreateFrame(inventoryPanel, "InventoryHeader", 0, 0, inventoryInnerWidth, inventoryHeaderHeight, ctx.HEADER_FILL_COLOR, 1)
        CreateTextElement(inventoryHeaderInner, "InventoryLabel", "Inventory", 0, 0, headerInnerWidth - 70, headerInnerHeight, "Center", false, {size = ctx.HEADER_TEXT_SIZE})

        local sortWidth = 70
        local sortButton = CreateButtonBox(inventoryHeaderInner, "InventorySort", "Sort by", headerInnerWidth - sortWidth, 0, sortWidth, headerInnerHeight)
        WireButton(sortButton, "InventorySort")

        local grid = inventoryPanel:AddChild("InventoryGrid", "GenericUI_Element_Grid")
        local gridPadding = 8
        local gridGap = 1
        local cols = 6
        local rows = 7
        local gridWidth = inventoryInnerWidth - gridPadding * 2
        local cellSize = math.floor((gridWidth - (cols - 1) * gridGap) / cols)
        grid:SetGridSize(rows, cols)
        grid:SetElementSpacing(gridGap, gridGap)
        grid:SetPosition(gridPadding, inventoryHeaderHeight + gridPadding)
        grid:SetRepositionAfterAdding(true)
        for i = 1, rows * cols do
            local cell = nil
            if ctx.gridCellTexture then
                cell = grid:AddChild("InventoryCell_" .. i, "GenericUI_Element_Texture")
                cell:SetTexture(ctx.gridCellTexture, V(cellSize, cellSize))
            else
                cell = grid:AddChild("InventoryCell_" .. i, "GenericUI_Element_Color")
                cell:SetSize(cellSize, cellSize)
                cell:SetColor(ctx.GRID_COLOR)
            end
        end
        grid:RepositionElements()
    end

    local wikiWidth = math.floor(midWidth * 0.55)
    local resultWidth = midWidth - wikiWidth - gap
    local wikiFrame, wikiPanel, wikiInnerWidth, wikiInnerHeight = CreateSkinnedPanel(canvas, "ForgeWiki", midX, midBottomY, wikiWidth, bottomHeight, ctx.wikiPanelTexture, Layout.Scale(10))
    local resultFrame, resultPanel, resultInnerWidth, resultInnerHeight = CreateSkinnedPanel(canvas, "ForgeResult", midX + wikiWidth + gap, midBottomY, resultWidth, bottomHeight, ctx.resultPanelTexture, Layout.Scale(10))
    if RegisterSearchBlur then
        RegisterSearchBlur(wikiFrame)
        RegisterSearchBlur(wikiPanel)
        RegisterSearchBlur(resultFrame)
        RegisterSearchBlur(resultPanel)
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

    local dropdownButtonWidth = math.min(Layout.ScaleX(220), wikiInnerWidth - 16)
    local dropdownButtonHeight = Layout.Clamp(Layout.ScaleY(24), 20, 24)
    local dropdownStyle = ctx.styleComboBox or ctx.buttonStyle
    local wikiDropdown = CreateButtonBox(wikiPanel, "ForgeWikiDropdown", "Rarity", 8, 6, dropdownButtonWidth, dropdownButtonHeight, false, dropdownStyle)

    local dropdownHeight = dropdownButtonHeight * #wikiEntries + 12
    local dropdownFrame, dropdownInner = nil, nil
    if ctx.dropdownPanelTexture then
        dropdownFrame, dropdownInner = CreateSkinnedPanel(wikiPanel, "ForgeWikiDropdownPanel", 8, dropdownButtonHeight + 10, dropdownButtonWidth, dropdownHeight, ctx.dropdownPanelTexture, 8)
        dropdownFrame:SetVisible(false)
    end

    local wikiTextY = dropdownButtonHeight + 16
    local wikiText = CreateTextElement(wikiPanel, "ForgeWikiText", wikiLookup["Rarity"], 12, wikiTextY, wikiInnerWidth - 24, wikiInnerHeight - wikiTextY - 12, "Left", true)

    if dropdownInner then
        local optionY = 6
        for _, entry in ipairs(wikiEntries) do
            local optionId = entry.Label:gsub("%s+", "_")
            local option = CreateButtonBox(dropdownInner, "ForgeWikiOption_" .. optionId, entry.Label, 0, optionY, dropdownButtonWidth - 16, dropdownButtonHeight, false, dropdownStyle)
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

    CreateTextElement(resultPanel, "ForgeResultHeader", "Forge Result", 0, 6, resultInnerWidth, 18, "Center", false, {size = ctx.HEADER_TEXT_SIZE})
    local primaryStyle = ctx.styleLargeRedWithArrows or ctx.buttonStyle
    local forgeButtonWidth = 110
    local forgeButtonHeight = Layout.Clamp(Layout.ScaleY(24), 20, 24)
    local forgeButtonX = resultInnerWidth - forgeButtonWidth - 12
    local forgeButtonY = resultInnerHeight - forgeButtonHeight - 6
    local forgeActionBtn = CreateButtonBox(resultPanel, "ForgeActionButton", "Forge", forgeButtonX, forgeButtonY, forgeButtonWidth, forgeButtonHeight, false, primaryStyle)
    WireButton(forgeActionBtn, "ForgeAction")

    -- Ensure the top bar sits above the panels so its buttons receive input.
    if (layoutTuning == nil or layoutTuning.RaiseTopBarToFront)
        and topBar and canvas and canvas.SetChildIndex and canvas.GetChildren then
        local children = canvas:GetChildren() or {}
        canvas:SetChildIndex(topBar, math.max(0, #children - 1))
    end

    return true
end

return Layout
