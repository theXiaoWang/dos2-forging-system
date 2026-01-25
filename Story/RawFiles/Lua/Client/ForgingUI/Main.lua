-- Client/ForgingUI/Main.lua
-- Forging System UI built on the local Generic UI framework (no external mod dependency).

local ForgingUI = {}
Client = Client or {}
Client.ForgingUI = ForgingUI
Ext.Require("Client/ForgingUI/Backend/InventoryService.lua")
Ext.Require("Client/ForgingUI/Backend/PreviewInventory/Logic.lua")
Ext.Require("Client/ForgingUI/UI/Widgets.lua")
Ext.Require("Client/ForgingUI/UI/Layout.lua")
Ext.Require("Client/ForgingUI/Backend/CraftDocking.lua")
local LayoutTuning = Ext.Require("Client/ForgingUI/Config/LayoutTuning.lua")
local UIConstants = Ext.Require("Client/ForgingUI/Config/UIConstants.lua")
local PreviewInventoryTuning = Ext.Require("Client/ForgingUI/Config/PreviewInventoryTuning.lua")
local LayoutStateFactory = Ext.Require("Client/ForgingUI/State/LayoutState.lua")
local UIStateFactory = Ext.Require("Client/ForgingUI/State/UIState.lua")
local Inventory = ForgingUI.Inventory or {}
local PreviewLogic = ForgingUI.PreviewInventoryLogic or {}
local Widgets = ForgingUI.Widgets or {}
local Layout = ForgingUI.Layout or {}
local Craft = ForgingUI.Craft or {}
local CraftState = Craft.State or {}
ForgingUI.Slots = {}
ForgingUI.Buttons = {}
local uiInstance = nil
local genericUI = nil
local hotbarSlotPrefab = nil
local slicedTexturePrefab = nil
local buttonPrefab = nil
local buttonStyle = nil
local primaryButtonStyle = nil
local closeButtonPrefab = nil
local styleLargeRed = nil
local styleLargeRedWithArrows = nil
local styleTabCharacterSheetWide = nil
local styleGreenMediumTextured = nil
local styleSquareStone = nil
local styleComboBox = nil
local styleDOS1Blue = nil
local styleClose = nil
local styleCloseDOS1Square = nil
local panelFrameStyle = nil
local sectionFrameStyle = nil
local backgroundTexture = nil
local backgroundTextureName = nil
local introPanelTexture = nil
local wikiPanelTexture = nil
local slotPanelTexture = nil
local previewPanelTexture = nil
local resultPanelTexture = nil
local dropdownPanelTexture = nil
local gridCellTexture = nil
local previewUsedFrameTexture = nil
local mainSlotFrameTexture = nil  -- Frame texture for Main/Donor slot visuals
local V = Vector.Create
local BASE_UI_WIDTH = UIConstants.BaseWidth
local BASE_UI_HEIGHT = UIConstants.BaseHeight
local UI_TARGET_WIDTH_RATIO = UIConstants.TargetWidthRatio
local UI_TARGET_HEIGHT_RATIO = UIConstants.TargetHeightRatio
local UI_OUTER_MARGIN = UIConstants.OuterMargin
local UI_PANEL_GAP = UIConstants.PanelGap
local UI_COLUMN_GAP = UIConstants.ColumnGap
local UI_CONTENT_INSET_X = UIConstants.ContentInsetX
local LayoutState = LayoutStateFactory.Create(BASE_UI_WIDTH, BASE_UI_HEIGHT)
local isEditorBuild = Ext.Utils and Ext.Utils.GameVersion and Ext.Utils.GameVersion() == "v3.6.51.9303"
local editorWarningShown = false
local UI_ID = "ForgingSystem_UI"
local TOGGLE_UI_ID = "ForgingSystem_ToggleUI"
local TOGGLE_ROOT_ID = "ForgingToggleRoot"
local ROOT_ID = "ForgingUI_Root"
local BUILD_TIMER_ID = "ForgingUI_Build"
local UIState = UIStateFactory.Create()
local BORDER_SIZE = UIConstants.BorderSize
local FRAME_ALPHA = UIConstants.FrameAlpha
local FRAME_TEXTURE_ALPHA = UIConstants.FrameTextureAlpha
local FRAME_TEXTURE_CENTER_ALPHA = UIConstants.FrameTextureCenterAlpha
local PANEL_FILL_ALPHA = UIConstants.PanelFillAlpha
local PANEL_TEXTURE_ALPHA = UIConstants.PanelTextureAlpha
local SLOT_PANEL_TEXTURE_ALPHA = UIConstants.SlotPanelTextureAlpha
local PREVIEW_USED_FRAME_ALPHA = UIConstants.PreviewUsedFrameAlpha
local PREVIEW_DROP_SOUND = UIConstants.PreviewDropSound
local BASE_PANEL_ALPHA = UIConstants.BasePanelAlpha
local SECTION_FRAME_ALPHA = UIConstants.SectionFrameAlpha
local SECTION_TEXTURE_CENTER_ALPHA = UIConstants.SectionTextureCenterAlpha
local SECTION_FILL_ALPHA = UIConstants.SectionFillAlpha
local TEXT_COLOR = UIConstants.TextColor
local HEADER_TEXT_SIZE = UIConstants.HeaderTextSize
local BODY_TEXT_SIZE = UIConstants.BodyTextSize
local BORDER_COLOR = Color.CreateFromHex(UIConstants.Colors.Border)
local FILL_COLOR = Color.CreateFromHex(UIConstants.Colors.Fill)
local HEADER_FILL_COLOR = Color.CreateFromHex(UIConstants.Colors.HeaderFill)
local GRID_COLOR = Color.CreateFromHex(UIConstants.Colors.Grid)
local PREVIEW_FILL_COLOR = Color.CreateFromHex(UIConstants.Colors.PreviewFill)
local TOGGLE_OFFSET_X = UIConstants.ToggleOffsetX
local TOGGLE_OFFSET_Y = UIConstants.ToggleOffsetY
local USE_TEXTURE_BACKGROUND = UIConstants.UseTextureBackground
local USE_BASE_BACKGROUND = UIConstants.UseBaseBackground
local USE_SLICED_BASE = UIConstants.UseSlicedBase
local USE_SLICED_FRAMES = UIConstants.UseSlicedFrames
local USE_SLICED_PANELS = UIConstants.UseSlicedPanels
local USE_VANILLA_COMBINE_PANEL = UIConstants.UseVanillaCombinePanel
local USE_SIDE_INVENTORY_PANEL = UIConstants.UseSideInventoryPanel
local USE_CUSTOM_PREVIEW_PANEL = UIConstants.UseCustomPreviewPanel
local displayMode = nil
local CRAFT_FILTER_TIMER_ID = "ForgingUI_CraftFilter"
local PREVIEW_REFRESH_TIMER_ID = "ForgingUI_PreviewRefresh"
local PREVIEW_REFRESH_INTERVAL = UIConstants.PreviewRefreshInterval
local DISPLAY_MODES = {
    Combine = "Combine",
    Preview = "Preview",
}
local CRAFT_PREVIEW_MODES = {
    Equipment = "Equipment",
    Magical = "Magical",
}
displayMode = DISPLAY_MODES.Combine

