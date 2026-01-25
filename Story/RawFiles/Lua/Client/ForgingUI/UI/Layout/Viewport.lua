-- Client/ForgingUI/UI/Layout/Viewport.lua
-- Viewport sizing/scaling helpers for the forging UI layout.

local Viewport = {}

---@param options table
function Viewport.Create(options)
    local opts = options or {}
    local getContext = opts.getContext
    local getLayoutState = opts.getLayoutState

    local function GetViewportSize()
        local ctx = getContext and getContext() or nil
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

    local function GetViewportScale()
        local _, viewportH = GetViewportSize()
        local scale = 1
        if viewportH and viewportH > 0 then
            scale = viewportH / 1080
        end
        if scale < 0.7 then
            scale = 0.7
        elseif scale > 1.5 then
            scale = 1.5
        end
        return scale
    end

    local function GetUIScaleMultiplier()
        local ctx = getContext and getContext() or nil
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

    local function UpdateUISizeFromViewport()
        local ctx = getContext and getContext() or nil
        local state = getLayoutState and getLayoutState() or nil
        if not state then
            return
        end

        local viewportW, viewportH = GetViewportSize()
        local uiScale = GetUIScaleMultiplier()
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

    local function ScaleX(value)
        local state = getLayoutState and getLayoutState() or nil
        if not state then
            return value
        end
        return math.floor(value * state.ScaleX + 0.5)
    end

    local function ScaleY(value)
        local state = getLayoutState and getLayoutState() or nil
        if not state then
            return value
        end
        return math.floor(value * state.ScaleY + 0.5)
    end

    local function Scale(value)
        local state = getLayoutState and getLayoutState() or nil
        if not state then
            return value
        end
        return math.floor(value * math.min(state.ScaleX, state.ScaleY) + 0.5)
    end

    local function Clamp(value, minValue, maxValue)
        if value < minValue then
            return minValue
        end
        if value > maxValue then
            return maxValue
        end
        return value
    end

    return {
        GetViewportScale = GetViewportScale,
        GetViewportSize = GetViewportSize,
        GetUIScaleMultiplier = GetUIScaleMultiplier,
        UpdateUISizeFromViewport = UpdateUISizeFromViewport,
        ScaleX = ScaleX,
        ScaleY = ScaleY,
        Scale = Scale,
        Clamp = Clamp,
    }
end

return Viewport
