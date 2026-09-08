local Rejoin = {}

local cloneref = cloneref
local game = game
local Players = cloneref(game:GetService("Players"))
local TeleportService = cloneref(game:GetService("TeleportService"))

local lp = Players.LocalPlayer
local teleporting = false

function Rejoin.Clicked()
    if not lp then lp = Players.LocalPlayer end
    if teleporting then return end
    teleporting = true
    
    local placeId = game.PlaceId
    local jobId = game.JobId

    TeleportService.TeleportInitFailed:Connect(function(p)
        if p == lp then TeleportService:Teleport(placeId, lp) end
    end)

    if #Players:GetPlayers() <= 1 or jobId == "" then
        TeleportService:Teleport(placeId, lp)
    else
        TeleportService:TeleportToPlaceInstance(placeId, jobId, lp)
    end
end

return Rejoin
