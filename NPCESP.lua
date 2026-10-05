local NPCESP = {}
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local LocalPlayer = Players.LocalPlayer
local Types = {
    ["Transfigured Human"] = "NPCTransfiguredHuman",
    KuroClone = "NPCKuroClone",
    HarutaSwordNPC = "NPCHarutaSword",
}
local Corners = {
    Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1),
    Vector3.new(1, 1, -1), Vector3.new(-1, 1, -1),
    Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1),
    Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1),
}
local Edges = {{1, 2}, {2, 3}, {3, 4}, {4, 1}, {5, 6}, {6, 7}, {7, 8}, {8, 5}, {1, 5}, {2, 6}, {3, 7}, {4, 8}}
local Green, Red = Color3.fromRGB(48, 209, 88), Color3.fromRGB(255, 69, 58)

local function owner(NPC)
    if NPC.Name == "Transfigured Human" then
        local Name = NPC:GetAttribute("Owner")
        return type(Name) == "string" and Players:FindFirstChild(Name) or nil
    end
    local Value = NPC:FindFirstChild("Owner")
    local Player = Value and Value:IsA("ObjectValue") and Value.Value
    return Player and Player:IsA("Player") and Player or nil
end

local function removeBox(Lines)
    for _, Line in ipairs(Lines) do Line:Remove() end
end

local function clearBoxes(Entry)
    for Part, Lines in pairs(Entry.Boxes) do
        removeBox(Lines)
        Entry.Boxes[Part] = nil
    end
    Entry.Dirty = true
end

local function updateParts(NPC, Entry)
    local Sword = NPC:FindFirstChild("HarutaSword")
    local Hand = Sword and Sword:FindFirstChild("Hand")
    local Parts = {}
    if Sword then
        if Sword:IsA("BasePart") then Parts[Sword] = true end
        for _, Part in ipairs(Sword:GetDescendants()) do
            if Part:IsA("BasePart") and not (Hand and Hand:IsA("Model") and Part:IsDescendantOf(Hand)) then
                Parts[Part] = true
            end
        end
        if Hand and Hand:IsA("Model") and Hand:FindFirstChildWhichIsA("BasePart", true) then Parts[Hand] = true end
    end
    for Part, Lines in pairs(Entry.Boxes) do
        if not Parts[Part] then removeBox(Lines); Entry.Boxes[Part] = nil end
    end
    for Part in pairs(Parts) do
        if not Entry.Boxes[Part] then
            local Lines = {}
            for i = 1, 12 do
                local Line = Drawing.new("Line")
                Line.Thickness, Line.Transparency, Line.Visible = 1.5, 1, false
                Lines[i] = Line
            end
            Entry.Boxes[Part] = Lines
        end
    end
    Entry.Dirty = false
end

local function drawBox(Camera, Part, Lines, Color)
    local CF, Size
    if Part:IsA("Model") then CF, Size = Part:GetBoundingBox()
    else CF, Size = Part.CFrame, Part.Size end
    local Points = {}
    for i, Corner in ipairs(Corners) do
        local P = Camera:WorldToViewportPoint(CF * (Corner * Size * 0.5))
        if P.Z > 0 then Points[i] = Vector2.new(P.X, P.Y) end
    end
    for i, Edge in ipairs(Edges) do
        local A, B = Points[Edge[1]], Points[Edge[2]]
        local Line = Lines[i]
        Line.Visible = A ~= nil and B ~= nil
        if A and B then Line.From, Line.To, Line.Color = A, B, Color end
    end
end

function NPCESP.Init(State)
    local Characters = workspace:WaitForChild("Characters")
    local Cache, RenderConnection = {}, nil
    local function add(NPC)
        if not Types[NPC.Name] or Cache[NPC] then return end
        local Entry = {Boxes = {}, Dirty = true, Connections = {}}
        Cache[NPC] = Entry
        if NPC.Name == "HarutaSwordNPC" then
            local function changed() Entry.Dirty = true end
            Entry.Connections = {
                NPC.DescendantAdded:Connect(changed),
                NPC.DescendantRemoving:Connect(changed),
            }
        end
    end
    local function remove(NPC)
        local Entry = Cache[NPC]
        if not Entry then return end
        if Entry.Text then Entry.Text:Remove() end
        clearBoxes(Entry)
        for _, Connection in ipairs(Entry.Connections) do Connection:Disconnect() end
        Cache[NPC] = nil
    end
    for _, NPC in ipairs(Characters:GetChildren()) do add(NPC) end
    table.insert(State.Connections, Characters.ChildAdded:Connect(add))
    table.insert(State.Connections, Characters.ChildRemoved:Connect(remove))

    local function render()
        local Camera = workspace.CurrentCamera
        for NPC, Entry in pairs(Cache) do
            local Owner = owner(NPC)
            local Labels = Camera and State.Toggles.NPCOwnerESP.Value and State.Toggles[Types[NPC.Name]].Value
            if Labels and Owner then
                local Root = NPC:FindFirstChild("Head") or NPC:FindFirstChild("HumanoidRootPart") or NPC.PrimaryPart
                local Point, Visible
                if Root and Root:IsA("BasePart") then
                    Point, Visible = Camera:WorldToViewportPoint(Root.Position + Vector3.new(0, 2, 0))
                end
                if not Entry.Text then
                    Entry.Text = Drawing.new("Text")
                    Entry.Text.Size, Entry.Text.Center, Entry.Text.Outline = 13, true, true
                    Entry.Text.Color = Color3.fromRGB(255, 255, 255)
                end
                Entry.Text.Visible = Visible == true
                if Visible then
                    Entry.Text.Text = Owner.Name
                    Entry.Text.Position = Vector2.new(Point.X, Point.Y)
                end
            elseif Entry.Text then Entry.Text.Visible = false end

            if NPC.Name == "HarutaSwordNPC" and Camera and State.Toggles.HarutaSwordESP.Value then
                if Entry.Dirty then updateParts(NPC, Entry) end
                local Color = Owner == LocalPlayer and Green or Red
                for Part, Lines in pairs(Entry.Boxes) do drawBox(Camera, Part, Lines, Color) end
            elseif next(Entry.Boxes) then clearBoxes(Entry) end
        end
    end
    local function toggle()
        local Labels = State.Toggles.NPCOwnerESP.Value and (
            State.Toggles.NPCTransfiguredHuman.Value or State.Toggles.NPCKuroClone.Value or State.Toggles.NPCHarutaSword.Value)
        local Enabled = Labels or State.Toggles.HarutaSwordESP.Value
        if Enabled and not RenderConnection then
            RenderConnection = RunService.RenderStepped:Connect(render)
            table.insert(State.Connections, RenderConnection)
        elseif not Enabled and RenderConnection then
            RenderConnection:Disconnect()
            RenderConnection = nil
        end
        render()
    end
    for _, Key in ipairs({"NPCOwnerESP", "NPCTransfiguredHuman", "NPCKuroClone", "NPCHarutaSword", "HarutaSwordESP"}) do
        table.insert(State.Connections, State.Toggles[Key].Changed:Connect(toggle))
    end
    toggle()
end

return NPCESP
