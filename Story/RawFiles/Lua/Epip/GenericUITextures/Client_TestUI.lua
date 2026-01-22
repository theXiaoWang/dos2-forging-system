
---------------------------------------------
-- Implements a UI that displays registered Generic textures,
-- useful for previewing them.
---------------------------------------------

local DefaultTable = DataStructures.Get("DataStructures_DefaultTable")
local Generic = Client.UI.Generic
local Button = Generic.GetPrefab("GenericUI_Prefab_Button")
local TextPrefab = Generic.GetPrefab("GenericUI_Prefab_Text")
local SlicedTexture = Generic.GetPrefab("GenericUI.Prefabs.SlicedTexture")
local V = Vector.Create

---@class Feature_GenericUITextures
local GenericUITextures = Epip.GetFeature("Feature_GenericUITextures")
local Textures = GenericUITextures.TEXTURES

local UI = Generic.Create("ForgingSystem_StyleTest")
GenericUITextures.TestUI = UI

UI.CONTAINER_OFFSET = V(100, 150)
UI.SCROLLLIST_FRAME_SIZE = V(680, 800)
UI.IGGY_ICON_SIZE = V(40, 40)
UI.SLICED_TEXTURE_SIZE = V(200, 100)
UI.ICON_INDEX_LABEL_SIZE = V(28, 14)
UI.ASSET_INDEX_FONT_SIZE = 14
UI.PANEL_INDEX_FONT_SIZE = 48
UI._currentPanelIndex = 1

local function GetElementLabelSize(element)
    local size = element:GetSize()
    if size[1] <= 0 or size[2] <= 0 then
        size = element:GetRawSize()
    end
    return size
end

local function CreateCenteredIndexLabel(parent, id, index, size, fontSize)
    local label = TextPrefab.Create(UI, id, parent, Text.Format(tostring(index), {
        Size = fontSize or UI.ASSET_INDEX_FONT_SIZE,
        Color = Color.WHITE,
    }), "Center", size)
    label:SetStroke(Color.BLACK, 1, 1, 6, 6)
    label:SetPosition(0, 0)
    return label
end

---------------------------------------------
-- SETTINGS, ACTIONS AND RESOURCES
---------------------------------------------

GenericUITextures.TranslatedStrings.Action_UI_Open_Name = GenericUITextures:RegisterTranslatedString("h8db61443g39bfg45f1g8c0cga6ab56bb12b7", {
    Text = "Open Generic UI Texture Test UI",
    ContextDescription = "Debug keybind",
})

GenericUITextures.InputActions.OpenTestUI = GenericUITextures:RegisterInputAction("OpenTestUI", {
    Name = GenericUITextures.TranslatedStrings.Action_UI_Open_Name:GetString(),
    DefaultInput1 = {Keys = {"lctrl", "l"}},
    DeveloperOnly = true,
})

---------------------------------------------
-- METHODS
---------------------------------------------

---@override
function UI:Show()
    UI._Initialize()
    Client.UI._BaseUITable.Show(self)
end

