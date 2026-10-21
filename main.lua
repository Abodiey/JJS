--[[
    Catstar Pro
]]--
while not game.GameId or game.GameId == 0 do task.wait() end
if game.GameId ~= 3508322461 then return end
print("Catstar Running")

if not Drawing or type(Drawing.new) ~= "function" then
    warn("Catstar needs Drawing support")
    return
end
local Previous = getgenv().CatstarMenu
if Previous and not Previous.Destroyed then
    Previous:SetVisible(true)
    return
end

getgenv().cloneref = cloneref or function(O) return O end
local cloneref = cloneref
local CoreGui = cloneref(game:GetService("CoreGui"))
local Players = cloneref(game:GetService("Players"))

local BaseUrl = "https://raw.githubusercontent.com/Abodiey/JJS/refs/heads/main/"

local SettingsFolder = CoreGui:FindFirstChild("CatstarSettings")
if SettingsFolder then SettingsFolder:Destroy() end

SettingsFolder = Instance.new("Folder")
SettingsFolder.Name = "CatstarSettings"
SettingsFolder.Parent = CoreGui

local TogglesFolder = Instance.new("Folder")
TogglesFolder.Name = "Toggles"
TogglesFolder.Parent = SettingsFolder

local VariablesFolder = Instance.new("Folder")
VariablesFolder.Name = "Variables"
VariablesFolder.Parent = SettingsFolder

local Config
local Ranges = {M1JumpDelay = {0, 1}, SpeedMultiplier = {1, 50}, Reach = {1, 15}}

local function SettingValue(Group, Key, Default, Saved)
    if type(Saved) == type(Default) and (type(Saved) ~= "number" or
        (Saved == Saved and math.abs(Saved) < math.huge)) then Default = Saved end
    local Range = Group == "Variables" and Ranges[Key]
    if Range then Default = math.clamp(Default, Range[1], Range[2]) end
    if Key == "AimbotKey" then
        local Valid, Code = pcall(function() return Enum.KeyCode[Default] end)
        if Default ~= "None" and (not Valid or not Code or Default == "Unknown" or Default == "Escape" or Default == "K") then Default = "C" end
    end
    return Default
end

local function BindToFolder(folderInstance, valueClassMapping, defaultValues)
    local cache = {}
    return setmetatable(cache, {
        __index = function(_, key)
            local existing = folderInstance:FindFirstChild(key)
            if existing then return existing end

            local default = defaultValues[key]
            if folderInstance == TogglesFolder then default = false end
            local className = key == "LockedTarget" and "ObjectValue" or valueClassMapping[type(default)] or "StringValue"
            local group = folderInstance == TogglesFolder and "Toggles" or "Variables"
            local persistent = key ~= "LockedTarget" and key ~= "Aim"
            default = SettingValue(group, key, default, persistent and Config and Config.Data[group][key])
            local valObj = Instance.new(className)
            valObj.Name = key
            valObj.Value = default
            valObj.Parent = folderInstance
            if Config and persistent then
                valObj.Changed:Connect(function() Config:Set(group, key, valObj.Value) end)
            end
            return valObj
        end
    })
end

local VariableDefaults = {
    M1JumpDelay = 0.35,
    SecondEmotes = "",
    SpeedMultiplier = 15,
    Reach = 15,
    LockedTarget = nil,
    AimbotKey = "C",
    NotifyJoinScope = "Everyone",
    NotifyLeaveScope = "Everyone",
    NotifyDeathScope = "Friends + Group",
}

local ClassMap = {
    ["boolean"] = "BoolValue",
    ["number"] = "NumberValue",
    ["string"] = "StringValue",
}

local CatstarState = {
    RouletteCharacters = {},
    Connections = setmetatable({}, { __mode = "v" }),
    Toggles = BindToFolder(TogglesFolder, ClassMap, {}),
    Variables = BindToFolder(VariablesFolder, ClassMap, VariableDefaults),
}

