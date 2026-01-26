-- Client/ForgingUI/UI/Layout/Base.lua
-- Base root + canvas construction for the forging UI.

local Base = {}

---@param options table
function Base.Build(options)
    local opts = options or {}
    local ctx = opts.ctx
    local layout = opts.layout
    local borderSize = opts.borderSize or 0
    local createFrame = opts.createFrame
    local scale = opts.scale or function(value) return value end
    local vector = opts.vector or function(...) return Vector.Create(...) end
    if not ctx or not ctx.uiInstance or not layout then
        return nil
    end
    local baseFrameX = opts.baseFrameX or 0
    local baseFrameY = opts.baseFrameY or 0
    local baseFrameWidth = opts.baseFrameWidth or layout.Width
    local baseFrameHeight = opts.baseFrameHeight or layout.Height
    local basePanelTexture = opts.basePanelTexture or (ctx and ctx.basePanelTexture)
    local useBasePanelTexture = basePanelTexture ~= nil and (type(basePanelTexture) ~= "table" or basePanelTexture.GUID)
    local layoutTuning = ctx and ctx.LayoutTuning or nil
    local hideBasePanel = layoutTuning and layoutTuning.HideBasePanel

    local existingRoot = ctx.uiInstance:GetElementByID(ctx.ROOT_ID)
    if existingRoot then
        ctx.uiInstance:DestroyElement(existingRoot)
    end

    local root = nil
    if ctx.USE_BASE_BACKGROUND and (ctx.USE_TEXTURE_BACKGROUND and ctx.backgroundTexture) then
        root = ctx.uiInstance:CreateElement(ctx.ROOT_ID, "GenericUI_Element_Texture")
        root:SetTexture(ctx.backgroundTexture, vector(layout.Width, layout.Height))
        root:SetSize(layout.Width, layout.Height)
    elseif ctx.USE_BASE_BACKGROUND then
        root = ctx.uiInstance:CreateElement(ctx.ROOT_ID, "GenericUI_Element_TiledBackground")
        root:SetBackground("Note", layout.Width, layout.Height)
    else
        root = ctx.uiInstance:CreateElement(ctx.ROOT_ID, "GenericUI_Element_Empty")
        root:SetSize(layout.Width, layout.Height)
    end

    if useBasePanelTexture and not hideBasePanel then
        local panelWidth = baseFrameWidth
        local panelHeight = baseFrameHeight
        local panelX = baseFrameX
        local panelY = baseFrameY
        local aspectRatio = layoutTuning and layoutTuning.BasePanelAspectRatio
        if aspectRatio and aspectRatio > 0 then
            local currentRatio = 0
            if baseFrameHeight > 0 then
                currentRatio = baseFrameWidth / baseFrameHeight
            end
            if currentRatio > aspectRatio then
                panelWidth = math.floor(baseFrameHeight * aspectRatio + 0.5)
                panelHeight = baseFrameHeight
            else
                panelWidth = baseFrameWidth
                panelHeight = math.floor(baseFrameWidth / aspectRatio + 0.5)
            end
            panelX = baseFrameX + math.floor((baseFrameWidth - panelWidth) / 2 + 0.5)
            panelY = baseFrameY + math.floor((baseFrameHeight - panelHeight) / 2 + 0.5)
        end
        local basePanel = root:AddChild("BasePanel", "GenericUI_Element_Texture")
        basePanel:SetTexture(basePanelTexture, vector(panelWidth, panelHeight))
        basePanel:SetSize(panelWidth, panelHeight)
        basePanel:SetPosition(panelX, panelY)
        if basePanel.SetAlpha and ctx and ctx.BASE_PANEL_ALPHA ~= nil then
            basePanel:SetAlpha(ctx.BASE_PANEL_ALPHA)
        end
        if basePanel.SetScale then
            basePanel:SetScale(vector(1, 1))
        end
        if root.SetChildIndex then
            root:SetChildIndex(basePanel, 0)
        end
    end

    if ctx.USE_SLICED_BASE and createFrame and not useBasePanelTexture and not hideBasePanel then
        createFrame(root, "BaseFrame", baseFrameX, baseFrameY, baseFrameWidth, baseFrameHeight, ctx.FILL_COLOR, ctx.BASE_PANEL_ALPHA, scale(10), true)
    end
    if root.SetScale then
        root:SetScale(vector(1, 1))
    end
    if root.SetSizeOverride then
        root:SetSizeOverride(layout.Width, layout.Height)
    end
    root:SetPosition(0, 0)

    local canvasWidth = layout.Width - borderSize * 2
    local canvasHeight = layout.Height - borderSize * 2

    local canvas = root:AddChild("ForgingUI_Content", "GenericUI_Element_Empty")
    canvas:SetPosition(borderSize, borderSize)
    -- Only create opaque canvas background if not using sliced base (which has its own transparency)
    if not (ctx.USE_TEXTURE_BACKGROUND and ctx.backgroundTexture)
        and not ctx.USE_SLICED_BASE
        and not useBasePanelTexture
        and not hideBasePanel then
        local canvasBG = canvas:AddChild("ForgingUI_ContentBG", "GenericUI_Element_Color")
        canvasBG:SetSize(canvasWidth, canvasHeight)
        canvasBG:SetColor(ctx.FILL_COLOR)
        canvasBG:SetAlpha(1)
        canvasBG:SetPosition(0, 0)
    end

    return {
        Root = root,
        Canvas = canvas,
        CanvasWidth = canvasWidth,
        CanvasHeight = canvasHeight,
    }
end

return Base
