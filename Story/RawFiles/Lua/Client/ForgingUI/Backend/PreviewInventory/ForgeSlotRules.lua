-- Client/ForgingUI/Backend/PreviewInventory/ForgeSlotRules.lua
-- Forge slot ID classification helpers.

local ForgeSlotRules = {}

---@param state table
function ForgeSlotRules.Create(state)
    local function IsEquipmentSlotId(slotId)
        local key = tostring(slotId or ""):lower()
        if key == "" then
            return false
        end
        if key:find("skillbook", 1, true) ~= nil then
            return false
        end
        return key:find("itemslot", 1, true) ~= nil
    end

    local function IsSkillbookSlotId(slotId)
        local key = tostring(slotId or ""):lower()
        if key == "" then
            return false
        end
        return key:find("skillbook", 1, true) ~= nil
    end

    local function ResolveForgeSlotMode(slotId)
        if IsSkillbookSlotId(slotId) then
            return "Skillbook"
        end
        if IsEquipmentSlotId(slotId) then
            return "Equipment"
        end
        if state and state.ForgeSlots and slotId and state.ForgeSlots[slotId] then
            return "Equipment"
        end
        return nil
    end

    return {
        IsEquipmentSlotId = IsEquipmentSlotId,
        IsSkillbookSlotId = IsSkillbookSlotId,
        ResolveForgeSlotMode = ResolveForgeSlotMode,
    }
end

return ForgeSlotRules
