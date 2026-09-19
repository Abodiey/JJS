local Reach = {}

-- Services & References
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer

-- Workspace & Tracking setup
local CharactersFolder = workspace:WaitForChild("Characters", 999)
local trackedRemotes = setmetatable({}, { __mode = "k" })

local character = LocalPlayer.Character
local localRoot = character and character:WaitForChild("HumanoidRootPart", 9999)
local oldNamecall = nil

local Blacklist = {
    ["EarthenInsect"] = true,
    ["HarutaSwordNPC"] = true, 
    ["FrameNPC"] = true, 
    ["MechamaruBot"] = true
}
-- Character Setup
local function setupCharacter(newChar)
    character = newChar
    localRoot = newChar:WaitForChild("HumanoidRootPart", 9999)

    newChar.ChildAdded:Connect(function(child)
        if child.Name == "RemoteEvent" then
            trackedRemotes[child] = true
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(setupCharacter)
if character then 
    setupCharacter(character) 
end

-- Module Variables
local maxDistance = 15
local isEnabled = false
local lockedTarget

-- Helper Functions
local function getClosestCharacter()
    if not character or not localRoot then return nil end

    local target = lockedTarget
    if target and target.Parent and not target:GetAttribute("Dead") and target:FindFirstChild("HumanoidRootPart") then return target end

    local closest, shortest = nil, maxDistance

    for _, char in ipairs(CharactersFolder:GetChildren()) do
        local owner = char.Name == "KuroClone" and char:FindFirstChild("Owner")
        local ignoreClone = char.Name == "KuroClone" and (not owner or owner.Value == LocalPlayer)
        if char ~= character and not Blacklist[char.Name] and not ignoreClone then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and char:FindFirstChild("Info") and not char.Info:FindFirstChild("Block") then
                local d = (root.Position - localRoot.Position).Magnitude
                if d <= shortest then
                    shortest = d
                    closest = char
                end
            end
        end
    end

    return closest
end

-- Hook Initialization
task.delay(60, function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if method == "FireServer" and not checkcaller() then
            if isEnabled and trackedRemotes[self] then
                local Args = table.pack(...)

                if Args.n == 2 and typeof(Args[2]) == "CFrame" then
                    if type(Args[1]) == "table" then
                        local target = Args[1][1]
                        local info = typeof(target) == "Instance" and target:FindFirstChild("Info")
                        if info and info:FindFirstChild("Block") then Args[1] = nil end
                    elseif Args[1] == nil then
                        local target = getClosestCharacter()
                        if target then Args[1] = {target} end
                    end
                    setnamecallmethod(method)
                    return oldNamecall(self, table.unpack(Args, 1, Args.n))
                end
            end
        end

        setnamecallmethod(method)
        return oldNamecall(self, ...)
    end))
end)

-- Module Core Initialization
function Reach.Init(State)
    local targetVariable = State.Variables.LockedTarget
    local toggleObject = State.Toggles.Reach
    local reachVariable = State.Variables.Reach

    local function handleToggleChange()
        isEnabled = toggleObject.Value
    end

    local function handleReachChange()
        maxDistance = reachVariable.Value
    end

    local function handleTargetChange()
        lockedTarget = targetVariable.Value
    end

    local targetConn = targetVariable:GetPropertyChangedSignal("Value"):Connect(handleTargetChange)
    table.insert(State.Connections, targetConn)
    handleTargetChange()

    -- Toggle setup
    local toggleConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleToggleChange)
    table.insert(State.Connections, toggleConn)
    handleToggleChange()

    -- Reach variable setup
    local reachConn = reachVariable:GetPropertyChangedSignal("Value"):Connect(handleReachChange)
    table.insert(State.Connections, reachConn)
    handleReachChange()
end

return Reach
