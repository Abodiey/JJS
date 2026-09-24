local Notifications = {}

local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local GROUP_ID = 16357742
local MAX_CARDS = 4
local CARD_LIFE = 5
local CARD_WIDTH = 320
local CARD_HEIGHT = 66
local GAP = 8

local WHITE = Color3.fromRGB(250, 250, 252)
local TEXT = Color3.fromRGB(28, 28, 30)
local MUTED = Color3.fromRGB(100, 100, 108)
local BLUE = Color3.fromRGB(0, 122, 255)

function Notifications.Init(State)
    local Toggles = State.Toggles
    local Variables = State.Variables
    local cards = {}
    local tracked = {}

    local function enabled(name)
        return Toggles.Notifications.Value and Toggles[name].Value
    end

    local function draw(kind, properties)
        local object = Drawing.new(kind)
        for key, value in pairs(properties) do object[key] = value end
        return object
    end

    local function layout()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local x = math.max(8, viewport.X - CARD_WIDTH - 18)
        for index, card in ipairs(cards) do
            local y = 68 + (index - 1) * (CARD_HEIGHT + GAP)
            card.base.Position = Vector2.new(x + 12, y)
            card.base.Size = Vector2.new(CARD_WIDTH - 24, CARD_HEIGHT)
            card.middle.Position = Vector2.new(x, y + 12)
            card.middle.Size = Vector2.new(CARD_WIDTH, CARD_HEIGHT - 24)
            for corner, point in ipairs({
                Vector2.new(x + 12, y + 12),
                Vector2.new(x + CARD_WIDTH - 12, y + 12),
                Vector2.new(x + 12, y + CARD_HEIGHT - 12),
                Vector2.new(x + CARD_WIDTH - 12, y + CARD_HEIGHT - 12)
            }) do
                card.corners[corner].Position = point
            end
            card.accent.Position = Vector2.new(x + 13, y + 16)
            card.accent.Size = Vector2.new(3, CARD_HEIGHT - 32)
            card.title.Position = Vector2.new(x + 27, y + 10)
            card.body.Position = Vector2.new(x + 27, y + 34)
        end
    end

    local function remove(card)
        for index, current in ipairs(cards) do
            if current == card then table.remove(cards, index); break end
        end
        for _, object in ipairs(card.objects) do object:Remove() end
        layout()
    end

    local function notify(title, body)
        local card = {objects = {}, corners = {}}
        local function add(kind, properties)
            local object = draw(kind, properties)
            card.objects[#card.objects + 1] = object
            return object
        end
        local background = {Filled = true, Color = WHITE, Transparency = 0.96, ZIndex = 1000, Visible = true}
        card.base = add("Square", background)
        card.middle = add("Square", background)
        for index = 1, 4 do
            card.corners[index] = add("Circle", {
                Filled = true, Radius = 12, NumSides = 24, Color = WHITE,
                Transparency = 0.96, ZIndex = 1000, Visible = true
            })
        end
        card.accent = add("Square", {Filled = true, Color = BLUE, Transparency = 1, ZIndex = 1001, Visible = true})
        card.title = add("Text", {
            Text = title, Size = 16, Font = 2, Color = TEXT, Outline = false,
            Transparency = 1, ZIndex = 1002, Visible = true
        })
        card.body = add("Text", {
            Text = body, Size = 13, Font = 2, Color = MUTED, Outline = false,
            Transparency = 1, ZIndex = 1002, Visible = true
        })
        cards[#cards + 1] = card
        if #cards > MAX_CARDS then remove(cards[1]) end
        layout()
        task.delay(CARD_LIFE, function()
            for _, current in ipairs(cards) do
                if current == card then remove(card); break end
            end
        end)
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
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local camera = workspace.CurrentCamera
        if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
        layout()
    end)
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
end

return Notifications

