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
            local saved = Config and Config.Data[group][key]
            if persistent and type(saved) == type(default) then
                if type(saved) ~= "number" or (saved == saved and math.abs(saved) < math.huge) then default = saved end
            end
            local range = group == "Variables" and Ranges[key]
            if range then default = math.clamp(default, range[1], range[2]) end
            if key == "AimbotKey" then
                local valid, keyCode = pcall(function() return Enum.KeyCode[default] end)
                if not valid or not keyCode or default == "Unknown" or default == "Escape" or default == "K" then default = "C" end
            end
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
    SpeedMultiplier = 15,
    Reach = 15,
    LockedTarget = nil,
    AimbotKey = "C",
}

local ClassMap = {
    ["boolean"] = "BoolValue",
    ["number"] = "NumberValue",
    ["string"] = "StringValue",
}

local StateStructure = {
    RouletteCharacters = {},
    Connections = setmetatable({}, { __mode = "v" }),
    Toggles = BindToFolder(TogglesFolder, ClassMap, {}),
    Variables = BindToFolder(VariablesFolder, ClassMap, VariableDefaults),
}

getgenv().CatstarState = StateStructure
local CatstarState = StateStructure

local function Load(Name)
    local Url = BaseUrl .. Name .. ".lua"
    local MaxRetries = 5
    local DelayTime = 1 + math.random()
    local Response = nil
    local Success = false

    for Attempt = 1, MaxRetries do
        local ReqSuccess, ReqResponse = pcall(function()
            return request({
                Url = Url,
                Method = "GET"
            })
        end)

        if ReqSuccess and type(ReqResponse) == "table" and ReqResponse.StatusCode == 200 then
            Response = ReqResponse
            Success = true
            break
        end

        local ErrorMsg = not ReqSuccess and tostring(ReqResponse) or (ReqResponse and "Status " .. tostring(ReqResponse.StatusCode) or "Unknown error")
        warn(string.format("Attempt %d/%d failed for %s: %s", Attempt, MaxRetries, Name, ErrorMsg))

        if Attempt < MaxRetries then
            task.wait(DelayTime)
            DelayTime = DelayTime * 2 -- Exponential backoff (1s, 2s, 4s...)
        end
    end

    if not Success or not Response then
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

local Menu = Load("Menu")
if type(Menu) ~= "table" or type(Menu.new) ~= "function" then
    warn("Could not load the menu")
    return
end
while not Players.LocalPlayer or not workspace.CurrentCamera do task.wait() end
local Window = Menu.new("CATSTAR", Enum.KeyCode.K)
getgenv().CatstarMenu = Window

task.spawn(function()
    Load("fixes")
end)

local TargetFilter = Load("TargetFilter")
if type(TargetFilter) ~= "table" or type(TargetFilter.IsValid) ~= "function" then
    Window:SetStatus("Failed: TargetFilter")
    return
end
CatstarState.TargetFilter = TargetFilter

local Modules = {}
local ModuleFailed = {}

local ModuleList = {"RouletteAutoCharacter", "BeamESP", "M1PingFix", "M1DownslamAssist", "ESP", "Aimbot", "Noclip", "Gamepasses", "AutoBurst", "Aura", "AntiBlackhole", "InstantInteract", "QTE", "DomainESP", "Reach", "AntiVoid", "ItemESP", "BlackFlash", "Ratio", "DummyESP", "Rejoin", "Train", "KillSound", "DiamondInTheSky"}