getgenv().CatstarState = CatstarState

local function Load(Name)
    local Url = BaseUrl .. Name .. ".lua"
    local MaxRetries = 5
    local DelayTime = 1 + math.random()
    local Response = nil

    for Attempt = 1, MaxRetries do
        local ReqSuccess, ReqResponse = pcall(function()
            return request({
                Url = Url,
                Method = "GET"
            })
        end)

        if ReqSuccess and type(ReqResponse) == "table" and ReqResponse.StatusCode == 200 then
            Response = ReqResponse
            break
        end

        local ErrorMsg = not ReqSuccess and tostring(ReqResponse) or (ReqResponse and "Status " .. tostring(ReqResponse.StatusCode) or "Unknown error")
        warn(string.format("Attempt %d/%d failed for %s: %s", Attempt, MaxRetries, Name, ErrorMsg))

        if Attempt < MaxRetries then
            task.wait(DelayTime)
            DelayTime = DelayTime * 2 -- Exponential backoff (1s, 2s, 4s...)
        end
    end

    if not Response then
        warn("Failed to fetch " .. Name .. " after max retries.")
        return nil 
    end

    local Chunk, CompileError = loadstring(Response.Body, "=" .. Name)
    if CompileError then 
        warn("Syntax error in " .. Name .. ": " .. CompileError) 
        return nil 
    end

    local RuntimeSuccess, Result = xpcall(Chunk, debug.traceback)
    if not RuntimeSuccess then 
        warn("Runtime error in " .. Name .. ":\n" .. tostring(Result)) 
        return nil 
    end

    return Result
end

local ConfigModule = Load("Config")
if type(ConfigModule) == "table" and type(ConfigModule.new) == "function" then
    Config = ConfigModule.new()
    for Mode, Name in pairs(Config.Data.RouletteCharacters) do
        if type(Name) == "string" then CatstarState.RouletteCharacters[Mode] = Name end
    end
end

local Interface = Load("Interface")
if type(Interface) ~= "table" or type(Interface.new) ~= "function" then
    warn("Could not load the menu")
    return
end
while not Players.LocalPlayer or not workspace.CurrentCamera do task.wait() end
local Window = Interface.new()
CatstarState.Notify = function(Title, Content) Window:Notify(Title, Content) end
getgenv().CatstarMenu = Window
local Version = Load("Version")
if type(Version) == "table" and type(Version.Init) == "function" then
    Version.Init(Window, Build)
end

task.spawn(function()
    Load("fixes")
end)

local TargetFilter = Load("TargetFilter")
if type(TargetFilter) ~= "table" or type(TargetFilter.IsValid) ~= "function" then
    Window:SetStatus("Failed: TargetFilter")
    return
end
CatstarState.TargetFilter = TargetFilter

local Modules = {BlackFlash = Load("BlackFlash")}
local ModuleFailed = {BlackFlash = Modules.BlackFlash == nil}

local ModuleList = {
    "RouletteAutoCharacter", "BeamESP", "M1PingFix", "M1DownslamAssist", "ESP", "NPCESP",
    "Aimbot", "Noclip", "Gamepasses", "AutoBurst", "Aura", "AntiBlackhole", "InstantInteract",
    "QTE", "DomainESP", "Reach", "AntiVoid", "ItemESP", "Ratio", "DummyESP", "Rejoin",
    "Train", "KillSound", "DiamondInTheSky", "Notifications",
}
local ESPFeatures = {"HealthBar", "EvadeBar", "SpecialMeter", "UltimateBar", "Moveset", "PlayerInfo", "Tracers"}

