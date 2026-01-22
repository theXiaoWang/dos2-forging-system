-- Client/Framework/Textures.lua
-- Loads the internal Generic UI texture registry for this mod.

Client = Client or {}
Client.Textures = Client.Textures or {}

Ext.Require("Epip/GenericUITextures/Client.lua")

if not Client.Textures.GenericUI then
    Ext.Print("[ForgingSystem] Generic UI textures failed to initialize.")
end

return Client.Textures.GenericUI
