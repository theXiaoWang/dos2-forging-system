-- Client/ForgingUI/UI/Widgets/Blocks.lua
-- Section and card builders for the forging UI.

local Blocks = {}

---@param options table
function Blocks.Create(options)
    local opts = options or {}
    local getContext = opts.getContext
    local createFrame = opts.createFrame
    local createTextElement = opts.createTextElement
    local scale = opts.scale or function(value) return value end

    local function CreateSectionBox(parent, id, x, y, width, height, title, bodyText, footerText)
        local ctx = getContext and getContext() or nil
        local frameAlpha = ctx and (ctx.SECTION_FRAME_ALPHA or ctx.FRAME_ALPHA) or nil
        local centerAlpha = ctx and ctx.SECTION_TEXTURE_CENTER_ALPHA or nil
        local fillAlpha = ctx and ctx.SECTION_FILL_ALPHA or nil
        local sectionStyle = ctx and ctx.sectionFrameStyle
        local frame, inner, innerWidth, innerHeight = createFrame(
            parent,
            id,
            x,
            y,
            width,
            height,
            ctx and ctx.FILL_COLOR,
            frameAlpha,
            scale(4),
            ctx and ctx.USE_SLICED_PANELS,
            centerAlpha,
            fillAlpha,
            sectionStyle
        )
        if inner then
            createTextElement(inner, id .. "_Header", title or "", 0, 0, innerWidth, 16, "Left", false, {size = ctx.HEADER_TEXT_SIZE})
            createTextElement(inner, id .. "_Body", bodyText or "", 0, 16, innerWidth, innerHeight - 32, "Left", true, {size = ctx.BODY_TEXT_SIZE})
            createTextElement(inner, id .. "_Footer", footerText or "", 0, innerHeight - 16, innerWidth, 16, "Left", false, {size = ctx.BODY_TEXT_SIZE})
        end
        return inner or frame
    end

    local function CreateItemCard(parent, id, x, y, width, height, iconLabel, bodyText, levelText)
        local ctx = getContext and getContext() or nil
        local frame, inner, innerWidth, innerHeight = createFrame(parent, id, x, y, width, height, ctx.FILL_COLOR, ctx.FRAME_ALPHA, scale(6))
        if inner then
            createTextElement(inner, id .. "_Icon", iconLabel or "", 0, 0, innerWidth, 20, "Left", false, {size = ctx.HEADER_TEXT_SIZE})
            createTextElement(inner, id .. "_Body", bodyText or "", 0, 20, innerWidth, innerHeight - 40, "Left", true, {size = ctx.BODY_TEXT_SIZE})
            createTextElement(inner, id .. "_Level", levelText or "", 0, innerHeight - 20, innerWidth, 20, "Right", false, {size = ctx.BODY_TEXT_SIZE})
        end
        return inner or frame
    end

    local function CreateSkillChip(parent, id, x, y, width, height, label, empty)
        local ctx = getContext and getContext() or nil
        local frame, inner, innerWidth, innerHeight = createFrame(parent, id, x, y, width, height, ctx.FILL_COLOR, ctx.FRAME_ALPHA, scale(2))
        if inner then
            local text = empty and "" or (label or "")
            createTextElement(inner, id .. "_Label", text, 0, 0, innerWidth, innerHeight, "Center", false, {size = ctx.BODY_TEXT_SIZE})
        end
        return inner or frame
    end

    return {
        CreateSectionBox = CreateSectionBox,
        CreateItemCard = CreateItemCard,
        CreateSkillChip = CreateSkillChip,
    }
end

return Blocks
