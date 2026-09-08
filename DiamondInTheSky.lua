local DiamondInTheSky = {}

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local PreSimulation = RunService.PreSimulation
local Vector3_new = Vector3.new

local player = Players.LocalPlayer

local character = nil
local rootPart = nil
local activeSwingForce = nil

local addedConn, removedConn, attrConn
local forceAddedConn, forceRemovedConn
local loopConn
local charAddedConn, charRemovingConn

local function setVelocity(State)
    if activeSwingForce then
        local currentVelocity = activeSwingForce.Velocity
        local mult = State.Variables.SpeedMultiplier.Value
        activeSwingForce.Velocity = Vector3_new(currentVelocity.X * mult, currentVelocity.Y, currentVelocity.Z * mult)
    end
end

local function toggleLoop(shouldEnable, State)
    if shouldEnable then
        if not loopConn then
            loopConn = PreSimulation:Connect(function()
                setVelocity(State)
            end)
        end
    else
        if loopConn then
            loopConn:Disconnect()
            loopConn = nil
        end
    end
end

local function checkEmote(emoteInstance, State)
    if attrConn then attrConn:Disconnect() end
    
    local isActive = (emoteInstance:GetAttribute("EmoteName") == "Diamond in the sky")
    toggleLoop(isActive, State)
    
    attrConn = emoteInstance:GetAttributeChangedSignal("EmoteName"):Connect(function()
        local isNowActive = (emoteInstance:GetAttribute("EmoteName") == "Diamond in the sky")
        toggleLoop(isNowActive, State)
    end)
end

local function cleanup()
    if addedConn then addedConn:Disconnect() addedConn = nil end
    if removedConn then removedConn:Disconnect() removedConn = nil end
    if attrConn then attrConn:Disconnect() attrConn = nil end
    if forceAddedConn then forceAddedConn:Disconnect() forceAddedConn = nil end
    if forceRemovedConn then forceRemovedConn:Disconnect() forceRemovedConn = nil end
    if loopConn then loopConn:Disconnect() loopConn = nil end
    
    character = nil
    rootPart = nil
    activeSwingForce = nil
end

local function setup(newCharacter, State)
    cleanup()
    
    character = newCharacter
    rootPart = character:WaitForChild("HumanoidRootPart", 99999)

    activeSwingForce = rootPart:FindFirstChild("SwingForce")
    
    forceAddedConn = rootPart.ChildAdded:Connect(function(child)
        if child.Name == "SwingForce" then
            activeSwingForce = child
        end
    end)

    forceRemovedConn = rootPart.ChildRemoved:Connect(function(child)
        if child == activeSwingForce then
            activeSwingForce = nil
        end
    end)

    local infoFolder = character:WaitForChild("Info", 99999)
    if infoFolder and character == newCharacter then
        local currentEmote = infoFolder:FindFirstChild("Emote")
        if currentEmote then
            checkEmote(currentEmote, State)
        end

        addedConn = infoFolder.ChildAdded:Connect(function(child)
            if child.Name == "Emote" then
                checkEmote(child, State)
            end
        end)

        removedConn = infoFolder.ChildRemoved:Connect(function(child)
            if child.Name == "Emote" then
                if loopConn then loopConn:Disconnect() loopConn = nil end
                if attrConn then attrConn:Disconnect() armConn = nil end
            end
        end)
    end
end

local function deepCleanup()
    cleanup()
    if charAddedConn then charAddedConn:Disconnect() charAddedConn = nil end
    if charRemovingConn then charRemovingConn:Disconnect() charRemovingConn = nil end
end

function DiamondInTheSky.Init(State)
    local toggleObject = State.Toggles.DiamondInTheSky

    local function handleStateChange()
        if toggleObject.Value then
            if player.Character then
                setup(player.Character, State)
            end
            
            if not charAddedConn then
                charAddedConn = player.CharacterAdded:Connect(function(char)
                    setup(char, State)
                end)
            end
            if not charRemovingConn then
                charRemovingConn = player.CharacterRemoving:Connect(cleanup)
            end
        else
            deepCleanup()
        end
    end

    local changeConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleStateChange)
    table.insert(State.Connections, changeConn)

    handleStateChange()
end

return DiamondInTheSky
