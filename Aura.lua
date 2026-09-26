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
local working = false
local warned = false
local LocalPlayer = Players.LocalPlayer
local CHECK_INTERVAL = 0.1
local lastCheck = 0
local nextRequestAt = 0
local rateLimitWait = 60
local REQUEST_INTERVAL = 3

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
    if type(request) ~= "function" then
        nextRequestAt = os.clock() + 15
        return nil, "request() unavailable"
    end

    local url = "https://translate.googleapis.com/translate_a/single?client=dict-chrome-ex&sl=auto&tl=en&dt=t&q=" .. HttpService:UrlEncode(text)
    local ok, response = pcall(request, {Url = url, Method = "GET"})
    nextRequestAt = os.clock() + REQUEST_INTERVAL
    local status = ok and type(response) == "table" and tonumber(response.StatusCode)

    if status == 429 then
        local retryAfter = 0
        for key, value in pairs(type(response.Headers) == "table" and response.Headers or {}) do
            if tostring(key):lower() == "retry-after" then retryAfter = tonumber(value) or 0 end
        end
        nextRequestAt = os.clock() + math.max(rateLimitWait, retryAfter)
        rateLimitWait = math.min(rateLimitWait * 2, 900)
        return nil, "Google translation is rate-limited; original messages still appear"
    end

    if status ~= 200 or type(response.Body) ~= "string" then
        nextRequestAt = os.clock() + 15
        return nil, status and ("HTTP " .. status) or "request failed"
    end

    local decodedOK, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
    local segments = decodedOK and type(decoded) == "table" and decoded[1]
    local parts = {}
    if type(segments) == "table" then
        for _, segment in ipairs(segments) do
            if type(segment) == "table" and type(segment[1]) == "string" then
                parts[#parts + 1] = segment[1]
            end
        end
    end

    local result = table.concat(parts)
    if result == "" then
        nextRequestAt = os.clock() + 15
        return nil, "invalid translation response"
    end

    rateLimitWait = 60
    warned = false
    cache[text] = result
    cacheOrder[#cacheOrder + 1] = text
    if #cacheOrder > 128 then cache[table.remove(cacheOrder, 1)] = nil end
    return result
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

    local function showTranslation(entry, translated)
        if not State.Toggles.MsgAura.Value or messages[entry.Player] ~= entry or entry.Player.Character ~= entry.Character then return end
        entry.Done = true
        if translated:lower() ~= entry.Text:lower() then
            display(entry, "(" .. translated .. ")")
        end
    end

    local function translateEntry(entry)
        working = true
        task.spawn(function()
            local translated, reason = translate(entry.Text)
            if translated then
                showTranslation(entry, translated)
            elseif not warned and State.Toggles.MsgAura.Value and messages[entry.Player] == entry then
                warned = true
                warn("Message Aura: " .. reason)
            end
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
                        entry = {Player = player, Character = char, Text = text, ChangedAt = now}
                        messages[player] = entry
                        display(entry, text)
                        local head = char:FindFirstChild("Head")
                        if head then Chat:Chat(head, text, Enum.ChatColor.White) end
                    end
                    if not entry.Done and now - entry.ChangedAt >= 0.5 then
                        if cache[text] then
                            showTranslation(entry, cache[text])
                        elseif not working and now >= nextRequestAt then
                            translateEntry(entry)
                        end
                    end
                end
            end
        end
    end)
    table.insert(State.Connections, conn)
    table.insert(State.Connections, Players.PlayerRemoving:Connect(function(player) messages[player] = nil end))
    table.insert(State.Connections, State.Toggles.MsgAura:GetPropertyChangedSignal("Value"):Connect(function()
        messages = {}
    end))
end

return Aura


