-- Client/ForgingUI/UI/Layout/TopBar.lua
-- Top bar and header buttons for the forging UI.

local TopBar = {}

---@param options table
function TopBar.Create(options)
    local opts = options or {}
    local ctx = opts.ctx
    local canvas = opts.canvas
    if not ctx or not canvas then
        return nil
    end

    local margin = opts.margin or 0
    local topBarX = opts.topBarX
    local topBarY = opts.topBarY
    local topBarHeight = opts.topBarHeight or 0
    local topBarWidth = opts.topBarWidth or 0
    local registerSearchBlur = opts.registerSearchBlur
    local createFrame = opts.createFrame
    local createButtonBox = opts.createButtonBox
    local wireButton = opts.wireButton
    local scaleX = opts.scaleX or function(value) return value end
    local scaleY = opts.scaleY or function(value) return value end
    local vector = opts.vector or (ctx and ctx.V) or function(...) return Vector.Create(...) end
    local layoutTuning = ctx.LayoutTuning or nil
    local useTransparentButtons = layoutTuning and layoutTuning.TopBarTransparentButtons
    local transparentStyle = useTransparentButtons and ctx.styleTransparentLong or nil
    local topBarDebug = layoutTuning and layoutTuning.TopBarDebug
    local function DebugPrint(message)
        if topBarDebug and ctx and ctx.Ext and ctx.Ext.Print then
            ctx.Ext.Print(message)
        end
    end
    local clamp = opts.clamp or function(value, minValue, maxValue)
        if value < minValue then
            return minValue
        end
        if value > maxValue then
            return maxValue
        end
        return value
    end

    local topBar = canvas:AddChild("TopBar", "GenericUI_Element_Empty")
    topBar:SetPosition(topBarX or margin, topBarY or margin)
    if registerSearchBlur then
        registerSearchBlur(topBar)
    end

    local topBarAlpha = 0
    if layoutTuning and layoutTuning.TopBarBackgroundAlpha ~= nil then
        topBarAlpha = clamp(layoutTuning.TopBarBackgroundAlpha, 0, 1)
    end
    local topBarFrameAlpha = layoutTuning and layoutTuning.TopBarFrameAlpha
    if topBarFrameAlpha == nil then
        topBarFrameAlpha = ctx and (ctx.FRAME_TEXTURE_ALPHA or ctx.FRAME_ALPHA) or 1
    end
    local topBarFrameCenterAlpha = layoutTuning and layoutTuning.TopBarFrameCenterAlpha
    if topBarFrameCenterAlpha == nil then
        topBarFrameCenterAlpha = ctx and ctx.FRAME_TEXTURE_CENTER_ALPHA
        if topBarFrameCenterAlpha == nil then
            topBarFrameCenterAlpha = topBarFrameAlpha
        end
    end

    local topBarBackground = topBar:AddChild("TopBar_Background", "GenericUI_Element_Color")
    topBarBackground:SetSize(topBarWidth, topBarHeight)
    topBarBackground:SetColor(ctx.topBarBackgroundColor or ctx.HEADER_FILL_COLOR)
    topBarBackground:SetAlpha(topBarAlpha)
    if topBarBackground.SetMouseEnabled then
        topBarBackground:SetMouseEnabled(false)
    end
    if topBarBackground.SetMouseChildren then
        topBarBackground:SetMouseChildren(false)
    end

    local function ApplyFrameAlphas(frameTex, frameAlpha, centerAlpha)
        if not frameTex then
            return
        end
        if frameTex.SetAlpha then
            frameTex:SetAlpha(frameAlpha)
        end
        if frameTex.Root and frameTex.Root.SetAlpha then
            frameTex.Root:SetAlpha(frameAlpha)
        end
        local children = nil
        if frameTex.Root and frameTex.Root.GetChildren then
            children = frameTex.Root:GetChildren()
        elseif frameTex.GetChildren then
            children = frameTex:GetChildren()
        end
        for _, child in ipairs(children or {}) do
            local id = child and child.ID or ""
            local isCenter = id == "Center" or (id ~= "" and id:find("Center", 1, true) ~= nil)
            local alpha = isCenter and centerAlpha or frameAlpha
            if child.SetAlpha then
                child:SetAlpha(alpha)
            end
            if isCenter and child.SetVisible then
                child:SetVisible(alpha > 0)
            end
        end
    end

    local topBarFrameStyle = nil
    if ctx and ctx.slicedTexturePrefab and ctx.slicedTexturePrefab.STYLES then
        local styleName = layoutTuning and layoutTuning.TopBarFrameStyle
        if styleName and ctx.slicedTexturePrefab.STYLES[styleName] then
            topBarFrameStyle = ctx.slicedTexturePrefab.STYLES[styleName]
        else
            topBarFrameStyle = ctx.slicedTexturePrefab.STYLES.SimpleTooltip
                or ctx.slicedTexturePrefab.STYLES.ContextMenu
        end
    end
    DebugPrint(string.format(
        "[ForgingUI] TopBar: size=%sx%s useSliced=%s hasPrefab=%s style=%s frameAlpha=%.2f centerAlpha=%.2f bgAlpha=%.2f",
        tostring(topBarWidth),
        tostring(topBarHeight),
        tostring(ctx and ctx.USE_SLICED_FRAMES),
        tostring(ctx and ctx.slicedTexturePrefab ~= nil),
        tostring(layoutTuning and layoutTuning.TopBarFrameStyle),
        tonumber(topBarFrameAlpha) or 0,
        tonumber(topBarFrameCenterAlpha) or 0,
        tonumber(topBarAlpha) or 0
    ))
    local topBarFrameTex = nil
    if createFrame and topBarFrameStyle then
        local frame, inner, _, _, frameTex = createFrame(
            topBar,
            "TopBar_ContextMenu",
            0,
            0,
            topBarWidth,
            topBarHeight,
            ctx.FILL_COLOR,
            topBarFrameAlpha,
            0,
            true,
            topBarFrameCenterAlpha,
            nil,
            topBarFrameStyle,
            vector(0, 0),
            vector(topBarWidth, topBarHeight)
        )
        topBarFrameTex = frameTex
        if frame and frame.SetMouseEnabled then
            frame:SetMouseEnabled(false)
        end
        if frame and frame.SetMouseChildren then
            frame:SetMouseChildren(false)
        end
        if inner and inner.SetMouseEnabled then
            inner:SetMouseEnabled(false)
        end
        if inner and inner.SetMouseChildren then
            inner:SetMouseChildren(false)
        end
        ApplyFrameAlphas(topBarFrameTex, topBarFrameAlpha, topBarFrameCenterAlpha)
        DebugPrint(string.format("[ForgingUI] TopBar: frame via CreateFrame=%s", tostring(topBarFrameTex ~= nil)))
    end
    if not topBarFrameTex and topBarFrameStyle and ctx and ctx.slicedTexturePrefab and ctx.uiInstance then
        local frameTex = ctx.slicedTexturePrefab.Create(ctx.uiInstance, "TopBar_ContextMenu_Frame", topBar, topBarFrameStyle, vector(topBarWidth, topBarHeight))
        if frameTex and frameTex.Root then
            if frameTex.Root.SetPosition then
                frameTex.Root:SetPosition(0, 0)
            end
            if frameTex.Root.SetScale then
                frameTex.Root:SetScale(vector(1, 1))
            end
            if frameTex.Root.SetMouseEnabled then
                frameTex.Root:SetMouseEnabled(false)
            end
            if frameTex.Root.SetMouseChildren then
                frameTex.Root:SetMouseChildren(false)
            end
        end
        local frameAlpha = topBarFrameAlpha
        local centerAlpha = topBarFrameCenterAlpha
        if frameTex and frameTex.SetAlpha then
            frameTex:SetAlpha(frameAlpha)
        end
        if frameTex and frameTex.Root and frameTex.Root.SetAlpha then
            frameTex.Root:SetAlpha(frameAlpha)
        end
        if frameTex and frameTex.GetChildren then
            for _, child in ipairs(frameTex:GetChildren() or {}) do
                if child then
                    local childAlpha = frameAlpha
                    local isCenter = child.ID and child.ID:match("Center$") ~= nil
                    if isCenter then
                        childAlpha = centerAlpha
                    end
                    if child.SetAlpha then
                        child:SetAlpha(childAlpha)
                    end
                    if isCenter and child.SetVisible then
                        child:SetVisible(childAlpha > 0)
                    end
                end
            end
        end
        topBarFrameTex = frameTex
        ApplyFrameAlphas(topBarFrameTex, topBarFrameAlpha, topBarFrameCenterAlpha)
        DebugPrint(string.format("[ForgingUI] TopBar: frame via direct prefab=%s", tostring(topBarFrameTex ~= nil)))
    end
    if topBar.SetChildIndex and topBarBackground then
        topBar:SetChildIndex(topBarBackground, 0)
    end
    if topBarFrameTex and topBarFrameTex.Root and topBarFrameTex.Root.GetChildren then
        local childIds = {}
        for _, child in ipairs(topBarFrameTex.Root:GetChildren() or {}) do
            table.insert(childIds, tostring(child and child.ID))
        end
        DebugPrint(string.format("[ForgingUI] TopBar: frame children=%s", table.concat(childIds, ", ")))
    end

    local dragArea = nil
    local dragAreaType = "GenericUI_Prefab_DraggingArea"
    local dragAreaAlpha = 0
    local draggingAreaPrefab = ctx and ctx.genericUI and ctx.genericUI.GetPrefab
        and ctx.genericUI.GetPrefab("GenericUI_Prefab_DraggingArea") or nil
    if draggingAreaPrefab and ctx.uiInstance then
        local dragInstance = draggingAreaPrefab.Create(
            ctx.uiInstance,
            "ForgeUIDragArea",
            topBar,
            vector(topBarWidth, topBarHeight),
            dragAreaAlpha
        )
        dragArea = dragInstance and dragInstance.Background or nil
    else
        dragAreaType = "GenericUI_Element_TiledBackground"
        dragArea = topBar:AddChild("ForgeUIDragArea", dragAreaType)
        if dragArea.SetBackground then
            dragArea:SetBackground("Black", topBarWidth, topBarHeight)
        else
            dragArea:SetSize(topBarWidth, topBarHeight)
        end
        if dragArea.SetAsDraggableArea then
            dragArea:SetAsDraggableArea()
        end
    end
    if dragArea then
        if dragArea.SetMouseEnabled then
            dragArea:SetMouseEnabled(true)
        end
        if dragArea.SetMouseChildren then
            dragArea:SetMouseChildren(true)
        end
        if dragArea.SetAlpha then
            dragArea:SetAlpha(dragAreaAlpha)
        end
        if registerSearchBlur then
            registerSearchBlur(dragArea)
        end
    end
    DebugPrint(string.format(
        "[ForgingUI] TopBar: dragAreaAlpha=%.2f framePresent=%s type=%s",
        dragArea and dragArea.GetAlpha and dragArea:GetAlpha() or dragAreaAlpha,
        tostring(topBarFrameTex ~= nil),
        tostring(dragAreaType)
    ))

    local topButtonHeight = clamp(scaleY(32), 40, 50)
    local topButtonY = math.floor((topBarHeight - topButtonHeight) / 2)
    local topBarPaddingX = scaleX(8)
    local leftButtonStyle = transparentStyle or ctx.styleDOS1Blue or ctx.styleLargeRed
    local forgeTabBtn = createButtonBox(topBar, "Btn_ForgeTab", "Forge", topBarPaddingX, topButtonY, 100, topButtonHeight, false, leftButtonStyle)
    if wireButton then
        wireButton(forgeTabBtn, "ForgeTab")
    end
    local uniqueTabBtn = createButtonBox(topBar, "Btn_UniqueTab", "Unique Forge", topBarPaddingX + 100, topButtonY, 175, topButtonHeight, false, leftButtonStyle)
    if wireButton then
        wireButton(uniqueTabBtn, "UniqueForgeTab")
    end

    local rightX = topBarWidth - topBarPaddingX
    local closeSize = topBarHeight
    local closeBtn = createButtonBox(topBar, "Btn_Close", "", topBarWidth - closeSize, 0, closeSize, closeSize, false, ctx.styleCloseDOS1Square or ctx.styleClose)
    if closeBtn and closeBtn.Events and closeBtn.Events.Pressed then
        closeBtn.Events.Pressed:Subscribe(function()
            if ctx.ForgingUI and ctx.ForgingUI.Hide then
                ctx.ForgingUI.Hide()
            end
        end)
    end
    rightX = rightX - closeSize - 6

    -- Top-right buttons removed.

    return topBar
end

return TopBar
