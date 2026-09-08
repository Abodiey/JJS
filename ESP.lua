local ESP = {}

-- Localize Services & Core API
local cloneref = cloneref or function(o) return o end
local game = game
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local workspace = cloneref(game:GetService("Workspace"))

-- Localize Global Engine Functions
local task = task
local t_wait = task.wait
local type = type
local typeof = typeof
local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local table = table
local table_insert = table.insert
local table_clear = table.clear

-- Localize Math & String Libraries
local math = math
local m_clamp = math.clamp
local m_floor = math.floor
local m_deg = math.deg
local m_atan2 = math.atan2
local m_abs = math.abs
local m_max = math.max
local string = string
local s_format = string.format
local os = os
local o_clock = os.clock

-- Localize Roblox Datatypes
local Vector2 = Vector2
local v2_new = Vector2.new
local Vector3 = Vector3
local v3_new = Vector3.new
local Color3 = Color3
local c3_fromHex = Color3.fromHex
local c3_new = Color3.new

local lp = Players.LocalPlayer
if not lp then
    task.spawn(function()
        lp = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    end)
end
local TARGET_GROUP = 16357742

local Cache = {}
local ActiveMarks = {} -- char -> { markObj, timestamp }
local FrameTick = 0 

-- Design Palette Constants
local COLOR_RED = c3_new(1, 0.1, 0.1)
local COLOR_YELLOW = c3_new(1, 1, 0)
local COLOR_GREEN = c3_new(0, 1, 0)
local COLOR_BRIGHT_GREEN = c3_new(0, 1, 0.2)
local COLOR_CYAN = c3_new(0, 0.8, 1)
local COLOR_DARK_BLUE = c3_new(0, 0.1, 0.5)
local COLOR_WHITE = c3_new(1, 1, 1)
local COLOR_BLACK = c3_new(0, 0, 0)
local COLOR_GOLD = c3_new(1, 0.85, 0)
local COLOR_PURPLE = c3_new(0.68, 0.1, 1)
local COLOR_LIGHT_BLUE = Color3.fromRGB(50, 180, 255)
local COLOR_SEAL_RED = c3_new(1, 0.2, 0.2)
local COLOR_SEAL_GREEN = c3_new(0.2, 1, 0.2)

local ultNamesModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UltNames"))

-- Dynamically generate MOVESET_COLORS and DARK_MOVESETS by looping over ultNamesModule
local MOVESET_COLORS = {
    ["Custom"] = "00FF80"
}
local DARK_MOVESETS = {}

for movesetName, dataTable in pairs(ultNamesModule) do
    local colorObj = dataTable[2]
    if typeof(colorObj) == "Color3" then
        MOVESET_COLORS[movesetName] = s_format("%02X%02X%02X", m_floor(colorObj.R * 255), m_floor(colorObj.G * 255), m_floor(colorObj.B * 255))
        
        local luminance = (0.299 * colorObj.R) + (0.587 * colorObj.G) + (0.114 * colorObj.B)
        if luminance < 0.2 then
            DARK_MOVESETS[movesetName] = true
        end
    end
end

-- Special cooldowns: moveset -> { Name, Duration }
local SPECIAL_COOLDOWNS = {
    Itadori = { Name = "Feint", Duration = 2 },
    Hakari = { Name = "Counter", Duration = 16 },
    -- Add more as needed
}

local function getGradientColor(percent)
    percent = m_clamp(percent, 0, 1)
    if percent > 0.5 then
        return COLOR_YELLOW:Lerp(COLOR_GREEN, (percent - 0.5) * 2)
    end
    return COLOR_RED:Lerp(COLOR_YELLOW, percent * 2)
end

local function formatVal(val)
    return val >= 1000 and s_format("%.1fk", val / 1000) or tostring(val)
end

local function isCustom(movesetFolder)
    if not movesetFolder then return false end
    local children = movesetFolder:GetChildren()
    if #children == 0 then return false end
    
    for _, move in ipairs(children) do
        if move.Name ~= "Custom" then 
            return false 
        end
    end
    return true
end

-- Helper constructor for Drawing API primitives
local function createDrawing(class, properties)
    local obj = Drawing.new(class)
    if properties then
        for k, v in pairs(properties) do
            obj[k] = v
        end
    end
    return obj
