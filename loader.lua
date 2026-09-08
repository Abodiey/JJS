local Url = "https://raw.githubusercontent.com/Abodiey/JJS/main/main.lua"
local MaxRetries = 3
local Delay = 1
local Response = nil

for Attempt = 1, MaxRetries do
    local Ok, Res = pcall(request, { Url = Url, Method = "GET" })
    if Ok and type(Res) == "table" and Res.StatusCode == 200 then
        Response = Res
        break
    end
    if Attempt < MaxRetries then
        task.wait(Delay)
        Delay = Delay * 2  -- 1s, 2s, 4s
    end
end

if Response then
    loadstring(Response.Body)()
else
    warn("Failed to fetch script after " .. MaxRetries .. " attempts.")
end
