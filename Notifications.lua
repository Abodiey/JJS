local Notifications = {}

local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local GROUP_ID = 16357742
function Notifications.Init(State)
    local Toggles = State.Toggles
    local Variables = State.Variables
    local tracked = {}

    local function enabled(name)
        return Toggles.Notifications.Value and Toggles[name].Value
    end

    local function notify(title, body)
        State.Notify(title, body)
    end

    local function playerName(player)
        return player.Name
    end

    local function allowed(player, scope)
        local info = tracked[player]
        if scope == "Everyone" then return true end
        if not info then return false end
        if scope == "Friends" then return info.friend end
        if scope == "Group" then return info.group end
        return info.friend or info.group
    end

    local function watchCharacter(player, character)
        local info = tracked[player]
        if not info or info.character == character then return end
        if info.deadConnection then info.deadConnection:Disconnect() end
        if info.ultConnection then info.ultConnection:Disconnect() end
        info.character = character
        local wasDead = character:GetAttribute("Dead") == true
        local wasUlt = character:GetAttribute("InUlt") ~= nil
        info.deadConnection = character:GetAttributeChangedSignal("Dead"):Connect(function()
            local isDead = character:GetAttribute("Dead") == true
            if isDead and not wasDead and enabled("NotifyDeaths") and allowed(player, Variables.NotifyDeathScope.Value) then
                notify("Player died", playerName(player))
            end
            wasDead = isDead
        end)
        info.ultConnection = character:GetAttributeChangedSignal("InUlt"):Connect(function()
            local isUlt = character:GetAttribute("InUlt") ~= nil
            if isUlt ~= wasUlt then
                if isUlt and enabled("NotifyUlts") then
                    notify("Ultimate activated", playerName(player))
                elseif not isUlt and enabled("NotifyUnults") then
                    notify("Ultimate ended", playerName(player))
                end
            end
            wasUlt = isUlt
        end)
    end

    local function watchPlayer(player, joining)
        if player == LocalPlayer or tracked[player] then return end
        local info = {friend = false, group = false, cash = player:GetAttribute("Cash")}
        tracked[player] = info
        info.characterConnection = player.CharacterAdded:Connect(function(character)
            watchCharacter(player, character)
        end)
        if player.Character then watchCharacter(player, player.Character) end
        info.cashConnection = player:GetAttributeChangedSignal("Cash"):Connect(function()
            local cash = player:GetAttribute("Cash")
            local previous = info.cash
            info.cash = cash
            if type(cash) ~= "number" or type(previous) ~= "number" then return end
            local spent = previous - cash
            if enabled("NotifyBuys") and spent >= 250 and spent % 250 == 0 then
                notify("Possible emote buy", playerName(player) .. " spent $" .. tostring(spent))
            end
        end)
        task.spawn(function()
            local friendOk, friend = pcall(LocalPlayer.IsFriendsWith, LocalPlayer, player.UserId)
            local rankOk, rank = pcall(player.GetRankInGroup, player, GROUP_ID)
            if tracked[player] ~= info then return end
            info.friend = friendOk and friend == true
            info.group = rankOk and type(rank) == "number" and rank > 1
            if joining and enabled("NotifyJoins") and allowed(player, Variables.NotifyJoinScope.Value) then
                notify(info.friend and "Friend joined" or (info.group and "Group member joined" or "Player joined"), playerName(player))
            end
        end)
    end

    Players.PlayerAdded:Connect(function(player) watchPlayer(player, true) end)
    Players.PlayerRemoving:Connect(function(player)
        local info = tracked[player]
        if not info then return end
        if enabled("NotifyLeaves") and allowed(player, Variables.NotifyLeaveScope.Value) then
            notify(info.friend and "Friend left" or (info.group and "Group member left" or "Player left"), playerName(player))
        end
        for _, connection in ipairs({info.characterConnection, info.cashConnection, info.deadConnection, info.ultConnection}) do
            connection:Disconnect()
        end
        tracked[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player, false) end
end

return Notifications
