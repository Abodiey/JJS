local Aura = {}

local TextChatService = cloneref(game:GetService("TextChatService"))
local Chat = cloneref(game:GetService("Chat"))
local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))

local LRI = "\u{2066}" 
local RLI = "\u{2067}" 
local PDI = "\u{2069}" 

local lastMsg = {}
local LocalPlayer = Players.LocalPlayer
local CHECK_INTERVAL = 0.1
local lastCheck = 0

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

-- Calculates Levenshtein edit distance to detect minor changes (e.g. <= 1 character away)
local function getEditDistance(s1, s2)
    local len1, len2 = #s1, #s2
    local matrix = {}

    for i = 0, len1 do
        matrix[i] = { [0] = i }
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (string.sub(s1, i, i) == string.sub(s2, j, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i - 1][j] + 1,
                matrix[i][j - 1] + 1,
                matrix[i - 1][j - 1] + cost
            )
        end
    end

    return matrix[len1][len2]
end

function Aura.Init(State)
    task.spawn(function()
        local BubbleConfig = TextChatService:WaitForChild("BubbleChatConfiguration", 99)
        if not BubbleConfig then return end
        BubbleConfig.MaxDistance = 500 
        BubbleConfig.MinimizeDistance = 400
        BubbleConfig.TextSize = 20
    end)
    
    local conn = RunService.Heartbeat:Connect(function(deltaTime)
        lastCheck = lastCheck + deltaTime
        if lastCheck < CHECK_INTERVAL then return end
        lastCheck = 0

        if not State.Toggles.MsgAura.Value then return end
        
        local generalChannel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if not generalChannel then return end

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            
            local char = player.Character
            if not char then continue end
            
            local board = char:FindFirstChild("Board")
            if not board then continue end
            
            local sGui = board:FindFirstChild("SurfaceGui")
            local label = sGui and sGui:FindFirstChild("TextLabel")
            if not label or label.Text == "" then continue end

            -- Clean up newlines, carriage returns, and duplicate spaces from label.Text
            local cleanedText = string.gsub(label.Text, "[\r\n]+", " ")
            cleanedText = string.gsub(cleanedText, "%s+", " ")
            cleanedText = string.match(cleanedText, "^%s*(.-)%s*$")

            if #cleanedText == 0 then continue end

            local rawMsg = cleanedText
            local charName = player.Name
            
            if lastMsg[charName] == rawMsg then continue end
            lastMsg[charName] = rawMsg
            
            task.spawn(function()
                local displayMsg = rawMsg
                
                if type(request) == "function" then
                    local apiUrl = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q=" .. HttpService:UrlEncode(rawMsg)
                    local responseSuccess, response = pcall(request, {
                        Url = apiUrl,
                        Method = "GET"
                    })
                    
                    if responseSuccess and response and response.StatusCode == 200 then
                        local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(response.Body) end)
                        if decodeSuccess and decoded and decoded[1] and decoded[1][1] and decoded[1][1][1] then
                            local translatedText = decoded[1][1][1]
                            local detectedLang = decoded[3]
                            
                            local lowerRaw = string.lower(rawMsg)
                            local lowerTrans = string.lower(translatedText)
                            
                            -- Ignore if language is English or if translation is <= 1 edit distance away
                            if detectedLang ~= "en" and getEditDistance(lowerRaw, lowerTrans) > 1 then
                                displayMsg = string.format("%s (%s)", rawMsg, translatedText)
                            end
                        end
                    end
                end

                local nameColor = ComputeNameColor(charName):ToHex()
                local directionMarker = isRTL(rawMsg) and RLI or LRI
                local isolatedMsg = directionMarker .. displayMsg .. PDI

                local formattedChat = string.format("%s<font color=\"#%s\"><b>%s:</b></font> %s%s", LRI, nameColor, charName, isolatedMsg, PDI)
                
                generalChannel:DisplaySystemMessage(formattedChat)
                
                local head = char:FindFirstChild("Head")
                if head then
                    Chat:Chat(head, rawMsg, Enum.ChatColor.White)
                end
            end)
        end
    end)
    
    table.insert(State.Connections, conn)
end

return Aura
