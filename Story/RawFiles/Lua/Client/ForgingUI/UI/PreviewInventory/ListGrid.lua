-- Client/ForgingUI/UI/PreviewInventory/ListGrid.lua
-- List and grid layout builder for the preview inventory panel.

local ListGrid = {}

---@param options table
function ListGrid.Build(options)
    local opts = options or {}
    local ctx = opts.ctx
    local previewInventory = opts.previewInventory
    local parent = opts.parent
    if not parent or not previewInventory then
        return {}
    end

    local width = opts.width or 0
    local height = opts.height or 0
    local filterHeight = opts.filterHeight or 0
    local scale = opts.scale or function(value) return value end
    local applySize = opts.applySize or function() end
    local normalizeScale = opts.normalizeScale or function() end
    local registerSearchBlur = opts.registerSearchBlur
    local previewTuning = (opts.previewTuning or (ctx and ctx.PreviewInventoryTuning)) or {}

    local list = parent:AddChild("PreviewInventory_List", "GenericUI_Element_ScrollList")
    local listOffsetY = filterHeight
    local listHeight = math.max(0, height - listOffsetY)
    list:SetPosition(0, listOffsetY)
    applySize(list, width, listHeight)
    normalizeScale(list)
    list:SetMouseWheelEnabled(true)
    previewInventory.ScrollList = list
    previewInventory.ListOffsetY = listOffsetY
    previewInventory.ListHeight = listHeight
    if registerSearchBlur then
        registerSearchBlur(list)
    end

    local grid = list:AddChild("PreviewInventory_Grid", "GenericUI_Element_Grid")
    local padding = scale(4)  -- Reduced padding to give more space for slots

    -- Fixed columns per row for consistent layout (tunable).
    local columns = math.max(1, math.floor(tonumber(previewTuning.GridColumns) or 8))
    previewInventory.Columns = columns
    local gridWidth = math.max(0, width - padding * 2)
    local slotSize = previewInventory.SlotSize or 66
    if slotSize < 48 then
        slotSize = 48
    end
    previewInventory.SlotSize = slotSize
    local gridSpacing = previewInventory.GridSpacing or 0
    if previewTuning.GridSpacingX ~= nil then
        gridSpacing = scale(previewTuning.GridSpacingX)
    elseif columns > 1 then
        gridSpacing = math.floor((gridWidth - slotSize * columns) / (columns - 1))
    else
        gridSpacing = 0
    end
    previewInventory.GridSpacing = gridSpacing

    -- Calculate actual grid content width and center it
    local gridContentWidth = columns * slotSize + (columns - 1) * gridSpacing
    local gridX = math.floor((width - gridContentWidth) / 2)
    local gridY = padding

    grid:SetPosition(gridX, gridY)
    applySize(grid, gridContentWidth, math.max(0, listHeight - padding * 2))
    normalizeScale(grid)
    grid:SetElementSpacing(previewInventory.GridSpacing, previewInventory.GridSpacing)
    previewInventory.Grid = grid
    previewInventory.GridPadding = padding
    previewInventory.GridOffsetY = gridY
    previewInventory.GridContentWidth = gridContentWidth
    if registerSearchBlur then
        registerSearchBlur(grid)
    end
    grid:SetGridSize(columns, 1)

    return {
        list = list,
        grid = grid,
        gridX = gridX,
        gridContentWidth = gridContentWidth,
        padding = padding,
        listHeight = listHeight,
        listOffsetY = listOffsetY,
    }
end

return ListGrid
