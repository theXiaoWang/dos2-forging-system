-- Client/ForgingUI/UI/Layout/WarningBanner.lua
-- Warning banner strip shown above the main content.

local WarningBanner = {}

---@param options table
function WarningBanner.Create(options)
    local opts = options or {}
    local canvas = opts.canvas
    if not canvas then
        return nil
    end

    local x = opts.x or 0
    local y = opts.y or 0
    local width = opts.width or 0
    local height = opts.height or 0
    local createTextElement = opts.createTextElement
    local labelOffsetX = opts.labelOffsetX or 0
    local labelOffsetY = opts.labelOffsetY or 0
    local bgColor = opts.bgColor or "2E1D12"
    local bgAlpha = opts.bgAlpha or 0.75
    local textStyle = opts.textStyle or {Size = 14, Color = "FFD27F"}

    local warningBG = canvas:AddChild("ForgeWarning_BG", "GenericUI_Element_Color")
    warningBG:SetPosition(x, y)
    warningBG:SetSize(width, height)
    warningBG:SetColor(Color.CreateFromHex(bgColor))
    warningBG:SetAlpha(bgAlpha)
    if warningBG.SetVisible then
        warningBG:SetVisible(false)
    end

    local warningLabel = nil
    if createTextElement then
        warningLabel = createTextElement(
            canvas,
            "ForgeWarning_Label",
            "",
            x + labelOffsetX,
            y + labelOffsetY,
            width - labelOffsetX * 2,
            height,
            "Left",
            false,
            textStyle
        )
        if warningLabel and warningLabel.SetVisible then
            warningLabel:SetVisible(false)
        end
    end

    return {
        Background = warningBG,
        Label = warningLabel,
    }
end

return WarningBanner