task.spawn(function()
    while not Players.LocalPlayer do task.wait() end
    for _, Name in ipairs(ModuleList) do
        task.spawn(function()
            local Result = Load(Name)
            if Result and Name == "ESP" then
                local Dependencies = {}
                local Pending = #ESPFeatures
                local Failed = false
                for _, Feature in ipairs(ESPFeatures) do
                    task.spawn(function()
                        local FeatureModule = Load(Feature)
                        if type(FeatureModule) == "table" and type(FeatureModule.Init) == "function" then
                            Dependencies[Feature] = FeatureModule
                        else
                            Failed = true
                            warn("Player ESP could not load " .. Feature)
                        end
                        Pending = Pending - 1
                    end)
                end
                while Pending > 0 do task.wait() end
                if Failed then
                    Result = nil
                else
                    Result.Dependencies = Dependencies
                end
            end
            if Result then
                Modules[Name] = Result
            else
                ModuleFailed[Name] = true
            end
        end)
    end
end)

local RouletteControls = {}
local function ApplyConfig()
    Config.Applying = true
    for _, Group in ipairs({"Variables", "Toggles"}) do
        local Folder = Group == "Toggles" and TogglesFolder or VariablesFolder
        for _, Object in ipairs(Folder:GetChildren()) do
            local Key = Object.Name
            if Key ~= "Aim" and Key ~= "LockedTarget" then
                local Default = VariableDefaults[Key]
                if Group == "Toggles" then Default = false end
                if Default ~= nil then
                    local Value = SettingValue(Group, Key, Default, Config.Data[Group][Key])
                    Config.Data[Group][Key] = Value
                    Object.Value = Value
                end
            end
        end
    end
    table.clear(CatstarState.RouletteCharacters)
    for Mode, Name in pairs(Config.Data.RouletteCharacters) do
        if type(Name) == "string" then CatstarState.RouletteCharacters[Mode] = Name end
    end
    for Mode, Control in pairs(RouletteControls) do
        local Name = CatstarState.RouletteCharacters[Mode] or "None"
        if not table.find(Control.Args.Options, Name) then Name = "None" end
        Control:SetValue(Name)
    end
    Config.Applying = false
    Window:Refresh()
end

local function Toggle(Title, Key, Module, Parent)
    local Binding = CatstarState.Toggles[Key]
    return {Type = "Toggle", Module = Module, Args = {
        Title = Title, Binding = Binding, Value = Binding.Value,
        Parent = Parent and CatstarState.Toggles[Parent],
        Callback = function(V) CatstarState.Toggles[Key].Value = V end,
    }}
end