task.spawn(function()
    while not Players.LocalPlayer do task.wait() end
    for _, Name in ipairs(ModuleList) do
        task.spawn(function()
            local Result = Load(Name)
            if Result and Name == "ESP" then
                local Dependencies = {}
                local Pending = 7
                local Failed = false
                for _, Feature in ipairs({"HealthBar", "EvadeBar", "SpecialMeter", "UltimateBar", "Moveset", "PlayerInfo", "Tracers"}) do
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

local UiLayout = {
    {Type = "Section",  Args = {Title = "Combat"}},
    {Type = "Toggle",   Module = "M1PingFix", Args = {Title = "M1 Ping Fix", Binding = CatstarState.Toggles.M1PingFix, Value = CatstarState.Toggles.M1PingFix.Value, Callback = function(V) CatstarState.Toggles.M1PingFix.Value = V end}},
    {Type = "Slider",   Module = "M1PingFix", Args = {Title = "M1 Jump Delay (s)", Binding = CatstarState.Variables.M1JumpDelay, Step = 0.01, Value = {Min = 0, Max = 1, Default = CatstarState.Variables.M1JumpDelay.Value}, Callback = function(V) CatstarState.Variables.M1JumpDelay.Value = V end}},
    {Type = "Toggle",   Module = "M1DownslamAssist", Args = {Title = "M1 Downslam Assist", Binding = CatstarState.Toggles.M1DownslamAssist, Value = CatstarState.Toggles.M1DownslamAssist.Value, Callback = function(V) CatstarState.Toggles.M1DownslamAssist.Value = V end}},

    {Type = "Toggle",   Module = "BlackFlash",        Args = {Title = "Auto BlackFlash", Binding = CatstarState.Toggles.BlackFlash, Value = CatstarState.Toggles.BlackFlash.Value, Callback = function(V) CatstarState.Toggles.BlackFlash.Value = V end}},
    {Type = "Toggle",   Module = "Ratio",             Args = {Title = "Auto Nanami Ratio", Binding = CatstarState.Toggles.Ratio, Value = CatstarState.Toggles.Ratio.Value, Callback = function(V) CatstarState.Toggles.Ratio.Value = V end}},
    {Type = "Toggle",   Module = "AutoBurst",         Args = {Title = "Auto Burst", Binding = CatstarState.Toggles.AutoBurst, Value = CatstarState.Toggles.AutoBurst.Value, Callback = function(V) CatstarState.Toggles.AutoBurst.Value = V end}},
    {Type = "Toggle",   Module = "QTE",               Args = {Title = "Auto QTE", Binding = CatstarState.Toggles.QTE, Value = CatstarState.Toggles.QTE.Value, Callback = function(V) CatstarState.Toggles.QTE.Value = V end}},
    {Type = "Toggle",   Module = "Reach",             Args = {Title = "Front Dash Reach", Binding = CatstarState.Toggles.Reach, Value = CatstarState.Toggles.Reach.Value, Callback = function(V) CatstarState.Toggles.Reach.Value = V end}},
    {Type = "Slider",   Module = "Reach",             Args = {Title = "Reach Distance", Binding = CatstarState.Variables.Reach, Step = 1, Value = {Min = 1, Max = 15, Default = CatstarState.Variables.Reach.Value}, Callback = function(V) CatstarState.Variables.Reach.Value = V end}},
    
    {Type = "Section",  Args = {Title = "Aimbot Settings"}},
    {Type = "Keybind",  Module = "Aimbot",            Args = {Title = "Aimbot Keybind", Binding = CatstarState.Variables.AimbotKey, Value = CatstarState.Variables.AimbotKey.Value, OnChanged = function(V) CatstarState.Variables.AimbotKey.Value = V end, Callback = function() if Modules.Aimbot then Modules.Aimbot.Toggle(CatstarState) end end}},
    {Type = "Toggle",   Module = "Aimbot",            Args = {Title = "Team Check", Binding = CatstarState.Toggles.TeamCheck, Value = CatstarState.Toggles.TeamCheck.Value, Callback = function(V) CatstarState.Toggles.TeamCheck.Value = V end}},

    {Type = "Section",  Args = {Title = "Movement & Protection"}},
    {Type = "Toggle",   Module = "Noclip",            Args = {Title = "Noclip through Players", Binding = CatstarState.Toggles.Noclip, Value = CatstarState.Toggles.Noclip.Value, Callback = function(V) CatstarState.Toggles.Noclip.Value = V end}},
    {Type = "Toggle",   Module = "AntiVoid",          Args = {Title = "Anti Void", Binding = CatstarState.Toggles.AntiVoid, Value = CatstarState.Toggles.AntiVoid.Value, Callback = function(V) CatstarState.Toggles.AntiVoid.Value = V end}},
    {Type = "Toggle",   Module = "AntiBlackhole",     Args = {Title = "Anti Blackhole", Binding = CatstarState.Toggles.AntiBlackhole, Value = CatstarState.Toggles.AntiBlackhole.Value, Callback = function(V) CatstarState.Toggles.AntiBlackhole.Value = V end}},
    {Type = "Toggle",   Module = "InstantInteract",   Args = {Title = "Instant Interact", Binding = CatstarState.Toggles.InstantInteract, Value = CatstarState.Toggles.InstantInteract.Value, Callback = function(V) CatstarState.Toggles.InstantInteract.Value = V end}},
    
    {Type = "Section",  Args = {Title = "Emote Exploits"}},
    {Type = "Toggle",   Module = "DiamondInTheSky",   Args = {Title = "Faster Diamond In The Sky", Binding = CatstarState.Toggles.DiamondInTheSky, Value = CatstarState.Toggles.DiamondInTheSky.Value, Callback = function(V) CatstarState.Toggles.DiamondInTheSky.Value = V end}},
    {Type = "Slider",   Module = "DiamondInTheSky",   Args = {Title = "Diamond In The Sky Speed", Binding = CatstarState.Variables.SpeedMultiplier, Step = 1, Value = {Min = 1, Max = 50, Default = CatstarState.Variables.SpeedMultiplier.Value}, Callback = function(V) CatstarState.Variables.SpeedMultiplier.Value = V end}},
    
    {Type = "Section",  Args = {Title = "Visuals"}},
    {Type = "Toggle",   Module = "ESP",               Args = {Title = "Player ESP", Binding = CatstarState.Toggles.ESP, Value = CatstarState.Toggles.ESP.Value, Callback = function(V) CatstarState.Toggles.ESP.Value = V end}},
    {Type = "Toggle",   Args = {Title = "Tracers", Parent = CatstarState.Toggles.ESP, Binding = CatstarState.Toggles.Tracers, Value = CatstarState.Toggles.Tracers.Value, Callback = function(V) CatstarState.Toggles.Tracers.Value = V end}},
    {Type = "Toggle",   Args = {Title = "Player Info", Parent = CatstarState.Toggles.ESP, Binding = CatstarState.Toggles.PlayerInfo, Value = CatstarState.Toggles.PlayerInfo.Value, Callback = function(V) CatstarState.Toggles.PlayerInfo.Value = V end}},
    {Type = "Toggle",   Args = {Title = "Health Bar", Parent = CatstarState.Toggles.ESP, Binding = CatstarState.Toggles.HealthBar, Value = CatstarState.Toggles.HealthBar.Value, Callback = function(V) CatstarState.Toggles.HealthBar.Value = V end}},
    {Type = "Toggle",   Args = {Title = "Evade Bar", Parent = CatstarState.Toggles.ESP, Binding = CatstarState.Toggles.EvadeBar, Value = CatstarState.Toggles.EvadeBar.Value, Callback = function(V) CatstarState.Toggles.EvadeBar.Value = V end}},
    {Type = "Toggle",   Args = {Title = "Ultimate Bar", Parent = CatstarState.Toggles.ESP, Binding = CatstarState.Toggles.UltimateBar, Value = CatstarState.Toggles.UltimateBar.Value, Callback = function(V) CatstarState.Toggles.UltimateBar.Value = V end}},
    {Type = "Toggle",   Args = {Title = "Special Meter", Parent = CatstarState.Toggles.ESP, Binding = CatstarState.Toggles.SpecialMeter, Value = CatstarState.Toggles.SpecialMeter.Value, Callback = function(V) CatstarState.Toggles.SpecialMeter.Value = V end}},
    {Type = "Toggle",   Args = {Title = "Moveset Cooldowns", Parent = CatstarState.Toggles.ESP, Binding = CatstarState.Toggles.Moveset, Value = CatstarState.Toggles.Moveset.Value, Callback = function(V) CatstarState.Toggles.Moveset.Value = V end}},
    {Type = "Toggle",   Module = "BeamESP", Args = {Title = "Beam ESP", Binding = CatstarState.Toggles.BeamESP, Value = CatstarState.Toggles.BeamESP.Value, Callback = function(V) CatstarState.Toggles.BeamESP.Value = V end}},
    {Type = "Toggle",   Module = "DomainESP",         Args = {Title = "Domain ESP", Binding = CatstarState.Toggles.DomainESP, Value = CatstarState.Toggles.DomainESP.Value, Callback = function(V) CatstarState.Toggles.DomainESP.Value = V end}},
    {Type = "Toggle",   Module = "DummyESP",          Args = {Title = "Dummy ESP", Binding = CatstarState.Toggles.DummyESP, Value = CatstarState.Toggles.DummyESP.Value, Callback = function(V) CatstarState.Toggles.DummyESP.Value = V end}},
    {Type = "Toggle",   Module = "ItemESP",           Args = {Title = "Item ESP", Binding = CatstarState.Toggles.ItemESP, Value = CatstarState.Toggles.ItemESP.Value, Callback = function(V) CatstarState.Toggles.ItemESP.Value = V end}},
    {Type = "Toggle",   Module = "Aura",              Args = {Title = "Message Aura", Binding = CatstarState.Toggles.MsgAura, Value = CatstarState.Toggles.MsgAura.Value, Callback = function(V) CatstarState.Toggles.MsgAura.Value = V end}},
    
    {Type = "Section",  Args = {Title = "Utility Mechanics"}},
    {Type = "Button",   Module = "Train",            InitArg = "Component", Args = {Title = "Spawn Train", Callback = function() if Modules.Train then Modules.Train.Clicked() end end}},
    {Type = "Button",   Module = "Rejoin",           InitName = "None", Args = {Title = "Rejoin Server", Callback = function() if Modules.Rejoin then Modules.Rejoin.Clicked() end end}},


    {Type = "Section",  Args = {Title = "Unlocks"}},
    {Type = "Toggle",   Module = "Gamepasses",        Args = {Title = "Free Gamepasses", Binding = CatstarState.Toggles.Gamepasses, Value = CatstarState.Toggles.Gamepasses.Value, Callback = function(V) CatstarState.Toggles.Gamepasses.Value = V end}},
    {Type = "Toggle",   Module = "KillSound",         Args = {Title = "Free Kill Sound", Binding = CatstarState.Toggles.KillSound, Value = CatstarState.Toggles.KillSound.Value, Callback = function(V) CatstarState.Toggles.KillSound.Value = V end}},
    {Type = "Section",  Args = {Title = "Config"}},
    {Type = "Button", Args = {Title = "Save Config", Callback = function() Window:SetStatus(Config and Config:Save() and "Config saved" or "Config saving unavailable or failed") end}},
    {Type = "Section",  Args = {Title = "Roulette"}},
    {Type = "Toggle",   Module = "RouletteAutoCharacter", Args = {Title = "Auto Character", Binding = CatstarState.Toggles.RouletteAutoCharacter, Value = CatstarState.Toggles.RouletteAutoCharacter.Value, Callback = function(V) CatstarState.Toggles.RouletteAutoCharacter.Value = V end}},
}

local InitializedModules = {}
local Pending = 0
local Failures = {}
for _, Element in ipairs(UiLayout) do
    local Component = Window:Add(Element.Type, Element.Args)
    local TargetModule = Element.Module
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
                            local Options = {""}
                            for _, Name in ipairs(Mod.Characters) do Options[#Options + 1] = Name end
                            for _, Mode in ipairs(Mod.Modes) do
                                local Key = Mode.Name:upper()
                                Window:Add("Dropdown", {Title = Mode.Name, Options = Options,
                                    Value = CatstarState.RouletteCharacters[Key] or "",
                                    Callback = function(Name)
                                        CatstarState.RouletteCharacters[Key] = Name ~= "" and Name or nil
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
            if not Ready then Failures[TargetModule] = true end
            Pending = Pending - 1
        end)
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

