-- Client/ForgingUI/UI/Widgets/Elements.lua
-- Core element builders shared across the forging UI.

local Elements = {}

---@param options table
function Elements.Create(options)
    local opts = options or {}
    local getContext = opts.getContext
    local getUI = opts.getUI
    local vector = opts.vector or function(...) return Vector.Create(...) end
    local registerSearchBlur = opts.registerSearchBlur

    local function CreateFrame(parent, id, x, y, width, height, fillColor, alpha, padding, useSliced, centerAlphaOverride, innerAlphaOverride, frameStyleOverride, frameOffset, frameSizeOverride)
        if not parent then
            return nil, nil
        end
        local ctx = getContext and getContext() or nil
        local function ApplySize(element, w, h)
            if not element then
                return
            end
            local skipSetSize = element.SetGridSize ~= nil
            if element.SetSize and not skipSetSize then
                element:SetSize(w, h)
            end
            if element.SetSizeOverride then
                element:SetSizeOverride(w, h)
            end
        end
        local function NormalizeScale(element)
            if element and element.SetScale then
                element:SetScale(vector(1, 1))
            end
        end

        local frame = parent:AddChild(id, "GenericUI_Element_Empty")
        frame:SetPosition(x, y)
        ApplySize(frame, width or 0, height or 0)
        NormalizeScale(frame)
        if frame.SetMouseEnabled then
            frame:SetMouseEnabled(true)
        end
        if frame.SetMouseChildren then
            frame:SetMouseChildren(true)
        end

        local frameTex = nil
        local frameStyle = frameStyleOverride or (ctx and ctx.panelFrameStyle)
        if useSliced and ctx and ctx.USE_SLICED_FRAMES and ctx.slicedTexturePrefab and frameStyle then
            local sliceSize = frameSizeOverride
            if not sliceSize then
                sliceSize = vector(width, height)
            elseif type(sliceSize) == "table" and sliceSize.unpack then
                sliceSize = vector(sliceSize:unpack())
            elseif type(sliceSize) == "table" then
                sliceSize = vector(sliceSize[1] or width, sliceSize[2] or height)
            end
            local ui = getUI and getUI() or nil
            frameTex = ctx.slicedTexturePrefab.Create(ui, id .. "_Frame", frame, frameStyle, sliceSize)
            if frameTex then
                local offset = frameOffset
                if offset == nil then
                    offset = vector(0, 0)
                elseif type(offset) == "number" then
                    offset = vector(offset, offset)
                elseif type(offset) == "table" or type(offset) == "userdata" then
                    if offset.unpack then
                        offset = vector(offset:unpack())
                    else
                        offset = vector(offset[1] or 0, offset[2] or 0)
                    end
                else
                    offset = vector(0, 0)
                end
                if frameTex.Root and frameTex.Root.SetPosition then
                    frameTex.Root:SetPosition(offset[1], offset[2])
                end
                if frameTex.Root and frameTex.Root.SetScale then
                    frameTex.Root:SetScale(vector(1, 1))
                end
                -- Apply configured alpha to sliced frames for consistent transparency.
                local frameAlpha = (alpha ~= nil and alpha)
                    or (ctx and ctx.FRAME_TEXTURE_ALPHA)
                    or (ctx and ctx.FRAME_ALPHA)
                    or 1
                local centerAlpha = (centerAlphaOverride ~= nil and centerAlphaOverride)
                    or (ctx and ctx.FRAME_TEXTURE_CENTER_ALPHA)
                    or 0
                if frameTex.SetAlpha then
                    frameTex:SetAlpha(frameAlpha)
                end
                if frameTex.Root and frameTex.Root.SetAlpha then
                    frameTex.Root:SetAlpha(frameAlpha)
                end
                -- Ensure all sliced texture children receive the same alpha.
                if frameTex.GetChildren then
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
            end
        end

        local innerWidth = width
        local innerHeight = height
        local inner = frame:AddChild(id .. "_Inner", "GenericUI_Element_Empty")
        inner:SetPosition(0, 0)
        NormalizeScale(inner)
        if inner.SetMouseEnabled then
            inner:SetMouseEnabled(true)
        end
        if inner.SetMouseChildren then
            inner:SetMouseChildren(true)
        end

        -- Only create innerBG if not using sliced textures (sliced textures have their own transparency)
        -- Similar to how CreateSkinnedPanel handles textures
        local innerBG = nil
        if not useSliced then
            local innerAlpha = innerAlphaOverride
            if innerAlpha == nil then
                innerAlpha = ctx and ctx.PANEL_FILL_ALPHA
                if innerAlpha == nil then
                    innerAlpha = alpha or (ctx and ctx.FRAME_ALPHA) or 1
                end
            end
            innerBG = inner:AddChild(id .. "_InnerBG", "GenericUI_Element_Color")
            innerBG:SetPosition(0, 0)
            ApplySize(innerBG, width or 0, height or 0)
            innerBG:SetColor(fillColor or (ctx and ctx.FILL_COLOR))
            innerBG:SetAlpha(innerAlpha)
            if innerBG.SetVisible then
                innerBG:SetVisible(innerAlpha > 0)
            end
            if innerBG.SetMouseEnabled then
                innerBG:SetMouseEnabled(false)
            end
            if innerBG.SetMouseChildren then
                innerBG:SetMouseChildren(false)
            end
            NormalizeScale(innerBG)
        end

        if padding and padding > 0 then
            innerWidth = width - padding * 2
            innerHeight = height - padding * 2
            inner:SetPosition(padding, padding)
            ApplySize(inner, innerWidth, innerHeight)
            NormalizeScale(inner)
            if innerBG then
                innerBG:SetPosition(0, 0)
                ApplySize(innerBG, innerWidth, innerHeight)
                NormalizeScale(innerBG)
            end
        else
            ApplySize(inner, width or 0, height or 0)
            NormalizeScale(inner)
        end

        return frame, inner, innerWidth, innerHeight, frameTex
    end

    local function CreateTextElement(parent, id, text, x, y, width, height, align, wrap, format)
        if not parent then
            return nil
        end
        local ctx = getContext and getContext() or nil

        local label = parent:AddChild(id, "GenericUI_Element_Text")
        label:SetPosition(x or 0, y or 0)
        label:SetSize(width or 0, height or 0)
        label:SetType(align or "Left")
        local formatted = text or ""
        if Text and Text.Format then
            local formatData = {}
            if format then
                for key, value in pairs(format) do
                    formatData[key] = value
                end
            end
            if formatData.Color == nil then
                formatData.Color = ctx and ctx.TEXT_COLOR or 0xFFFFFF
            end
            if formatData.Size == nil then
                formatData.Size = formatData.size or (ctx and ctx.BODY_TEXT_SIZE) or 12
            end
            formatted = Text.Format(text or "", formatData)
        end
        label:SetText(formatted)
        if label.SetWrap then
            label:SetWrap(wrap or false)
        end
        if label.SetMouseEnabled then
            label:SetMouseEnabled(false)
        end
        return label
    end

    local function CreatePanel(parent, id, x, y, width, height, title)
        local ctx = getContext and getContext() or nil
        local frame, inner, innerWidth, innerHeight = CreateFrame(parent, id, x, y, width, height, ctx and ctx.FILL_COLOR, ctx and ctx.FRAME_ALPHA, 0)
        if title and title ~= "" and inner then
            CreateTextElement(inner, id .. "_Title", title, 0, 0, innerWidth, 22, "Center", false, {size = ctx and ctx.HEADER_TEXT_SIZE or 13})
        end
        return frame, inner, innerWidth, innerHeight
    end

    local function BuildButtonStyle(width, height, baseStyle)
        if not baseStyle then
            return {Size = vector(width, height)}
        end
        local style = {}
        for k, v in pairs(baseStyle) do
            style[k] = v
        end
        style.Size = vector(width, height)
        return style
    end

    local function CreateSkinnedPanel(parent, id, x, y, width, height, texture, padding, frameStyleOverride, frameOffset, frameSizeOverride)
        if not parent then
            return nil, nil, 0, 0
        end
        local ctx = getContext and getContext() or nil

        local hasTexture = texture ~= nil
        local validTexture = hasTexture and (type(texture) ~= "table" or texture.GUID)
        local fillAlpha = ctx and ctx.FRAME_ALPHA or 1
        if validTexture then
            fillAlpha = 0 -- Allow the texture to render without being covered by the inner fill.
        end
        local centerAlphaOverride = nil
        if validTexture then
            -- Avoid dark overlay from sliced frame center when a panel texture is present.
            centerAlphaOverride = 0
        end
        local frame, inner, innerWidth, innerHeight = CreateFrame(
            parent,
            id,
            x,
            y,
            width,
            height,
            ctx and ctx.FILL_COLOR,
            fillAlpha,
            padding or 0,
            ctx and ctx.USE_SLICED_PANELS,
            centerAlphaOverride,
            nil,
            frameStyleOverride,
            frameOffset,
            frameSizeOverride
        )

        if validTexture then
            local panel = frame:AddChild(id .. "_Panel", "GenericUI_Element_Texture")
            panel:SetTexture(texture, vector(width, height))
            panel:SetSize(width, height)
            panel:SetPosition(0, 0)
            local panelAlpha = (ctx and ctx.PANEL_TEXTURE_ALPHA)
            if panelAlpha == nil then
                panelAlpha = 1
            end
            if ctx and ctx.SLOT_PANEL_TEXTURE_ALPHA ~= nil and texture == ctx.slotPanelTexture then
                panelAlpha = ctx.SLOT_PANEL_TEXTURE_ALPHA
            end
            if panel.SetAlpha then
                panel:SetAlpha(panelAlpha)
            end
            if panel.SetVisible then
                panel:SetVisible(panelAlpha > 0)
            end
            if panel.SetScale then
                panel:SetScale(vector(1, 1))
            end
            if frame.SetChildIndex then
                frame:SetChildIndex(panel, 0)
            end
        end

        return frame, inner, innerWidth, innerHeight
    end

    local function CreateButtonBox(parent, id, label, x, y, width, height, wrap, styleOverride)
        local ctx = getContext and getContext() or nil
        if not parent or not ctx or not ctx.buttonPrefab then
            return nil
        end

        local baseStyle = styleOverride or ctx.buttonStyle
        local style = BuildButtonStyle(width, height, baseStyle)
        local ui = getUI and getUI() or nil
        local button = ctx.buttonPrefab.Create(ui, id .. "_Button", parent, style)
        button.Root:SetPosition(x, y)
        if label then
            button:SetLabel(label, "Center")
            if wrap then
                local labelElement = button.Label and button.Label.Element
                if labelElement and labelElement.SetWrap and labelElement.SetSize then
                    labelElement:SetWrap(true)
                    labelElement:SetSize(width - 6, height - 4)
                end
            end
        end
        local buttonRoot = button.Root or (button.GetRootElement and button:GetRootElement() or nil)
        if registerSearchBlur and buttonRoot then
            registerSearchBlur(buttonRoot)
        end
        return button
    end

    return {
        CreateFrame = CreateFrame,
        CreateTextElement = CreateTextElement,
        CreatePanel = CreatePanel,
        BuildButtonStyle = BuildButtonStyle,
        CreateSkinnedPanel = CreateSkinnedPanel,
        CreateButtonBox = CreateButtonBox,
    }
end

return Elements
