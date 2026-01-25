-- Client/ForgingUI/UI/PreviewInventory/SearchInput.lua
-- Search input builder for the preview inventory panel.

local SearchInput = {}

---@param options table
function SearchInput.Build(options)
    local opts = options or {}
    local ctx = opts.ctx
    local previewInventory = opts.previewInventory
    local parent = opts.parent
    if not ctx or not previewInventory or not parent then
        return nil
    end

    local x = opts.x or 0
    local y = opts.y or 0
    local width = opts.width or 0
    local height = opts.height or 0
    local previewTuning = opts.previewTuning
    local scaleX = opts.scaleX or function(value) return value end
    local scaleY = opts.scaleY or function(value) return value end
    local clamp = opts.clamp or function(value, minValue, maxValue)
        if value < minValue then
            return minValue
        end
        if value > maxValue then
            return maxValue
        end
        return value
    end
    local normalizeSearchQuery = opts.normalizeSearchQuery
    local registerPreviewSearchShortcuts = opts.registerPreviewSearchShortcuts
    local renderPreviewInventory = opts.renderPreviewInventory
    local applyPreviewSortMode = opts.applyPreviewSortMode
    local resolveDefaultSortMode = opts.resolveDefaultSortMode
    local applySize = opts.applySize or function() end
    local normalizeScale = opts.normalizeScale or function() end

    local searchRoot = parent:AddChild("PreviewInventory_Search", "GenericUI_Element_Empty")
    searchRoot:SetPosition(x, y)
    applySize(searchRoot, width, height)
    normalizeScale(searchRoot)

    local textPaddingBase = (previewTuning and previewTuning.SearchTextPaddingX) or 6
    local textPaddingMin = (previewTuning and previewTuning.SearchTextPaddingMin) or 4
    local textPaddingMax = (previewTuning and previewTuning.SearchTextPaddingMax) or 10
    local textPadding = clamp(scaleX(textPaddingBase), textPaddingMin, textPaddingMax)
    local textWidth = math.max(0, width - textPadding * 2)
    local inputTextSize = clamp(math.floor(height * 0.6), 11, 14)
    local hintTextSize = clamp(inputTextSize + 2, 12, 15)
    local inputTextLiftY = clamp(scaleY(7), 6, 8)
    local hintTextLiftY = clamp(scaleY(5), 4, 6)
    local inputTextOffsetY = math.floor((height - inputTextSize) / 2) - inputTextLiftY
    local hintTextOffsetY = math.floor((height - hintTextSize) / 2) - hintTextLiftY
    local textHeight = height

    local searchInput = searchRoot:AddChild("PreviewInventory_Search_Input", "GenericUI_Element_Text")
    searchInput:SetPosition(textPadding, 0)
    searchInput:SetSize(textWidth, textHeight)
    searchInput:SetType("Left")
    searchInput:SetText(previewInventory.SearchQuery or "")
    searchInput:SetEditable(true)
    if searchInput.SetMouseEnabled then
        searchInput:SetMouseEnabled(true)
    end
    if searchInput.SetMouseChildren then
        searchInput:SetMouseChildren(true)
    end
    if searchInput.SetWordWrap then
        searchInput:SetWordWrap(false)
    end
    if searchInput.SetTextFormat then
        searchInput:SetTextFormat({color = 0xFFFFFF, size = inputTextSize})
    end
    local inputMC = searchInput.GetMovieClip and searchInput:GetMovieClip() or nil
    if inputMC and inputMC.text_txt then
        inputMC.text_txt.type = "input"
        inputMC.text_txt.selectable = true
        inputMC.text_txt.alwaysShowSelection = true
        inputMC.text_txt.multiline = false
        inputMC.text_txt.wordWrap = false
    end

    local searchHint = searchRoot:AddChild("PreviewInventory_Search_Hint", "GenericUI_Element_Text")
    searchHint:SetPosition(textPadding, 0)
    searchHint:SetSize(textWidth, textHeight)
    searchHint:SetType("Left")
    searchHint:SetText((previewTuning and previewTuning.SearchPlaceholderText) or "Type to search...")
    if searchHint.SetTextFormat then
        searchHint:SetTextFormat({color = 0xB0B0B0, size = hintTextSize})
    end
    if searchHint.SetMouseEnabled then
        searchHint:SetMouseEnabled(false)
    end

    local function CenterSearchText(element, offsetY)
        local mc = element and element.GetMovieClip and element:GetMovieClip() or nil
        if mc and mc.text_txt then
            mc.text_txt.y = offsetY
        end
    end

    CenterSearchText(searchInput, inputTextOffsetY)
    CenterSearchText(searchHint, hintTextOffsetY)

    local function UpdateSearchHint(rawText)
        local hasText = false
        if normalizeSearchQuery then
            hasText = normalizeSearchQuery(rawText) ~= nil
        else
            hasText = tostring(rawText or "") ~= ""
        end
        local isFocused = searchInput.IsFocused and searchInput:IsFocused()
        if searchHint.SetVisible then
            searchHint:SetVisible((not hasText) and not isFocused)
        end
    end

    local function QueueSearchCaret(targetIndex)
        local function ApplyCaret()
            local mc = searchInput and searchInput.GetMovieClip and searchInput:GetMovieClip() or nil
            if mc and mc.text_txt and mc.text_txt.setSelection then
                local textValue = previewInventory.SearchQuery or ""
                local index = targetIndex
                if index == nil or index > #textValue then
                    index = #textValue
                end
                if index < 0 then
                    index = 0
                end
                mc.text_txt.setSelection(index, index)
            end
        end

        ApplyCaret()
        if Timer and Timer.Start then
            Timer.Start("ForgingUI_SearchCaret", 0.01, ApplyCaret)
        end
    end

    local function RecordSearchHistory(nextText)
        if previewInventory.SearchHistoryIgnore then
            return
        end
        local history = previewInventory.SearchHistory or {}
        local index = previewInventory.SearchHistoryIndex or #history
        if index <= 0 then
            index = #history
        end
        local current = history[index] or ""
        if nextText == current then
            return
        end
        for i = #history, index + 1, -1 do
            history[i] = nil
        end
        history[#history + 1] = nextText
        previewInventory.SearchHistory = history
        previewInventory.SearchHistoryIndex = #history
        local maxHistory = 50
        if #history > maxHistory then
            local overflow = #history - maxHistory
            for _ = 1, overflow do
                table.remove(history, 1)
            end
            previewInventory.SearchHistoryIndex = math.max(1, previewInventory.SearchHistoryIndex - overflow)
        end
    end

    local function ApplySearchText(nextText, ignoreHistory, keepCaretEnd, caretIndex)
        local nextValue = nextText or ""
        if not ignoreHistory then
            RecordSearchHistory(nextValue)
        end
        previewInventory.SearchHistoryIgnore = true
        previewInventory.SearchQuery = nextValue
        if searchInput.SetText then
            searchInput:SetText(previewInventory.SearchQuery)
        end
        previewInventory.SearchHistoryIgnore = false
        UpdateSearchHint(previewInventory.SearchQuery)
        if renderPreviewInventory then
            renderPreviewInventory()
        end
        if keepCaretEnd then
            QueueSearchCaret(#previewInventory.SearchQuery)
        elseif caretIndex ~= nil then
            QueueSearchCaret(caretIndex)
        end
    end

    previewInventory.ApplySearchText = ApplySearchText
    previewInventory.SearchHistory = {previewInventory.SearchQuery or ""}
    previewInventory.SearchHistoryIndex = #previewInventory.SearchHistory

    UpdateSearchHint(previewInventory.SearchQuery or "")

    if searchInput.Events and searchInput.Events.Changed then
        searchInput.Events.Changed:Subscribe(function (ev)
            local nextText = ev and ev.Text or ""
            RecordSearchHistory(nextText)
            local previousActive = false
            if normalizeSearchQuery then
                previousActive = normalizeSearchQuery(previewInventory.SearchQuery) ~= nil
            else
                previousActive = tostring(previewInventory.SearchQuery or "") ~= ""
            end
            previewInventory.SearchQuery = nextText
            local nextActive = false
            if normalizeSearchQuery then
                nextActive = normalizeSearchQuery(previewInventory.SearchQuery) ~= nil
            else
                nextActive = tostring(previewInventory.SearchQuery or "") ~= ""
            end
            UpdateSearchHint(previewInventory.SearchQuery)
            if previousActive and not nextActive then
                if applyPreviewSortMode then
                    local defaultMode = resolveDefaultSortMode and resolveDefaultSortMode() or "Default"
                    applyPreviewSortMode(defaultMode)
                end
            elseif renderPreviewInventory then
                renderPreviewInventory()
            end
        end)
    end
    if searchInput.Events and searchInput.Events.Focused then
        searchInput.Events.Focused:Subscribe(function ()
            previewInventory.SearchFocused = true
            if registerPreviewSearchShortcuts then
                registerPreviewSearchShortcuts()
            end
            if searchHint.SetVisible then
                searchHint:SetVisible(false)
            end
        end)
    end
    if searchInput.Events and searchInput.Events.Unfocused then
        searchInput.Events.Unfocused:Subscribe(function ()
            previewInventory.SearchFocused = false
            previewInventory.SearchCtrlHeld = false
            UpdateSearchHint(previewInventory.SearchQuery)
        end)
    end

    previewInventory.SearchRoot = searchRoot
    previewInventory.SearchFrame = nil
    previewInventory.SearchText = searchInput
    previewInventory.SearchHint = searchHint

    return searchRoot
end

return SearchInput
