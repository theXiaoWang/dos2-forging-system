-- Client/ForgingUI/UI/Layout/SideInventory.lua
-- Optional right-side inventory panel.

local SideInventory = {}

---@param options table
function SideInventory.Create(options)
    local opts = options or {}
    local ctx = opts.ctx
    local canvas = opts.canvas
    local createFrame = opts.createFrame
    local createTextElement = opts.createTextElement
    local createButtonBox = opts.createButtonBox
    local registerSearchBlur = opts.registerSearchBlur
    local wireButton = opts.wireButton
    local vector = opts.vector or function(...) return Vector.Create(...) end
    if not ctx or not canvas or not createFrame or not createTextElement or not createButtonBox then
        return nil
    end

    local x = opts.x or 0
    local y = opts.y or 0
    local width = opts.width or 0
    local height = opts.height or 0

    local inventoryFrame, inventoryPanel, inventoryInnerWidth = createFrame(
        canvas,
        "InventoryPanel",
        x,
        y,
        width,
        height,
        ctx.FILL_COLOR,
        ctx.FRAME_ALPHA
    )
    if registerSearchBlur then
        registerSearchBlur(inventoryFrame)
        registerSearchBlur(inventoryPanel)
    end

    local inventoryHeaderHeight = 22
    local _, inventoryHeaderInner, headerInnerWidth, headerInnerHeight = createFrame(
        inventoryPanel,
        "InventoryHeader",
        0,
        0,
        inventoryInnerWidth,
        inventoryHeaderHeight,
        ctx.HEADER_FILL_COLOR,
        1
    )
    createTextElement(inventoryHeaderInner, "InventoryLabel", "Inventory", 0, 0, headerInnerWidth - 70, headerInnerHeight, "Center", false, {size = ctx.HEADER_TEXT_SIZE})

    local sortWidth = 70
    local sortButton = createButtonBox(inventoryHeaderInner, "InventorySort", "Sort by", headerInnerWidth - sortWidth, 0, sortWidth, headerInnerHeight)
    if wireButton then
        wireButton(sortButton, "InventorySort")
    end

    local grid = inventoryPanel:AddChild("InventoryGrid", "GenericUI_Element_Grid")
    local gridPadding = 8
    local gridGap = 1
    local cols = 6
    local rows = 7
    local gridWidth = inventoryInnerWidth - gridPadding * 2
    local cellSize = math.floor((gridWidth - (cols - 1) * gridGap) / cols)
    grid:SetGridSize(rows, cols)
    grid:SetElementSpacing(gridGap, gridGap)
    grid:SetPosition(gridPadding, inventoryHeaderHeight + gridPadding)
    grid:SetRepositionAfterAdding(true)
    for i = 1, rows * cols do
        local cell = nil
        if ctx.gridCellTexture then
            cell = grid:AddChild("InventoryCell_" .. i, "GenericUI_Element_Texture")
            cell:SetTexture(ctx.gridCellTexture, vector(cellSize, cellSize))
        else
            cell = grid:AddChild("InventoryCell_" .. i, "GenericUI_Element_Color")
            cell:SetSize(cellSize, cellSize)
            cell:SetColor(ctx.GRID_COLOR)
        end
    end
    grid:RepositionElements()

    return inventoryPanel
end

return SideInventory
