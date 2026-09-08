local Targeting = {}

-- Localize Services & Core API
local cloneref = cloneref
local game = game
local workspace = cloneref(game:GetService("Workspace"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))

-- Localize Global Engine Functions
local ipairs = ipairs
local string = string
local s_lower = string.lower
local table = table

local LocalPlayer = Players.LocalPlayer

-- Connection tracker
local loopConn = nil

-- Safely resets the camera subject back to the local character's humanoid
local function resetCamera()
    if loopConn then
        loopConn:Disconnect()
        loopConn = nil
    end

    local camera = workspace.CurrentCamera
    if not camera then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        camera.CameraSubject = hum
    end
end

-- Helper to find player via partial Name or DisplayName match
local function findTargetPlayer(searchTerm)
    if not searchTerm or searchTerm == "" then return nil end
    local cleanTerm = s_lower(searchTerm)

    local allPlayers = Players:GetPlayers()
    for i = 1, #allPlayers do
        local pl = allPlayers[i]
        if pl ~= LocalPlayer then
            if s_lower(pl.Name):find(cleanTerm, 1, true) or s_lower(pl.DisplayName):find(cleanTerm, 1, true) then
                return pl
            end
        end
    end
    return nil
end

-- Executed when the Spectate button is clicked
function Targeting.Clicked(State)
    -- Toggle behavior: if already spectating, return the camera back to our own player
    if loopConn then
        resetCamera()
        return
    end

    -- Safety check for state variable
    if not State.Variables or not State.Variables.TargetIdentifier then 
        return 
    end

    local targetPlayer = findTargetPlayer(State.Variables.TargetIdentifier.Value)
    if not targetPlayer then
        return
    end

    -- Connect updating camera alignment loop
    loopConn = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        if not camera then return end

        local targetChar = targetPlayer.Character
        if not targetChar or targetChar:GetAttribute("Dead") then resetCamera() return end
        local targetRoot = targetChar.PrimaryPart

        if targetRoot then
            if camera.CameraSubject ~= targetHum then
                camera.CameraSubject = targetHum
            end
        else
            -- Target died, left, or went invalid; return view to original player safely
            resetCamera()
        end
    end)
end

return Targeting
