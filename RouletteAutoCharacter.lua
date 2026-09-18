local RouletteAutoCharacter = {}

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Players = cloneref(game:GetService("Players"))

RouletteAutoCharacter.Modes = {
    {Name = "Brain Swap", Code = "SWP"},
    {Name = "Sorcery Clash", Code = "SRC"},
    {Name = "First to Twelve", Code = "FTT"},
    {Name = "Final Showdown", Code = "FSD"},
    {Name = "End of Journey", Code = "EOJ"},
    {Name = "Perfection Tag", Code = "PFT"},
    {Name = "American Shenanigans", Code = "AMS"},
    {Name = "Prison Realm", Code = "PSR"},
    {Name = "Soul Swap", Code = "SSP"},
}

function RouletteAutoCharacter.Init(State)
    local LocalPlayer = Players.LocalPlayer
    local Services = ReplicatedStorage:WaitForChild("Knit"):WaitForChild("Knit"):WaitForChild("Services")
    local Effects = Services:WaitForChild("RouletteService"):WaitForChild("RE"):WaitForChild("Effects")
    local Change = Services:WaitForChild("JoinService"):WaitForChild("RE"):WaitForChild("Change")
    local UltNames = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UltNames"))
    local Characters = {}
    local ValidCharacters = {}
    for Name in pairs(UltNames) do
        if type(Name) == "string" then
            Characters[#Characters + 1] = Name
            ValidCharacters[Name] = true
        end
    end
    table.sort(Characters)
    RouletteAutoCharacter.Characters = Characters
    State.RouletteCharacters = State.RouletteCharacters or {}
    local Aliases = {}
    for _, Mode in ipairs(RouletteAutoCharacter.Modes) do Aliases[Mode.Code] = Mode.Name:upper() end

    table.insert(State.Connections, Effects.OnClientEvent:Connect(function(Action, Mode)
        if not State.Toggles.RouletteAutoCharacter.Value or Action ~= "Announce" or type(Mode) ~= "string" then return end
        local Name = State.RouletteCharacters[Mode] or State.RouletteCharacters[Aliases[Mode]]
        if ValidCharacters[Name] and LocalPlayer:GetAttribute("Moveset") ~= Name then
            Change:FireServer(Name)
        end
    end))
end

return RouletteAutoCharacter
