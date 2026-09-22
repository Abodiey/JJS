local Config = {}

function Config.new()
    local HttpService = game:GetService("HttpService")
    local Path = "CatstarJJS.json"
    local Data = {Toggles = {}, Variables = {}, RouletteCharacters = {}}
    local Pending = false
    local Available = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"

    if Available then
        local Success, Result = pcall(function()
            if isfile(Path) then return HttpService:JSONDecode(readfile(Path)) end
        end)
        if Success and type(Result) == "table" then
            for Group in pairs(Data) do
                if type(Result[Group]) == "table" then
                    for Key, Value in pairs(Result[Group]) do
                        if type(Key) == "string" and (type(Value) == "boolean" or type(Value) == "string" or type(Value) == "number") then
                            Data[Group][Key] = Value
                        end
                    end
                end
            end
        elseif not Success then
            warn("Config could not load: " .. tostring(Result))
        end
    else
        warn("Config saving needs readfile, writefile and isfile support")
    end

    local Settings = {Data = Data}
    function Settings:Save()
        if not Available then return false end
        local Success, Error = pcall(function() writefile(Path, HttpService:JSONEncode(Data)) end)
        if not Success then warn("Config could not save: " .. tostring(Error)) end
        return Success
    end

    function Settings:Set(Group, Key, Value)
        if Data[Group][Key] == Value then return end
        Data[Group][Key] = Value
        if not Available or Pending then return end
        Pending = true
        task.delay(0.5, function()
            Pending = false
            self:Save()
        end)
    end
    return Settings
end

return Config