local Context = {
    V = V,
    Ext = Ext,
    Client = Client,
    ForgingUI = ForgingUI,
    LayoutTuning = LayoutTuning,
    PreviewInventoryTuning = PreviewInventoryTuning,
    LayoutState = LayoutState,
    UIState = UIState,
    ROOT_ID = ROOT_ID,
    UI_ID = UI_ID,
    TOGGLE_UI_ID = TOGGLE_UI_ID,
    TOGGLE_ROOT_ID = TOGGLE_ROOT_ID,
    TOGGLE_OFFSET_X = TOGGLE_OFFSET_X,
    TOGGLE_OFFSET_Y = TOGGLE_OFFSET_Y,
    BASE_UI_WIDTH = BASE_UI_WIDTH,
    BASE_UI_HEIGHT = BASE_UI_HEIGHT,
    UI_TARGET_WIDTH_RATIO = UI_TARGET_WIDTH_RATIO,
    UI_TARGET_HEIGHT_RATIO = UI_TARGET_HEIGHT_RATIO,
    DISPLAY_MODES = DISPLAY_MODES,
    CRAFT_PREVIEW_MODES = CRAFT_PREVIEW_MODES,
    CRAFT_FILTER_TIMER_ID = CRAFT_FILTER_TIMER_ID,
}

