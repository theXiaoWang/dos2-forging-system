-- Client/ForgingUI/UI/PreviewInventory/Search.lua
-- Search helpers for preview inventory.

local Search = {}

---@param options table
function Search.Create(options)
    local opts = options or {}
    local preview = opts.previewInventory or {}
    local shortcuts = opts.previewSearchShortcuts

    local shortcutsRegistered = false

    local function UnfocusPreviewSearch()
        local searchInput = preview.SearchText
        if searchInput and searchInput.SetFocused then
            local isFocused = searchInput.IsFocused and searchInput:IsFocused()
            if isFocused then
                searchInput:SetFocused(false)
            end
        end
    end

    local function RegisterSearchBlur(element)
        if not element or not element.Events or not element.Events.MouseDown then
            return
        end
        if element._PreviewSearchBlurHooked then
            return
        end
        element._PreviewSearchBlurHooked = true
        element.Events.MouseDown:Subscribe(function ()
            UnfocusPreviewSearch()
        end)
    end

    local function RegisterPreviewSearchShortcuts()
        if shortcutsRegistered then
            return
        end
        if not Ext or not Ext.Events or not Ext.Events.RawInput then
            return
        end
        shortcutsRegistered = true
        if shortcuts and shortcuts.Register then
            shortcuts.Register(preview)
        end
    end

    local function NormalizeSearchQuery(value)
        if value == nil then
            return nil
        end
        local trimmed = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed == "" then
            return nil
        end
        return string.lower(trimmed)
    end

    local function GetItemSearchName(item)
        if not item then
            return nil
        end
        if Item and Item.GetDisplayName then
            local ok, name = pcall(Item.GetDisplayName, item)
            if ok and name and name ~= "" then
                return name
            end
        end
        if item.DisplayName and item.DisplayName ~= "" then
            return item.DisplayName
        end
        local stats = item.Stats
        if type(stats) == "string" and Ext and Ext.Stats and Ext.Stats.Get then
            local ok, statsObj = pcall(Ext.Stats.Get, stats)
            if ok and statsObj then
                stats = statsObj
            end
        end
        if stats and stats.Name and stats.Name ~= "" then
            return stats.Name
        end
        return item.StatsId or item.StatsID
    end

    return {
        UnfocusPreviewSearch = UnfocusPreviewSearch,
        RegisterSearchBlur = RegisterSearchBlur,
        RegisterPreviewSearchShortcuts = RegisterPreviewSearchShortcuts,
        NormalizeSearchQuery = NormalizeSearchQuery,
        GetItemSearchName = GetItemSearchName,
    }
end

return Search