---Initializes the elements of the UI.
function UI._Initialize()
    if UI._Initialized then return end
    local buttonStyle = Button.STYLES.SmallRed
    local bg = UI:CreateElement("Root", "GenericUI_Element_Texture")
    UI._BuildPanelList()
    UI._currentPanelIndex = UI._GetPanelIndex("CLIPBOARD_LARGE") or 1
    bg:SetTexture(UI._panelTextures[UI._currentPanelIndex])

    local header = TextPrefab.Create(UI, "Header", bg, Text.Format("Texture Test UI", {Color = Color.BLACK}), "Center", V(bg:GetWidth(), 50))
    header:SetPositionRelativeToParent("Top", 0, 70)

    local buttonList = bg:AddChild("RootButtonList", "GenericUI_Element_HorizontalList")
    buttonList:SetPositionRelativeToParent("TopLeft", 100, 100)

    UI.Background = bg
    UI.PanelIndexLabel = CreateCenteredIndexLabel(bg, "PanelIndexLabel", UI._currentPanelIndex, V(220, 90), UI.PANEL_INDEX_FONT_SIZE)
    UI.PanelIndexLabel:SetPositionRelativeToParent("TopRight", -120, 70)

    UI._SetupButtonList()
    UI._SetupFrameList()
    UI._SetupInputIconList()
    UI._SetupIconList()
    UI._SetupSlicedTextureList()

    ---@type {Element:GenericUI_Element, Name:string}[]
    local buttons = {
        {
            Element = UI.ButtonList,
            Name = "Buttons",
        },
        {
            Element = UI.FrameList,
            Name = "Frames",
        },
        {
            Element = UI.InputIconsList,
            Name = "Input Icons",
        },
        {
            Element = UI.IconList,
            Name = "Icons",
        },
        {
            Element = UI.SlicedTexturesList,
            Name = "Sliced",
        },
    }

    for _,buttonData in ipairs(buttons) do
        local button = Button.Create(UI, "RootButton_" .. buttonData.Name, buttonList, buttonStyle)

        button:SetLabel(buttonData.Name, "Center")

        -- Toggle off previous container(s) and show new one when pressed
        button.Events.Pressed:Subscribe(function (_)
            for _,bData in ipairs(buttons) do
                bData.Element:SetVisible(false)
            end
            buttonData.Element:SetVisible(true)
        end)
    end

    -- Add button to cycle panels
    local panelButton = Button.Create(UI, "RootButton_Panel", buttonList, buttonStyle)
    panelButton:SetLabel("Panel")
    panelButton.Events.Pressed:Subscribe(function (_)
        if not UI._panelTextures then
            UI._BuildPanelList()
        end
        UI._currentPanelIndex = UI._currentPanelIndex + 1
        if UI._currentPanelIndex > #UI._panelTextures then
            UI._currentPanelIndex = 1
        end

        bg:SetTexture(UI._panelTextures[UI._currentPanelIndex])
        UI._UpdatePanelIndexLabel()
        -- Show panel name and copy to clipboard
        local panelName = UI._panelNames[UI._currentPanelIndex]
        Ext.Print(string.format("[GenericUITextures] Panel %d: %s", UI._currentPanelIndex, tostring(panelName)))
        Client.CopyToClipboard(panelName)
    end)

    UI:SetIggyEventCapture("UICancel", true)

    -- Close the UI through IggyEvents
    UI.Events.IggyEventUpCaptured:Subscribe(function (ev)
        if ev.EventID == "UICancel" then
            UI:SetIggyEventCapture("UICancel", false)
            UI:Hide()
        end
    end)
    UI._Initialized = true
end

function UI._BuildPanelList()
    local panelNames = {}
    for name in pairs(Textures.PANELS) do
        table.insert(panelNames, name)
    end
    table.sort(panelNames)

    UI._panelNames = panelNames
    UI._panelTextures = {}
    for _,name in ipairs(panelNames) do
        table.insert(UI._panelTextures, Textures.PANELS[name])
    end
end

function UI._GetPanelIndex(name)
    if not UI._panelNames then
        UI._BuildPanelList()
    end

    for i,panelName in ipairs(UI._panelNames) do
        if panelName == name then
            return i
        end
    end

    return nil
end

function UI._UpdatePanelIndexLabel()
    if UI.PanelIndexLabel then
        UI.PanelIndexLabel:SetText(Text.Format(tostring(UI._currentPanelIndex), {
            Size = UI.PANEL_INDEX_FONT_SIZE,
            Color = Color.WHITE,
        }))
    end
end

local function NormalizeIndexCategory(category)
    if not category then
        return nil
    end

    local key = string.lower(category)
    local map = {
        panel = "panels",
        panels = "panels",
        frame = "frames",
        frames = "frames",
        input = "input",
        inputs = "input",
        inputicon = "input",
        inputicons = "input",
        icon = "icons",
        icons = "icons",
        sliced = "sliced",
        slice = "sliced",
        button = "buttons",
        buttons = "buttons",
    }

    return map[key]
end

function UI._GetPanelByIndex(index)
    UI._BuildPanelList()
    local name = UI._panelNames and UI._panelNames[index] or nil
    return name, name and UI._panelTextures[index] or nil
end

function UI._GetFrameByIndex(index)
    local textures = UI._FindTexturesRecursively(Textures.FRAMES)
    table.sort(textures, function(a, b)
        return tostring(a.Name) < tostring(b.Name)
    end)
    local texture = textures[index]
    return texture and texture.Name or nil, texture
end

function UI._GetInputByIndex(index)
    local textures = UI._FindTexturesRecursively(Textures.INPUT)
    table.sort(textures, function(a, b)
        return tostring(a.Name) < tostring(b.Name)
    end)
    local texture = textures[index]
    return texture and texture.Name or nil, texture
end

function UI._GetIconByIndex(index)
    local icons = UI._FindIconsRecursively(GenericUITextures.ICONS)
    table.sort(icons, function(a, b)
        return tostring(a) < tostring(b)
    end)
    local icon = icons[index]
    return icon, icon
end

function UI._GetSlicedByIndex(index)
    local styles = {}
    for id,style in pairs(SlicedTexture:GetStyles()) do
        table.insert(styles, {ID = id, Style = style})
    end
    table.sort(styles, function(a, b)
        return a.ID < b.ID
    end)
    local style = styles[index]
    return style and style.ID or nil, style
end

