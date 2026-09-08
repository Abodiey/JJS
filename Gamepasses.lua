local Gamepasses = {}
local passIds = {"1151174294", "718699461", "984868818", "857428668", "718947270", "742180133"}

-- Helper function to remove already-owned gamepasses from the target table
local function filterOwnedPasses()
    if not gamepassesFolder then return end
    local currentAttributes = gamepassesFolder:GetAttributes()
    
    for i = #passIds, 1, -1 do
        local id = passIds[i]
        if currentAttributes[id] ~= nil then
            table.remove(passIds, i)
        end
    end
end

local Players = cloneref(game:GetService("Players"))
local plr = Players.LocalPlayer
if not plr then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    plr = Players.LocalPlayer
end

local gamepassesFolder = plr:WaitForChild("Gamepasses",999)

-- Run initial filter check at startup
filterOwnedPasses()

function Gamepasses.Init(State)
    -- Fallback check if the folder wasn't ready at startup
    if not gamepassesFolder then
        gamepassesFolder = plr:FindFirstChild("Gamepasses")
        filterOwnedPasses()
    end

    local toggleObject = State.Toggles.Gamepasses

    local function handleToggleChange()
        if not gamepassesFolder then
            gamepassesFolder = plr:FindFirstChild("Gamepasses")
            filterOwnedPasses()
        end
        
        local isEnabled = toggleObject.Value
        if isEnabled then
            for _, id in ipairs(passIds) do
                gamepassesFolder:SetAttribute(id, true)
            end
        else
            for _, id in ipairs(passIds) do
                gamepassesFolder:SetAttribute(id, nil)
            end
        end
    end

    local toggleConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleToggleChange)
    table.insert(State.Connections, toggleConn)

    handleToggleChange()
end

return Gamepasses
