local BlackFlash = {}
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer

BlackFlash.Options = {
    {Id = "100962226150441", Ids = {"100962226150441", "95852624447551", "74145636023952"}, Name = "Yuji BlackFlash", Delay = 180, Min = 80, Max = 280, Move = 3},
    {Id = "72475960800126", Name = "Mahito Black Flash", Delay = 200, Min = 70, Max = 200, Move = 3},
    {Id = "100081544058065", Name = "Todo Kick", Delay = 300, Min = 0, Max = 350, Move = 2},
    {Id = "136536827155962", Name = "Todo BlackFlash", Delay = 350, Min = 350, Max = 550, Move = 2},
}
local DB = {}
for _, Option in ipairs(BlackFlash.Options) do
    for _, Id in ipairs(Option.Ids or {Option.Id}) do DB[tonumber(Id)] = Option end
end

local function doMove(character, moveNumber, State)
    if not State.Toggles.BlackFlash.Value or LocalPlayer.Character ~= character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    local moveset = character:FindFirstChild("Moveset")
    if not humanoid or humanoid.Health <= 0 or not moveset then return end

    local knit = ReplicatedStorage:FindFirstChild("Knit")
    knit = knit and knit:FindFirstChild("Knit")
    local services = knit and knit:FindFirstChild("Services")
    if not services then return end

    for _, move in ipairs(moveset:GetChildren()) do
        if move:GetAttribute("Key") == moveNumber then
            local serviceName = move:GetAttribute("Service") or move.Name:gsub(" ", "") .. "Service"
            if type(serviceName) ~= "string" then return end
            local service = services:FindFirstChild(serviceName) or services:FindFirstChild(serviceName .. "Service")
            local re = service and service:FindFirstChild("RE")
            local activated = re and re:FindFirstChild("Activated")
            if activated then activated:FireServer(move) end
            return
        end
    end
end

function BlackFlash.Init(State)
    local function setup(char)
        local humanoid = char:WaitForChild("Humanoid", 5)
        local animator = humanoid and humanoid:WaitForChild("Animator", 5)
        
        if not animator or LocalPlayer.Character ~= char then return end

        local conn = animator.AnimationPlayed:Connect(function(track)
            if not State.Toggles.BlackFlash.Value then return end
            
            local id = tonumber(track.Animation.AnimationId:match("%d+$"))
            local cfg = DB[id]
            
            if cfg and State.Toggles["BlackFlash" .. cfg.Id].Value then
                local delay = State.Variables["BlackFlashDelayMs" .. cfg.Id].Value
                task.delay(delay / 1000, function()
                    if State.Toggles["BlackFlash" .. cfg.Id].Value then
                        doMove(char, cfg.Move, State)
                    end
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

