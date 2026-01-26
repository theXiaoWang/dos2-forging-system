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
    local topBarHeight = opts.topBarHeight or 0
    local topBarWidth = opts.topBarWidth or 0
    local registerSearchBlur = opts.registerSearchBlur
    local createButtonBox = opts.createButtonBox
    local wireButton = opts.wireButton
    local scaleX = opts.scaleX or function(value) return value end
    local scaleY = opts.scaleY or function(value) return value end
    local layoutTuning = ctx.LayoutTuning or nil
    local useTransparentButtons = layoutTuning and layoutTuning.TopBarTransparentButtons
    local transparentStyle = useTransparentButtons and ctx.styleTransparentLong or nil
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
    topBar:SetPosition(margin, margin)
    if registerSearchBlur then
        registerSearchBlur(topBar)
    end

    local dragArea = topBar:AddChild("ForgeUIDragArea", "GenericUI_Element_Color")
    dragArea:SetSize(topBarWidth, topBarHeight)
    dragArea:SetColor(ctx.topBarBackgroundColor or ctx.HEADER_FILL_COLOR)
    local topBarAlpha = 0
    if layoutTuning and layoutTuning.TopBarBackgroundAlpha ~= nil then
        topBarAlpha = clamp(layoutTuning.TopBarBackgroundAlpha, 0, 1)
    end
    dragArea:SetAlpha(topBarAlpha)
    dragArea:SetAsDraggableArea()
    if registerSearchBlur then
        registerSearchBlur(dragArea)
    end

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

    local rightButtons = {
        {Label = "Level Up", Width = 80},
        {Label = "Level Up All", Width = 100},
        {Label = "Toggle Auto\nLevel Up", Width = 110, Wrap = true},
    }
    for i = #rightButtons, 1, -1 do
        local button = rightButtons[i]
        rightX = rightX - button.Width
        local rightButtonStyle = transparentStyle or ctx.styleTabCharacterSheetWide
        local topBtn = createButtonBox(topBar, "Btn_TopRight_" .. i, button.Label, rightX, topButtonY, button.Width, topButtonHeight, button.Wrap, rightButtonStyle)
        if wireButton then
            wireButton(topBtn, button.Label)
        end
        rightX = rightX - 6
    end

    return topBar
end

return TopBar