function UI._GetButtonByIndex(index)
    local styles = {}
    for id,style in pairs(Button:GetStyles()) do
        local activeStyleMatch = id:match("(.+)_Active$")
        local inactiveStyleMatch = id:match("(.+)_Inactive$")
        style.___ID = id

        if not activeStyleMatch and not inactiveStyleMatch then
            table.insert(styles, style)
        end
    end
    table.sortByProperty(styles, "___ID")
    local style = styles[index]
    return style and style.___ID or nil, style
end

function UI._SetupFrameList()
    local frameList = UI._SetupScrollList("FrameList")

    local frameTextures = UI._FindTexturesRecursively(Textures.FRAMES)
    table.sort(frameTextures, function(a, b)
        return tostring(a.Name) < tostring(b.Name)
    end)
    UI._RenderTextures(frameList, frameTextures, "FrameIndex_")

    UI.FrameList = frameList
    frameList:RepositionElements()
    frameList:SetVisible(false)
end

---Creates the list of input icons.
function UI._SetupInputIconList()
    local list = UI._SetupScrollList("InputIconsList")
    local textures = UI._FindTexturesRecursively(Textures.INPUT)
    table.sort(textures, function(a, b)
        return tostring(a.Name) < tostring(b.Name)
    end)
    UI._RenderTextures(list, textures, "InputIconIndex_")
    UI.InputIconsList = list
end

---Creates the list of buttons.
function UI._SetupButtonList()
    local list = UI._SetupScrollList("ButtonList")
    local stateButtonStyles = DefaultTable.Create({}) ---@type table<string, {InactiveStyle: GenericUI_Prefab_Button_Style, ActiveStyle: GenericUI_Prefab_Button_Style}>

    local styles = {} ---@type GenericUI_I_Stylable_Style[]
    for id,style in pairs(Button:GetStyles()) do
        ---@cast style GenericUI_Prefab_Button_Style
        local activeStyleMatch = id:match("(.+)_Active$")
        local inactiveStyleMatch = id:match("(.+)_Inactive$")
        style.___ID = id

        if activeStyleMatch then
            stateButtonStyles[activeStyleMatch].ActiveStyle = style
        elseif inactiveStyleMatch then
            stateButtonStyles[inactiveStyleMatch].InactiveStyle = style
        else
            table.insert(styles, style)
        end
    end

    table.sortByProperty(styles, "___ID")

    for i,style in ipairs(styles) do
        ---@diagnostic disable: undefined-field
        local button = Button.Create(UI, style.___ID, list, style)
 
        -- Keep indices centered inside each button, like the original UI.
        button:SetLabel(tostring(i))
        button.Events.Pressed:Subscribe(function (_)
            print(style.___ID)
            Client.CopyToClipboard(style.___ID)
        end)
        ---@diagnostic enable: undefined-field
    end
    for id,styleSet in pairs(stateButtonStyles) do
        local button = Button.Create(UI, id, list, styleSet.InactiveStyle)

        button:SetActiveStyle(styleSet.ActiveStyle)
        button:SetLabel("")
    end

    UI.ButtonList = list
    list:RepositionElements()
    list:SetVisible(false)
end

