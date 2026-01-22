-- BootstrapClient.lua
-- Client-side initialization for Forging System mod

Ext.Print("[ForgingSystem] ===== CLIENT BOOTSTRAP STARTING =====")

local success, err = pcall(function()
    Ext.Require("Client/Framework/Bootstrap.lua")
    Ext.Require("Client/ForgingUI.lua")
end)

if success then
    Ext.Print("[ForgingSystem] Client side initialized successfully")
else
    Ext.Print("[ForgingSystem] ERROR loading client modules: " .. tostring(err))
end