local function RefreshContext()
    Context.uiInstance = uiInstance
    Context.genericUI = genericUI
    Context.hotbarSlotPrefab = hotbarSlotPrefab
    Context.slicedTexturePrefab = slicedTexturePrefab
    Context.buttonPrefab = buttonPrefab
    Context.buttonStyle = buttonStyle
    Context.primaryButtonStyle = primaryButtonStyle
    Context.closeButtonPrefab = closeButtonPrefab
    Context.styleLargeRed = styleLargeRed
    Context.styleLargeRedWithArrows = styleLargeRedWithArrows
    Context.styleTabCharacterSheetWide = styleTabCharacterSheetWide
    Context.styleGreenMediumTextured = styleGreenMediumTextured
    Context.styleSquareStone = styleSquareStone
    Context.styleComboBox = styleComboBox
    Context.styleDOS1Blue = styleDOS1Blue
    Context.styleClose = styleClose
    Context.styleCloseDOS1Square = styleCloseDOS1Square
    Context.panelFrameStyle = panelFrameStyle
    Context.sectionFrameStyle = sectionFrameStyle
    Context.backgroundTexture = backgroundTexture
    Context.backgroundTextureName = backgroundTextureName
    Context.introPanelTexture = introPanelTexture
    Context.wikiPanelTexture = wikiPanelTexture
    Context.slotPanelTexture = slotPanelTexture
    Context.previewPanelTexture = previewPanelTexture
    Context.resultPanelTexture = resultPanelTexture
    Context.dropdownPanelTexture = dropdownPanelTexture
    Context.gridCellTexture = gridCellTexture
    Context.PREVIEW_USED_FRAME_TEXTURE = previewUsedFrameTexture
    Context.mainSlotFrameTexture = mainSlotFrameTexture
    Context.BORDER_SIZE = BORDER_SIZE
    Context.FRAME_ALPHA = FRAME_ALPHA
    Context.FRAME_TEXTURE_ALPHA = FRAME_TEXTURE_ALPHA
    Context.FRAME_TEXTURE_CENTER_ALPHA = FRAME_TEXTURE_CENTER_ALPHA
    Context.PANEL_FILL_ALPHA = PANEL_FILL_ALPHA
    Context.PANEL_TEXTURE_ALPHA = PANEL_TEXTURE_ALPHA
    Context.SLOT_PANEL_TEXTURE_ALPHA = SLOT_PANEL_TEXTURE_ALPHA
    Context.PREVIEW_USED_FRAME_ALPHA = PREVIEW_USED_FRAME_ALPHA
    Context.PREVIEW_DROP_SOUND = PREVIEW_DROP_SOUND
    Context.BASE_PANEL_ALPHA = BASE_PANEL_ALPHA
    Context.SECTION_FRAME_ALPHA = SECTION_FRAME_ALPHA
    Context.SECTION_TEXTURE_CENTER_ALPHA = SECTION_TEXTURE_CENTER_ALPHA
    Context.SECTION_FILL_ALPHA = SECTION_FILL_ALPHA
    Context.TEXT_COLOR = TEXT_COLOR
    Context.HEADER_TEXT_SIZE = HEADER_TEXT_SIZE
    Context.BODY_TEXT_SIZE = BODY_TEXT_SIZE
    Context.BORDER_COLOR = BORDER_COLOR
    Context.FILL_COLOR = FILL_COLOR
    Context.HEADER_FILL_COLOR = HEADER_FILL_COLOR
    Context.GRID_COLOR = GRID_COLOR
    Context.PREVIEW_FILL_COLOR = PREVIEW_FILL_COLOR
    Context.USE_TEXTURE_BACKGROUND = USE_TEXTURE_BACKGROUND
    Context.USE_BASE_BACKGROUND = USE_BASE_BACKGROUND
    Context.USE_SLICED_BASE = USE_SLICED_BASE
    Context.USE_SLICED_FRAMES = USE_SLICED_FRAMES
    Context.USE_SLICED_PANELS = USE_SLICED_PANELS
    Context.USE_VANILLA_COMBINE_PANEL = USE_VANILLA_COMBINE_PANEL
    Context.USE_SIDE_INVENTORY_PANEL = USE_SIDE_INVENTORY_PANEL
    Context.USE_CUSTOM_PREVIEW_PANEL = USE_CUSTOM_PREVIEW_PANEL
    Context.UI_OUTER_MARGIN = UI_OUTER_MARGIN
    Context.UI_PANEL_GAP = UI_PANEL_GAP
    Context.UI_COLUMN_GAP = UI_COLUMN_GAP
    Context.UI_CONTENT_INSET_X = UI_CONTENT_INSET_X
    Context.Inventory = Inventory
    Context.PreviewLogic = PreviewLogic
    Context.Widgets = Widgets
    Context.Timer = Timer
    Context.Craft = Craft
    Context.RequestCraftDock = Craft.RequestDock
    Context.GetDisplayMode = function()
        return displayMode
    end
    if SetDisplayMode then
        Context.SetDisplayMode = SetDisplayMode
    else
        Context.SetDisplayMode = function(mode)
            displayMode = mode
        end
    end
    Context.ScaleX = Layout.ScaleX
    Context.ScaleY = Layout.ScaleY
    Context.Scale = Layout.Scale
    Context.Clamp = Layout.Clamp
    Context.BuildButtonStyle = Widgets.BuildButtonStyle
    Context.SetPreviewInventoryMode = Widgets.SetPreviewInventoryMode
