local BlackFlash = {}
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer

BlackFlash.Options = {
    {Id = "100962226150441", Name = "Move 3 (100962226150441)", Delay = 0.18, Move = 3},
    {Id = "95852624447551", Name = "Move 3 (95852624447551)", Delay = 0.18, Move = 3},
    {Id = "74145636023952", Name = "Move 3 (74145636023952)", Delay = 0.18, Move = 3},
    {Id = "72475960800126", Name = "Move 3 (72475960800126)", Delay = 0.20, Move = 3},
    {Id = "100081544058065", Name = "Todo: 3 + R + 2", Delay = 0.3, Move = 2},
    {Id = "136536827155962", Name = "Todo: 3 + R + 2 + 2", Delay = 0.3, Move = 2},
    {Id = "123167492985370", Name = "Move 2 (123167492985370)", Delay = 0.6, Move = 2},
}
local DB = {}
for _, Option in ipairs(BlackFlash.Options) do DB[tonumber(Option.Id)] = Option end

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
                local delay = State.Variables["BlackFlashDelay" .. cfg.Id].Value
                task.delay(delay, function()
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

