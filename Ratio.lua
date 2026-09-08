local Ratio = {}

-- Localize Services & Core API
local cloneref = cloneref
local game = game
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))
local workspace = cloneref(game:GetService("Workspace"))

-- Localize Global Engine Functions
local task = task
local table = table
local table_insert = table.insert
local table_clear = table.clear
local pairs = pairs

local RightActivated = ReplicatedStorage:WaitForChild("Knit"):WaitForChild("Knit"):WaitForChild("Services"):WaitForChild("NanamiService"):WaitForChild("RE"):WaitForChild("RightActivated")
local charFolder = workspace:WaitForChild("Characters")

-- State and Connection Tracking
local activeHeartbeats = {}
local instanceConnections = {}
local toggleConn = nil

-- Cleans up all frame loops and instance tracking listeners
local function cleanupRatio()
    -- Disconnect instance streaming listeners
    for id, conn in pairs(instanceConnections) do
        conn:Disconnect()
    end
    table_clear(instanceConnections)

    -- Disconnect active minigame frame loops
    for ratio, conn in pairs(activeHeartbeats) do
        conn:Disconnect()
    end
    table_clear(activeHeartbeats)
end

local function monitor(char, ratio)
    if activeHeartbeats[ratio] then return end
    
    local bar = ratio:FindFirstChild("Bar")
    local cursor = bar and bar:FindFirstChild("Cursor")
    if not cursor then return end

    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not cursor or not cursor.Parent then
            if activeHeartbeats[ratio] then
                activeHeartbeats[ratio]:Disconnect()
                activeHeartbeats[ratio] = nil
            end
            return
        end

        -- Hit the critical frame timing perfectly
        if cursor.Position.Y.Scale < 0.45 then
            if activeHeartbeats[ratio] then
                activeHeartbeats[ratio]:Disconnect()
                activeHeartbeats[ratio] = nil
            end
            RightActivated:FireServer(char)
        end
    end)

    activeHeartbeats[ratio] = connection
end

local function checkCharacter(char)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local ratio = hrp and hrp:FindFirstChild("Ratio")

    if ratio then
        monitor(char, ratio)
    end
end

function Ratio.Init(State)
    local toggleObject = State.Toggles.Ratio

    local function handleToggleChange()
        local isEnabled = toggleObject.Value

        if isEnabled then
            -- 1. Scan current world state immediately upon toggle activation
            local children = charFolder:GetChildren()
            for i = 1, #children do
                local char = children[i]
                checkCharacter(char)
                
                -- Catch dynamically spawned UI indicators within existing characters
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local childConn = hrp.ChildAdded:Connect(function(child)
                        if child.Name == "Ratio" then
                            monitor(char, child)
                        end
                    end)
                    instanceConnections[hrp] = childConn
                end
            end

            -- 2. Stream new characters safely without flat loop polling
            instanceConnections["ChildAdded"] = charFolder.ChildAdded:Connect(function(char)
                local hrp = char:WaitForChild("HumanoidRootPart", 5)
                if hrp then
                    checkCharacter(char)
                    local childConn = hrp.ChildAdded:Connect(function(child)
                        if child.Name == "Ratio" then
                            monitor(char, child)
                        end
                    end)
                    instanceConnections[hrp] = childConn
                end
            end)

            -- 3. Clean up instance listeners from memory immediately when entities leave
            instanceConnections["ChildRemoved"] = charFolder.ChildRemoved:Connect(function(char)
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and instanceConnections[hrp] then
                    instanceConnections[hrp]:Disconnect()
                    instanceConnections[hrp] = nil
                end
            end)
        else
            cleanupRatio()
        end
    end

    toggleConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleToggleChange)
    table_insert(State.Connections, toggleConn)

    handleToggleChange()
end

return Ratio
