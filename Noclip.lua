local Noclip = {}

local charFolder = workspace:WaitForChild("Characters")
local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))
local localPlayer = Players.LocalPlayer

local TARGET_NAMES = {
    Head = true,
    Torso = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    Collide = true,
    Mask = true,
}

-- Only these parts are checked each frame. The old version rescanned every
-- character and every child on every frame.
local trackedParts = {}
local originalCollision = {}
local characterStates = {}

local runtimeConnections = {}
local enabled = false

local function disconnect(connection)
    if connection then
        connection:Disconnect()
    end
end

local function rememberOriginalState(part)
    if originalCollision[part] == nil then
        originalCollision[part] = part.CanCollide and 1 or 0
    end
end

local function trackPart(part, character, canCollide)
    if not part or not part.Parent or not part:IsA("BasePart") then
        return
    end

    rememberOriginalState(part)
    trackedParts[part] = {
        character = character,
        canCollide = canCollide,
    }

    local characterState = characterStates[character]
    if enabled and characterState and not characterState.dead and part.CanCollide ~= canCollide then
        part.CanCollide = canCollide
    end
end

local function untrackCharacter(character, discardOriginal)
    for part, state in pairs(trackedParts) do
        if state.character == character then
            trackedParts[part] = nil
            if discardOriginal then
                originalCollision[part] = nil
            end
        end
    end
end

local function trackNormalPart(part, character, moveset)
    if not part:IsA("BasePart") then
        return
    end

    local parent = part.Parent

    if parent == character and TARGET_NAMES[part.Name] then
        trackPart(part, character, false)
        return
    end

    -- Some body parts contain an additional collision part.
    if part.Name == "Collide"
        and parent
        and parent.Parent == character
        and TARGET_NAMES[parent.Name]
    then
        trackPart(part, character, false)
        return
    end

    if moveset == "Gojo"
        and part.Name == "Mask"
        and parent
        and parent.Name == "GojoMask"
        and parent.Parent
        and parent.Parent.Name == "SetAssets"
        and parent.Parent.Parent == character
    then
        trackPart(part, character, false)
    elseif moveset == "Hanami"
        and part.Name == "ArmWrap"
        and parent
        and parent.Name == "SetAssets"
        and parent.Parent == character
    then
        trackPart(part, character, false)
    end
end

local function rebuildCharacter(character)
    local state = characterStates[character]
    if not state or state.dead or character == localPlayer.Character or not character.Parent then
        return
    end

    untrackCharacter(character)

    if character.Name == "FrameNPC" then
        local torso = character:FindFirstChild("Torso")
        if torso then
            trackPart(torso, character, false)
        else
            character:Destroy()
        end
        return
    end

    if character.Name == "MechamaruBot" then
        trackPart(character:FindFirstChild("Torso"), character, true)
        trackPart(character:FindFirstChild("Head"), character, false)
        return
    end

    if character.Name == "HarutaSwordNPC" then
        local sword = character:FindFirstChild("HarutaSword")
        local hand = sword and sword:FindFirstChild("Hand")
        trackPart(hand and hand:FindFirstChild("Handle"), character, false)
        return
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        trackNormalPart(descendant, character, state.moveset)
    end
end

local function removeCharacter(character)
    local state = characterStates[character]
    if not state then
        return
    end

    disconnect(state.deadChanged)
    disconnect(state.movesetChanged)
    disconnect(state.descendantAdded)
    disconnect(state.descendantRemoving)

    untrackCharacter(character, true)
    characterStates[character] = nil
end

local function addCharacter(character)
    if character == localPlayer.Character or characterStates[character] then
        return
    end

    local state = {
        dead = character:GetAttribute("Dead") == true,
        moveset = character:GetAttribute("Moveset"),
    }
    characterStates[character] = state

    state.deadChanged = character:GetAttributeChangedSignal("Dead"):Connect(function()
        state.dead = character:GetAttribute("Dead") == true
        if not state.dead then
            rebuildCharacter(character)
        end
    end)

    state.movesetChanged = character:GetAttributeChangedSignal("Moveset"):Connect(function()
        state.moveset = character:GetAttribute("Moveset")
        rebuildCharacter(character)
    end)

    state.descendantAdded = character.DescendantAdded:Connect(function(descendant)
        if state.dead then
            return
        end

        if character.Name == "FrameNPC"
            or character.Name == "MechamaruBot"
            or character.Name == "HarutaSwordNPC"
        then
            rebuildCharacter(character)
        elseif descendant:IsA("BasePart") then
            trackNormalPart(descendant, character, state.moveset)
        end
    end)

    state.descendantRemoving = character.DescendantRemoving:Connect(function(descendant)
        trackedParts[descendant] = nil
        originalCollision[descendant] = nil
    end)

    rebuildCharacter(character)
end

local function stopNoclip()
    enabled = false

    for _, connection in ipairs(runtimeConnections) do
        disconnect(connection)
    end
    table.clear(runtimeConnections)

    for part, originalState in pairs(originalCollision) do
        if part and part.Parent then
            part.CanCollide = originalState == 1
        end
    end

    for character in pairs(characterStates) do
        removeCharacter(character)
    end

    table.clear(trackedParts)
    table.clear(originalCollision)
end

local function startNoclip()
    if enabled then
        return
    end

    enabled = true

    runtimeConnections[#runtimeConnections + 1] = charFolder.ChildAdded:Connect(addCharacter)
    runtimeConnections[#runtimeConnections + 1] = charFolder.ChildRemoved:Connect(removeCharacter)

    for _, character in ipairs(charFolder:GetChildren()) do
        addCharacter(character)
    end

    runtimeConnections[#runtimeConnections + 1] = RunService.Stepped:Connect(function()
        for part, state in pairs(trackedParts) do
            local characterState = characterStates[state.character]

            if not part.Parent or not characterState then
                trackedParts[part] = nil
                originalCollision[part] = nil
            elseif state.character == localPlayer.Character then
                part.CanCollide = originalCollision[part] == 1
                trackedParts[part] = nil
                originalCollision[part] = nil
            elseif not characterState.dead and part.CanCollide ~= state.canCollide then
                part.CanCollide = state.canCollide
            end
        end
    end)
end

function Noclip.Init(State)
    local toggle = State.Toggles.Noclip

    local toggleConnection = toggle:GetPropertyChangedSignal("Value"):Connect(function()
        if toggle.Value then
            startNoclip()
        else
            stopNoclip()
        end
    end)
    table.insert(State.Connections, toggleConnection)

    if toggle.Value then
        startNoclip()
    end
end

return Noclip
