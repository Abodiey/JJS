local DummyESP = {}

local Characters = workspace:WaitForChild("Characters")
local RunService = game:GetService("RunService")

-- Pre-allocated streamproof drawing instance
local box = Drawing.new("Square")
box.Thickness = 2
box.Filled = false
box.Transparency = 1
box.Color = Color3.fromRGB(0, 255, 0)
box.Visible = false

local childAddedConn = nil
local childRemovedConn = nil
local attributeConn = nil
local toggleConn = nil
local renderConn = nil
local hrpAncestryConn = nil

local currentDummy = nil
local currentHRP = nil

local function updateESPColor()
    if not currentDummy then return end
    
    if currentDummy:GetAttribute("Dead") == true then
        box.Color = Color3.fromRGB(255, 0, 0)
    else
        box.Color = Color3.fromRGB(0, 255, 0)
    end
end

local function bindToHRP(hrp)
    if hrpAncestryConn then
        hrpAncestryConn:Disconnect()
        hrpAncestryConn = nil
    end

    currentHRP = hrp
    if hrp then
        hrpAncestryConn = hrp.AncestryChanged:Connect(function(_, parent)
            if not parent then
                currentHRP = nil
                box.Visible = false
            end
        end)
    end
end

local function refreshTargetDummy()
    if attributeConn then
        attributeConn:Disconnect()
        attributeConn = nil
    end

    local children = Characters:GetChildren()
    local targetDummy = nil

    for i = #children, 1, -1 do
        local child = children[i]
        if child and child.Name == "Dummy" then
            targetDummy = child
            break
        end
    end

    if targetDummy then
        currentDummy = targetDummy
        updateESPColor()

        attributeConn = targetDummy:GetAttributeChangedSignal("Dead"):Connect(updateESPColor)

        -- Check if HRP exists immediately, otherwise listen for it dynamically
        local hrp = targetDummy:FindFirstChild("HumanoidRootPart")
        if hrp then
            bindToHRP(hrp)
        else
            bindToHRP(nil)
            task.spawn(function()
                local foundHRP = targetDummy:WaitForChild("HumanoidRootPart", 15)
                if currentDummy == targetDummy and foundHRP then
                    bindToHRP(foundHRP)
                end
            end)
        end
    else
        currentDummy = nil
        bindToHRP(nil)
        box.Visible = false
    end
end

local function cleanupESP()
    if childAddedConn then childAddedConn:Disconnect() childAddedConn = nil end
    if childRemovedConn then childRemovedConn:Disconnect() childRemovedConn = nil end
    if attributeConn then attributeConn:Disconnect() attributeConn = nil end
    if renderConn then renderConn:Disconnect() renderConn = nil end
    if hrpAncestryConn then hrpAncestryConn:Disconnect() hrpAncestryConn = nil end

    currentDummy = nil
    currentHRP = nil
    box.Visible = false
end

function DummyESP.Init(State)
    local toggleObject = State.Toggles.DummyESP

    -- Dedicated render connection
    renderConn = RunService.RenderStepped:Connect(function()
        if not toggleObject.Value then
            box.Visible = false
            return
        end

        -- Auto-retry finding HRP if dummy exists but HRP was lost during respawn
        if currentDummy and (not currentHRP or not currentHRP.Parent) then
            local hrp = currentDummy:FindFirstChild("HumanoidRootPart")
            if hrp then
                bindToHRP(hrp)
            else
                box.Visible = false
                return
            end
        end

        if not currentHRP then
            box.Visible = false
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then 
            box.Visible = false
            return 
        end

        local hrpPos = currentHRP.Position
        local screenPos, onScreen = camera:WorldToViewportPoint(hrpPos)

        if onScreen and screenPos.Z > 0 then
            local distance = (camera.CFrame.Position - hrpPos).Magnitude
            local factor = 1000 / math.max(distance, 1)
            local width = math.clamp(4 * factor, 10, 300)
            local height = math.clamp(6 * factor, 15, 450)

            box.Size = Vector2.new(width, height)
            box.Position = Vector2.new(screenPos.X - (width * 0.5), screenPos.Y - (height * 0.5))
            box.Visible = true
        else
            box.Visible = false
        end
    end)
    table.insert(State.Connections, renderConn)

    local function handleStateChange()
        if toggleObject.Value then
            refreshTargetDummy()

            if not childAddedConn then
                childAddedConn = Characters.ChildAdded:Connect(function(child)
                    if child and child.Name == "Dummy" then
                        refreshTargetDummy()
                    end
                end)
            end

            if not childRemovedConn then
                childRemovedConn = Characters.ChildRemoved:Connect(function(child)
                    if child and child.Name == "Dummy" then
                        task.defer(refreshTargetDummy)
                    end
                end)
            end
        else
            cleanupESP()
        end
    end

    toggleConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleStateChange)
    table.insert(State.Connections, toggleConn)

    handleStateChange()
end

return DummyESP
