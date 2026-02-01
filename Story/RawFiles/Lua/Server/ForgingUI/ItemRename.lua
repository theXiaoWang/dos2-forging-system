-- Server/ForgingUI/ItemRename.lua
-- Applies custom item name changes requested by the client.

local RENAME_NET_CHANNEL = "ForgingUI_RenameItem"

Ext.RegisterNetListener(RENAME_NET_CHANNEL, function(_, payload)
    local data = payload
    if type(payload) == "string" then
        local ok, parsed = pcall(Ext.Json.Parse, payload)
        if ok then
            data = parsed
        end
    end
    if type(data) ~= "table" then
        return
    end
    local netId = data.ItemNetID
    if not netId then
        return
    end
    local name = data.NewName
    if name == nil then
        name = ""
    end
    local item = Ext.Entity.GetItem(netId)
    if item then
        item.CustomDisplayName = tostring(name)
    end
end)
