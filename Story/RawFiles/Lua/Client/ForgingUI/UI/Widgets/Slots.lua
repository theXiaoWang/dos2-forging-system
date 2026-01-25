-- Client/ForgingUI/UI/Widgets/Slots.lua
-- Slot creation and wiring helpers.

local Slots = {}

---@param options table
function Slots.Create(options)
    local opts = options or {}
    local getContext = opts.getContext
    local getUI = opts.getUI
    local vector = opts.vector or function(...) return Vector.Create(...) end
    local registerSearchBlur = opts.registerSearchBlur
    local unfocusPreviewSearch = opts.unfocusPreviewSearch
    local createFrame = opts.createFrame
    local createTextElement = opts.createTextElement
    local scale = opts.scale or function(value) return value end

    local function WireButton(button, id, requestDisplay)
        local ctx = getContext and getContext() or nil
        if not button or not ctx or not ctx.ForgingUI then
            return
        end
        ctx.ForgingUI.Buttons[id] = button
        local buttonRoot = button.Root or (button.GetRootElement and button:GetRootElement() or nil)
        if registerSearchBlur then
            registerSearchBlur(buttonRoot or button)
        end
        if button.Events and button.Events.Pressed then
            button.Events.Pressed:Subscribe(function ()
                if unfocusPreviewSearch then
                    unfocusPreviewSearch()
                end
                if requestDisplay and ctx.RequestCraftDock then
                    ctx.RequestCraftDock(id)
                elseif ctx.ForgingUI.OnForgeButtonClicked and id == "ForgeAction" then
                    ctx.ForgingUI.OnForgeButtonClicked()
                end
            end)
        end
    end

    local function WireSlot(slot, id)
        local ctx = getContext and getContext() or nil
        if not slot or not ctx then
            return
        end
        if slot.SlotElement then
            if registerSearchBlur then
                registerSearchBlur(slot.SlotElement)
            end
        end
        slot.Events.Clicked:Subscribe(function ()
            if unfocusPreviewSearch then
                unfocusPreviewSearch()
            end
            if ctx.RequestCraftDock then
                ctx.RequestCraftDock(id)
            end
        end)
        slot.Events.ObjectDraggedIn:Subscribe(function ()
            if unfocusPreviewSearch then
                unfocusPreviewSearch()
            end
            if ctx.RequestCraftDock then
                ctx.RequestCraftDock(id)
            end
        end)
    end

    local function CreateDropSlot(parent, id, x, y, size, useFancyFrame)
        local ctx = getContext and getContext() or nil
        if not parent or not ctx then
            return nil
        end

        -- Default to fancy frame for Main/Donor item slots
        if useFancyFrame == nil then
            useFancyFrame = id and (id:find("Main_ItemSlot") or id:find("Donor_ItemSlot"))
        end

        if ctx.hotbarSlotPrefab and ctx.hotbarSlotPrefab.Create then
            local baseFrameTexture = ctx.mainSlotFrameBaseTexture or ctx.mainSlotFrameTexture
            local highlightFrameTexture = ctx.mainSlotFrameHighlightTexture
            local useFancy = useFancyFrame and baseFrameTexture ~= nil
            local useCustomHover = useFancy and highlightFrameTexture ~= nil
            local framePadding = (useFancy and ctx.mainSlotFramePadding and scale(ctx.mainSlotFramePadding)) or 0
            local frameSize = size + framePadding * 2
            local frameX = x - framePadding
            local frameY = y - framePadding

            local frameBase = nil
            if useFancy then
                frameBase = parent:AddChild(id .. "_FrameBase", "GenericUI_Element_Texture")
                frameBase:SetTexture(baseFrameTexture, vector(frameSize, frameSize))
                frameBase:SetPosition(frameX, frameY)
                frameBase:SetSize(frameSize, frameSize)
                if frameBase.SetMouseEnabled then
                    frameBase:SetMouseEnabled(false)
                end
                if frameBase.SetMouseChildren then
                    frameBase:SetMouseChildren(false)
                end
            end

            local frameHighlight = nil
            if useCustomHover then
                frameHighlight = parent:AddChild(id .. "_FrameHighlight", "GenericUI_Element_Texture")
                frameHighlight:SetTexture(highlightFrameTexture, vector(frameSize, frameSize))
                frameHighlight:SetPosition(frameX, frameY)
                frameHighlight:SetSize(frameSize, frameSize)
                if frameHighlight.SetVisible then
                    frameHighlight:SetVisible(false)
                end
                if frameHighlight.SetMouseEnabled then
                    frameHighlight:SetMouseEnabled(false)
                end
                if frameHighlight.SetMouseChildren then
                    frameHighlight:SetMouseChildren(false)
                end
            end

            local ui = getUI and getUI() or nil
            local slot = ctx.hotbarSlotPrefab.Create(ui, id, parent)
            slot:SetPosition(frameX, frameY)
            slot:SetSize(frameSize, frameSize)
            slot:SetCanDrop(true)
            slot:SetEnabled(true)
            if slot.SlotElement then
                if slot.SlotElement.SetSizeOverride then
                    slot.SlotElement:SetSizeOverride(vector(frameSize, frameSize))
                end
                if slot.SlotElement.SetSize then
                    slot.SlotElement:SetSize(frameSize, frameSize)
                end
                if slot.SlotElement.SetMouseEnabled then
                    slot.SlotElement:SetMouseEnabled(true)
                end
                if slot.SlotElement.SetMouseChildren then
                    slot.SlotElement:SetMouseChildren(true)
                end
            end

            -- Hide the original slot visuals for fancy frame slots and drive hover via textures.
            if useFancy then
                local slotElement = slot.SlotElement or slot
                if slotElement and slotElement.GetMovieClip then
                    local mc = slotElement:GetMovieClip()
                    if mc then
                        if mc.frame_mc then mc.frame_mc.visible = false end
                        if mc.source_frame_mc then mc.source_frame_mc.visible = false end
                        if mc.bg_mc then mc.bg_mc.visible = false end
                        if useCustomHover and mc.highlight_mc then
                            mc.highlight_mc.visible = false
                            mc.highlight_mc.alpha = 0
                        end
                    end
                end
                if useCustomHover and slot.SlotElement and slot.SlotElement.SetHighlighted then
                    slot.SlotElement.SetHighlighted = function() end
                end
            end

            if frameHighlight and slot.SlotElement and slot.SlotElement.Events then
                local function SetHoverFrame(visible)
                    if frameHighlight.SetVisible then
                        frameHighlight:SetVisible(visible)
                    end
                end
                slot.SlotElement.Events.MouseOver:Subscribe(function()
                    SetHoverFrame(true)
                end)
                slot.SlotElement.Events.MouseOut:Subscribe(function()
                    SetHoverFrame(false)
                end)
            end
            if useFancy and framePadding > 0 then
                local parentScale = frameSize / size
                local scaleFactor = ctx.mainSlotIconScale or 1
                local iconScale = math.min(1, scaleFactor / parentScale)
                local iconScaleVector = vector(iconScale, iconScale)

                local function GetIconSize(target)
                    local iconW, iconH = 52, 52
                    if target.ICON_SIZE then
                        if target.ICON_SIZE.unpack then
                            iconW, iconH = target.ICON_SIZE:unpack()
                        else
                            iconW = target.ICON_SIZE[1] or iconW
                            iconH = target.ICON_SIZE[2] or iconH
                        end
                    end
                    return iconW, iconH
                end

                local function ApplySlotIconLayout(target)
                    local iconW, iconH = GetIconSize(target)
                    local scaledW = math.floor(iconW * scaleFactor)
                    local scaledH = math.floor(iconH * scaleFactor)
                    local iconOffsetX = (framePadding + math.floor((size - scaledW) / 2)) / parentScale
                    local iconOffsetY = (framePadding + math.floor((size - scaledH) / 2)) / parentScale
                    if target.SlotIcon then
                        if target.SlotIcon.SetScale then
                            target.SlotIcon:SetScale(iconScaleVector)
                        end
                        if target.SlotIcon.SetPosition then
                            target.SlotIcon:SetPosition(iconOffsetX, iconOffsetY)
                        end
                    end
                    if target.RarityIcon then
                        if target.RarityIcon.SetScale then
                            target.RarityIcon:SetScale(iconScaleVector)
                        end
                        if target.RarityIcon.SetPosition then
                            target.RarityIcon:SetPosition(iconOffsetX, iconOffsetY)
                        end
                    end
                    if target.RuneSlotsIcon then
                        if target.RuneSlotsIcon.SetScale then
                            target.RuneSlotsIcon:SetScale(iconScaleVector)
                        end
                        if target.RuneSlotsIcon.SetPosition then
                            target.RuneSlotsIcon:SetPosition(iconOffsetX, iconOffsetY)
                        end
                    end
                end

                ApplySlotIconLayout(slot)

                if slot.SetIcon then
                    local originalSetIcon = slot.SetIcon
                    slot.SetIcon = function(self, icon, iconSize)
                        originalSetIcon(self, icon, iconSize)
                        ApplySlotIconLayout(self)
                    end
                end
                if slot.SetRarityIcon then
                    local originalSetRarityIcon = slot.SetRarityIcon
                    slot.SetRarityIcon = function(self, rarity)
                        originalSetRarityIcon(self, rarity)
                        ApplySlotIconLayout(self)
                    end
                end
                if slot.SetItem then
                    local originalSetItem = slot.SetItem
                    slot.SetItem = function(self, item)
                        originalSetItem(self, item)
                        ApplySlotIconLayout(self)
                    end
                end
            end

            if ctx.ForgingUI and ctx.ForgingUI.Slots then
                ctx.ForgingUI.Slots[id] = slot
            end
            WireSlot(slot, id)

            return slot
        end

        local cell = parent:AddChild(id .. "_Fallback", "GenericUI_Element_Texture")
        cell:SetTexture(ctx.gridCellTexture, vector(size, size))
        cell:SetPosition(x, y)
        WireButton(cell, id, true)
        return cell
    end

    local function CreateItemSlotRow(parent, id, x, y, width, height, slotID)
        local ctx = getContext and getContext() or nil
        local frame, inner, innerWidth, innerHeight = createFrame(parent, id, x, y, width, height, ctx.FILL_COLOR, ctx.FRAME_ALPHA, scale(4))
        if inner then
            local slotSize = math.min(innerHeight - 8, 56)
            local slotY = math.floor((innerHeight - slotSize) / 2)
            CreateDropSlot(inner, slotID, 6, slotY, slotSize)
        end
        return frame, inner
    end

    local function CreateItemSlot(id, parent, x, y, width, height, title)
        local ctx = getContext and getContext() or nil
        if not ctx or not ctx.uiInstance or not parent then
            return nil
        end

        local slot, inner, innerWidth = createFrame(parent, id, x, y, width, height, ctx.FILL_COLOR, ctx.FRAME_ALPHA)

        local titleBar = inner:AddChild(id .. "_TitleBar", "GenericUI_Element_Color")
        titleBar:SetSize(innerWidth, 42)
        titleBar:SetColor(ctx.HEADER_FILL_COLOR)
        titleBar:SetPosition(0, 0)

        createTextElement(titleBar, id .. "_Title", title, 0, 0, innerWidth, 42, "Center")

        local hotbarSlot = nil
        if ctx.hotbarSlotPrefab and ctx.hotbarSlotPrefab.Create then
            hotbarSlot = ctx.hotbarSlotPrefab.Create(ctx.uiInstance, id .. "_Slot", inner)
            hotbarSlot:SetPosition(16, 45)
            hotbarSlot:SetSize(67, 67)
            hotbarSlot:SetCanDrop(true)
            hotbarSlot:SetEnabled(true)
            if ctx.ForgingUI and ctx.ForgingUI.Slots then
                ctx.ForgingUI.Slots[id] = hotbarSlot
            end
        else
            local icon = inner:AddChild(id .. "_Icon", "GenericUI_Element_Color")
            icon:SetSize(67, 67)
            icon:SetColor(ctx.HEADER_FILL_COLOR)
            icon:SetPosition(16, 45)
        end

        return hotbarSlot or slot
    end

    return {
        WireButton = WireButton,
        WireSlot = WireSlot,
        CreateDropSlot = CreateDropSlot,
        CreateItemSlotRow = CreateItemSlotRow,
        CreateItemSlot = CreateItemSlot,
    }
end

return Slots