end

Widgets.SetContext(Context)
Layout.SetContext(Context)
Craft.SetContext(Context)
if PreviewLogic and PreviewLogic.SetContext then
    PreviewLogic.SetContext(Context)
end

local RenderPreviewInventory = Widgets.RenderPreviewInventory

local function StartPreviewInventoryRefresh()
    if not USE_CUSTOM_PREVIEW_PANEL then
        return
    end
    if not Timer or not Timer.Start or not Timer.GetTimer then
        return
    end
    if Timer.GetTimer(PREVIEW_REFRESH_TIMER_ID) then
        return
    end
    local timer = Timer.Start(PREVIEW_REFRESH_TIMER_ID, PREVIEW_REFRESH_INTERVAL, function()
        if UIState.IsVisible and USE_CUSTOM_PREVIEW_PANEL then
            RenderPreviewInventory()
        else
            local existing = Timer.GetTimer(PREVIEW_REFRESH_TIMER_ID)
            if existing then
                existing:Cancel()
            end
        end
    end)
    timer:SetRepeatCount(-1)
end

local function StopPreviewInventoryRefresh()
    if not Timer or not Timer.GetTimer then
        return
    end
    local timer = Timer.GetTimer(PREVIEW_REFRESH_TIMER_ID)
    if timer then
        timer:Cancel()
    end
end
local HasLayout = Layout.HasLayout
local PositionUI = Layout.PositionUI
local PrintUIState = Layout.PrintUIState
local PrintElementInfo = Layout.PrintElementInfo
local DumpElementTree = Layout.DumpElementTree
local DumpFillElements = Layout.DumpFillElements
local UpdateUISizeFromViewport = Layout.UpdateUISizeFromViewport
local EnsureToggleButton = Layout.EnsureToggleButton
local EnsureViewportListener = Layout.EnsureViewportListener
local EnsureEscListener = Layout.EnsureEscListener
local ApplyUIInputState = Layout.ApplyUIInputState
local ScheduleUIInputRefresh = Layout.ScheduleUIInputRefresh
local ScheduleToggleReady = Layout.ScheduleToggleReady
local GetClientGameState = Layout.GetClientGameState
local IsGameStateRunning = Layout.IsGameStateRunning

