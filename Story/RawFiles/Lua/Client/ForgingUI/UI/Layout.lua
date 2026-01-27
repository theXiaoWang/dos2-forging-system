-- Client/ForgingUI/UI/Layout.lua
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
local TopBar = Ext.Require("Client/ForgingUI/UI/Layout/TopBar.lua")
local WarningBanner = Ext.Require("Client/ForgingUI/UI/Layout/WarningBanner.lua")
local LeftInfo = Ext.Require("Client/ForgingUI/UI/Layout/LeftInfo.lua")
local Columns = Ext.Require("Client/ForgingUI/UI/Layout/Columns.lua")
local SideInventory = Ext.Require("Client/ForgingUI/UI/Layout/SideInventory.lua")
local BottomPanels = Ext.Require("Client/ForgingUI/UI/Layout/BottomPanels.lua")
local Base = Ext.Require("Client/ForgingUI/UI/Layout/Base.lua")
local Geometry = Ext.Require("Client/ForgingUI/UI/Layout/Geometry.lua")

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
    local uiState = GetUIState()
    local dragWidth = uiState and uiState.DragBoundsWidth or nil
    local dragHeight = uiState and uiState.DragBoundsHeight or nil
    if ctx.uiInstance.SetPanelSize and state then
        local width = state.Width
        local height = state.Height
        if dragWidth and dragWidth > 0 then
            width = dragWidth
        end
        if dragHeight and dragHeight > 0 then
            height = dragHeight
        end
        ctx.uiInstance:SetPanelSize(V(width, height))
    end
    if ctx.uiInstance.SetPositionRelativeToViewport then
        ctx.uiInstance:SetPositionRelativeToViewport("center", "center", "screen", 0)
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

    local geometry = Geometry.Compute({
        ctx = ctx,
        canvasWidth = canvasWidth,
        canvasHeight = canvasHeight,
        scale = Layout.Scale,
        scaleX = Layout.ScaleX,
        scaleY = Layout.ScaleY,
        clamp = Layout.Clamp,
    })
    if not geometry then
        return false
    end

    local layoutTuning = geometry.layoutTuning
    local topBarX = geometry.margin
    local topBarWidth = geometry.topBarWidth
    do
        local minX = nil
        local maxX = nil
        local function consider(x, width)
            if not width or width <= 0 then
                return
            end
            if minX == nil or x < minX then
                minX = x
            end
            local right = x + width
            if maxX == nil or right > maxX then
                maxX = right
            end
        end
        consider(geometry.leftX, geometry.leftWidth)
        for _, cfg in ipairs(geometry.columnConfigs or {}) do
            consider(cfg.X, cfg.Width)
        end
        if ctx.USE_SIDE_INVENTORY_PANEL then
            consider(geometry.rightXPos, geometry.rightWidth)
        end
        if minX ~= nil and maxX ~= nil then
            topBarX = minX
            topBarWidth = math.max(0, maxX - minX)
        end
    end
    if layoutTuning and layoutTuning.TopBarTrimX then
        local trimX = Layout.ScaleX(layoutTuning.TopBarTrimX)
        if trimX ~= 0 then
            topBarX = topBarX + trimX
            topBarWidth = math.max(0, topBarWidth - trimX * 2)
        end
    end

    -- Trim the base frame to the lowest child panel edge.
    local baseFrameHeight = nil
    local baseFramePadding = 0
    local slotPanelExtraBottom = 0
    if layoutTuning and layoutTuning.BaseFrameBottomPaddingY then
        baseFramePadding = Layout.ScaleY(layoutTuning.BaseFrameBottomPaddingY)
    end
    if layoutTuning and layoutTuning.SlotPanelExtraBottomY then
        slotPanelExtraBottom = Layout.ScaleY(layoutTuning.SlotPanelExtraBottomY)
    end
    local infoBottom = geometry.contentTop + geometry.midTopHeight
    local slotBottom = geometry.contentTop + Layout.ScaleY(geometry.slotPanelOffsetY) + geometry.slotPanelHeight
    local panelBottom = math.max(infoBottom, slotBottom)
    local infoExtraBottom = baseFramePadding + (panelBottom - infoBottom)
    local slotExtraBottom = baseFramePadding + (panelBottom - slotBottom) + slotPanelExtraBottom
    if infoExtraBottom < 0 then
        infoExtraBottom = 0
    end
    if slotExtraBottom < 0 then
        slotExtraBottom = 0
    end
    baseFrameHeight = math.min(layout.Height, math.max(0, borderSize + panelBottom + baseFramePadding))
    local baseFrameX = 0
    local baseFrameY = 0
    local baseFrameWidth = math.min(layout.Width, math.max(0, (geometry.canvasWidth or canvasWidth) + borderSize * 2))
    do
        local minX = nil
        local maxX = nil
        local function consider(x, width)
            if not width or width <= 0 then
                return
            end
            if minX == nil or x < minX then
                minX = x
            end
            local right = x + width
            if maxX == nil or right > maxX then
                maxX = right
            end
        end
        consider(topBarX, topBarWidth)
        consider(geometry.leftX, geometry.leftWidth)
        for _, cfg in ipairs(geometry.columnConfigs or {}) do
            consider(cfg.X, cfg.Width)
        end
        if ctx.USE_SIDE_INVENTORY_PANEL then
            consider(geometry.rightXPos, geometry.rightWidth)
        end
        if minX ~= nil and maxX ~= nil then
            baseFrameX = borderSize + minX
            baseFrameWidth = math.max(0, maxX - minX)
            if baseFrameX < 0 then
                baseFrameWidth = math.max(0, baseFrameWidth + baseFrameX)
                baseFrameX = 0
            end
            if baseFrameX + baseFrameWidth > layout.Width then
                baseFrameWidth = math.max(0, layout.Width - baseFrameX)
            end
        end
    end
    if layoutTuning and layoutTuning.BaseFrameTrimX then
        local trimX = Layout.ScaleX(layoutTuning.BaseFrameTrimX)
        if trimX ~= 0 then
            baseFrameX = baseFrameX + trimX
            baseFrameWidth = math.max(0, baseFrameWidth - trimX * 2)
        end
    end
    local dragBoundsWidth = baseFrameWidth
    local dragBoundsHeight = baseFrameHeight
    if layoutTuning and layoutTuning.DragBoundsTrimX then
        local trimX = Layout.ScaleX(layoutTuning.DragBoundsTrimX)
        if trimX ~= 0 then
            dragBoundsWidth = math.max(0, dragBoundsWidth - trimX * 2)
        end
    end
    if layoutTuning and layoutTuning.BaseFrameScale and layoutTuning.BaseFrameScale ~= 1 then
        local baseScale = layoutTuning.BaseFrameScale
        local newWidth = math.floor(baseFrameWidth * baseScale + 0.5)
        local newHeight = math.floor(baseFrameHeight * baseScale + 0.5)
        local dx = math.floor((newWidth - baseFrameWidth) / 2 + 0.5)
        local dy = math.floor((newHeight - baseFrameHeight) / 2 + 0.5)
        baseFrameX = baseFrameX - dx
        baseFrameY = baseFrameY - dy
        baseFrameWidth = newWidth
        baseFrameHeight = newHeight
        if baseFrameX < 0 then
            baseFrameWidth = math.max(0, baseFrameWidth + baseFrameX)
            baseFrameX = 0
        end
        if baseFrameY < 0 then
            baseFrameHeight = math.max(0, baseFrameHeight + baseFrameY)
            baseFrameY = 0
        end
        if baseFrameX + baseFrameWidth > layout.Width then
            baseFrameWidth = math.max(0, layout.Width - baseFrameX)
        end
        if baseFrameY + baseFrameHeight > layout.Height then
            baseFrameHeight = math.max(0, layout.Height - baseFrameY)
        end
    end

    local uiState = GetUIState()
    if uiState then
        if not dragBoundsWidth or dragBoundsWidth <= 0 then
            dragBoundsWidth = baseFrameWidth
        end
        if not dragBoundsHeight or dragBoundsHeight <= 0 then
            dragBoundsHeight = baseFrameHeight
        end
        uiState.DragBoundsWidth = dragBoundsWidth
        uiState.DragBoundsHeight = dragBoundsHeight
    end

    local base = Base.Build({
        ctx = ctx,
        layout = layout,
        borderSize = borderSize,
        createFrame = CreateFrame,
        scale = Layout.Scale,
        vector = V,
        baseFrameHeight = baseFrameHeight,
        baseFrameWidth = baseFrameWidth,
        baseFrameX = baseFrameX,
        baseFrameY = baseFrameY,
        basePanelTexture = ctx.basePanelTexture,
    })
    if not base then
        return false
    end
    local root = base.Root
    local canvas = base.Canvas
    local margin = geometry.margin
    local gap = geometry.gap
    local topBarHeight = geometry.topBarHeight
    local leftWidth = geometry.leftWidth
    local rightWidth = geometry.rightWidth
    local bottomHeight = geometry.bottomHeight
    local topBar = TopBar.Create({
        ctx = ctx,
        canvas = canvas,
        margin = margin,
        topBarX = topBarX,
        topBarHeight = topBarHeight,
        topBarWidth = topBarWidth,
        registerSearchBlur = RegisterSearchBlur,
        createFrame = CreateFrame,
        createButtonBox = CreateButtonBox,
        wireButton = WireButton,
        scaleX = Layout.ScaleX,
        scaleY = Layout.ScaleY,
        clamp = Layout.Clamp,
    })

    local contentTop = geometry.contentTop
    local contentHeight = geometry.contentHeight
    local warningHeight = geometry.warningHeight
    local warningY = geometry.warningY
    local warningX = geometry.warningX
    local warningWidth = geometry.warningWidth
    local warningElements = WarningBanner.Create({
        canvas = canvas,
        x = warningX,
        y = warningY,
        width = warningWidth,
        height = warningHeight,
        createTextElement = CreateTextElement,
        textStyle = {Size = 14, Color = "FFD27F", FontType = Text.FONTS.BOLD},
        bgColor = "2E1D12",
        bgAlpha = 0.75,
        labelOffsetX = 8,
        labelOffsetY = 2,
    })
    local warningBG = warningElements and warningElements.Background or nil
    local warningLabel = warningElements and warningElements.Label or nil
    if uiState then
        uiState.WarningLabel = warningLabel
        uiState.WarningBackground = warningBG
    end
    local rightXPos = geometry.rightXPos
    local leftX = geometry.leftX
    local midX = geometry.midX
    local midWidth = geometry.midWidth
    local midTopHeight = geometry.midTopHeight
    local slotPanelHeight = geometry.slotPanelHeight
    local slotPanelOffsetY = geometry.slotPanelOffsetY
    local infoPanelOffsetY = geometry.infoPanelOffsetY
    local midBottomY = geometry.midBottomY

    local craftState = ctx.Craft and ctx.Craft.State or nil
    if craftState then
        craftState.Anchor = nil
        craftState.PreviewAnchorID = nil
        craftState.PreviewArea = nil
    end

    if not (layoutTuning and layoutTuning.HideInfoPanel) then
        local infoHeight = midTopHeight - Layout.ScaleY(infoPanelOffsetY) + infoExtraBottom
        if infoHeight < 0 then
            infoHeight = 0
        end
        local infoPanelY = contentTop + Layout.ScaleY(infoPanelOffsetY)
        LeftInfo.Create({
            canvas = canvas,
            x = leftX,
            y = infoPanelY,
            width = leftWidth,
            height = infoHeight,
            texture = ctx.introPanelTexture,
            padding = Layout.Scale(10),
            headerText = "Forge / Unique Forge",
            headerStyle = {size = ctx.HEADER_TEXT_SIZE},
            bodyText = table.concat({
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
            }, "\n"),
            createSkinnedPanel = CreateSkinnedPanel,
            createTextElement = CreateTextElement,
            registerSearchBlur = RegisterSearchBlur,
        })
    end

    local columnConfigs = geometry.columnConfigs

    Columns.Build({
        ctx = ctx,
        canvas = canvas,
        columnConfigs = columnConfigs,
        contentTop = contentTop,
        midTopHeight = midTopHeight,
        infoPanelOffsetY = infoPanelOffsetY,
        slotPanelHeight = slotPanelHeight,
        slotPanelOffsetY = slotPanelOffsetY,
        extraInfoBottomHeight = infoExtraBottom,
        extraSlotBottomHeight = slotExtraBottom,
        craftState = craftState,
        createSkinnedPanel = CreateSkinnedPanel,
        createTextElement = CreateTextElement,
        createButtonBox = CreateButtonBox,
        createPreviewInventoryPanel = CreatePreviewInventoryPanel,
        createSectionBox = CreateSectionBox,
        createDropSlot = CreateDropSlot,
        registerSearchBlur = RegisterSearchBlur,
        wireButton = WireButton,
        applyElementSize = ApplyElementSize,
        scaleX = Layout.ScaleX,
        scaleY = Layout.ScaleY,
        vector = V,
    })

    if ctx.USE_SIDE_INVENTORY_PANEL then
        local sideInventoryHeight = contentHeight
        if panelBottom then
            sideInventoryHeight = panelBottom - contentTop + baseFramePadding
        end
        if sideInventoryHeight < 0 then
            sideInventoryHeight = 0
        end
        SideInventory.Create({
            ctx = ctx,
            canvas = canvas,
            x = rightXPos,
            y = contentTop,
            width = rightWidth,
            height = sideInventoryHeight,
            createFrame = CreateFrame,
            createTextElement = CreateTextElement,
            createButtonBox = CreateButtonBox,
            registerSearchBlur = RegisterSearchBlur,
            wireButton = WireButton,
            vector = V,
        })
    end

    BottomPanels.Build({
        ctx = ctx,
        canvas = canvas,
        midX = midX,
        midBottomY = midBottomY,
        midWidth = midWidth,
        bottomHeight = bottomHeight,
        gap = gap,
        panelPadding = Layout.Scale(10),
        createSkinnedPanel = CreateSkinnedPanel,
        createTextElement = CreateTextElement,
        createButtonBox = CreateButtonBox,
        registerSearchBlur = RegisterSearchBlur,
        wireButton = WireButton,
        scaleX = Layout.ScaleX,
        scaleY = Layout.ScaleY,
        clamp = Layout.Clamp,
    })

    -- Ensure the top bar sits above the panels so its buttons receive input.
    if (layoutTuning == nil or layoutTuning.RaiseTopBarToFront)
        and topBar and canvas and canvas.SetChildIndex and canvas.GetChildren then
        local children = canvas:GetChildren() or {}
        canvas:SetChildIndex(topBar, math.max(0, #children - 1))
    end

    return true
end

return Layout