local UiLayout = {
    {Type = "Section", Args = {Title = "Combat"}},
    Toggle("M1 Ping Fix", "M1PingFix", "M1PingFix"),
    {Type = "Slider",   Module = "M1PingFix", Args = {
        Title = "M1 Jump Delay (s)", Binding = CatstarState.Variables.M1JumpDelay,
        Step = 0.01, Value = {Min = 0, Max = 1, Default = CatstarState.Variables.M1JumpDelay.Value},
        Callback = function(V) CatstarState.Variables.M1JumpDelay.Value = V end,
    }},
    Toggle("M1 Downslam Assist", "M1DownslamAssist", "M1DownslamAssist"),
    Toggle("Auto BlackFlash", "BlackFlash", "BlackFlash"),
    Toggle("Auto Nanami Ratio", "Ratio", "Ratio"),
    Toggle("Auto Burst", "AutoBurst", "AutoBurst"),
    Toggle("Auto QTE", "QTE", "QTE"),

    {Type = "Section", Args = {Title = "Targeting"}},
    {Type = "Keybind", Module = "Aimbot", Args = {
        Title = "Aimbot Keybind", Binding = CatstarState.Variables.AimbotKey,
        Value = CatstarState.Variables.AimbotKey.Value,
        OnChanged = function(V) CatstarState.Variables.AimbotKey.Value = V end,
        Callback = function() if Modules.Aimbot then Modules.Aimbot.Toggle(CatstarState) end end,
    }},
    Toggle("Team Check", "TeamCheck", "Aimbot"),
    Toggle("Front Dash Reach", "Reach", "Reach"),
    {Type = "Slider",   Module = "Reach", Args = {
        Title = "Reach Distance", Binding = CatstarState.Variables.Reach,
        Step = 1, Value = {Min = 1, Max = 15, Default = CatstarState.Variables.Reach.Value},
        Callback = function(V) CatstarState.Variables.Reach.Value = V end,
    }},

    {Type = "Section", Args = {Title = "Movement & Protection"}},
    Toggle("Noclip through Players", "Noclip", "Noclip"),
    Toggle("Anti Void", "AntiVoid", "AntiVoid"),
    Toggle("Anti Blackhole", "AntiBlackhole", "AntiBlackhole"),

    {Type = "Section", Args = {Title = "Player ESP"}},
    Toggle("Player ESP", "ESP", "ESP"),
    Toggle("Tracers", "Tracers", nil, "ESP"),
    Toggle("Player Info", "PlayerInfo", nil, "ESP"),
    Toggle("Health Bar", "HealthBar", nil, "ESP"),
    Toggle("Evade Bar", "EvadeBar", nil, "ESP"),
    Toggle("Ultimate Bar", "UltimateBar", nil, "ESP"),
    Toggle("Special Meter", "SpecialMeter", nil, "ESP"),
    Toggle("Moveset Cooldowns", "Moveset", nil, "ESP"),

    {Type = "Section", Args = {Title = "NPC ESP"}},
    Toggle("NPC Owner ESP", "NPCOwnerESP", "NPCESP"),
    Toggle("Transfigured Human", "NPCTransfiguredHuman", "NPCESP", "NPCOwnerESP"),
    Toggle("KuroClone", "NPCKuroClone", "NPCESP", "NPCOwnerESP"),
    Toggle("Haruta Sword NPC", "NPCHarutaSword", "NPCESP", "NPCOwnerESP"),
    Toggle("Haruta Sword ESP", "HarutaSwordESP", "NPCESP"),

    {Type = "Section", Args = {Title = "World ESP"}},
    Toggle("Beam ESP", "BeamESP", "BeamESP"),
    Toggle("Domain ESP", "DomainESP", "DomainESP"),
    Toggle("Dummy ESP", "DummyESP", "DummyESP"),
    Toggle("Item ESP", "ItemESP", "ItemESP"),

    {Type = "Section", Args = {Title = "Roulette"}},
    Toggle("Auto Character", "RouletteAutoCharacter", "RouletteAutoCharacter"),

    {Type = "Section", Args = {Title = "Emotes & Unlocks"}},
    Toggle("Free Gamepasses", "Gamepasses", "Gamepasses"),
    {Type = "Button", Module = "Gamepasses", Args = {Title = "Calibrate Second Emotes", Parent = CatstarState.Toggles.Gamepasses, Callback = function()
        Window:SetStatus("Calibrating second-page emotes...")
        local Success, Message = Modules.Gamepasses.Calibrate(CatstarState)
        if Success then
            if Config then
                Config:Set("Variables", "SecondEmotes", CatstarState.Variables.SecondEmotes.Value)
            end
            if not Config or not Config:Save() then Message = Message .. " (config saving unavailable)" end
        end
        Window:SetStatus(Message)
    end}},
    Toggle("Faster Diamond In The Sky", "DiamondInTheSky", "DiamondInTheSky"),
    {Type = "Slider",   Module = "DiamondInTheSky", Args = {
        Title = "Diamond In The Sky Speed", Binding = CatstarState.Variables.SpeedMultiplier,
        Step = 1, Value = {Min = 1, Max = 50, Default = CatstarState.Variables.SpeedMultiplier.Value},
        Callback = function(V) CatstarState.Variables.SpeedMultiplier.Value = V end,
    }},
    Toggle("Free Kill Sound", "KillSound", "KillSound"),

    {Type = "Section", Args = {Title = "Chat"}},
    Toggle("Message Aura", "MsgAura", "Aura"),

    {Type = "Section", Args = {Title = "Notifications"}},
    Toggle("Notifications", "Notifications", "Notifications"),
    Toggle("Joins", "NotifyJoins", "Notifications", "Notifications"),
    {Type = "Dropdown", Module = "Notifications", Args = {
        Title = "Join scope", Parent = CatstarState.Toggles.Notifications,
        Binding = CatstarState.Variables.NotifyJoinScope, Options = {"Everyone", "Friends", "Group", "Friends + Group"},
        Value = CatstarState.Variables.NotifyJoinScope.Value, Callback = function(V) CatstarState.Variables.NotifyJoinScope.Value = V end,
    }},
    Toggle("Leaves", "NotifyLeaves", "Notifications", "Notifications"),
    {Type = "Dropdown", Module = "Notifications", Args = {
        Title = "Leave scope", Parent = CatstarState.Toggles.Notifications,
        Binding = CatstarState.Variables.NotifyLeaveScope, Options = {"Everyone", "Friends", "Group", "Friends + Group"},
        Value = CatstarState.Variables.NotifyLeaveScope.Value, Callback = function(V) CatstarState.Variables.NotifyLeaveScope.Value = V end,
    }},
    Toggle("Deaths", "NotifyDeaths", "Notifications", "Notifications"),
    {Type = "Dropdown", Module = "Notifications", Args = {
        Title = "Death scope", Parent = CatstarState.Toggles.Notifications,
        Binding = CatstarState.Variables.NotifyDeathScope, Options = {"Friends", "Group", "Friends + Group"},
        Value = CatstarState.Variables.NotifyDeathScope.Value, Callback = function(V) CatstarState.Variables.NotifyDeathScope.Value = V end,
    }},
    Toggle("Ultimate starts", "NotifyUlts", "Notifications", "Notifications"),
    Toggle("Ultimate ends", "NotifyUnults", "Notifications", "Notifications"),
    Toggle("Emote spending", "NotifyBuys", "Notifications", "Notifications"),

    {Type = "Section", Args = {Title = "Utilities"}},
    Toggle("Instant Interact", "InstantInteract", "InstantInteract"),
    {Type = "Button",   Module = "Train",            InitArg = "Component", Args = {Title = "Spawn Train", Callback = function() if Modules.Train then Modules.Train.Clicked() end end}},
    {Type = "Button",   Module = "Rejoin",           InitName = "None", Args = {Title = "Rejoin Server", Callback = function() if Modules.Rejoin then Modules.Rejoin.Clicked() end end}},

    {Type = "Section", Args = {Title = "Config"}},
    {Type = "Button", Args = {Title = "Save Config", Callback = function() Window:SetStatus(Config and Config:Save() and "Config saved" or "Config saving unavailable or failed") end}},
    {Type = "Button", Args = {Title = "Load Config", Callback = function()
        if Config and Config:Load() then ApplyConfig(); Window:SetStatus("Config loaded")
        else Window:SetStatus("Config missing, invalid, or unavailable") end
    end}},
    {Type = "Button", Args = {Title = "Reset Config", Callback = function()
        if not Config then Window:SetStatus("Config unavailable"); return end
        Config:Reset()
        ApplyConfig()
        if Modules.Aimbot and CatstarState.Toggles.Aim.Value then Modules.Aimbot.Toggle(CatstarState) end
        Window:SetStatus(Config:Save() and "Config reset" or "Config reset; saving unavailable or failed")
    end}},
}