local function DebugShowState(tag)
    if not Ext then
        return
    end
    local uiObject = uiInstance and uiInstance.GetUI and uiInstance:GetUI() or nil
    local visible = uiInstance and uiInstance.IsVisible and uiInstance:IsVisible() or false
    Ext.Print(string.format(
        "[ForgingUI] %s: uiInstance=%s hasLayout=%s uiObject=%s visible=%s",
        tostring(tag),
        tostring(uiInstance ~= nil),
        tostring(HasLayout()),
        tostring(uiObject ~= nil),
        tostring(visible)
    ))
end

local function InitTextureStyles()
    if panelFrameStyle ~= nil then
        return
    end

    local texturesFeature = Client.Textures and Client.Textures.GenericUI
    if not texturesFeature or not texturesFeature.TEXTURES then
        return
    end

    local textures = texturesFeature.TEXTURES
    if textures.PANELS then
        -- Panels stretch at runtime; avoid panel textures entirely and rely on sliced assets.
        backgroundTexture = nil
        backgroundTextureName = nil
        introPanelTexture = nil
        wikiPanelTexture = nil
        slotPanelTexture = nil
        previewPanelTexture = nil
        resultPanelTexture = nil
        dropdownPanelTexture = nil
    end
    if textures.PANELS and (textures.PANELS.CLIPBOARD_THIN or textures.PANELS.TALL_PAGE) then
        -- Use the clipboard thin panel for main/donor slot columns (stretched to fit).
        slotPanelTexture = textures.PANELS.CLIPBOARD_THIN or textures.PANELS.TALL_PAGE
    end

    if backgroundTextureName then
        Ext.Print(string.format("[ForgingUI] Background panel set to %s", backgroundTextureName))
    end

    if not backgroundTexture and textures.BACKGROUNDS then
        backgroundTexture = textures.BACKGROUNDS.NOTEBOOK or textures.BACKGROUNDS.PAGE
    end

    if textures.FRAMES then
        gridCellTexture = textures.FRAMES.DITTERED_CELL or textures.FRAMES.BROWN_SHADED
        if not gridCellTexture and textures.FRAMES.RECTANGLES then
            gridCellTexture = textures.FRAMES.RECTANGLES.TINY
        end
        -- Use WHITE_SHADED frame for used items in preview inventory
        previewUsedFrameTexture = textures.FRAMES.WHITE_SHADED
        -- Fancy silver highlighted frame for Main/Donor slots
        Ext.Print("[ForgingUI] Checking textures.FRAMES.SLOT: " .. tostring(textures.FRAMES.SLOT ~= nil))
        if textures.FRAMES.SLOT then
            Ext.Print("[ForgingUI] SLOT.SILVER_HIGHLIGHTED: " .. tostring(textures.FRAMES.SLOT.SILVER_HIGHLIGHTED ~= nil))
            Ext.Print("[ForgingUI] SLOT.SILVER: " .. tostring(textures.FRAMES.SLOT.SILVER ~= nil))
            mainSlotFrameTexture = textures.FRAMES.SLOT.SILVER_HIGHLIGHTED
                or textures.FRAMES.SLOT.SILVER
            Ext.Print("[ForgingUI] mainSlotFrameTexture loaded: " .. tostring(mainSlotFrameTexture ~= nil))
        else
            Ext.Print("[ForgingUI] WARNING: textures.FRAMES.SLOT is nil!")
        end
    end

    if slicedTexturePrefab and slicedTexturePrefab.STYLES then
        panelFrameStyle = slicedTexturePrefab.STYLES.SimpleTooltip
            or slicedTexturePrefab.STYLES.ControllerContextMenu
            or slicedTexturePrefab.STYLES.AztecSquiggles
        sectionFrameStyle = slicedTexturePrefab.STYLES.AztecSquiggles
    end
end

local function WarnEditorUnsupported()
    if not editorWarningShown then
        Ext.Print("[ForgingUI] Generic UI does not initialize in the editor; test in-game.")
        editorWarningShown = true
    end
end

local function GetGenericUI()
    if Client and Client.UI and Client.UI.Generic then
        return Client.UI.Generic
    end
    return nil
end

