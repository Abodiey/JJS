local ItemESP = {}

-- Localize Services & Core API
local cloneref = cloneref or function(o) return o end
local game = game
local RunService = cloneref(game:GetService("RunService"))
local workspace = cloneref(game:GetService("Workspace"))

-- Localize Global Engine Functions
local task = task
local t_wait = task.wait
local type = type
local tostring = tostring
local ipairs = ipairs
local pairs = pairs
local table = table
local table_insert = table.insert
local table_clear = table.clear

-- Localize Math & String Libraries
local math = math
local m_clamp = math.clamp
local m_floor = math.floor
local string = string
local s_format = string.format

-- Localize Roblox Datatypes
local Vector3 = Vector3
local v3_new = Vector3.new
local Vector2 = Vector2
local v2_new = Vector2.new
local Color3 = Color3
local c3_new = Color3.new

local Cache = {}
local itemsFolder = workspace:WaitForChild("Items")

-- Connection trackers
local loopConn = nil

-- Design Palette Constants matching PlayerESP
local COLOR_WHITE = c3_new(1, 1, 1)
local COLOR_BLACK = c3_new(0, 0, 0)
local COLOR_CYAN = c3_new(0, 0.8, 1)
local COLOR_YELLOW = c3_new(1, 1, 0)
local COLOR_RED = c3_new(1, 0.1, 0.1)

local function getGradientColor(percent)
    percent = m_clamp(percent, 0, 1)
    if percent > 0.5 then
        return COLOR_YELLOW:Lerp(COLOR_CYAN, (percent - 0.5) * 2)
    end
    return COLOR_RED:Lerp(COLOR_YELLOW, percent * 2)
end

local function CreateESP()
    local textDrawing = Drawing.new("Text")
    textDrawing.Size = 13
    textDrawing.Center = true
    textDrawing.Outline = true
    textDrawing.OutlineColor = COLOR_BLACK
    textDrawing.Color = COLOR_CYAN
    textDrawing.Visible = false

    return {
        Text = textDrawing
    }
end

local function DestroyESP(assets)
    if assets and assets.Text then
        assets.Text.Visible = false
        if assets.Text.Remove then
            assets.Text:Remove()
        elseif assets.Text.Destroy then
            assets.Text:Destroy()
        end
    end
end

function ItemESP.Init(State)
    local toggleObject = State.Toggles.ItemESP

    local function handleToggleChange()
        local isEnabled = toggleObject.Value

        if isEnabled then
            if not loopConn then
                loopConn = RunService.RenderStepped:Connect(function()
                    if not itemsFolder then return end

                    local cam = workspace.CurrentCamera
                    if not cam then return end

                    local camPos = cam.CFrame.Position
                    local currentItems = itemsFolder:GetChildren()
                    local activeIds = {}

                    -- Stacking lookup tracker using rounded world coordinates
                    local positionCounts = {}

                    for i = 1, #currentItems do
                        local item = currentItems[i]
                        local id = item:GetDebugId()
                        activeIds[id] = true

                        local c = Cache[id]
                        local part = item:IsA("BasePart") and item or item:FindFirstChildOfClass("BasePart")

                        if part then
                            if not c then
                                c = CreateESP()
                                Cache[id] = c
                            end

                            local pos = part.Position
                            local posKey = s_format("%d_%d_%d", m_floor(pos.X * 0.5), m_floor(pos.Y * 0.5), m_floor(pos.Z * 0.5))

                            local stackIndex = positionCounts[posKey] or 0
                            positionCounts[posKey] = stackIndex + 1

                            -- Calculate vertical staggering offset in 3D space
                            local worldPosOffset = pos + v3_new(0, 0.5 + (stackIndex * 1.5), 0)
                            local screenPos, onScreen = cam:WorldToViewportPoint(worldPosOffset)

                            if onScreen then
                                local dist = (pos - camPos).Magnitude
                                local distCol = getGradientColor(dist / 400)

                                c.Text.Position = v2_new(screenPos.X, screenPos.Y)
                                c.Text.Text = s_format("%s\n[%dm]", item.Name, m_floor(dist))
                                c.Text.Color = distCol
                                c.Text.Visible = true
                            else
                                c.Text.Visible = false
                            end
                        elseif c then
                            c.Text.Visible = false
                        end
                    end

                    -- Cleanup elements that no longer exist
                    for id, assets in pairs(Cache) do
                        if not activeIds[id] then
                            DestroyESP(assets)
                            Cache[id] = nil
                        end
                    end
                end)
            end
        else
            -- Disconnect loop when disabled
            if loopConn then
                loopConn:Disconnect()
                loopConn = nil
            end

            -- Clear drawing elements from memory
            for id, assets in pairs(Cache) do
                DestroyESP(assets)
            end
            table_clear(Cache)
        end
    end

    local toggleConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleToggleChange)
    table_insert(State.Connections, toggleConn)

    handleToggleChange()
end

return ItemESP
