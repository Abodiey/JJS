local AutoBurst = {}

local DASH_DIRECTION = "Left"
local ATTRIBUTE_NAME = "Burst"

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local LocalPlayer = Players.LocalPlayer

local DashRemote
task.spawn(function()
    DashRemote = ReplicatedStorage:WaitForChild("Knit", 99999):WaitForChild("Knit", 99999):WaitForChild("Services", 99999):WaitForChild("MovementService", 99999):WaitForChild("RE", 99999):WaitForChild("Dash", 99999)
end)

local currentCharacter = LocalPlayer.Character
LocalPlayer.CharacterAdded:Connect(function(char)
    currentCharacter = char
end)
LocalPlayer.CharacterRemoving:Connect(function()
    currentCharacter = nil
end)

local getAttribute = game.GetAttribute

function AutoBurst.Init(State)
    local wasBurstActive = false

    local HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not State.Toggles.AutoBurst.Value then return end
        if not DashRemote or not currentCharacter then return end

        local isBurstActive = getAttribute(currentCharacter, ATTRIBUTE_NAME)

        if isBurstActive and not wasBurstActive then
            DashRemote:FireServer(DASH_DIRECTION, true)
        end

        wasBurstActive = isBurstActive
    end)

    table.insert(State.Connections, HeartbeatConnection)
end

return AutoBurst