local function IsGenericUIAvailable()
    local generic = GetGenericUI()
    if generic then
        return true, generic
    end

    return false, nil
end

local function DestroyStaleUI(generic)
    if generic and generic.INSTANCES then
        for typeId, instance in pairs(generic.INSTANCES) do
            if instance and instance.GetID and instance:GetID() == UI_ID then
                generic.INSTANCES[typeId] = nil
            end
        end
    end

    if Ext and Ext.UI and Ext.UI.GetByName and Ext.UI.Destroy then
        local existingUI = Ext.UI.GetByName(UI_ID)
        if existingUI then
            pcall(Ext.UI.Destroy, UI_ID)
        end
    end

    uiInstance = nil
end

local function QueueLayoutBuild(showAfter)
    UIState.PendingShowAfterBuild = UIState.PendingShowAfterBuild or showAfter
    if not Timer or not Timer.Start then
        Ext.Print("[ForgingUI] ERROR: Timer library unavailable; cannot retry UI build.")
        UIState.PendingShowAfterBuild = false
        return
    end

    Timer.Start(BUILD_TIMER_ID, 0.1, function()
        if not HasLayout() then
            ForgingUI.Initialize()
        end

        if uiInstance and HasLayout() then
            if UIState.PendingShowAfterBuild then
                PositionUI()
                uiInstance:Show()
                UIState.IsVisible = true
                EnsureEscListener()
                ApplyUIInputState(true)
                ScheduleUIInputRefresh()
                Ext.Print("[ForgingUI] UI shown")
                if USE_CUSTOM_PREVIEW_PANEL then
                    if Widgets.ClearPreviewSearch then
                        Widgets.ClearPreviewSearch()
                    else
                        RenderPreviewInventory()
                    end
                    StartPreviewInventoryRefresh()
                end
                if CraftState.DockRequested and displayMode == DISPLAY_MODES.Combine and Craft.DockUI then
                    Craft.DockUI(true)
                end
            end
        else
            Ext.Print("[ForgingUI] ERROR: UI root not ready; layout build failed.")
        end

        UIState.PendingShowAfterBuild = false
    end)
end

local function SetDisplayMode(mode)
    displayMode = mode
    if not UIState.IsVisible then
        return
    end
    if mode == DISPLAY_MODES.Combine then
        if CraftState.DockRequested and Craft.DockUI then
            Craft.DockUI(true)
        end
    else
        if Craft.HideUI then
            Craft.HideUI()
        end
    end
end
function ForgingUI.Initialize()
    if isEditorBuild then
        WarnEditorUnsupported()
        return false
    end

    local available, generic = IsGenericUIAvailable()
    if available then
        Ext.Print("[ForgingUI] Generic UI system available")
        return ForgingUI.InitializeWithGenericUI(generic)
    else
        Ext.Print("[ForgingUI] ERROR: Generic UI system is not available.")
        Ext.Print("[ForgingUI] Ensure the Forge UI framework is loaded before this mod.")
        return false
    end
end

