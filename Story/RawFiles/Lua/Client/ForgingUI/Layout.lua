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

function Layout.PrintUIState(tag)
    if not ctx or not ctx.uiInstance then
        if ctx and ctx.Ext then
            ctx.Ext.Print(string.format("[ForgingUI] %s: uiInstance missing", tag))
        end
        return
    end

    local uiObject = ctx.uiInstance:GetUI()
    if not uiObject then
        ctx.Ext.Print(string.format("[ForgingUI] %s: UIObject missing", tag))
        return
    end

    local x, y = ctx.uiInstance:GetPosition()
    local size = nil
    local sizeText = "nil"
    local okSize, sizeValue = pcall(function()
        return uiObject.SysPanelSize
    end)
    if okSize and sizeValue then
        size = sizeValue
        sizeText = string.format("%d,%d", size[1], size[2])
    end

    local scaleValue = 1
    local okScale, scale = pcall(function()
        return uiObject.SysPanelScale
    end)
    if okScale and scale ~= nil then
        if type(scale) == "table" then
            scaleValue = scale[1] or scaleValue
        elseif type(scale) == "number" then
            scaleValue = scale
        end
    end

    ctx.Ext.Print(string.format(
        "[ForgingUI] %s: visible=%s pos=%d,%d size=%s layer=%s scale=%.3f",
        tag,
        tostring(ctx.uiInstance:IsVisible()),
        x or -1,
        y or -1,
        sizeText,
        tostring(uiObject.Layer or "n/a"),
        scaleValue
    ))
end

function Layout.PrintElementInfo(id)
    if not ctx or not ctx.uiInstance or not id then
        return
    end
    local function UnpackSize(value)
        if type(value) == "table" then
            if value.unpack then
                return value:unpack()
            end
            return value[1] or value.x or value.X, value[2] or value.y or value.Y
        end
        return nil, nil
    end

    local element = ctx.uiInstance:GetElementByID(id)
    if not element then
        ctx.Ext.Print(string.format("[ForgingUI] Debug: element '%s' missing", id))
        return
    end
    local x, y = element:GetPosition()
    local w, h = nil, nil
    if element.GetSize then
        local ok, sizeValue = pcall(element.GetSize, element, true)
        if ok and sizeValue then
            w, h = UnpackSize(sizeValue)
        end
    end
    local rawW, rawH = nil, nil
    if element.GetRawSize then
        local ok, rawValue = pcall(element.GetRawSize, element)
        if ok and rawValue then
            rawW, rawH = UnpackSize(rawValue)
        end
    end
    local overrideW, overrideH = nil, nil
    if element.GetSizeOverride then
        local ok, overrideValue = pcall(element.GetSizeOverride, element)
        if ok and overrideValue then
            overrideW, overrideH = UnpackSize(overrideValue)
        end
    end
    local scaleText = "n/a"
    if element.GetScale then
        local ok, scale = pcall(element.GetScale, element)
        if ok and scale then
            scaleText = string.format("%.2f,%.2f", scale[1], scale[2])
        end
    end
    if (w == nil or h == nil) and element.GetMovieClip then
        local ok, mc = pcall(element.GetMovieClip, element)
        if ok and mc then
            if w == nil then
                w = mc.width
            end
            if h == nil then
                h = mc.height
            end
            if scaleText == "n/a" then
                local sx = mc.scaleX
                local sy = mc.scaleY
                if sx and sy then
                    scaleText = string.format("%.2f,%.2f", sx, sy)
                end
            end
        end
    end

    ctx.Ext.Print(string.format(
        "[ForgingUI] Debug: %s pos=%s,%s size=%s,%s raw=%s,%s override=%s,%s scale=%s visible=%s parent=%s",
        tostring(id),
        tostring(x or "n/a"),
        tostring(y or "n/a"),
        tostring(w or "n/a"),
        tostring(h or "n/a"),
        tostring(rawW or "n/a"),
        tostring(rawH or "n/a"),
        tostring(overrideW or "n/a"),
        tostring(overrideH or "n/a"),
        tostring(scaleText),
        tostring(element.IsVisible and element:IsVisible() or true),
        tostring(element.ParentID)
    ))
end

