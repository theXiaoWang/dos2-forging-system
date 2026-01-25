-- Client/ForgingUI/Inventory.lua
-- Backwards-compatible wrapper. Implementation moved to `Backend/InventoryService.lua`.

local ForgingUI = Client.ForgingUI or {}
Client.ForgingUI = ForgingUI

local Inventory = Ext.Require("Client/ForgingUI/Backend/InventoryService.lua")
ForgingUI.Inventory = Inventory

return Inventory

