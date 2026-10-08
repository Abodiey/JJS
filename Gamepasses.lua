local Gamepasses = {}
local passIds = {"1151174294", "718699461", "984868818", "857428668", "718947270", "742180133"}

local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local HttpService = cloneref(game:GetService("HttpService"))
local plr = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
local gamepassesFolder = plr:WaitForChild("Gamepasses", 999)
local Knit
local originalMaxPage
local calibrating = false

if gamepassesFolder then
    for i = #passIds, 1, -1 do
        if gamepassesFolder:GetAttribute(passIds[i]) ~= nil then table.remove(passIds, i) end
    end
end

local function emotes()
    if not Knit then
        local Module = ReplicatedStorage:WaitForChild("Knit"):WaitForChild("Knit")
        local GetIdentity = getthreadidentity or getidentity
        local SetIdentity = setthreadidentity or setidentity
        local Identity = GetIdentity and SetIdentity and GetIdentity()
        if Identity then SetIdentity(2) end
        local Success, Result = pcall(require, Module)
        if Identity then SetIdentity(Identity) end
        if not Success then error(Result, 0) end
        Knit = Result
    end
    local Started, Error = Knit.OnStart():await()
    if not Started then error(Error or "Knit could not start", 0) end
    return Knit.GetController("EmoteController"), Knit.GetService("EmoteService")
end

local function savedEmotes(State)
    local ok, data = pcall(HttpService.JSONDecode, HttpService, State.Variables.SecondEmotes.Value)
    return ok and type(data) == "table" and data or {}
end

local function setPage(EC, State)
    local gui = plr:FindFirstChild("PlayerGui")
    local emotesGui = gui and gui:WaitForChild("Emotes", 10)
    local emote = emotesGui and emotesGui:FindFirstChild("Emote")
    local menu = emote and emote:FindFirstChild("EmoteMenu")
    originalMaxPage = originalMaxPage or EC.MaxPage or 1
    EC.MaxPage = State.Toggles.Gamepasses.Value and math.max(originalMaxPage, 2) or originalMaxPage
    if not menu then return end
    local switch = menu:FindFirstChild("Switch")
    local page = menu:FindFirstChild("Page")
    if switch then switch.Visible = EC.MaxPage > 1 end
    if page then page.Visible = EC.MaxPage > 1 end
    local pages = menu:FindFirstChild("Pages")
    if State.Toggles.Gamepasses.Value then
        menu.TextBox.Visible = true
        menu.Switch.Visible = true
        menu.Page.Visible = true
        menu.Pages.Visible = true
        menu.Search.Visible = false
        menu.TextBox.Text = "x"
        menu.TextBox.Text = ""
    end
    local label = pages and pages:FindFirstChild("Page")
    if label then
        label.Visible = EC.MaxPage ~= 1
        label.Text = string.format("%d/%d", EC.WheelPage or 1, EC.MaxPage)
    end
end

local function restore(State, EC)
    local saved = savedEmotes(State)
    if not next(saved) then return end
    if not State.Toggles.Gamepasses.Value or calibrating then return end
    for i = 9, 16 do
        local entry = saved[tostring(i)]
        if type(entry) == "table" and type(entry[1]) == "string" and type(entry[2]) == "string" and entry[2] ~= "" then
            EC.EmoteCache[i] = {entry[1], entry[2], nil}
        end
    end
end

function Gamepasses.Calibrate(State)
    if calibrating then return false, "Emote calibration already running" end
    if not State.Toggles.Gamepasses.Value then return false, "Enable Free Gamepasses first" end
    calibrating = true
    local ES
    local ok, result = pcall(function()
        local EC
        EC, ES = emotes()
        local char = plr.Character
        if not char then error("Character unavailable", 0) end
        local saved, count = savedEmotes(State), 0
        for i = 9, 16 do
            local info = char:FindFirstChild("Info")
            if not info then error("Character Info unavailable", 0) end
            local started = os.clock()
            while info:FindFirstChild("Emote") and os.clock() - started < 2 do task.wait() end
            if plr.Character ~= char or not State.Toggles.Gamepasses.Value then error("Calibration cancelled", 0) end
            if info:FindFirstChild("Emote") then error("Current emote did not end; try again", 0) end

            ES.Emote:Fire(i)
            started = os.clock()
            while os.clock() - started < 2 do
                if plr.Character ~= char or not State.Toggles.Gamepasses.Value then error("Calibration cancelled", 0) end
                local e = info:FindFirstChild("Emote")
                if e and e:IsA("Animation") and e.AnimationId ~= "" then
                    local entry = {e:GetAttribute("EmoteName") or "", e.AnimationId}
                    EC.EmoteCache[i] = {entry[1], entry[2], nil}
                    saved[tostring(i)] = entry
                    count = count + 1
                    break
                end
                task.wait()
            end
            ES.EmoteEnd:Fire()
            task.wait()
        end
        if count == 0 then error("No emotes captured; try again", 0) end
        State.Variables.SecondEmotes.Value = HttpService:JSONEncode(saved)
        return string.format("Calibrated %d/8 second-page emotes", count)
    end)
    if not ok and ES then pcall(function() ES.EmoteEnd:Fire() end) end
    calibrating = false
    return ok, tostring(result)
end

function Gamepasses.Init(State)
    local toggleObject = State.Toggles.Gamepasses
    local function handleToggleChange()
        gamepassesFolder = gamepassesFolder or plr:FindFirstChild("Gamepasses")
        if not gamepassesFolder then return end
        for _, id in ipairs(passIds) do gamepassesFolder:SetAttribute(id, toggleObject.Value and true or nil) end
        if toggleObject.Value or Knit then
            task.spawn(function()
                local ok, err = pcall(function()
                    local EC = emotes()
                    setPage(EC, State)
                    if toggleObject.Value then restore(State, EC) end
                end)
                if not ok then warn("Emote cache: " .. tostring(err)) end
            end)
        end
    end
    table.insert(State.Connections, toggleObject:GetPropertyChangedSignal("Value"):Connect(handleToggleChange))
    handleToggleChange()
end

return Gamepasses