function Layout.DumpElementTree(id, maxDepth)
    if not ctx or not ctx.uiInstance or not id then
        return
    end
    local depthLimit = maxDepth or 2

    local function DumpElement(elem, depth)
        local mcAlpha = "n/a"
        local mcVisible = "n/a"
        local mcWidth = "n/a"
        local mcHeight = "n/a"
        if elem.GetMovieClip then
            local ok, mc = pcall(elem.GetMovieClip, elem)
            if ok and mc then
                if mc.alpha ~= nil then
                    mcAlpha = mc.alpha
                end
                if mc.visible ~= nil then
                    mcVisible = mc.visible
                end
                if mc.width ~= nil then
                    mcWidth = mc.width
                end
                if mc.height ~= nil then
                    mcHeight = mc.height
                end
            end
        end
        ctx.Ext.Print(string.format(
            "[ForgingUI] AlphaDump: %s type=%s depth=%d alpha=%s visible=%s size=%s,%s",
            tostring(elem.ID),
            tostring(elem.Type or "n/a"),
            depth,
            tostring(mcAlpha),
            tostring(mcVisible),
            tostring(mcWidth),
            tostring(mcHeight)
        ))
        if depth >= depthLimit then
            return
        end
        if elem.GetChildren then
            for _, child in ipairs(elem:GetChildren() or {}) do
                DumpElement(child, depth + 1)
            end
        end
    end

    local element = ctx.uiInstance:GetElementByID(id)
    if not element then
        local matches = {}
        local search = tostring(id)
        for elemId,_ in pairs(ctx.uiInstance.Elements or {}) do
            if tostring(elemId):find(search, 1, true) then
                table.insert(matches, elemId)
            end
        end
        table.sort(matches)
        if #matches == 0 then
            ctx.Ext.Print(string.format("[ForgingUI] AlphaDump: element '%s' missing", search))
            return
        end
        ctx.Ext.Print(string.format("[ForgingUI] AlphaDump: element '%s' missing; %d match(es) found", search, #matches))
        for _, matchId in ipairs(matches) do
            local matchElem = ctx.uiInstance:GetElementByID(matchId)
            if matchElem then
                DumpElement(matchElem, 0)
            end
        end
        return
    end

    DumpElement(element, 0)
end

function Layout.DumpFillElements(alphaThreshold)
    if not ctx or not ctx.uiInstance then
        return
    end
    local threshold = tonumber(alphaThreshold) or 0.05
    local elements = ctx.uiInstance.Elements or {}
    for id, element in pairs(elements) do
        if element and (element.Type == "GenericUI_Element_Color"
            or element.Type == "GenericUI_Element_Texture"
            or element.Type == "GenericUI_Element_TiledBackground") then
            local mcAlpha = nil
            local mcVisible = nil
            local mcWidth = nil
            local mcHeight = nil
            if element.GetMovieClip then
                local ok, mc = pcall(element.GetMovieClip, element)
                if ok and mc then
                    mcAlpha = mc.alpha
                    mcVisible = mc.visible
                    mcWidth = mc.width
                    mcHeight = mc.height
                end
            end
            if mcAlpha and (mcVisible == nil or mcVisible == true) and mcAlpha > threshold then
                ctx.Ext.Print(string.format(
                    "[ForgingUI] FillDump: %s type=%s alpha=%.2f visible=%s size=%.1f,%.1f",
                    tostring(id),
                    tostring(element.Type),
                    mcAlpha,
                    tostring(mcVisible),
                    tonumber(mcWidth or 0) or 0,
                    tonumber(mcHeight or 0) or 0
                ))
            end
        end
    end
end

function Layout.GetViewportScale()
    local size = nil
    if ctx and ctx.Client and ctx.Client.GetViewportSize then
        size = ctx.Client.GetViewportSize()
    elseif ctx and ctx.Ext and ctx.Ext.UI and ctx.Ext.UI.GetViewportSize then
        size = ctx.Ext.UI.GetViewportSize()
    end
    local scale = 1
    if size and size[2] and size[2] > 0 then
        scale = size[2] / 1080
    end
    if scale < 0.7 then
        scale = 0.7
    elseif scale > 1.5 then
        scale = 1.5
    end
    return scale
end

function Layout.GetViewportSize()
    local size = nil
    if ctx and ctx.Client and ctx.Client.GetViewportSize then
        size = ctx.Client.GetViewportSize()
    elseif ctx and ctx.Ext and ctx.Ext.UI and ctx.Ext.UI.GetViewportSize then
        size = ctx.Ext.UI.GetViewportSize()
    end
    if size and size[1] and size[2] then
        return size[1], size[2]
    end
    return nil, nil
end

function Layout.GetUIScaleMultiplier()
    if ctx and ctx.uiInstance and ctx.uiInstance.GetUI then
        local uiObject = ctx.uiInstance:GetUI()
        if uiObject and uiObject.GetUIScaleMultiplier then
            local ok, scale = pcall(uiObject.GetUIScaleMultiplier, uiObject)
            if ok and scale and scale > 0 then
                return scale
            end
        end
    end
    return 1
end

function Layout.UpdateUISizeFromViewport()
    local state = GetLayoutState()
    if not state then
        return
    end

    local viewportW, viewportH = Layout.GetViewportSize()
    local uiScale = Layout.GetUIScaleMultiplier()
    if not uiScale or uiScale <= 0 then
        uiScale = 1
    end
    if viewportW and viewportH and viewportW > 0 and viewportH > 0 then
        state.Width = math.floor((viewportW * (ctx.UI_TARGET_WIDTH_RATIO or 1)) / uiScale)
        state.Height = math.floor((viewportH * (ctx.UI_TARGET_HEIGHT_RATIO or 1)) / uiScale)
        state.ScaleX = state.Width / (ctx.BASE_UI_WIDTH or state.Width)
        state.ScaleY = state.Height / (ctx.BASE_UI_HEIGHT or state.Height)
    else
        state.Width = ctx.BASE_UI_WIDTH or state.Width
        state.Height = ctx.BASE_UI_HEIGHT or state.Height
        state.ScaleX = 1
        state.ScaleY = 1
    end
end

function Layout.ScaleX(value)
    local state = GetLayoutState()
    if not state then
        return value
    end
    return math.floor(value * state.ScaleX + 0.5)
end

function Layout.ScaleY(value)
    local state = GetLayoutState()
    if not state then
        return value
    end
    return math.floor(value * state.ScaleY + 0.5)
end

function Layout.Scale(value)
    local state = GetLayoutState()
    if not state then
        return value
    end
    return math.floor(value * math.min(state.ScaleX, state.ScaleY) + 0.5)
end

function Layout.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
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
        uiState.ToggleUIInstance = ctx.genericUI.Create(ctx.TOGGLE_UI_ID, {Layer = 100, Visible = false})
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
    local dragArea = topBar:AddChild("ForgeUIDragArea", "GenericUI_Element_Color")
    dragArea:SetSize(topBarWidth, topBarHeight)
    dragArea:SetColor(ctx.HEADER_FILL_COLOR)
    dragArea:SetAlpha(0)
    dragArea:SetAsDraggableArea()

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
    local contentInsetX = Layout.Scale(ctx.UI_CONTENT_INSET_X or 0)
    local rightXPos = canvasWidth - margin - rightWidth - contentInsetX
    local leftX = margin
    local midX = leftX + leftWidth + gapX + contentInsetX
    -- Don't subtract gapX from midWidth - already accounted for in midX
    local midWidth = rightXPos - midX
    local midTopHeight = contentHeight - bottomHeight - gap
    -- Height multiplier for Main/Donor slot panels (1.0 = same as Preview, >1.0 = taller, <1.0 = shorter)
    local slotPanelHeightMultiplier = 1.05
    local slotPanelHeight = math.floor(midTopHeight * slotPanelHeightMultiplier)
    -- Vertical offset to move Main/Donor panels up (negative values move up, positive move down)
    local slotPanelOffsetY = -11
    -- Vertical offset for Info panel and Preview panel (positive moves down)
    local infoPanelOffsetY = 4
    local midBottomY = contentTop + midTopHeight + gap
    local columnGap = Layout.Scale(ctx.UI_COLUMN_GAP or 0)
    local columnTotal = midWidth - columnGap * 2
    -- Main and Donor slots share the same width ratio (they use the same template)
    local slotPanelWidthRatio = 0.30
    local slotPanelWidth = math.floor(columnTotal * slotPanelWidthRatio)
    local mainWidth = slotPanelWidth
    local donorWidth = slotPanelWidth
    local previewWidth = columnTotal - mainWidth - donorWidth
    local mainX = midX
    local previewX = mainX + mainWidth + columnGap
    local donorX = previewX + previewWidth + columnGap

    local craftState = ctx.Craft and ctx.Craft.State or nil
    if craftState then
        craftState.Anchor = nil
        craftState.PreviewAnchorID = nil
        craftState.PreviewArea = nil
    end

    local infoHeight = contentHeight - Layout.ScaleY(infoPanelOffsetY)
    local infoPanelY = contentTop + Layout.ScaleY(infoPanelOffsetY)
    local leftInfoFrame, leftInfo, leftInfoWidth, leftInfoHeight = CreateSkinnedPanel(canvas, "LeftInfo", leftX, infoPanelY, leftWidth, infoHeight, ctx.introPanelTexture, Layout.Scale(10))
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
        {ID = "Preview", Title = "", Mode = "Preview", X = previewX, Width = previewWidth, Texture = ctx.previewPanelTexture, Padding = Layout.Scale(8)},
        {ID = "Donor", Title = "Donor Slot", Mode = "Donor", X = donorX, Width = donorWidth, Texture = ctx.slotPanelTexture, Padding = Layout.Scale(6)},
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

    return true
end

return Layout