end

-- Safe cleanup helper for Drawing objects
local function safeRemove(drawingObj)
    if drawingObj then
        pcall(function()
            drawingObj:Remove()
        end)
    end
end

-- Generates Drawing lines for interval ticks
local function applyBrawlhallaTicks(count)
    count = count or 9
    local lineCache = {}
    for idx = 1, count do
        lineCache[idx] = createDrawing("Line", {
            Color = COLOR_BLACK,
            Thickness = 1,
            Transparency = 0.5,
            Visible = false
        })
    end
    return lineCache
end

-- Helper to bundle bar components (Background, Outline, Fill, and Ticks)
local function createBarGroupWithTicks(tickCount)
    return {
        Back = createDrawing("Square", { Filled = true, Color = c3_new(0.05, 0.05, 0.05), Transparency = 0.5, Visible = false }),
        Outline = createDrawing("Square", { Filled = false, Color = COLOR_BLACK, Thickness = 1, Visible = false }),
        Fill = createDrawing("Square", { Filled = true, Transparency = 0.8, Visible = false }),
        Lines = applyBrawlhallaTicks(tickCount)
    }
end

local function createBarGroup()
    return createBarGroupWithTicks(9)
end

local function setBarGroupVisible(bar, visible)
    bar.Back.Visible = visible
    bar.Outline.Visible = visible
    bar.Fill.Visible = visible
    for i = 1, #bar.Lines do
        bar.Lines[i].Visible = visible
    end
end

local function removeBarGroup(bar)
    safeRemove(bar.Back)
    safeRemove(bar.Outline)
    safeRemove(bar.Fill)
    for i = 1, #bar.Lines do
        safeRemove(bar.Lines[i])
    end
end

-- ============================================================================


-- ============================================================================
-- ASSET CREATION & LIFECYCLE
-- ============================================================================

local function CreateAssets(p)
    local assets = {}

    -- Tracer Line
    assets.Line = createDrawing("Line", {
        Thickness = 1,
        Color = COLOR_GREEN,
        Transparency = 1,
        Visible = false
    })

    -- RichText Segment Pool
    assets.TextPool = {}

    -- Bars
    assets.UltBar = createBarGroup()
    assets.HealthBar = createBarGroup()
    assets.EvadeBar = createBarGroup()
    assets.ExtraBar = createBarGroupWithTicks(9)

    -- Moveset slots: 0 = special, 1-4 = regular, 5 = extra (Reggie)
    assets.MovesetItems = {}
    for i = 0, 5 do
        assets.MovesetItems[i] = {
            Back = createDrawing("Square", { Filled = true, Color = c3_new(0.1, 0.1, 0.1), Transparency = 0.6, Visible = false }),
            Fill = createDrawing("Square", { Filled = true, Color = COLOR_LIGHT_BLUE, Transparency = 0.5, Visible = false }),
            Outline = createDrawing("Square", { Filled = false, Color = COLOR_BLACK, Thickness = 1, Visible = false }),
            Label = createDrawing("Text", { Size = 10, Center = true, Outline = true, OutlineColor = COLOR_BLACK, Color = COLOR_WHITE, Visible = false }),
            SealCircle = createDrawing("Circle", { Filled = true, Radius = 4, Color = COLOR_SEAL_RED, Visible = false }),
            Data = { Visible = false, Key = tostring(i), Name = "", Tip = "", CooldownRatio = 0 },
            MoveRef = nil
        }
    end

    -- Single special cooldown end timestamp
    assets.SpecialCooldownEnd = 0

    -- Dead state
    assets.IsDead = false
    assets.CurrentCharacter = nil

    -- Moveset tracking for resetting special on change
    assets.CurrentMoveset = ""

    -- Connections
    assets.Connections = {}
    assets.CharacterConnections = {} 
    assets.KillValueConnections = {} 
    
    -- AFK
    assets.LastPosition = v3_new(0, 0, 0)
    assets.LastMoveTime = o_clock()
    assets.IsAFK = false
    
    -- Cached display strings
    assets.LastDist = 0
    assets.CachedKills = 0
    assets.CachedMoveset = ""
    assets.NameDisplay = ""
    assets.CashDisplay = ""
    assets.GroupRoleTag = ""
    assets.IsFriend = false
    assets.IsMutual = false
    assets.LineColor = COLOR_GREEN
    assets.HexKillColor = "ffffff"
    assets.HexDistColor = "ffffff"
    assets.IsHidingKills = false

    -- Extra info
    assets.AgeDisplay = ""
    assets.FriendDisplay = ""
    assets.GamepassDisplay = ""
    assets.MiracleDisplay = ""
    assets.ExtraInfo = ""
    
    return assets
