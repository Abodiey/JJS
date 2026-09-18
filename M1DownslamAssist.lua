local M1DownslamAssist = {}

local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer

function M1DownslamAssist.Init(State)
    local toggleObject = State.Toggles.M1DownslamAssist
    local connections = {}
    local currentCharacter
    local generation = 0
    local sequence = 0

    local function clearCharacter()
        generation = generation + 1
        sequence = sequence + 1
        for _, connection in ipairs(connections) do connection:Disconnect() end
        connections = {}
        currentCharacter = nil
    end

    local function setupCharacter(character)
        clearCharacter()
        currentCharacter = character
        local version = generation
        task.spawn(function()
            local humanoid = character:WaitForChild("Humanoid", 10)
            local info = character:WaitForChild("Info", 10)
            if not humanoid or not info or version ~= generation or LocalPlayer.Character ~= character then return end
            local lastValue = character:GetAttribute("CurrentM1")

            table.insert(connections, info.ChildAdded:Connect(function(child)
                if child.Name == "Stun" or child.Name == "Ragdoll" then sequence = sequence + 1 end
            end))
            table.insert(connections, character:GetAttributeChangedSignal("CurrentM1"):Connect(function()
                local value = character:GetAttribute("CurrentM1")
                local previous = lastValue
                lastValue = value
                sequence = sequence + 1
                if previous ~= 3 or value ~= 4 or not toggleObject.Value then return end
                local token = sequence
                local started = os.clock()

                task.spawn(function()
                    task.wait()
                    while version == generation and token == sequence and toggleObject.Value
                        and LocalPlayer.Character == character and character.Parent and info.Parent == character
                        and humanoid.Parent == character and humanoid.Health > 0 and not character:GetAttribute("Dead")
                        and not info:FindFirstChild("Stun") and not info:FindFirstChild("Ragdoll")
                        and os.clock() - started < 1.5 do
                        if not info:FindFirstChild("NoJump") then
                            local state = humanoid:GetState()
                            if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then return end
                            if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
                                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                state = humanoid:GetState()
                                if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then return end
                            end
                        end
                        RunService.RenderStepped:Wait()
                    end
                end)
            end))
        end)
    end

    table.insert(State.Connections, toggleObject:GetPropertyChangedSignal("Value"):Connect(function()
        sequence = sequence + 1
    end))
    table.insert(State.Connections, LocalPlayer.CharacterAdded:Connect(setupCharacter))
    table.insert(State.Connections, LocalPlayer.CharacterRemoving:Connect(function(character)
        if character == currentCharacter then clearCharacter() end
    end))
    if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
end

return M1DownslamAssist