function ForgingUI.InitializeWithGenericUI(generic)
    Ext.Print("[ForgingUI] Initializing with Generic UI...")

    genericUI = generic or genericUI or GetGenericUI()
    if not genericUI then
        Ext.Print("[ForgingUI] ERROR: Could not access Generic UI.")
        return false
    end

    local existing = genericUI.GetInstance and genericUI.GetInstance(UI_ID) or nil
    if existing and (not existing.GetUI or not existing:GetUI()) then
        existing = nil
        DestroyStaleUI(genericUI)
    end

    if not existing then
        if Ext and Ext.UI and Ext.UI.GetByName and Ext.UI.GetByName(UI_ID) then
            DestroyStaleUI(genericUI)
        end
        local baseLayer = genericUI.DEFAULT_LAYER or 15
        local uiLayer = math.max(1, baseLayer - 8)
        local ok, created = pcall(genericUI.Create, UI_ID, {Layer = uiLayer, Visible = false})
        if not ok or not created then
            Ext.Print(string.format("[ForgingUI] ERROR: Generic UI creation failed: %s", tostring(created)))
            return false
        end
        uiInstance = created
    else
        uiInstance = existing
    end

    RefreshContext()
    UpdateUISizeFromViewport()

    ForgingUI.Slots = {}
    ForgingUI.Buttons = {}
    hotbarSlotPrefab = genericUI.GetPrefab and genericUI.GetPrefab("GenericUI_Prefab_HotbarSlot") or nil
    slicedTexturePrefab = genericUI.GetPrefab and genericUI.GetPrefab("GenericUI.Prefabs.SlicedTexture") or nil
    buttonPrefab = genericUI.GetPrefab and genericUI.GetPrefab("GenericUI_Prefab_Button") or nil
    buttonStyle = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.MenuSlate or buttonPrefab.STYLES.BrownLong) or nil
    styleLargeRed = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.LargeRed or buttonPrefab.STYLES.MediumRed or buttonStyle) or buttonStyle
    styleLargeRedWithArrows = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.LargeRedWithArrows or styleLargeRed) or styleLargeRed
    styleTabCharacterSheetWide = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.TabCharacterSheetWide or buttonStyle) or buttonStyle
    styleGreenMediumTextured = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.GreenMediumTextured or buttonStyle) or buttonStyle
    styleSquareStone = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.SquareStone or buttonStyle) or buttonStyle
    styleComboBox = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.ComboBox or buttonStyle) or buttonStyle
    styleDOS1Blue = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.DOS1Blue or buttonStyle) or buttonStyle
    primaryButtonStyle = styleLargeRed
    closeButtonPrefab = genericUI.GetPrefab and genericUI.GetPrefab("GenericUI_Prefab_CloseButton") or nil
    styleClose = buttonPrefab and buttonPrefab.STYLES and (buttonPrefab.STYLES.Close or buttonPrefab.STYLES.CloseStone or buttonPrefab.STYLES.CloseSlate) or nil
    styleCloseDOS1Square = buttonPrefab and buttonPrefab.STYLES and buttonPrefab.STYLES.CloseDOS1Square or nil
    InitTextureStyles()
    RefreshContext()
    EnsureToggleButton()
    EnsureViewportListener()
    Craft.EnsureHooks()
    if not hotbarSlotPrefab then
        Ext.Print("[ForgingUI] WARNING: Generic UI HotbarSlot prefab not available; using placeholder slots")
    end
    local uiObject = uiInstance:GetUI()
    if not uiObject or not uiObject:GetRoot() then
        Ext.Print("[ForgingUI] WARNING: UI root not ready; delaying layout build.")
        QueueLayoutBuild(false)
        return true
    end

    if HasLayout() then
        PositionUI()
        uiInstance:Hide()
        return true
    end
    local okBuild, buildResult = pcall(Layout.BuildUI)
    if not okBuild then
        Ext.Print(string.format("[ForgingUI] ERROR: UI build failed: %s", tostring(buildResult)))
        QueueLayoutBuild(false)
        return true
    end
    if not buildResult then
        QueueLayoutBuild(false)
        return true
    end
    if PreviewLogic and PreviewLogic.Bind then
        PreviewLogic.Bind(ForgingUI.Slots, Widgets.GetPreviewInventory and Widgets.GetPreviewInventory() or nil)
    end

    Ext.Print("[ForgingUI] Generic UI created successfully")

    PositionUI()
    uiInstance:Hide()
    return true
end

function ForgingUI.CreateItemSlot(id, parent, x, y, width, height, title)
    return Widgets.CreateItemSlot(id, parent, x, y, width, height, title)
