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
            -- For fancy frame slots, create the frame background first
            -- Frame is larger than slot to contain the hover highlight
            local frameBackground = nil
            local framePadding = 12  -- Extra padding to contain highlight
            if useFancyFrame and ctx.mainSlotFrameTexture then
                local frameSize = size + framePadding * 2
                local frameX = x - framePadding
                local frameY = y - framePadding
                frameBackground = parent:AddChild(id .. "_FancyFrame", "GenericUI_Element_Texture")
                frameBackground:SetTexture(ctx.mainSlotFrameTexture, vector(frameSize, frameSize))
                frameBackground:SetPosition(frameX, frameY)
                frameBackground:SetSize(frameSize, frameSize)
                if frameBackground.SetMouseEnabled then
                    frameBackground:SetMouseEnabled(false)
                end
            end

            local ui = getUI and getUI() or nil
            local slot = ctx.hotbarSlotPrefab.Create(ui, id, parent)
            slot:SetPosition(x, y)
            slot:SetSize(size, size)
            slot:SetCanDrop(true)
            slot:SetEnabled(true)
            if slot.SlotElement then
                if slot.SlotElement.SetMouseEnabled then
                    slot.SlotElement:SetMouseEnabled(true)
                end
                if slot.SlotElement.SetMouseChildren then
                    slot.SlotElement:SetMouseChildren(true)
                end
            end

            -- Hide the original slot's frame elements and center the highlight for fancy frame slots
            if useFancyFrame and ctx.mainSlotFrameTexture then
                local slotElement = slot.SlotElement or slot
                if slotElement and slotElement.GetMovieClip then
                    local mc = slotElement:GetMovieClip()
                    if mc then
                        -- Hide internal frame elements
                        if mc.frame_mc then mc.frame_mc.visible = false end
                        if mc.source_frame_mc then mc.source_frame_mc.visible = false end
                        if mc.bg_mc then mc.bg_mc.visible = false end
                        -- Center and resize the highlight
                        if mc.highlight_mc then
                            -- Adjust x and y to center the highlight
                            mc.highlight_mc.x = (mc.highlight_mc.x or 0) -2
                            mc.highlight_mc.y = (mc.highlight_mc.y or 0) -2
                            -- Adjust width and height to resize the highlight
                            mc.highlight_mc.width = size + 1  -- Match frame size (size + framePadding*2)
                            mc.highlight_mc.height = size + 1
                        end
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
