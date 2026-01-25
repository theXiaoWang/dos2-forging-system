-- Client/ForgingUI/UI/Layout/LeftInfo.lua
-- Left-side info panel with header and description text.

local LeftInfo = {}

---@param options table
function LeftInfo.Create(options)
    local opts = options or {}
    local canvas = opts.canvas
    local createSkinnedPanel = opts.createSkinnedPanel
    local createTextElement = opts.createTextElement
    if not canvas or not createSkinnedPanel or not createTextElement then
        return nil
    end

    local x = opts.x or 0
    local y = opts.y or 0
    local width = opts.width or 0
    local height = opts.height or 0
    local texture = opts.texture
    local padding = opts.padding or 0
    local headerText = opts.headerText or ""
    local headerStyle = opts.headerStyle or {}
    local bodyText = opts.bodyText or ""
    local registerSearchBlur = opts.registerSearchBlur

    local frame, panel, innerWidth, innerHeight = createSkinnedPanel(
        canvas,
        "LeftInfo",
        x,
        y,
        width,
        height,
        texture,
        padding
    )

    if registerSearchBlur then
        registerSearchBlur(frame)
        registerSearchBlur(panel)
    end

    local headerHeight = 0
    if panel and headerText ~= "" then
        createTextElement(panel, "LeftInfo_Header", headerText, 0, 0, innerWidth, 22, "Center", false, headerStyle)
        headerHeight = 22
    end

    createTextElement(
        panel,
        "LeftInfo_Text",
        bodyText,
        12,
        headerHeight + 10,
        innerWidth - 24,
        innerHeight - headerHeight - 20,
        "Left",
        true
    )

    return {
        Frame = frame,
        Panel = panel,
    }
end

return LeftInfo
