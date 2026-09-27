local Version = {}

local HttpService = cloneref(game:GetService("HttpService"))

local function Age(Timestamp)
    local Seconds = math.max(0, os.time() - Timestamp)
    if Seconds < 60 then return "just now" end
    if Seconds < 3600 then return math.floor(Seconds / 60) .. "m ago" end
    if Seconds < 86400 then return math.floor(Seconds / 3600) .. "h ago" end
    return math.floor(Seconds / 86400) .. "d ago"
end

function Version.Init(Window, Build)
    if type(Build) ~= "table" then
        Window:SetVersion("Development", "Run loader.lua to see the published version")
        return
    end

    local Status = "Checking updates..."
    local Label = "v" .. Build.Version .. "+" .. Build.Revision:sub(1, 7)
    local function Refresh()
        if not Window.Destroyed then
            Window:SetVersion(Label, "Updated " .. Build.Updated .. " (" .. Age(Build.Timestamp) .. ") / " .. Status)
        end
    end

    Refresh()
    task.spawn(function()
        local NextCheck = 0
        while not Window.Destroyed do
            if os.time() >= NextCheck then
                NextCheck = os.time() + 300
                local Ok, Response = pcall(request, {
                    Url = "https://api.github.com/repos/Abodiey/JJS/contents/build.json?ref=main&t=" .. os.time(),
                    Method = "GET",
                    Headers = {Accept = "application/vnd.github.raw+json", ["X-GitHub-Api-Version"] = "2022-11-28", ["Cache-Control"] = "no-cache"},
                })
                local Latest
                if Ok and type(Response) == "table" and Response.StatusCode == 200 and type(Response.Body) == "string" then
                    local Decoded, Data = pcall(HttpService.JSONDecode, HttpService, Response.Body)
                    if Decoded and type(Data) == "table" and type(Data.Revision) == "string" and type(Data.Version) == "string" then Latest = Data end
                end
                if Latest then
                    Status = Latest.Revision == Build.Revision and Latest.Version == Build.Version and "Up to date" or "Update available - rejoin to load"
                else
                    Status = "Couldn't check for updates"
                end
            end
            Refresh()
            task.wait(60)
        end
    end)
end

return Version