---Creates the grid of IggyIcons.
function UI._SetupIconList()
    local bg = UI.Background
    local iconList = bg:AddChild("IconList", "GenericUI_Element_Grid")
    iconList:SetGridSize(10, -1)
    iconList:SetPositionRelativeToParent("TopLeft", UI.CONTAINER_OFFSET:unpack())

    local icons = UI._FindIconsRecursively(GenericUITextures.ICONS)
    table.sort(icons, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for index,icon in ipairs(icons) do
        local element = iconList:AddChild(icon, "GenericUI_Element_IggyIcon")
        element:SetIcon(icon, UI.IGGY_ICON_SIZE:unpack())
        element.Events.MouseUp:Subscribe(function (_)
            Client.CopyToClipboard(icon)
        end)
        CreateCenteredIndexLabel(element, "IconIndex_" .. tostring(index), index, UI.IGGY_ICON_SIZE)
    end

    UI.IconList = iconList
    iconList:RepositionElements()
    iconList:SetVisible(false)
end

---Creates the list of sliced textures.
function UI._SetupSlicedTextureList()
    local list = UI._SetupScrollList("SlicedTextures")

    local styles = {}
    for id,style in pairs(SlicedTexture:GetStyles()) do
        table.insert(styles, {
            ID = id,
            Style = style,
        })
    end
    table.sort(styles, function(a, b)
        return a.ID < b.ID
    end)

    for index,styleData in ipairs(styles) do
        ---@cast styleData.Style GenericUI.Prefabs.SlicedTexture.Style
        local instance = SlicedTexture.Create(UI, styleData.ID, list, styleData.Style, UI.SLICED_TEXTURE_SIZE)

        instance.Events.MouseUp:Subscribe(function (_)
            print(styleData.ID)
            Client.CopyToClipboard(styleData.ID)
        end)

        CreateCenteredIndexLabel(instance.Root, "SlicedIndex_" .. tostring(index), index, UI.SLICED_TEXTURE_SIZE)
    end

    UI.SlicedTexturesList = list
    list:RepositionElements()
end

---Initializes a scroll list.
---@param id string
---@return GenericUI_Element_ScrollList
function UI._SetupScrollList(id)
    local bg = UI.Background
    local list = bg:AddChild(id, "GenericUI_Element_ScrollList")
    list:SetFrame(UI.SCROLLLIST_FRAME_SIZE:unpack())
    list:SetMouseWheelEnabled(true)

    list:SetPositionRelativeToParent("TopLeft", UI.CONTAINER_OFFSET:unpack())
    list:SetVisible(false)

    return list
end

---Renders textures onto a list.
---@param list GenericUI_ContainerElement
---@param textures TextureLib_Texture[]
---@param labelPrefix string?
---@param fontSize number?
function UI._RenderTextures(list, textures, labelPrefix, fontSize)
    for index,texture in ipairs(textures) do
        local element = list:AddChild(texture.GUID, "GenericUI_Element_Texture")
        element:SetTexture(texture)

        -- Show texture name and GUID on click and copy to clipboard
        element.Events.MouseUp:Subscribe(function (_)
            print(texture.Name, texture.GUID)
            Client.CopyToClipboard(texture.Name)
        end)

        if labelPrefix then
            local labelSize = GetElementLabelSize(element)
            CreateCenteredIndexLabel(element, labelPrefix .. tostring(index), index, labelSize, fontSize)
        end
    end
end

---Returns a list of textures found recursively within a table.
---@param tbl table<string, table|TextureLib_Texture>
---@return TextureLib_Texture[]
function UI._FindTexturesRecursively(tbl)
    local textures = {}

    for _,frame in pairs(tbl) do
        if frame.GUID then
            table.insert(textures, frame)
        else
            textures = table.join(textures, UI._FindTexturesRecursively(frame))
        end
    end

    return textures
end

---Returns a list of Iggy icons found recursively within a table.
---@param tbl table<string, table|TextureLib_Texture>
---@return icon[]
function UI._FindIconsRecursively(tbl)
    local icons = {} ---@type icon[]
    for _,v in pairs(tbl) do
        if type(v) == "table" then
            icons = table.join(icons, UI._FindIconsRecursively(v))
        else
            table.insert(icons, v)
        end
    end
    return icons
end

---------------------------------------------
-- EVENT LISTENERS
---------------------------------------------

-- Open the UI through a console command.
Ext.RegisterConsoleCommand("genericstyles", function (_, _)
    UI:Show()
end)

Ext.RegisterConsoleCommand("guitexturepanel", function (_, index)
    local idx = tonumber(index)
    if not idx then
        Ext.Print("[GenericUITextures] Usage: !guitexturepanel <index>")
        return
    end

    UI._BuildPanelList()
    local panelName = UI._panelNames and UI._panelNames[idx] or nil
    if not panelName then
        Ext.Print(string.format("[GenericUITextures] No panel at index %d", idx))
        return
    end

    Ext.Print(string.format("[GenericUITextures] Panel %d: %s", idx, panelName))
    Client.CopyToClipboard(panelName)
end)

Ext.RegisterConsoleCommand("gui", function (_, category, index)
    local idx = tonumber(index)
    local normalized = NormalizeIndexCategory(category)
    if not idx or not normalized then
        Ext.Print("[GenericUITextures] Usage: !gui <panels|frames|input|icons|sliced|buttons> <index>")
        return
    end

    local name = nil
    if normalized == "panels" then
        name = UI._GetPanelByIndex(idx)
    elseif normalized == "frames" then
        name = UI._GetFrameByIndex(idx)
    elseif normalized == "input" then
        name = UI._GetInputByIndex(idx)
    elseif normalized == "icons" then
        name = UI._GetIconByIndex(idx)
    elseif normalized == "sliced" then
        name = UI._GetSlicedByIndex(idx)
    elseif normalized == "buttons" then
        name = UI._GetButtonByIndex(idx)
    end

    if not name then
        Ext.Print(string.format("[GenericUITextures] No %s entry at index %d", normalized, idx))
        return
    end

    Ext.Print(string.format("[GenericUITextures] %s %d: %s", normalized, idx, tostring(name)))
    Client.CopyToClipboard(name)
end)

-- Open the UI through the Input action.
Client.Input.Events.ActionExecuted:Subscribe(function (ev)
    if ev.Action == GenericUITextures.InputActions.OpenTestUI then
        UI:Show()
    end
end)
