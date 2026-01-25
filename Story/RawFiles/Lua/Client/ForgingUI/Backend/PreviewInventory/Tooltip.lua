-- Client/ForgingUI/Backend/PreviewInventory/Tooltip.lua
-- Tooltip helpers for preview inventory slots.

local Tooltip = {}

---@param getMonotonicTime function
---@param getPreviewSlotItem function
---@param throttleMs number
function Tooltip.Create(getMonotonicTime, getPreviewSlotItem, throttleMs)
    local function GetInventoryTooltipUI()
        if Ext and Ext.UI and Ext.UI.GetByType and Ext.UI.TypeID and Ext.UI.TypeID.containerInventory then
            local ui = Ext.UI.GetByType(Ext.UI.TypeID.containerInventory.Pickpocket)
            if not ui then
                ui = Ext.UI.GetByType(Ext.UI.TypeID.containerInventory.Default)
            end
            return ui
        end
        return nil
    end

    local function ShowItemTooltipWithFallback(item)
        if not item then
            return false
        end
        if Client and Client.Tooltip and Client.Tooltip.ShowItemTooltip then
            pcall(Client.Tooltip.ShowItemTooltip, item)
        end
        local ui = GetInventoryTooltipUI()
        if not ui or not ui.ExternalInterfaceCall then
            return false
        end
        local handle = item.Handle or item.ItemHandle
        if not handle or not Client or not Client.GetMousePosition or not Ext or not Ext.UI or not Ext.UI.HandleToDouble then
            return false
        end
        local mouseX, mouseY = Client.GetMousePosition()
        local ok = pcall(ui.ExternalInterfaceCall, ui, "showItemTooltip", Ext.UI.HandleToDouble(handle), mouseX, mouseY, 100, 100, -1, "left")
        return ok == true
    end

    local function HideItemTooltipWithFallback()
        local hidden = false
        if Client and Client.Tooltip and Client.Tooltip.HideTooltip then
            hidden = pcall(Client.Tooltip.HideTooltip) == true or hidden
        end
        local ui = GetInventoryTooltipUI()
        if ui and ui.ExternalInterfaceCall then
            pcall(ui.ExternalInterfaceCall, ui, "hideTooltip")
            hidden = true
        end
        return hidden
    end

    local function ShowPreviewSlotTooltip(slot)
        if not slot then
            return
        end
        local item = getPreviewSlotItem and getPreviewSlotItem(slot) or nil
        if not item then
            return
        end
        local handle = item.Handle or item.ItemHandle
        if slot._PreviewTooltipVisible and slot._PreviewTooltipHandle == handle then
            return
        end
        local now = getMonotonicTime and getMonotonicTime() or nil
        if now and slot._PreviewTooltipLastTime and (now - slot._PreviewTooltipLastTime) < throttleMs then
            return
        end
        slot._PreviewTooltipLastTime = now or slot._PreviewTooltipLastTime
        local shown = ShowItemTooltipWithFallback(item)
        slot._PreviewTooltipHandle = shown and handle or slot._PreviewTooltipHandle
        slot._PreviewTooltipVisible = shown == true
    end

    local function HidePreviewSlotTooltip(slot)
        if not slot then
            return
        end
        HideItemTooltipWithFallback()
        slot._PreviewTooltipHandle = nil
        slot._PreviewTooltipVisible = false
    end

    return {
        ShowPreviewSlotTooltip = ShowPreviewSlotTooltip,
        HidePreviewSlotTooltip = HidePreviewSlotTooltip,
    }
end

return Tooltip
