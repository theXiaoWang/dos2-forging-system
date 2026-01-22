-- Client/Framework/Bootstrap.lua
-- Minimal framework bootstrap for Generic UI and utility libs.

local Framework = {
    MOD_TABLE = "forging_system",
    MOD_GUID = "forging_system_d581d214-2dd4-4690-bb44-e371432f1bfc",
}

Utilities = Utilities or {}
Client = Client or {UI = {GM = {}, Controller = {}}}
PersistentVars = PersistentVars or {Features = {}}

Ext.Require("Utilities/Inheritance.lua")
Ext.Require("Utilities/Table.lua")
Ext.Require("Utilities/OOP/OOP.lua")
Ext.Require("Utilities/Event.lua")
Ext.Require("Utilities/OOP/_Library.lua")

if not Epip then
    Epip = {
        _Features = {},
    }

    function Epip.InitializeLibrary(id, lib)
        OOP.GetClass("Library").Create(Framework.MOD_TABLE, id, lib)
    end

    function Epip.InitializeUI(type, id, ui, assignToUINamespace)
        if assignToUINamespace == nil then assignToUINamespace = true end
        local instance = Client.UI._BaseUITable.Create(id, type, ui)
        if assignToUINamespace then
            Client.UI[id] = ui
        end
        Client._PathToUI = Client._PathToUI or {}
        local path = ui.GetPath and ui:GetPath()
        if path then
            Client._PathToUI[path] = ui
        end
        return instance
    end

    function Epip.RegisterFeature(modTable, id, feature)
        if not feature and type(id) == "table" then
            feature = id
            id = modTable
            modTable = Framework.MOD_TABLE
        end
        Epip._Features[modTable] = Epip._Features[modTable] or {Features = {}}
        Epip._Features[modTable].Features[id] = feature
        return feature
    end

    function Epip.GetFeature(modTable, id, required)
        if id == nil then
            modTable, id = Framework.MOD_TABLE, modTable
        end
        local modEntry = Epip._Features[modTable]
        local feature = nil
        if modEntry then
            local stripped = id:gsub("^Feature_", "", 1)
            stripped = stripped:gsub("^Features%.", "", 1)
            feature = modEntry.Features[id] or modEntry.Features[stripped]
        end
        if not feature and required then
            error("[ForgingSystem] Missing feature: " .. tostring(id), 2)
        end
        return feature
    end

    function Epip.ImportGlobals(tbl)
        for k,v in pairs(_G) do
            tbl[k] = v
        end
    end

    ---Returns whether developer mode is enabled.
    ---Fallback stub to avoid hard dependency on Epip settings.
    ---@param _requirePipPoem? boolean
    ---@return boolean
    function Epip.IsDeveloperMode(_requirePipPoem)
        if Ext and Ext.Debug and Ext.Debug.IsDeveloperMode then
            return Ext.Debug.IsDeveloperMode()
        end
        return false
    end
end

if not Client._AbsoluteUIPathToDataPath then
    ---Converts an absolute UI swf path to one relative to the Data directory.
    ---@param path string
    ---@return string?
    function Client._AbsoluteUIPathToDataPath(path)
        return string.match(path, ".*(Public/.+)$")
    end
end

Ext.Require("Client/Client.lua")

Ext.Require("Utilities/DataStructures/Main.lua")
Ext.Require("Utilities/DataStructures/DefaultTable.lua")
Ext.Require("Utilities/DataStructures/Set.lua")
Ext.Require("Utilities/Vector.lua")
Ext.Require("Utilities/Color.lua")
Ext.Require("Utilities/IO.lua")
Ext.Require("Utilities/Text/Library.lua")
Ext.Require("Utilities/Text/HTML.lua")
Ext.Require("Utilities/Text/CommonStrings.lua")
Ext.Require("Utilities/Text/Localization.lua")
Ext.Require("Utilities/Item/Shared.lua")
Ext.Require("Utilities/Texture.lua")
Ext.Require("Utilities/Hooks.lua")
Ext.Require("Utilities/Timer.lua")

Ext.Require("Client/Framework/Textures.lua")
Ext.Require("Tables/_UI.lua")
Ext.Require("Client/Framework/LoadGenericUI.lua")
-- Texture test UI pulls in additional Epip feature helpers; keep it disabled for runtime stability.
-- Ext.Require("Epip/GenericUITextures/Client_TestUI.lua")

return Framework