end

local function HideAllAssets(assets)
    if assets.Line then assets.Line.Visible = false end
    if assets.TextPool then
        for _, textObj in ipairs(assets.TextPool) do
            textObj.Visible = false
        end
    end
    if assets.UltBar then setBarGroupVisible(assets.UltBar, false) end
    if assets.HealthBar then setBarGroupVisible(assets.HealthBar, false) end
    if assets.EvadeBar then setBarGroupVisible(assets.EvadeBar, false) end
    if assets.ExtraBar then setBarGroupVisible(assets.ExtraBar, false) end
    
    if assets.MovesetItems then
        for i = 0, 5 do
            local item = assets.MovesetItems[i]
            item.Back.Visible = false
            item.Fill.Visible = false
            item.Outline.Visible = false
            item.Label.Visible = false
            item.SealCircle.Visible = false
        end
    end
end

local function CleanupCacheEntry(p, assets)
    for _, conn in ipairs(assets.Connections) do conn:Disconnect() end
    for _, conn in ipairs(assets.CharacterConnections) do conn:Disconnect() end
    for _, conn in ipairs(assets.KillValueConnections) do conn:Disconnect() end
    
    safeRemove(assets.Line)
    
    if assets.TextPool then
        for _, textObj in ipairs(assets.TextPool) do
            safeRemove(textObj)
        end
    end
    
    if assets.UltBar then removeBarGroup(assets.UltBar) end
    if assets.HealthBar then removeBarGroup(assets.HealthBar) end
    if assets.EvadeBar then removeBarGroup(assets.EvadeBar) end
    if assets.ExtraBar then removeBarGroup(assets.ExtraBar) end

    if assets.MovesetItems then
        for i = 0, 5 do
            local item = assets.MovesetItems[i]
            safeRemove(item.Back)
            safeRemove(item.Fill)
            safeRemove(item.Outline)
            safeRemove(item.Label)
            safeRemove(item.SealCircle)
        end
    end
    
    Cache[p] = nil
end

local function CleanupAllESP()
    for p, assets in pairs(Cache) do
        CleanupCacheEntry(p, assets)
    end
    table_clear(ActiveMarks)
end

-- ============================================================================
-- PLAYER INFO UPDATER
-- ============================================================================

local function UpdatePlayerInfo(p, assets)
    local age = p.AccountAge or 0
    local ageStr
    if age >= 1 then
        ageStr = s_format("%dd", m_floor(age))
    elseif age * 24 >= 1 then
        ageStr = s_format("%dh", m_floor(age * 24))
    else
        ageStr = s_format("%dm", m_floor(age * 24 * 60))
    end
    assets.AgeDisplay = s_format("<font color='#FFA500'>%s</font>", ageStr)

    task.spawn(function()
        local success, friends = pcall(function()
            return p:GetFriendsAsync()
        end)
        if success and friends then
            local count = #friends
            if count > 0 then
                assets.FriendDisplay = s_format("<font color='#00BFFF'>%dF</font>", count)
            else
                assets.FriendDisplay = ""
            end
        else
            assets.FriendDisplay = ""
        end
    end)

    task.spawn(function()
        local gamepassFolder = p:FindFirstChild("Gamepasses")
        if gamepassFolder then
            local attrs = gamepassFolder:GetAttributes()
            local count = 0
            for _ in pairs(attrs) do count = count + 1 end
            if count > 0 then
                assets.GamepassDisplay = s_format("<font color='#00FF00'>%dG</font>", count)
            else
                assets.GamepassDisplay = ""
            end
        else
            assets.GamepassDisplay = ""
        end
    end)
