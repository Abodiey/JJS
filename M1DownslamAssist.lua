local M1DownslamAssist = {}

local RunService = cloneref(game:GetService("RunService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local Blacklist = {HarutaSwordNPC = true, FrameNPC = true, MechamaruBot = true}

function M1DownslamAssist.Init(State)
    local Services = ReplicatedStorage:WaitForChild("Knit"):WaitForChild("Knit"):WaitForChild("Services")
    local toggleObject = State.Toggles.M1DownslamAssist
    local connections = {}
    local currentCharacter, pending

    local function cancel()
        if pending then pending:Disconnect(); pending = nil end
    end

    local function getTarget(character, root)
        local target = State.Variables.LockedTarget.Value
        if target and target.Parent and not target:GetAttribute("Dead") and target:FindFirstChild("HumanoidRootPart") then return target end
        local folder = workspace:FindFirstChild("Characters")
        if not folder then return nil end
        local closest, distance = nil, State.Variables.Reach.Value
        for _, other in ipairs(folder:GetChildren()) do
            local otherRoot = other:FindFirstChild("HumanoidRootPart")
            local info = other:FindFirstChild("Info")
            if other ~= character and not Blacklist[other.Name] and not other:GetAttribute("Dead")
                and otherRoot and info and not info:FindFirstChild("Block") then
                local d = (otherRoot.Position - root.Position).Magnitude
                if d <= distance then closest, distance = other, d end
            end
        end
        return closest
    end

    local function clearCharacter()
        cancel()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        connections = {}
        currentCharacter = nil
    end

    local function setupCharacter(character)
        clearCharacter()
        currentCharacter = character
        task.spawn(function()
            local humanoid = character:WaitForChild("Humanoid", 10)
            local info = character:WaitForChild("Info", 10)
            local root = character:WaitForChild("HumanoidRootPart", 10)
            if not humanoid or not info or not root or currentCharacter ~= character or LocalPlayer.Character ~= character then return end
            local lastValue = character:GetAttribute("CurrentM1")
            connections[1] = info.ChildAdded:Connect(function(child)
                if child.Name == "Stun" or child.Name == "Ragdoll" then cancel() end
            end)
            connections[2] = character:GetAttributeChangedSignal("CurrentM1"):Connect(function()
                local value = character:GetAttribute("CurrentM1")
                local previous = lastValue
                lastValue = value
                cancel()
                if previous ~= 3 or value ~= 4 or not toggleObject.Value then return end
                local jumped = false
                local started = os.clock()
                pending = RunService.Heartbeat:Connect(function()
                    if LocalPlayer.Character ~= character or not character.Parent or humanoid.Health <= 0
                        or character:GetAttribute("Dead") or info.Parent ~= character or root.Parent ~= character
                        or humanoid.Parent ~= character or not toggleObject.Value
                        or info:FindFirstChild("Stun") or info:FindFirstChild("Ragdoll") then cancel(); return end
                    local state = humanoid:GetState()
                    local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
                    if not jumped then
                        if os.clock() - started >= 1.5 then cancel(); return end
                        if airborne then
                            jumped = true
                        elseif not info:FindFirstChild("NoJump") and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) then
                            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                            jumped = true
                        end
                        return
                    end
                    if info:FindFirstChild("InSkill") or (airborne and root.AssemblyLinearVelocity.Y >= 0) then return end
                    cancel()
                    local moveset = LocalPlayer:GetAttribute("Moveset")
                    local service = type(moveset) == "string" and Services:FindFirstChild(moveset .. "Service")
                    local re = service and service:FindFirstChild("RE")
                    local event = re and re:FindFirstChild("Activated")
                    if event then event:FireServer("Down", getTarget(character, root)) end
                end)
            end)
        end)
    end

    table.insert(State.Connections, toggleObject:GetPropertyChangedSignal("Value"):Connect(cancel))
    table.insert(State.Connections, LocalPlayer.CharacterAdded:Connect(setupCharacter))
    table.insert(State.Connections, LocalPlayer.CharacterRemoving:Connect(function(character)
        if character == currentCharacter then clearCharacter() end
    end))
    if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
end

return M1DownslamAssist
