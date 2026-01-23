
---@class GameStateLib
local GameState = GameState

---------------------------------------------
-- METHODS
---------------------------------------------

---@return boolean
function GameState.IsPaused()
    return Ext.Client.GetGameState() == GameState.CLIENT_STATES.PAUSED
end

---@return GameState
function GameState.GetState()
    return Ext.Client.GetGameState()
end

---Fires the ClientReady event.
---@param fromReset boolean?
function GameState._ThrowClientReadyEvent(fromReset)
    ---@type GameStateLib_Event_ClientReady
    local character = Client.GetCharacter()
    if not character then
        return
    end
    local event = {
        CharacterNetID = character.NetID,
        ProfileGUID = Client.GetProfileGUID(),
        FromReset = fromReset or false,
    }

    GameState.Events.ClientReady:Throw(event)
    if Net and Net.PostToServer then
        Net.PostToServer("EPIPENCOUNTERS_GameStateLib_ClientReady", event)
    end
end

---------------------------------------------
-- EVENT LISTENERS
---------------------------------------------

-- Re-throw ClientReady after a reset.
GameState.Events.LuaResetted:Subscribe(function (_)
    GameState._ThrowClientReadyEvent(true)
end)
