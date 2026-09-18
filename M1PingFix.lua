local M1PingFix = {}

local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer

function M1PingFix.Init(State)
    local toggleObject = State.Toggles.M1PingFix
    local delayObject = State.Variables.M1JumpDelay
    local connections = {}
    local currentCharacter
    local generation = 0
    local cancellation = 0

    local function clearCharacter()
        generation = generation + 1
        for _, connection in ipairs(connections) do connection:Disconnect() end
        connections = {}
        currentCharacter = nil
    end

    local function setupCharacter(character)
        clearCharacter()
        currentCharacter = character
        local version = generation
        task.spawn(function()
            local info = character:WaitForChild("Info", 10)
            if not info or version ~= generation or LocalPlayer.Character ~= character then return end

            local function valid(sequence)
                return version == generation and sequence == cancellation and toggleObject.Value
                    and LocalPlayer.Character == character and character.Parent and info.Parent == character
                    and not character:GetAttribute("Dead")
                    and not info:FindFirstChild("Stun") and not info:FindFirstChild("Ragdoll")
            end

            table.insert(connections, info.ChildRemoved:Connect(function(child)
                if child.Name == "InSkill" or child.Name == "NoSprint" then
                    cancellation = cancellation + 1
                end
            end))
            table.insert(connections, info.ChildAdded:Connect(function(child)
                if child.Name == "Stun" or child.Name == "Ragdoll" then
                    cancellation = cancellation + 1
                end
            end))
            table.insert(connections, character:GetAttributeChangedSignal("CurrentM1"):Connect(function()
                if not toggleObject.Value then return end
                local start = os.clock()
                local sequence = cancellation
                task.wait()
                if not valid(sequence) then return end
                local inSkill = info:FindFirstChild("InSkill")
                local noSprint = info:FindFirstChild("NoSprint")
                local noJump = info:FindFirstChild("NoJump")
                if not inSkill or not noSprint or not noJump then return end

                while os.clock() - start < delayObject.Value do
                    if not valid(sequence) or noJump.Parent ~= info then return end
                    RunService.RenderStepped:Wait()
                end
                if valid(sequence) and inSkill.Parent == info and noSprint.Parent == info and noJump.Parent == info then
                    noJump:Destroy()
                end
            end))
        end)
    end

    table.insert(State.Connections, toggleObject:GetPropertyChangedSignal("Value"):Connect(function()
        cancellation = cancellation + 1
    end))
    table.insert(State.Connections, LocalPlayer.CharacterAdded:Connect(setupCharacter))
    table.insert(State.Connections, LocalPlayer.CharacterRemoving:Connect(function(character)
        if character == currentCharacter then clearCharacter() end
    end))
    if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
end

return M1PingFix