end
function ForgingUI.Show()
    if isEditorBuild then
        WarnEditorUnsupported()
        return false
    end

    Craft.EnsureHooks()
    CraftState.DockRequested = USE_VANILLA_COMBINE_PANEL
    displayMode = DISPLAY_MODES.Combine
    Craft.SetPreviewMode(CRAFT_PREVIEW_MODES.Equipment)

    if not uiInstance or not HasLayout() then
        Ext.Print("[ForgingUI] Show: UI not ready; initializing...")
        local ok, err = pcall(ForgingUI.Initialize)
        if not ok then
            Ext.Print(string.format("[ForgingUI] ERROR: Initialize failed during show: %s", tostring(err)))
        end
    end

    if not uiInstance or not HasLayout() then
        DebugShowState("Show: layout missing after init")
        QueueLayoutBuild(true)
        Ext.Print("[ForgingUI] UI layout not ready; will show after build.")
        return false
    end

    if uiInstance then
        PositionUI()
        uiInstance:Show()
        UIState.IsVisible = true
        EnsureEscListener()
        ApplyUIInputState(true)
        ScheduleUIInputRefresh()
        Ext.Print("[ForgingUI] UI shown")
        if USE_CUSTOM_PREVIEW_PANEL then
            if Widgets.ClearPreviewSearch then
                Widgets.ClearPreviewSearch()
            else
                RenderPreviewInventory()
            end
            StartPreviewInventoryRefresh()
        end
        if CraftState.DockRequested and displayMode == DISPLAY_MODES.Combine and Craft.DockUI then
            Craft.DockUI(true)
        end
        return true
    else
        Ext.Print("[ForgingUI] ERROR: UI not initialized. Check console for initialization errors.")
        return false
    end
end

function ForgingUI.Hide()
    if isEditorBuild then
        WarnEditorUnsupported()
        return false
    end

    if uiInstance then
        uiInstance:Hide()
        UIState.IsVisible = false
        ApplyUIInputState(false)
        if Widgets.ClearPreviewSearch then
            Widgets.ClearPreviewSearch({skipSort = true})
        end
          CraftState.DockRequested = false
          Craft.SetPreviewMode(nil)
          Craft.HideUI()
          StopPreviewInventoryRefresh()
          Ext.Print("[ForgingUI] UI hidden")
          return true
    else
        Ext.Print("[ForgingUI] ERROR: UI not initialized.")
        return false
    end
end

function ForgingUI.Toggle()
    if UIState.IsVisible then
        ForgingUI.Hide()
    else
        ForgingUI.Show()
    end
end

function ForgingUI.Rebuild()
    local generic = GetGenericUI()
    local existing = generic and generic.GetInstance and generic.GetInstance(UI_ID) or nil
    if existing and existing.GetUI and existing:GetUI() then
        uiInstance = existing
        local root = uiInstance:GetElementByID(ROOT_ID)
        if root then
            uiInstance:DestroyElement(root)
        end
    else
        DestroyStaleUI(generic)
    end

    ForgingUI.Slots = {}
    ForgingUI.Buttons = {}
    return ForgingUI.Initialize()
end

function ForgingUI.OnForgeButtonClicked()
    Ext.Print("[ForgingUI] Forge button clicked - implement forging logic here")
end

-- Debug helpers used by forgeuistatus.
ForgingUI.Debug = {
    PrintUIState = PrintUIState,
    PrintElementInfo = PrintElementInfo,
    DumpElementTree = DumpElementTree,
    DumpFillElements = DumpFillElements,
    GetBackgroundPanelName = function()
        return backgroundTextureName
    end,
}

Ext.Events.SessionLoaded:Subscribe(function()
    if isEditorBuild then
        WarnEditorUnsupported()
        return
    end

    if Ext.IsServer and Ext.IsServer() then
        return
    end

    Ext.Print("[ForgingUI] Session loaded - initializing UI...")
    if not IsGenericUIAvailable() then
        Ext.Print("[ForgingUI] Generic UI not available; skipping initialization.")
        return
    end

    ForgingUI.Initialize()
    if IsGameStateRunning() then
        ScheduleToggleReady()
    end
end)

Ext.Events.GameStateChanged:Subscribe(function()
    if Ext.IsServer and Ext.IsServer() then
        return
    end

    local state = GetClientGameState()
    if state == UIState.LastGameState then
        return
    end
    UIState.LastGameState = state

    if IsGameStateRunning() then
        if not UIState.ToggleReady then
            ScheduleToggleReady()
        else
            EnsureToggleButton()
        end
    else
        if UIState.ToggleUIInstance and UIState.ToggleUIInstance.Hide then
            UIState.ToggleUIInstance:Hide()
        end
    end
end)

return ForgingUI
