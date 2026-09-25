local Aura = {}

local TextChatService = cloneref(game:GetService("TextChatService"))
local Chat = cloneref(game:GetService("Chat"))
local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))

local LRI = "\u{2066}" 
local RLI = "\u{2067}" 
local PDI = "\u{2069}" 

local messages = {}
local cache = {}
local cacheOrder = {}
local queue = {}
local working = false
local lastWarning = -math.huge
local LocalPlayer = Players.LocalPlayer
local CHECK_INTERVAL = 0.1
local lastCheck = 0
local nextRequestAt = 0
local rateLimitWait = 60
local REQUEST_INTERVAL = 2

-- Standard Roblox Chat Colors
local NAME_COLORS = {
    Color3.fromRGB(253, 41, 67),
    Color3.fromRGB(1, 162, 255),
    Color3.fromRGB(2, 184, 87),
    BrickColor.new("Bright violet").Color,
    BrickColor.new("Bright orange").Color,
    BrickColor.new("Bright yellow").Color,
    BrickColor.new("Light reddish violet").Color,
    BrickColor.new("Brick yellow").Color,
}

local function GetNameValue(pName)
    local value = 0
    for index = 1, #pName do
        local cValue = string.byte(string.sub(pName, index, index))
        local reverseIndex = #pName - index + 1
        if #pName % 2 == 1 then
            reverseIndex = reverseIndex - 1
        end
        if reverseIndex % 4 >= 2 then
            cValue = -cValue
        end
        value = value + cValue
    end
    return value
end

local function translate(text)
    if cache[text] then return cache[text] end
    if type(request) ~= "function" then return nil, "request() unavailable" end
    if os.clock() < nextRequestAt then return nil, "waiting for translator", true end
    local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q=" .. HttpService:UrlEncode(text)
    local reason
    for attempt = 1, 3 do
        nextRequestAt = os.clock() + REQUEST_INTERVAL
        local ok, response = pcall(request, {Url = url, Method = "GET"})
        local status = ok and type(response) == "table" and tonumber(response.StatusCode)
        if status == 200 and type(response.Body) == "string" then
            local decodedOK, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
            local segments = decodedOK and type(decoded) == "table" and decoded[1]
            local parts = {}
            if type(segments) == "table" then
                for _, segment in ipairs(segments) do
                    if type(segment) == "table" and type(segment[1]) == "string" then parts[#parts + 1] = segment[1] end
                end
            end
            local result = table.concat(parts)
            if result ~= "" then
                rateLimitWait = 60
                cache[text] = result
                cacheOrder[#cacheOrder + 1] = text
                if #cacheOrder > 128 then cache[table.remove(cacheOrder, 1)] = nil end
                return result
            end
            reason = "invalid translation response"
        else
            reason = status and ("HTTP " .. status) or "request failed"
            if status == 429 then
                local retryAfter
                if type(response.Headers) == "table" then
                    for key, value in pairs(response.Headers) do
                        if tostring(key):lower() == "retry-after" then retryAfter = tonumber(value); break end
                    end
                end
                nextRequestAt = os.clock() + math.min(900, math.max(rateLimitWait, retryAfter or 0))
                rateLimitWait = math.min(rateLimitWait * 2, 600)
                return nil, reason, true
            end
            if status and status >= 400 and status < 500 and status ~= 429 then break end
        end
        if attempt < 3 then task.wait(attempt * 2) end
    end
    return nil, reason
end

local function ComputeNameColor(pName)
    return NAME_COLORS[(GetNameValue(pName) % #NAME_COLORS) + 1]
end

local function isRTL(text)
    for _, codePoint in utf8.codes(text) do
        if (codePoint >= 0x0590 and codePoint <= 0x08FF) or (codePoint >= 0xFB50 and codePoint <= 0xFDFF) then
            return true
        end
    end
    return false
end

local function escape(text)
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Aura.Init(State)
    task.spawn(function()
        local BubbleConfig = TextChatService:WaitForChild("BubbleChatConfiguration", 99)
        if not BubbleConfig then return end
        BubbleConfig.MaxDistance = 500
        BubbleConfig.MinimizeDistance = 400
        BubbleConfig.TextSize = 20
    end)

    local function display(entry, text)
        local channels = TextChatService:FindFirstChild("TextChannels")
        local channel = channels and channels:FindFirstChild("RBXGeneral")
        if not channel then return end
        local direction = isRTL(text) and RLI or LRI
        channel:DisplaySystemMessage(string.format('%s<font color="#%s"><b>%s:</b></font> %s%s%s%s',
            LRI, ComputeNameColor(entry.Player.Name):ToHex(), escape(entry.Player.Name), direction, escape(text), PDI, PDI))
    end

    local function processQueue()
        if working or os.clock() < nextRequestAt then return end
        working = true
        task.spawn(function()
            while #queue > 0 and os.clock() >= nextRequestAt do
                local entry = table.remove(queue, 1)
                local player = entry.Player
                if State.Toggles.MsgAura.Value and messages[player] == entry and player.Character == entry.Character then
                    local translated, reason, deferred = translate(entry.Text)
                    if State.Toggles.MsgAura.Value and messages[player] == entry and player.Character == entry.Character then
                        if translated and translated:lower() ~= entry.Text:lower() then
                            display(entry, "(" .. translated .. ")")
                        end
                        entry.Done = translated ~= nil
                        entry.RetryAt = deferred and nextRequestAt or os.clock() + 15
                        if not translated and not (reason == "waiting for translator") and os.clock() - lastWarning >= 30 then
                            lastWarning = os.clock()
                            warn("Message Aura translation failed: " .. tostring(reason) .. "; retrying later")
                        end
                    end
                    task.wait(0.3)
                end
                entry.Queued = false
            end
            for _, entry in ipairs(queue) do entry.Queued = false end
            queue = {}
            working = false
        end)
    end

    local conn = RunService.Heartbeat:Connect(function(deltaTime)
        lastCheck = lastCheck + deltaTime
        if lastCheck < CHECK_INTERVAL then return end
        lastCheck = 0
        if not State.Toggles.MsgAura.Value then return end
        local channels = TextChatService:FindFirstChild("TextChannels")
        if not channels or not channels:FindFirstChild("RBXGeneral") then return end
        local now = os.clock()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local board = char and char:FindFirstChild("Board")
                local gui = board and board:FindFirstChild("SurfaceGui")
                local label = gui and gui:FindFirstChild("TextLabel")
                local text = label and label.Text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
                if text == "" then
                    messages[player] = nil
                else
                    local entry = messages[player]
                    if not entry or entry.Text ~= text or entry.Character ~= char then
                        entry = {Player = player, Character = char, Text = text, ChangedAt = now, RetryAt = 0}
                        messages[player] = entry
                        display(entry, text)
                        local head = char:FindFirstChild("Head")
                        if head then Chat:Chat(head, text, Enum.ChatColor.White) end
                    end
                    if not entry.Done and not entry.Queued and now - entry.ChangedAt >= 0.5 and now >= entry.RetryAt and now >= nextRequestAt then
                        entry.Queued = true
                        queue[#queue + 1] = entry
                    end
                end
            end
        end
        if #queue > 0 then processQueue() end
    end)
    table.insert(State.Connections, conn)
    table.insert(State.Connections, Players.PlayerRemoving:Connect(function(player) messages[player] = nil end))
    table.insert(State.Connections, State.Toggles.MsgAura:GetPropertyChangedSignal("Value"):Connect(function()
        messages = {}
        queue = {}
    end))
end

return Aura