end

local function StartPeriodicInfoUpdates(p, assets)
    UpdatePlayerInfo(p, assets)
    task.spawn(function()
        while p and p.Parent do
            t_wait(60)
            UpdatePlayerInfo(p, assets)
        end
    end)
end

-- ============================================================================
-- PLAYER & CHARACTER SIGNALS
-- ============================================================================

local function SetupPlayerSignals(p, assets)
    task.spawn(function()
        local directSuccess, directRes = pcall(function() return lp:IsFriendsWith(p.UserId) end)
        if directSuccess and directRes then
            assets.IsFriend = true
            return
        end

        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= lp and other ~= p then
                local s1, r1 = pcall(function() return lp:IsFriendsWith(other.UserId) end)
                local s2, r2 = pcall(function() return p:IsFriendsWith(other.UserId) end)
                if s1 and r1 and s2 and r2 then
                    assets.IsMutual = true
                    break
                end
            end
        end
    end)

    task.spawn(function()
        local success, rank = pcall(p.GetRankInGroup, p, TARGET_GROUP)
        if success and type(rank) == "number" and rank > 0 then
            local successRole, role = pcall(p.GetRoleInGroup, p, TARGET_GROUP)
            if successRole then
                role = tostring(role)
                assets.GroupRoleTag = s_format("<font color='#00AAFF'>[%s]</font> ", role)
                return
            end
        end
    end)

    local function trackValueInstance(killsVal)
        for _, conn in ipairs(assets.KillValueConnections) do conn:Disconnect() end
        table_clear(assets.KillValueConnections)

        if not killsVal then return end

        local function updateKills()
            assets.CachedKills = tonumber(killsVal.Value) or 0
            local killCol = getGradientColor(1 - (assets.CachedKills / 1000))
            assets.HexKillColor = s_format("%02x%02x%02x", m_floor(killCol.R * 255), m_floor(killCol.G * 255), m_floor(killCol.B * 255))
        end
        table_insert(assets.KillValueConnections, killsVal:GetPropertyChangedSignal("Value"):Connect(updateKills))
        updateKills()
    end

    local function watchKills(leaderstats)
        local function evaluateSource()
            local isHidden = leaderstats:GetAttribute("HiddenKills")
            assets.IsHidingKills = not not isHidden

            task.spawn(function()
                if isHidden then
                    local hiddenFolder = leaderstats:FindFirstChild("Hidden")
                    while not hiddenFolder and p.Parent and leaderstats:GetAttribute("HiddenKills") == true do
                        t_wait()
                        hiddenFolder = leaderstats:FindFirstChild("Hidden")
                    end
                    if not hiddenFolder then return end
                    
                    local killsVal = hiddenFolder:FindFirstChild("Kills")
                    while not killsVal and p.Parent and leaderstats:GetAttribute("HiddenKills") == true do
                        t_wait()
                        killsVal = hiddenFolder:FindFirstChild("Kills")
                    end
                    if killsVal then trackValueInstance(killsVal) end
                else
                    local killsVal = leaderstats:FindFirstChild("Kills")
                    while not killsVal and p.Parent and not leaderstats:GetAttribute("HiddenKills") do
                        t_wait()
                        killsVal = leaderstats:FindFirstChild("Kills")
                    end
                    if killsVal then trackValueInstance(killsVal) end
                end
            end)
        end

        table_insert(assets.Connections, leaderstats:GetAttributeChangedSignal("HiddenKills"):Connect(evaluateSource))
        evaluateSource()
    end

    local function checkLeaderstats()
        local leaderstats = p:FindFirstChild("leaderstats")
        if leaderstats then
            watchKills(leaderstats)
        else
            task.spawn(function()
                local leaderstatsWait = p:FindFirstChild("leaderstats")
                while not leaderstatsWait and p.Parent do
                    t_wait()
                    leaderstatsWait = p:FindFirstChild("leaderstats")
                end
                if leaderstatsWait then watchKills(leaderstatsWait) end
            end)
        end
    end
    checkLeaderstats()

    StartPeriodicInfoUpdates(p, assets)

    -- Listen to player's Moveset attribute changes to reset special
    local function onPlayerMovesetChanged()
        assets.SpecialCooldownEnd = 0
    end
    assets.Connections[#assets.Connections+1] = p:GetAttributeChangedSignal("Moveset"):Connect(onPlayerMovesetChanged)
end

local function SetupCharacterSignals(assets, char, hum)
    for _, conn in ipairs(assets.CharacterConnections) do conn:Disconnect() end
    table_clear(assets.CharacterConnections)

    if not hum then return end

    assets.IsDead = false

    -- Dead attribute
    local function onDeadChanged()
        assets.IsDead = char:GetAttribute("Dead") or false
    end
    assets.CharacterConnections[#assets.CharacterConnections+1] = char:GetAttributeChangedSignal("Dead"):Connect(onDeadChanged)
    onDeadChanged()

    -- Moveset attribute on character - reset special
    local function onCharMovesetChanged()
        assets.SpecialCooldownEnd = 0
    end
    assets.CharacterConnections[#assets.CharacterConnections+1] = char:GetAttributeChangedSignal("Moveset"):Connect(onCharMovesetChanged)

    -- Health bar updates
    local function updateBarsInline()
        if assets.LastDist < 10 then return end
        local hpPerc = m_clamp(hum.Health / hum.MaxHealth, 0, 1)
        
        if hpPerc <= 0.02 then
            setBarGroupVisible(assets.HealthBar, false)
        else
            if hpPerc >= 0.99 then
                assets.HealthBar.Fill.Color = COLOR_GOLD
                for i = 1, 9 do assets.HealthBar.Lines[i].Visible = false end
            else
                assets.HealthBar.Fill.Color = COLOR_BRIGHT_GREEN:Lerp(COLOR_RED, 1 - hpPerc)
            end
        end
    end
    
    table_insert(assets.CharacterConnections, hum:GetPropertyChangedSignal("Health"):Connect(updateBarsInline))
    table_insert(assets.CharacterConnections, hum:GetPropertyChangedSignal("MaxHealth"):Connect(updateBarsInline))
    updateBarsInline()
end

-- ============================================================================
-- ESP INIT
-- ============================================================================

function ESP.Init(State)
    local toggleObject = State.Toggles.ESP

    local Helpers = {
        ActiveMarks = ActiveMarks,
        COLOR_BLACK = COLOR_BLACK,
        COLOR_BRIGHT_GREEN = COLOR_BRIGHT_GREEN,
        COLOR_CYAN = COLOR_CYAN,
        COLOR_DARK_BLUE = COLOR_DARK_BLUE,
        COLOR_GOLD = COLOR_GOLD,
        COLOR_LIGHT_BLUE = COLOR_LIGHT_BLUE,
        COLOR_PURPLE = COLOR_PURPLE,
        COLOR_RED = COLOR_RED,
        COLOR_SEAL_GREEN = COLOR_SEAL_GREEN,
        COLOR_SEAL_RED = COLOR_SEAL_RED,
        COLOR_WHITE = COLOR_WHITE,
        COLOR_YELLOW = COLOR_YELLOW,
        DARK_MOVESETS = DARK_MOVESETS,
        MOVESET_COLORS = MOVESET_COLORS,
        SPECIAL_COOLDOWNS = SPECIAL_COOLDOWNS,
        c3_fromHex = c3_fromHex,
        c3_new = c3_new,
        formatVal = formatVal,
        getGradientColor = getGradientColor,
        m_clamp = m_clamp,
        m_floor = m_floor,
        m_max = m_max,
        o_clock = o_clock,
        s_format = s_format,
        setBarGroupVisible = setBarGroupVisible,
        table_insert = table_insert,
        v2_new = v2_new,
    }
    local HealthBar = ESP.Dependencies.HealthBar.Init(State, Helpers)
    local EvadeBar = ESP.Dependencies.EvadeBar.Init(State, Helpers)
    local SpecialMeter = ESP.Dependencies.SpecialMeter.Init(State, Helpers)
    local UltimateBar = ESP.Dependencies.UltimateBar.Init(State, Helpers)
    local Moveset = ESP.Dependencies.Moveset.Init(State, Helpers)
    local PlayerInfo = ESP.Dependencies.PlayerInfo.Init(State, Helpers)
    local Tracers = ESP.Dependencies.Tracers.Init(State, Helpers)

    local function handleToggleChange()
        if not toggleObject.Value then 
            for _, assets in pairs(Cache) do
                HideAllAssets(assets)
            end
            return 
        end
    end

    -- Get Knit and descendants using WaitForChild
    local KnitFolder = ReplicatedStorage:WaitForChild("Knit")
    local Knit = KnitFolder:WaitForChild("Knit")
    local Services = Knit:WaitForChild("Services")

    -- Charles Mark
    local CharlesService = Services:WaitForChild("CharlesService")
    local CharlesRE = CharlesService:WaitForChild("RE")
    local CharlesEffects = CharlesRE:WaitForChild("Effects")
    local markConn = CharlesEffects.OnClientEvent:Connect(function(action, charInstance, pos, markValueObject)
        if action == "Mark" and typeof(charInstance) == "Instance" and typeof(markValueObject) == "Instance" then
            -- Store mark with timestamp
            ActiveMarks[charInstance] = {
                mark = markValueObject,
                timestamp = o_clock()
            }
        end
    end)
    table_insert(State.Connections, markConn)

    -- Itadori Feint
    local ItadoriService = Services:WaitForChild("ItadoriService")
    local ItadoriRE = ItadoriService:WaitForChild("RE")
    local ItadoriEffects = ItadoriRE:WaitForChild("Effects")
    local feintConn = ItadoriEffects.OnClientEvent:Connect(function(action, charInstance, ...)
        if action == "Feint" and typeof(charInstance) == "Instance" then
            for p, c in pairs(Cache) do
                if p.Character == charInstance then
                    local spec = SPECIAL_COOLDOWNS["Itadori"]
                    if spec then
                        c.SpecialCooldownEnd = o_clock() + spec.Duration
                    end
                    break
                end
            end
        end
    end)
    table_insert(State.Connections, feintConn)

    -- Hakari Counter
    local HakariService = Services:WaitForChild("HakariService")
    local HakariRE = HakariService:WaitForChild("RE")
    local HakariEffects = HakariRE:WaitForChild("Effects")
    local counterConn = HakariEffects.OnClientEvent:Connect(function(action, charInstance, ...)
        if action == "Counter" and typeof(charInstance) == "Instance" then
            for p, c in pairs(Cache) do
                if p.Character == charInstance then
                    local spec = SPECIAL_COOLDOWNS["Hakari"]
                    if spec then
                        c.SpecialCooldownEnd = o_clock() + spec.Duration
                    end
                    break
                end
            end
        end
    end)
    table_insert(State.Connections, counterConn)

    local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        if player == lp then
            CleanupAllESP()
        end
    end)
    table_insert(State.Connections, playerRemovingConn)

    local conn = RunService.RenderStepped:Connect(function()
        if not toggleObject.Value then return end
        if not (State.Toggles.HealthBar.Value or State.Toggles.EvadeBar.Value or State.Toggles.SpecialMeter.Value or State.Toggles.UltimateBar.Value or State.Toggles.Moveset.Value or State.Toggles.PlayerInfo.Value or State.Toggles.Tracers.Value) then return end

        local cam = workspace.CurrentCamera
        if not cam or not lp then return end
        local viewportSize = cam.ViewportSize
        local char_lp = lp.Character
        local myRoot = char_lp and char_lp.PrimaryPart
        
        FrameTick = FrameTick + 1
        local shouldUpdateHeavy = (FrameTick % 2 == 0)
        local isThrottledFrame = (FrameTick % 3 == 0)
        local gameClock = o_clock()

        local globalRainbowColor = Color3.fromHSV((gameClock * 0.4) % 1, 1, 1)
        local globalRainbowHex = s_format("%02x%02x%02x", m_floor(globalRainbowColor.R * 255), m_floor(globalRainbowColor.G * 255), m_floor(globalRainbowColor.B * 255))

        -- Clean dead cache entries
        for p, assets in pairs(Cache) do
            if not p or not p.Parent then CleanupCacheEntry(p, assets) end
        end

        -- Remove expired marks (>25s)
        for char, data in pairs(ActiveMarks) do
            if gameClock - data.timestamp > 25 then
                ActiveMarks[char] = nil
            end
        end

        -- Loop through all players including local
        for _, p in pairs(Players:GetPlayers()) do
            local char = p.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local root = char and char.PrimaryPart

            local c = Cache[p]
            if not c then 
                c = CreateAssets(p)
                Cache[p] = c 
                c.LastPosition = root and root.Position or v3_new(0,0,0)
                c.LastMoveTime = gameClock
                SetupPlayerSignals(p, c)
                -- SetupCharacterSignals called below when char exists
            end

            -- Check if character changed (respawn or first load)
            if c.CurrentCharacter ~= char then
                -- Reset special on respawn
                c.SpecialCooldownEnd = 0
                c.CurrentCharacter = char
                if char and hum then
                    SetupCharacterSignals(c, char, hum)
                else
                    for _, conn in ipairs(c.CharacterConnections) do conn:Disconnect() end
                    table_clear(c.CharacterConnections)
                    c.IsDead = false
                end
            end

            if root and hum then
                -- AFK detection
                if c.LastPosition and (c.LastPosition - root.Position).Magnitude > 0.1 then
                    c.LastPosition = root.Position
                    c.LastMoveTime = gameClock
                    c.IsAFK = false
                elseif (gameClock - c.LastMoveTime) >= 300 then
                    c.IsAFK = true
                end
                
                -- Project positions
                local root2D, visRoot = cam:WorldToViewportPoint(root.Position)
                local head2D, visHead = cam:WorldToViewportPoint(root.Position + v3_new(0, 3.2, 0))
                local feet2D, visFeet = cam:WorldToViewportPoint(root.Position - v3_new(0, 3.6, 0))

                if visRoot and root2D.Z > 0 then
                    local currentRootPos = myRoot and myRoot.Position or cam.CFrame.Position
                    local dist = (currentRootPos - root.Position).Magnitude
                    c.LastDist = dist

                    local scaleFactor = m_clamp(50 / m_max(dist, 10), 0.55, 1.35)

                    local baseBoxHeight = m_abs(feet2D.Y - head2D.Y)
                    local boxHeight = m_floor(m_clamp(baseBoxHeight * scaleFactor, 18, 500))
                    local boxWidth = m_floor(m_clamp(boxHeight * 0.55, 18, 260))
                    local boxX = m_floor(root2D.X - (boxWidth / 2))
                    local boxY = m_floor(head2D.Y)

                    local sX, sY
                    if myRoot then
                        local p1, visP1 = cam:WorldToViewportPoint(myRoot.Position)
                        sX, sY = m_floor(p1.X), m_floor(p1.Y)
                    else
                        sX, sY = m_floor(viewportSize.X * 0.5), m_floor(viewportSize.Y)
                    end

                    local hideNameAndHealth = (dist < 10)

                    -- Moveset name
                    local movesetName = ""
                    local movesetFolder = char:FindFirstChild("Moveset")
                    local fullyCustom = isCustom(movesetFolder)
                    local cm = char:GetAttribute("Moveset")
                    local pm = p:GetAttribute("Moveset")
                    if cm == "Custom" or fullyCustom then
                        if fullyCustom then
                            local ultAttr = char:GetAttribute("CustomUlt")
                            local customChild = movesetFolder and movesetFolder:FindFirstChild("Custom")
                            local tagAttr = customChild and customChild:GetAttribute("Tag")
                            if type(ultAttr) == "string" and ultAttr:find("%a") then
                                movesetName = ultAttr
                            elseif tagAttr then
                                movesetName = tagAttr
                            else
                                movesetName = "Custom"
                            end
                        else
                            movesetName = pm or "Custom"
                        end
                    else
                        movesetName = cm or pm or ""
                    end

                    -- Update current moveset tracking
                    c.CurrentMoveset = movesetName

                    local isRyu = (movesetName == "Ryu")
                    local isHaruta = (movesetName == "Haruta")
                    local isReggie = (movesetName == "Reggie")
                    local info = char:FindFirstChild("Info")
                    local overheatObj = info and info:FindFirstChild("Overheat")
                    local miraclesObj = info and info:FindFirstChild("Miracles")
                    local nextReceiptObj = info and info:FindFirstChild("NextReceipt")

                    HealthBar.Render(c, hum, scaleFactor, boxX, boxY, boxHeight, hideNameAndHealth)
                    EvadeBar.Render(c, char, scaleFactor, boxX, boxY, boxWidth, boxHeight)
                    SpecialMeter.Render(c, scaleFactor, boxX, boxY, boxWidth, boxHeight, isRyu, isHaruta, overheatObj, miraclesObj)

                    local uHeight = m_floor(m_clamp(4 * scaleFactor, 2, 8))
                    local uGap = m_floor(m_clamp(3 * scaleFactor, 2, 6))
                    local uY = boxY - uHeight - uGap
                    local rawUlt = p:GetAttribute("Ultimate")
                    local ultValue = type(rawUlt) == "number" and rawUlt or 0
                    UltimateBar.Render(c, boxX, uY, boxWidth, uHeight, ultValue, movesetName, fullyCustom, globalRainbowColor, globalRainbowHex, shouldUpdateHeavy, isThrottledFrame)

                    local hasActiveMoveset, slotY = Moveset.Render(c, movesetName, movesetFolder, isReggie, nextReceiptObj, scaleFactor, root2D, uY)
                    PlayerInfo.Render(c, p, char, info, dist, movesetName, fullyCustom, isHaruta, miraclesObj, hideNameAndHealth, globalRainbowHex, shouldUpdateHeavy, scaleFactor, root2D, hasActiveMoveset, slotY, uY)
                    Tracers.Render(c, sX, sY, root2D, feet2D, dist, shouldUpdateHeavy)
                else
                    HideAllAssets(c)
                end
            else
                -- No character
                if c then
                    HideAllAssets(c)
                    if c.CurrentCharacter then
                        for _, conn in ipairs(c.CharacterConnections) do conn:Disconnect() end
                        table_clear(c.CharacterConnections)
                        c.CurrentCharacter = nil
                        c.IsDead = false
                        c.SpecialCooldownEnd = 0
                    end
                end
            end
        end
    end)
    table_insert(State.Connections, conn)

    local toggleConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleToggleChange)
    table_insert(State.Connections, toggleConn)

    table_insert(State.Connections, State.Toggles.HealthBar:GetPropertyChangedSignal("Value"):Connect(function()
        if not State.Toggles.HealthBar.Value then
            for _, assets in pairs(Cache) do HealthBar.Hide(assets) end
        end
    end))
    table_insert(State.Connections, State.Toggles.EvadeBar:GetPropertyChangedSignal("Value"):Connect(function()
        if not State.Toggles.EvadeBar.Value then
            for _, assets in pairs(Cache) do EvadeBar.Hide(assets) end
        end
    end))
    table_insert(State.Connections, State.Toggles.SpecialMeter:GetPropertyChangedSignal("Value"):Connect(function()
        if not State.Toggles.SpecialMeter.Value then
            for _, assets in pairs(Cache) do SpecialMeter.Hide(assets) end
        end
    end))
    table_insert(State.Connections, State.Toggles.UltimateBar:GetPropertyChangedSignal("Value"):Connect(function()
        if not State.Toggles.UltimateBar.Value then
            for _, assets in pairs(Cache) do UltimateBar.Hide(assets) end
        end
    end))
    table_insert(State.Connections, State.Toggles.Moveset:GetPropertyChangedSignal("Value"):Connect(function()
        if not State.Toggles.Moveset.Value then
            for _, assets in pairs(Cache) do Moveset.Hide(assets) end
        end
    end))
    table_insert(State.Connections, State.Toggles.PlayerInfo:GetPropertyChangedSignal("Value"):Connect(function()
        if not State.Toggles.PlayerInfo.Value then
            for _, assets in pairs(Cache) do PlayerInfo.Hide(assets) end
        end
    end))
    table_insert(State.Connections, State.Toggles.Tracers:GetPropertyChangedSignal("Value"):Connect(function()
        if not State.Toggles.Tracers.Value then
            for _, assets in pairs(Cache) do Tracers.Hide(assets) end
        end
    end))

    handleToggleChange()
end

return ESP

