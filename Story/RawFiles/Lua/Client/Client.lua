-- Client/Client.lua
-- Minimal client helper functions required by migrated Epip UI prefabs.

Client = Client or {UI = {GM = {}, Controller = {}}}

Client.IS_HOST = Client.IS_HOST or false

Client.USE_LEGACY_EVENTS = false
Client.USE_LEGACY_HOOKS = false
Client.Events = Client.Events or {}
Client.Events.ViewportChanged = Client.Events.ViewportChanged or {}

local function GetPlayerData(playerIndex)
    local playerManager = Ext.Entity.GetPlayerManager()
    if not playerManager or not playerManager.ClientPlayerData then
        return nil
    end
    local data = playerManager.ClientPlayerData[playerIndex]
    if not data then
        data = playerManager.ClientPlayerData[0]
    end
    if not data then
        for _, entry in pairs(playerManager.ClientPlayerData) do
            data = entry
            break
        end
    end
    return data
end

local function GetCharacterFromNetID(netID)
    if not netID then
        return nil
    end
    if Character and Character.Get then
        return Character.Get(netID)
    end
    if Ext.Entity and Ext.Entity.GetCharacter then
        return Ext.Entity.GetCharacter(netID)
    end
    return nil
end

---Returns the currently-controlled character on the client.
---@param playerIndex integer? Defaults to 1.
---@return EclCharacter?
function Client.GetCharacter(playerIndex)
    playerIndex = playerIndex or 1
    local data = GetPlayerData(playerIndex)
    if not data then
        return nil
    end
    local netID = data.CharacterNetId or data.CharacterNetID
    return GetCharacterFromNetID(netID)
end

---Returns the profile GUID of a player.
---@param playerIndex integer? Defaults to 1.
---@return GUID?
function Client.GetProfileGUID(playerIndex)
    playerIndex = playerIndex or 1
    local data = GetPlayerData(playerIndex)
    return data and data.ProfileGuid or nil
end

---Returns the local character NetID for the specified player.
---@param playerIndex integer? Defaults to 1.
---@return NetId?
function Client.GetLocalCharacterID(playerIndex)
    playerIndex = playerIndex or 1
    local data = GetPlayerData(playerIndex)
    return data and (data.CharacterNetId or data.CharacterNetID) or nil
end

---Returns the character with the given NetID.
---@param netID NetId
---@return EclCharacter?
function Client.GetCharacterByID(netID)
    return GetCharacterFromNetID(netID)
end

---Returns the mouse position in Flash coordinates.
---@return integer, integer
function Client.GetMousePosition()
    return table.unpack(Ext.UI.GetMouseFlashPos())
end

---Returns the current viewport size.
---@return Vector2|table
function Client.GetViewportSize()
    local size = Ext.UI.GetViewportSize()
    if Vector and Vector.Create then
        return Vector.Create(size)
    end
    return size
end

---Returns the global UI scale preference.
---@return number
function Client.GetGlobalUIScale()
    local switches = Ext.Utils.GetGlobalSwitches()
    return switches and switches.UIScaling or 1
end

---Returns whether the client is the session host.
---@return boolean
function Client.IsHost()
    return Client.IS_HOST or false
end

---Returns whether the client character is in dialogue.
---@return boolean
function Client.IsInDialogue()
    local char = Client.GetCharacter()
    return char and char.InDialog or false
end

---Returns whether the client is using a controller.
---@return boolean
function Client.IsUsingController()
    return Ext.UI.GetByPath("Public/Game/GUI/msgBox_c.swf") ~= nil
end

---Returns whether the client is using keyboard and mouse.
---@return boolean
function Client.IsUsingKeyboardAndMouse()
    return not Client.IsUsingController()
end

---Returns whether the client character is in combat.
---@return boolean
function Client.IsInCombat()
    local char = Client.GetCharacter()
    return char and char.InCombat or false
end

---Returns whether the client character is the active combatant.
---@return boolean
function Client.IsActiveCombatant()
    local char = Client.GetCharacter()
    if not char or not char.InCombat then
        return false
    end
    if Combat and Combat.GetActiveCombatant and Character and Character.GetCombatID then
        local combatID = Character.GetCombatID(char)
        local active = Combat.GetActiveCombatant(combatID)
        return active and active == char or false
    end
    return true
end

---Attempts to prepare a skill via the hotbar when available.
---@param char EclCharacter
---@param skillID string
function Client.PrepareSkill(char, skillID)
    if Client.UI and Client.UI.Hotbar and Client.UI.Hotbar.UseSkill then
        Client.UI.Hotbar.UseSkill(skillID)
    end
end

if Epip and Epip.InitializeLibrary then
    Epip.InitializeLibrary("Client", Client)
end
