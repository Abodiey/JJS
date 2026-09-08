local Aimbot = {}

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local GuiService = cloneref(game:GetService("GuiService"))

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

while not Camera do
    task.wait()
end

local MAX_ESP_DISTANCE = 500

local COLOR_DEFAULT = Color3.fromRGB(255, 0, 0)
local COLOR_IN_SKILL = Color3.fromRGB(255, 140, 0)

local R6_PART_NAMES = {
    "Head",
    "HumanoidRootPart",
    "Left Arm",
    "Right Arm",
    "Left Leg",
    "Right Leg"
}

local Blacklist = {
    ["HarutaSwordNPC"] = true, 
    ["FrameNPC"] = true, 
    ["MechamaruBot"] = true
}

local BOX_CORNERS = {
    Vector3.new(-1,  1, -1),
    Vector3.new( 1,  1, -1),
    Vector3.new( 1,  1,  1),
    Vector3.new(-1,  1,  1),
    Vector3.new(-1, -1, -1),
    Vector3.new( 1, -1, -1),
    Vector3.new( 1, -1,  1),
    Vector3.new(-1, -1,  1)
}

local EDGES = {
    {1, 2}, {2, 3}, {3, 4}, {4, 1},
    {5, 6}, {6, 7}, {7, 8}, {8, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8}
}

-- Pre-allocated line pool (6 parts x 12 lines = 72 lines)
local FixedBoxPool = table.create(#R6_PART_NAMES)
for i = 1, #R6_PART_NAMES do
    local lines = table.create(12)
    for j = 1, 12 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = COLOR_DEFAULT
        line.Thickness = 1.5
        line.Transparency = 1
        lines[j] = line
    end
    FixedBoxPool[i] = lines
end

-- Pre-allocated Target Name Text Object (White Text, Black Outline)
local TargetNameText = Drawing.new("Text")
TargetNameText.Visible = false
TargetNameText.Size = 14
TargetNameText.Center = true
TargetNameText.Outline = true
TargetNameText.OutlineColor = Color3.fromRGB(0, 0, 0)       -- Black outline
TargetNameText.Color = Color3.fromRGB(255, 255, 255)       -- White text
TargetNameText.Transparency = 1

local ScreenCornersBuffer = table.create(8)

local function HideAllBoxes()
    for i = 1, #FixedBoxPool do
        local lines = FixedBoxPool[i]
        for j = 1, 12 do
            lines[j].Visible = false
        end
    end
    TargetNameText.Visible = false
end

local function HidePartBox(lines)
    for j = 1, 12 do
        lines[j].Visible = false
    end
end

local function Draw3DPartBox(part, lines, boxColor)
    local cf = part.CFrame
    local halfSize = part.Size * 0.5
    local hX, hY, hZ = halfSize.X, halfSize.Y, halfSize.Z

    local visibleCount = 0

    for i = 1, 8 do
        local unit = BOX_CORNERS[i]
        local worldPos = cf * Vector3.new(unit.X * hX, unit.Y * hY, unit.Z * hZ)
        local pos, onScreen = Camera:WorldToViewportPoint(worldPos)
        
        if onScreen then
            ScreenCornersBuffer[i] = Vector2.new(pos.X, pos.Y)
            visibleCount = visibleCount + 1
        else
            ScreenCornersBuffer[i] = nil
        end
    end

    if visibleCount == 0 then
        HidePartBox(lines)
        return
    end

    for i = 1, 12 do
        local edge = EDGES[i]
        local p1 = ScreenCornersBuffer[edge[1]]
        local p2 = ScreenCornersBuffer[edge[2]]
        local line = lines[i]

        if p1 and p2 then
            line.From = p1
            line.To = p2
            line.Color = boxColor
            line.Visible = true
        else
            line.Visible = false
        end
    end
end

function Aimbot.Toggle(State)
    if State.Toggles.Aim.Value then 
        State.Toggles.Aim.Value = false
        State.Variables.LockedTarget.Value = nil
        HideAllBoxes()
        return 
    end

    local nearest, dist = nil, math.huge
    local inset = GuiService:GetGuiInset()
    local mousePos = UserInputService:GetMouseLocation() - inset
    local myTeam = Player.Team
    local characterFolder = workspace:FindFirstChild("Characters") or workspace
    Camera = workspace.CurrentCamera

    for _, obj in ipairs(characterFolder:GetChildren()) do
        if obj == Player.Character or obj:GetAttribute("Dead") or Blacklist[obj.Name] then continue end
        
        local hrp = obj:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        
        local targetPlayer = Players:GetPlayerFromCharacter(obj)
        if State.Toggles.TeamCheck.Value and myTeam and targetPlayer and targetPlayer.Team == myTeam then 
            continue 
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then continue end

        local mDist = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
        if mDist >= dist then continue end

        dist = mDist
        nearest = obj 
    end

    if not nearest then return end
    
    State.Variables.LockedTarget.Value = nearest
    State.Toggles.Aim.Value = true
end

function Aimbot.Init(State)
    Camera = workspace.CurrentCamera
    State.Connections = State.Connections or {}
    
    if State.Toggles.TeamCheck.Value == nil then
        State.Toggles.TeamCheck.Value = true
    end

    local removeConn = Players.PlayerRemoving:Connect(function(p)
        local currentTarget = State.Variables.LockedTarget.Value
        if currentTarget and currentTarget.Name == p.Name then
            State.Variables.LockedTarget.Value = nil
            HideAllBoxes()
        end
    end)
    table.insert(State.Connections, removeConn)

    RunService:UnbindFromRenderStep("AimbotRenderStep")
    RunService:BindToRenderStep("AimbotRenderStep", Enum.RenderPriority.Camera.Value + 1, function()
        Camera = workspace.CurrentCamera
        
        if not State.Toggles.Aim.Value then 
            HideAllBoxes() 
            return 
        end
        
        local target = State.Variables.LockedTarget.Value
        if not target or not target.Parent or target:GetAttribute("Dead") then 
            State.Variables.LockedTarget.Value = nil
            State.Toggles.Aim.Value = false
            HideAllBoxes() 
            return 
        end

        local targetPart = target:FindFirstChild("HumanoidRootPart")
        if not targetPart then
            State.Variables.LockedTarget.Value = nil
            State.Toggles.Aim.Value = false
            HideAllBoxes()
            return
        end

        local camPos = Camera.CFrame.Position
        local targetPos = targetPart.Position
        if (camPos - targetPos).Magnitude > MAX_ESP_DISTANCE then
            HideAllBoxes()
            return
        end

        Camera.CFrame = CFrame.lookAt(camPos, targetPos)

        -- Check if target is actively in a skill
        local infoFolder = target:FindFirstChild("Info")
        local isInSkill = infoFolder and infoFolder:FindFirstChild("InSkill") ~= nil
        local currentBoxColor = isInSkill and COLOR_IN_SKILL or COLOR_DEFAULT

        -- Update center target name text display
        local viewportSize = Camera.ViewportSize
        TargetNameText.Text = target.Name
        TargetNameText.Position = Vector2.new(viewportSize.X * 0.5 + 35, viewportSize.Y * 0.5 + 25)
        TargetNameText.Visible = true

        -- Render 3D boxes for parts with dynamic state color
        for i = 1, #R6_PART_NAMES do
            local child = target:FindFirstChild(R6_PART_NAMES[i])
            local lines = FixedBoxPool[i]
            
            if child and child:IsA("BasePart") then
                Draw3DPartBox(child, lines, currentBoxColor)
            else
                HidePartBox(lines)
            end
        end
    end)
end

return Aimbot
