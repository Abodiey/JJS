local BlackFlash = {}
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer

local DB = {
    [100962226150441] = {delay = 0.18, move = 3},
    [95852624447551] = {delay = 0.18, move = 3},
    [74145636023952] = {delay = 0.18, move = 3},
    [72475960800126] = {delay = 0.20, move = 3},
    [100081544058065] = {delay = 0.3, move = 2},
    [123167492985370] = {delay = 0.6, move = 2}
}

local function doMove(moveNumber)
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local character = LocalPlayer.Character
    
    if not (PlayerGui and PlayerGui.Parent and character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0) then 
        return 
    end

    local main = PlayerGui:FindFirstChild("Main")
    local controls = main and main:FindFirstChild("Controls")
    local movesetGui = controls and controls:FindFirstChild("Moveset")
    if not movesetGui then return end

    local frames = {}
    for _, v in pairs(movesetGui:GetChildren()) do 
        if v:IsA("Frame") then 
            table.insert(frames, v) 
        end 
    end
    
    table.sort(frames, function(a, b) 
        return (a.LayoutOrder or 0) < (b.LayoutOrder or 0) 
    end)

    local target = frames[moveNumber]
    if target then
        local knit = ReplicatedStorage:WaitForChild("Knit", 5)
        if not knit then return end
        
        local serviceName = target.Name:gsub(" ", "") .. "Service"
        local service = knit:WaitForChild("Knit"):WaitForChild("Services"):FindFirstChild(serviceName)
        
        if service then 
            local activatedRemote = service:WaitForChild("RE"):WaitForChild("Activated")
            local moveObject = character.Moveset:FindFirstChild(target.Name)
            
            if moveObject then
                activatedRemote:FireServer(moveObject)
            end
        end
    end
end

function BlackFlash.Init(State)
    local function setup(char)
        local humanoid = char:WaitForChild("Humanoid", 5)
        local animator = humanoid and humanoid:WaitForChild("Animator", 5)
        
        if not animator then return end

        local conn = animator.AnimationPlayed:Connect(function(track)
            if not State.Toggles.BlackFlash.Value then return end
            
            local id = tonumber(track.Animation.AnimationId:match("%d+$"))
            local cfg = DB[id]
            
            if cfg then 
                task.delay(cfg.delay, function() 
                    doMove(cfg.move) 
                end) 
            end
        end)
        
        table.insert(State.Connections, conn)
    end

    if LocalPlayer.Character then 
        setup(LocalPlayer.Character) 
    end
    
    local charAddedConn = LocalPlayer.CharacterAdded:Connect(setup)
    table.insert(State.Connections, charAddedConn)
end

return BlackFlash
