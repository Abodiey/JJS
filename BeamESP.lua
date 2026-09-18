local BeamESP = {}

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))

local RYU_PREDICTED_DELAY = 3.3333
local YUTA_PREDICTION_LIFETIME = 4
local CHOSO_PREDICTION_LIFETIME = 2.25

local RYU_BEAM_LENGTH = 180
local RYU_BEAM_WIDTH = 35

local YUTA_BEAM_LENGTH = 180
local YUTA_BEAM_WIDTH = 35

local CHOSO_BEAM_LENGTH = 120
local CHOSO_BEAM_WIDTH = 20

local EDGES = {
    {1, 2}, {2, 4}, {4, 3}, {3, 1},
    {5, 6}, {6, 8}, {8, 7}, {7, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8}
}

local function sanitizeWidth(width)
    if typeof(width) == "Vector2" then
        return math.max(width.X, width.Y)
    elseif typeof(width) == "number" then
        return width
    end

    return 0
end


function BeamESP.Init(State)
    local Camera = workspace.CurrentCamera
    local function getBeamCorners(beamCF, width, length)
        local halfWidth = width / 2
        local endCF = beamCF + beamCF.LookVector * length

        return {
            beamCF:PointToWorldSpace(Vector3.new(-halfWidth, -halfWidth, 0)),
            beamCF:PointToWorldSpace(Vector3.new(halfWidth, -halfWidth, 0)),
            beamCF:PointToWorldSpace(Vector3.new(-halfWidth, halfWidth, 0)),
            beamCF:PointToWorldSpace(Vector3.new(halfWidth, halfWidth, 0)),

            endCF:PointToWorldSpace(Vector3.new(-halfWidth, -halfWidth, 0)),
            endCF:PointToWorldSpace(Vector3.new(halfWidth, -halfWidth, 0)),
            endCF:PointToWorldSpace(Vector3.new(-halfWidth, halfWidth, 0)),
            endCF:PointToWorldSpace(Vector3.new(halfWidth, halfWidth, 0))
        }
    end

    local function clipLineToViewport(a, b)
        local viewport = Camera.ViewportSize
        local xMin, yMin = 0, 0
        local xMax, yMax = viewport.X, viewport.Y

        local dx = b.X - a.X
        local dy = b.Y - a.Y

        local u1 = 0
        local u2 = 1

        local function clip(p, q)
            if p == 0 then
                return q >= 0
            end

            local t = q / p

            if p < 0 then
                if t > u2 then
                    return false
                end

                if t > u1 then
                    u1 = t
                end
            else
                if t < u1 then
                    return false
                end

                if t < u2 then
                    u2 = t
                end
            end

            return true
        end

        if not clip(-dx, a.X - xMin) then return nil end
        if not clip(dx, xMax - a.X) then return nil end
        if not clip(-dy, a.Y - yMin) then return nil end
        if not clip(dy, yMax - a.Y) then return nil end

        return Vector2.new(
            a.X + u1 * dx,
            a.Y + u1 * dy
        ), Vector2.new(
            a.X + u2 * dx,
            a.Y + u2 * dy
        )
    end

    local function projectBeamLine(worldA, worldB)
        local cameraCF = Camera.CFrame

        local cameraA = cameraCF:PointToObjectSpace(worldA)
        local cameraB = cameraCF:PointToObjectSpace(worldB)

        local nearZ = -0.05

        local behindA = cameraA.Z > nearZ
        local behindB = cameraB.Z > nearZ

        if behindA and behindB then
            return nil
        end

        if behindA ~= behindB then
            local t = (nearZ - cameraA.Z) / (cameraB.Z - cameraA.Z)
            local clipped = cameraA:Lerp(cameraB, t)

            if behindA then
                cameraA = clipped
            else
                cameraB = clipped
            end

            worldA = cameraCF:PointToWorldSpace(cameraA)
            worldB = cameraCF:PointToWorldSpace(cameraB)
        end

        local pointA = Camera:WorldToViewportPoint(worldA)
        local pointB = Camera:WorldToViewportPoint(worldB)

        local a = Vector2.new(pointA.X, pointA.Y)
        local b = Vector2.new(pointB.X, pointB.Y)

        return clipLineToViewport(a, b)
    end


    local toggleObject = State.Toggles.BeamESP
    local activeBoxes = {}
    local actualBoxes = {}
    local yutaPredictionBox
    local chosoPredictionBoxes = {}
    local renderConnection
    local render

    local function remove3DBox(box)
        if not box or not activeBoxes[box] then return end
        activeBoxes[box] = nil
        if yutaPredictionBox == box then yutaPredictionBox = nil end
        if box.character then chosoPredictionBoxes[box.character] = nil end
        if box.beamInfo then actualBoxes[box.beamInfo] = nil end
        for _, connection in ipairs(box.connections) do connection:Disconnect() end
        for _, line in ipairs(box.lines) do line:Remove() end
        if not next(activeBoxes) and renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
            State.Connections.BeamESPRender = nil
        end
    end

    local function create3DBox(color)
        local box = {lines = {}, connections = {}, cframe = CFrame.new(), width = 1, length = 1}
        for i = 1, 12 do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Color = color
            line.Thickness = 2
            line.Transparency = 1
            box.lines[i] = line
        end
        activeBoxes[box] = true
        if not renderConnection then
            renderConnection = RunService.RenderStepped:Connect(render)
            State.Connections.BeamESPRender = renderConnection
        end
        return box
    end

    local function drawBox(box, now)
        if box.expireTime and now >= box.expireTime then remove3DBox(box); return end
        if box.beamInfo and not box.beamInfo:IsDescendantOf(workspace) then remove3DBox(box); return end
        local follow = box.followRoot or box.followPart or box.followAttachment
        if follow then
            if not follow.Parent then remove3DBox(box); return end
            if box.followRoot then box.cframe = follow.CFrame * CFrame.new(0, 2.010, -1.000)
            elseif box.followPart then box.cframe = follow.CFrame
            else box.cframe = follow.WorldCFrame end
        end
        if not Camera or box.waiting then
            for _, line in ipairs(box.lines) do line.Visible = false end
            return
        end
        local corners = getBeamCorners(box.cframe, box.width, box.length)
        for i, edge in ipairs(EDGES) do
            local line = box.lines[i]
            local from, to = projectBeamLine(corners[edge[1]], corners[edge[2]])
            line.Visible = from ~= nil and to ~= nil
            if from and to then line.From = from; line.To = to end
        end
    end

    render = function()
        Camera = workspace.CurrentCamera
        local now = time()
        for box in pairs(activeBoxes) do drawBox(box, now) end
    end

    table.insert(State.Connections, toggleObject:GetPropertyChangedSignal("Value"):Connect(function()
        if not toggleObject.Value then
            for box in pairs(activeBoxes) do remove3DBox(box) end
        end
    end))

    local Services = ReplicatedStorage:WaitForChild("Knit"):WaitForChild("Knit"):WaitForChild("Services")
    local function listen(Service, Callback)
        local Event = Services:WaitForChild(Service):WaitForChild("RE"):WaitForChild("Effects")
        table.insert(State.Connections, Event.OnClientEvent:Connect(function(...)
            if toggleObject.Value then Callback(...) end
        end))
    end

    listen("RyuService", function(action, character)
        if action ~= "UltimateCharge" or typeof(character) ~= "Instance" or not character:IsA("Model") then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then return end
        local box = create3DBox(Color3.fromRGB(255, 170, 0))
        box.width, box.length = RYU_BEAM_WIDTH, RYU_BEAM_LENGTH
        box.followRoot = root
        box.expireTime = time() + RYU_PREDICTED_DELAY + 0.35
    end)

    listen("LoveBeamService", function(action, chargeBall)
        if action ~= "Track" or typeof(chargeBall) ~= "Instance" or not chargeBall:IsA("BasePart") then return end
        if yutaPredictionBox then
            if yutaPredictionBox.followPart == chargeBall then
                yutaPredictionBox.expireTime = time() + YUTA_PREDICTION_LIFETIME
                return
            end
            remove3DBox(yutaPredictionBox)
        end
        local box = create3DBox(Color3.fromRGB(255, 105, 180))
        box.width, box.length = YUTA_BEAM_WIDTH, YUTA_BEAM_LENGTH
        box.followPart = chargeBall
        box.expireTime = time() + YUTA_PREDICTION_LIFETIME
        yutaPredictionBox = box
    end)

    listen("PlasmaWaveService", function(action, character, attachment)
        if action ~= "Startup" or typeof(character) ~= "Instance" or not character:IsA("Model") then return end
        if typeof(attachment) ~= "Instance" or not attachment:IsA("Attachment") then return end
        local box = chosoPredictionBoxes[character] or create3DBox(Color3.fromRGB(120, 170, 255))
        box.width, box.length = CHOSO_BEAM_WIDTH, CHOSO_BEAM_LENGTH
        box.followAttachment = attachment
        box.expireTime = time() + CHOSO_PREDICTION_LIFETIME
        box.character = character
        chosoPredictionBoxes[character] = box
    end)

    listen("BeamService", function(action, beamInfo)
        if action ~= "StartBeam" or typeof(beamInfo) ~= "Instance" or actualBoxes[beamInfo] then return end
        if not beamInfo:IsDescendantOf(workspace) then return end
        local box = create3DBox(Color3.fromRGB(255, 0, 0))
        box.beamInfo = beamInfo
        box.length, box.width = RYU_BEAM_LENGTH, RYU_BEAM_WIDTH
        box.waiting = true
        actualBoxes[beamInfo] = box
        local function update()
            local cf = beamInfo:GetAttribute("BeamStartCFrame")
            if typeof(cf) == "CFrame" then box.cframe = cf; box.waiting = false end
            local length = beamInfo:GetAttribute("BeamLength")
            if typeof(length) == "number" then box.length = math.max(box.length, length) end
            box.width = math.max(box.width, sanitizeWidth(beamInfo:GetAttribute("Width")))
        end
        for _, name in ipairs({"BeamStartCFrame", "BeamLength", "Width"}) do
            table.insert(box.connections, beamInfo:GetAttributeChangedSignal(name):Connect(update))
        end
        update()
    end)

end

return BeamESP
