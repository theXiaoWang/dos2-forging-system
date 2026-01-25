-- Client/ForgingUI/Input/PreviewSearchShortcuts.lua
-- Ctrl-shortcuts (undo/redo/select all/copy/paste/cut) for the preview inventory search field.

local PreviewSearchShortcuts = {}

local registered = false

---@param previewInventory table
function PreviewSearchShortcuts.Register(previewInventory)
    if registered then
        return
    end
    if not previewInventory then
        return
    end
    if not Ext or not Ext.Events or not Ext.Events.RawInput then
        return
    end
    registered = true

    local function GetSearchTextField()
        local searchInput = previewInventory.SearchText
        local mc = searchInput and searchInput.GetMovieClip and searchInput:GetMovieClip() or nil
        return mc and mc.text_txt or nil
    end

    local function GetSearchSelectionRange()
        local textField = GetSearchTextField()
        if not textField then
            return nil, nil
        end
        local startIndex = textField.selectionBeginIndex
        local endIndex = textField.selectionEndIndex
        if startIndex == nil or endIndex == nil then
            return nil, nil
        end
        if startIndex > endIndex then
            startIndex, endIndex = endIndex, startIndex
        end
        return startIndex, endIndex
    end

    local function SetSearchSelection(startIndex, endIndex)
        local textField = GetSearchTextField()
        if textField and textField.setSelection then
            textField.setSelection(startIndex, endIndex)
        end
    end

    local function CopySearchText(textValue)
        if textValue == nil then
            return
        end
        previewInventory.SearchClipboard = textValue

        if Ext and Ext.UI and Ext.UI.GetByType then
            local ui = Ext.UI.GetByType(Ext.UI.TypeID.msgBox)
            if ui and ui.GetRoot and ui.ExternalInterfaceCall and Timer and Timer.Start then
                local root = ui:GetRoot()
                if root and root.setInputText then
                    root.setInputText(textValue)
                    if root.popup_mc and root.popup_mc.input_mc and root.popup_mc.input_mc.acceptSave then
                        root.popup_mc.input_mc.acceptSave()
                    end
                    if root.focusInputEnabled then
                        root.focusInputEnabled()
                    end
                    local timerID = "ForgingUI_SearchCopy_" .. tostring(Ext.MonotonicTime())
                    Timer.Start(timerID, 0.2, function()
                        ui:ExternalInterfaceCall("copyPressed")
                    end)
                    return
                end
            end
        end
    end

    local function RequestClipboardText(callback)
        if not callback then
            return
        end
        if Ext and Ext.UI and Ext.UI.GetByType and Timer and Timer.Start then
            local ui = Ext.UI.GetByType(Ext.UI.TypeID.msgBox)
            if ui and ui.ExternalInterfaceCall and ui.GetRoot then
                local timerID = "ForgingUI_SearchPaste_" .. tostring(Ext.MonotonicTime())
                ui:ExternalInterfaceCall("pastePressed")
                Timer.Start(timerID, 0.1, function()
                    local text = nil
                    local root = ui:GetRoot()
                    local inputField = root
                        and root.popup_mc
                        and root.popup_mc.input_mc
                        and root.popup_mc.input_mc.input_txt
                    if inputField and inputField.text then
                        text = inputField.text or ""
                    end
                    if text == nil or text == "" then
                        text = previewInventory.SearchClipboard or ""
                    end
                    callback(text)
                end)
                return
            end
        end
        callback(previewInventory.SearchClipboard or "")
    end

    local function PasteIntoSearch(pasteText)
        if pasteText == nil then
            return
        end
        local cleaned = tostring(pasteText):gsub("[\r\n\t]", "")
        local textValue = previewInventory.SearchQuery or ""
        local startIndex, endIndex = GetSearchSelectionRange()
        if startIndex == nil or endIndex == nil then
            startIndex = #textValue
            endIndex = #textValue
        end
        local before = textValue:sub(1, startIndex)
        local after = textValue:sub(endIndex + 1)
        local merged = before .. cleaned .. after
        local caretIndex = startIndex + #cleaned
        if previewInventory.ApplySearchText then
            previewInventory.ApplySearchText(merged, false, false, caretIndex)
        end
    end

    Ext.Events.RawInput:Subscribe(function(ev)
        local inputEvent = ev and ev.Input or nil
        local input = inputEvent and inputEvent.Input or nil
        local value = inputEvent and inputEvent.Value or nil
        if not input or not value then
            return
        end

        local id = tostring(input.InputId or "")
        if id == "" then
            return
        end

        local state = value.State
        if id == "lctrl" or id == "rctrl" then
            previewInventory.SearchCtrlHeld = state == "Pressed"
            if state == "Released" then
                previewInventory.SearchCtrlHeld = false
            end
            return
        end

        if state ~= "Pressed" then
            return
        end
        if not previewInventory.SearchFocused or not previewInventory.SearchCtrlHeld then
            return
        end

        local key = string.lower(id)
        if key == "a" then
            local textValue = previewInventory.SearchQuery or ""
            SetSearchSelection(0, #textValue)
            return
        end

        if key == "z" then
            local history = previewInventory.SearchHistory
            local index = previewInventory.SearchHistoryIndex or 0
            if history and index > 1 then
                index = index - 1
                previewInventory.SearchHistoryIndex = index
                local text = history[index] or ""
                if previewInventory.ApplySearchText then
                    previewInventory.ApplySearchText(text, true, true)
                end
            end
            return
        end

        if key == "y" then
            local history = previewInventory.SearchHistory
            local index = previewInventory.SearchHistoryIndex or 0
            if history and index < #history then
                index = index + 1
                previewInventory.SearchHistoryIndex = index
                local text = history[index] or ""
                if previewInventory.ApplySearchText then
                    previewInventory.ApplySearchText(text, true, true)
                end
            end
            return
        end

        if key == "c" then
            local textValue = previewInventory.SearchQuery or ""
            local startIndex, endIndex = GetSearchSelectionRange()
            if startIndex ~= nil and endIndex ~= nil and startIndex ~= endIndex then
                local selection = textValue:sub(startIndex + 1, endIndex)
                if selection ~= "" then
                    CopySearchText(selection)
                end
            end
            return
        end

        if key == "v" then
            RequestClipboardText(function(text)
                PasteIntoSearch(text or "")
            end)
            return
        end

        if key == "x" then
            local textValue = previewInventory.SearchQuery or ""
            local startIndex, endIndex = GetSearchSelectionRange()
            if startIndex ~= nil and endIndex ~= nil and startIndex ~= endIndex then
                local selection = textValue:sub(startIndex + 1, endIndex)
                if selection ~= "" then
                    CopySearchText(selection)
                end
                local before = textValue:sub(1, startIndex)
                local after = textValue:sub(endIndex + 1)
                local merged = before .. after
                if previewInventory.ApplySearchText then
                    previewInventory.ApplySearchText(merged, false, false, startIndex)
                end
            end
            return
        end
    end, {StringID = "ForgingUI_SearchShortcuts"})
end

return PreviewSearchShortcuts

