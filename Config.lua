local Config = {}

function Config.new()
    local HttpService = game:GetService("HttpService")
    local Path = "CatstarJJS.json"
    local Data = {Toggles = {}, Variables = {}, RouletteCharacters = {}}
    local Pending = false
    local Available = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"
    local Settings = {Data = Data}

    function Settings:Load()
        if not Available then return false end
        local Success, Result = pcall(function()
            if not isfile(Path) then return nil end
            return HttpService:JSONDecode(readfile(Path))
        end)
        if not Success or type(Result) ~= "table" then return false end
        for Group in pairs(Data) do
            local Values = {}
            if type(Result[Group]) == "table" then
                for Key, Value in pairs(Result[Group]) do
                    local Kind = type(Value)
                    if type(Key) == "string" and (Kind == "boolean" or Kind == "string" or
                        (Kind == "number" and Value == Value and math.abs(Value) < math.huge)) then
                        Values[Key] = Value
                    end
                end
            end
            Data[Group] = Values
        end
        return true
    end

    function Settings:Reset()
        for Group in pairs(Data) do Data[Group] = {} end
    end

    function Settings:Save()
        if not Available then return false end
        local Success, Error = pcall(function() writefile(Path, HttpService:JSONEncode(Data)) end)
        if not Success then warn("Config could not save: " .. tostring(Error)) end
        return Success
    end

    function Settings:Set(Group, Key, Value)
        if Data[Group][Key] == Value then return end
        Data[Group][Key] = Value
        if not Available or Pending or self.Applying then return end
        Pending = true
        task.delay(0.5, function()
            Pending = false
            self:Save()
        end)
    end

    if Available then
        local Success, Exists = pcall(isfile, Path)
        if Success and Exists and not Settings:Load() then warn("Config could not load") end
    else
        warn("Config saving needs readfile, writefile and isfile support")
    end
    return Settings
end

return Config