local function AddBlackFlashOptions(Mod, Section)
    local Children = {}
    for _, Option in ipairs(Mod.Options) do
        local Key = "BlackFlash" .. Option.Id
        local DelayKey = "BlackFlashDelayMs" .. Option.Id
        VariableDefaults[DelayKey] = Option.Delay
        Ranges[DelayKey] = {Option.Min, Option.Max}
        local Toggle = CatstarState.Toggles[Key]
        local Delay = CatstarState.Variables[DelayKey]
        local Component = Window:AddControl(Section,"Toggle", {Title = Option.Name, Parent = CatstarState.Toggles.BlackFlash,
            Binding = Toggle, Value = Toggle.Value, Callback = function(V) Toggle.Value = V end})
        Component:SetEnabled(false)
        Children[#Children + 1] = Component
        local Component = Window:AddControl(Section,"Slider", {Title = Option.Name .. " delay (ms)", Parent = CatstarState.Toggles.BlackFlash,
            Binding = Delay, Step = 1, Value = {Min = Option.Min, Max = Option.Max, Default = Delay.Value},
            Callback = function(V) Delay.Value = V end})
        Component:SetEnabled(false)
        Children[#Children + 1] = Component
    end
    return Children
end

local InitializedModules = {}
local Pending = 0
local Failures = {}
local Section
for _, Element in ipairs(UiLayout) do
    if Element.Type == "Section" then
        Section = Window:AddSection(Element.Args.Title)
    else
        local Component = Window:AddControl(Section, Element.Type, Element.Args, Element.InitArg == "Component")
        local TargetModule = Element.Module
        local Children = TargetModule == "BlackFlash" and Modules.BlackFlash and AddBlackFlashOptions(Modules.BlackFlash, Section) or {}
        if TargetModule then
            Pending = Pending + 1
            Component:SetEnabled(false)
            task.spawn(function()
                while not Modules[TargetModule] and not ModuleFailed[TargetModule] do task.wait() end
                local Mod = Modules[TargetModule]
                local RunName = Element.InitName or "Init"
                if Mod and RunName ~= "None" then
                    if not InitializedModules[TargetModule] then
                        InitializedModules[TargetModule] = "Loading"
                        local Success, Error = xpcall(function()
                            assert(type(Mod) == "table" and type(Mod[RunName]) == "function", "Missing " .. RunName)
                            if Element.InitArg == "Component" then Mod[RunName](Component, CatstarState)
                            else Mod[RunName](CatstarState) end
                            if TargetModule == "RouletteAutoCharacter" then
                                local Options = {"None"}
                                for _, Name in ipairs(Mod.Characters) do Options[#Options + 1] = Name end
                                for _, Mode in ipairs(Mod.Modes) do
                                    local Key = Mode.Name:upper()
                                    RouletteControls[Key] = Window:AddControl(Window.Sections.Roulette, "Dropdown", {Title = Mode.Name, Options = Options,
                                        Value = table.find(Options, CatstarState.RouletteCharacters[Key]) and CatstarState.RouletteCharacters[Key] or "None",
                                        Callback = function(Name)
                                            CatstarState.RouletteCharacters[Key] = Name ~= "None" and Name or nil
                                            if Config then Config:Set("RouletteCharacters", Key, CatstarState.RouletteCharacters[Key]) end
                                        end})
                                end
                            end
                        end, debug.traceback)
                        InitializedModules[TargetModule] = Success and "Ready" or "Failed"
                        if not Success then warn(TargetModule .. ": " .. tostring(Error)) end
                    else
                        while InitializedModules[TargetModule] == "Loading" do task.wait() end
                    end
                end
                local Ready = Mod ~= nil and InitializedModules[TargetModule] ~= "Failed"
                Component:SetEnabled(Ready)
                for _, Child in ipairs(Children) do Child:SetEnabled(Ready) end
                if not Ready then Failures[TargetModule] = true end
                Pending = Pending - 1
            end)
        end
    end
end
Window:Refresh()
Window:SetStatus("Loading modules...")
task.spawn(function()
    while Pending > 0 do task.wait() end
    local Names = {}
    for Name in pairs(Failures) do Names[#Names + 1] = Name end
    table.sort(Names)
    Window:SetStatus(#Names == 0 and "Ready" or ("Failed: " .. table.concat(Names, ", ")))
end)
