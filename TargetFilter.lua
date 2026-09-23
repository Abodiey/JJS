local TargetFilter = {}
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local Blacklist = {EarthenInsect = true, HarutaSwordNPC = true, FrameNPC = true, MechamaruBot = true}

function TargetFilter.IsValid(character, teamCheck, allowBlocking)
    if typeof(character) ~= "Instance" or not character.Parent or character == LocalPlayer.Character
        or Blacklist[character.Name] or character:GetAttribute("Dead") then return false end
    if character.Name == "KuroClone" then
        local owner = character:FindFirstChild("Owner")
        if not owner or owner.Value == LocalPlayer then return false end
    end
    local info = character:FindFirstChild("Info")
    if not character:FindFirstChild("HumanoidRootPart") or not info or (not allowBlocking and info:FindFirstChild("Block")) then return false end
    if teamCheck and LocalPlayer.Team then
        local player = Players:GetPlayerFromCharacter(character)
        if player and player.Team == LocalPlayer.Team then return false end
    end
    return true
end

return TargetFilter
