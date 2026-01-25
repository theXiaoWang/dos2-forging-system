-- Client/ForgingUI/UI/Layout/Diagnostics.lua
-- Layout-related debug helpers.

local Diagnostics = {}

---@param options table
function Diagnostics.Create(options)
    local opts = options or {}
    local getContext = opts.getContext

    local function PrintUIState(tag)
        local ctx = getContext and getContext() or nil
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

    local function PrintElementInfo(id)
        local ctx = getContext and getContext() or nil
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

    local function DumpElementTree(id, maxDepth)
        local ctx = getContext and getContext() or nil
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

    local function DumpFillElements(alphaThreshold)
        local ctx = getContext and getContext() or nil
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

    return {
        PrintUIState = PrintUIState,
        PrintElementInfo = PrintElementInfo,
        DumpElementTree = DumpElementTree,
        DumpFillElements = DumpFillElements,
    }
end

return Diagnostics
