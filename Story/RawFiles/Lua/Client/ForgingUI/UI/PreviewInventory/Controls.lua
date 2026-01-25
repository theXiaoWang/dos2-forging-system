-- Client/ForgingUI/UI/PreviewInventory/Controls.lua
-- Filter/sort controls for the preview inventory panel.

local Controls = {}

---@param options table
function Controls.Create(options)
    local opts = options or {}
    local preview = opts.previewInventory or {}
    local getContext = opts.getContext
    local getUI = opts.getUI
    local buildButtonStyle = opts.buildButtonStyle
    local renderPreviewInventory = opts.renderPreviewInventory

    local function SetPreviewFilterButtonActive(button, active)
        if not button then
            return
        end
        if button._IsStateButton and button:_IsStateButton() and button.SetActivated then
            button:SetActivated(active)
        elseif button.Root and button.Root.SetAlpha then
            button.Root:SetAlpha(active and 1 or 0.5)
        end
    end

    local function UpdatePreviewFilterButtons()
        local ctx = getContext and getContext() or nil
        if not ctx or not ctx.CRAFT_PREVIEW_MODES then
            return
        end
        SetPreviewFilterButtonActive(
            preview.FilterButtons[ctx.CRAFT_PREVIEW_MODES.Equipment],
            preview.Filter == ctx.CRAFT_PREVIEW_MODES.Equipment
        )
        SetPreviewFilterButtonActive(
            preview.FilterButtons[ctx.CRAFT_PREVIEW_MODES.Magical],
            preview.Filter == ctx.CRAFT_PREVIEW_MODES.Magical
        )
    end

    local function SetPreviewInventoryMode(mode)
        preview.Filter = mode
        UpdatePreviewFilterButtons()
        if renderPreviewInventory then
            renderPreviewInventory()
        end
    end

    local function WirePreviewFilterButton(button, mode)
        if not button or not button.Events or not button.Events.Pressed then
            return
        end
        button.Events.Pressed:Subscribe(function ()
            SetPreviewInventoryMode(mode)
        end)
    end

    local function ApplyPreviewSortMode(mode)
        local ctx = getContext and getContext() or nil
        if ctx and ctx.PreviewLogic and ctx.PreviewLogic.SetPreviewSortMode then
            ctx.PreviewLogic.SetPreviewSortMode(mode, true)
        end
        if renderPreviewInventory then
            renderPreviewInventory()
        end
    end

    local function SetSortByPanelOpen(open)
        preview.SortByOpen = open == true
        if preview.SortByPanel and preview.SortByPanel.SetVisible then
            preview.SortByPanel:SetVisible(preview.SortByOpen)
            if preview.Root and preview.Root.SetChildIndex then
                preview.Root:SetChildIndex(preview.SortByPanel, 9999)
            end
        end
        if preview.SortByButton and preview.SortByStyles then
            local style = preview.SortByOpen and preview.SortByStyles.Open or preview.SortByStyles.Closed
            preview.SortByButton:SetStyle(style)
        end
    end

    local function CreateSortOption(list, id, label, sortMode, width, height)
        local ctx = getContext and getContext() or nil
        if not list or not ctx or not ctx.buttonPrefab then
            return nil
        end
        local style = ctx.buttonPrefab.STYLES
            and (ctx.buttonPrefab.STYLES.LabelPointy or ctx.buttonPrefab.STYLES.MenuSlate or ctx.buttonStyle)
            or ctx.buttonStyle
        local makeStyle = buildButtonStyle and buildButtonStyle(width, height, style) or nil
        local button = ctx.buttonPrefab.Create(getUI and getUI() or nil, id .. "_Button", list, makeStyle)
        button.Root:SetPosition(0, 0)
        if button.Root.SetAlpha then
            button.Root:SetAlpha(0.7)
        end

        local labelText = label
        if Text and Text.Format then
            local labelSize = math.max(10, math.floor(height * 0.4))
            labelText = Text.Format(label or "", {Color = "FFFFFF", Size = labelSize})
        end
        button:SetLabel(labelText, "Center")

        if button.Events and button.Events.Pressed then
            button.Events.Pressed:Subscribe(function ()
                ApplyPreviewSortMode(sortMode)
                SetSortByPanelOpen(false)
            end)
        end

        return button
    end

    return {
        SetPreviewFilterButtonActive = SetPreviewFilterButtonActive,
        UpdatePreviewFilterButtons = UpdatePreviewFilterButtons,
        SetPreviewInventoryMode = SetPreviewInventoryMode,
        WirePreviewFilterButton = WirePreviewFilterButton,
        ApplyPreviewSortMode = ApplyPreviewSortMode,
        SetSortByPanelOpen = SetSortByPanelOpen,
        CreateSortOption = CreateSortOption,
    }
end

return Controls
