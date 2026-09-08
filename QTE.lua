local QTE = {}

-- Localize Services & Core API
local cloneref = cloneref
local game = game
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local workspace = cloneref(game:GetService("Workspace"))

-- Localize Global Engine Functions
local task = task
local typeof = typeof
local os = os
local math = math
local m_max = math.max
local table = table
local table_insert = table.insert

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local CharactersFolder = workspace:WaitForChild("Characters", 99)
local Knit = ReplicatedStorage:WaitForChild("Knit", 99)
local Event = Knit and Knit:WaitForChild("Knit", 99):WaitForChild("Services", 99):WaitForChild("FinalJudgementService", 99):WaitForChild("RE", 99):WaitForChild("Effects", 99)

QTE.InitialDelay = 1
QTE.MinimumDelay = 0.15
QTE.RampSpeed = 0.21

-- Current Execution Instance Identifier for immediate thread termination
local CurrentScriptID = 0

-- Connection Trackers
local networkConn = nil
local toggleConn = nil

local function cleanupQTE()
    CurrentScriptID = CurrentScriptID + 1 -- Invalidates any running loop threads instantly
    if networkConn then
        networkConn:Disconnect()
        networkConn = nil
    end
end

function QTE.Init(State)
    local toggleObject = State.Toggles.QTE

    local function handleToggleChange()
        local isEnabled = toggleObject.Value

        if isEnabled and Event then
            if not networkConn then
                local remoteTarget = nil

                networkConn = Event.OnClientEvent:Connect(function(mode, targetEvent)
                    if typeof(mode) ~= "string" or mode ~= "QTE" then return end
                    if typeof(targetEvent) ~= "Instance" or not targetEvent:IsA("RemoteEvent") then return end
                    if not targetEvent:IsDescendantOf(CharactersFolder) then return end

                    remoteTarget = targetEvent

                    local child = PlayerGui:WaitForChild("QTE", 5)
                    if not child then return end

                    -- Capture execution state scope
                    CurrentScriptID = CurrentScriptID + 1
                    local memScriptID = CurrentScriptID

                    task.spawn(function()
                        local currentDelay = QTE.InitialDelay
                        local startTime = os.clock()

                        while memScriptID == CurrentScriptID do
                            if child.Parent ~= PlayerGui then break end
                            if not remoteTarget or not remoteTarget.Parent then break end

                            local healthFolder = child:FindFirstChild("Health")
                            local healthBar = healthFolder and healthFolder:FindFirstChild("Bar1")
                            if not healthBar then break end

                            local currentScale = healthBar.Size.X.Scale

                            if currentScale > 0.65 then
                                task.wait()
                                continue
                            end

                            if (os.clock() - startTime > 5) and currentScale < 0.55 then
                                remoteTarget:FireServer(true)
                                task.wait()
                                continue
                            end

                            remoteTarget:FireServer(true)
                            
                            task.wait(currentDelay)
                            currentDelay = m_max(QTE.MinimumDelay, currentDelay - QTE.RampSpeed)
                        end
                    end)
                end)
            end
        else
            cleanupQTE()
        end
    end

    toggleConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleToggleChange)
    table_insert(State.Connections, toggleConn)

    handleToggleChange()
end

return QTE
