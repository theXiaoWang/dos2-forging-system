-- Utilities/LegacyAlias.lua
-- Creates warning proxies for legacy aliases.

local LegacyAlias = {}
LegacyAlias.WarningsEnabled = true

function LegacyAlias.SetWarningsEnabled(enabled)
    LegacyAlias.WarningsEnabled = enabled == true
end

---@param aliasName string
---@param targetName string
---@param target table
---@return table
function LegacyAlias.Create(aliasName, targetName, target)
    local warned = false

    local function WarnOnce()
        if warned then
            return
        end
        if not LegacyAlias.WarningsEnabled then
            return
        end
        warned = true
        local message = string.format("[ForgingUI] Legacy alias '%s' used; prefer '%s'.", aliasName, targetName)
        if Ext and Ext.Print then
            Ext.Print(message)
        else
            print(message)
        end
    end

    local proxy = {}
    local mt = {
        __index = function(_, key)
            WarnOnce()
            return target[key]
        end,
        __newindex = function(_, key, value)
            WarnOnce()
            target[key] = value
        end,
        __len = function()
            WarnOnce()
            return #target
        end,
        __pairs = function()
            WarnOnce()
            return pairs(target)
        end,
        __ipairs = function()
            WarnOnce()
            return ipairs(target)
        end,
        __tostring = function()
            WarnOnce()
            return tostring(target)
        end,
    }

    return setmetatable(proxy, mt)
end

return LegacyAlias
