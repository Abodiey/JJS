-- =============================================================================
-- [ 1. SERVICES & GLOBAL VARIABLES ]
-- =============================================================================
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Debris = cloneref(game:GetService("Debris"))

local LTM = "LocalTransparencyModifier"
local Connections = {}
local DomainConnections = {}
local Whitelist = { ["FinalBeam"] = true, ["Beam"] = true, ["PlasmaWave"] = true, ["ArmProjectile"] = true, }

-- =============================================================================
-- [ 2. IMMEDIATE EXECUTION: SERVICES & HOOKS ]
-- =============================================================================
local function HookRemote(descendant)
    if descendant:IsA("RemoteEvent") or descendant:IsA("UnreliableRemoteEvent") then
        Connections[descendant] = descendant.OnClientEvent:Connect(function() end)
    end
end

-- Setup services as fast as possible
task.spawn(function()
    local Knit = ReplicatedStorage:WaitForChild("Knit",99)
    if not Knit then return end
    local Services = Knit:WaitForChild("Knit",99):WaitForChild("Services",99)
    for _, v in ipairs({"DebreeService", "HandicapService", "BlockService"}) do
        task.spawn(function()
            local service = Services:WaitForChild(v, 99)
            local reContainer = service and service:WaitForChild("RE", 99)
            if not reContainer then return end
            for _, d in ipairs(reContainer:GetChildren()) do HookRemote(d) end
            table.insert(Connections, reContainer.ChildAdded:Connect(HookRemote))
        end)
    end
    task.delay(30, function()
        for _, conn in pairs(Connections) do pcall(function() conn:Disconnect() end) end
        table.clear(Connections)
    end)
end)

-- Run hookmetamethod immediately after service hooks
if hookmetamethod then
    local OldIndex; OldIndex = hookmetamethod(game, "__newindex", function(Self, Prop, Val)
        if Prop ~= LTM then return OldIndex(Self, Prop, Val) end
        if Val == false then return OldIndex(Self, Prop, 0) end
        if Val == true and Self:IsA("BasePart") then return OldIndex(Self, Prop, 0.7) end
        return OldIndex(Self, Prop, Val)
    end)
end

-- =============================================================================
-- [ 3. EFFECTS SYSTEM ]
-- =============================================================================
local function HandleEffect(child)
    if Whitelist[child.Name] then Debris.AddItem(Debris, child, 60) end
end

local Effects = workspace:WaitForChild("Effects", 99999)
if Effects then
    for _, child in ipairs(Effects:GetChildren()) do HandleEffect(child) end
    table.insert(Connections, Effects.ChildAdded:Connect(HandleEffect))
end

-- =============================================================================
-- [ 4. DOMAINS SYSTEM ]
-- =============================================================================
local function HandleDomainChild(domainChild)
    local remote = domainChild:WaitForChild("UnreliableRemoteEvent", 15)
    if not remote or not remote:IsA("UnreliableRemoteEvent") then return end
    DomainConnections[domainChild] = remote.OnClientEvent:Connect(function() end)
end

local Domains = workspace:WaitForChild("Domains", 99999)
if Domains then
    for _, child in ipairs(Domains:GetChildren()) do task.spawn(HandleDomainChild, child) end
    
    Domains.ChildAdded:Connect(HandleDomainChild)
    Domains.ChildRemoved:Connect(function(domainChild)
        local conn = DomainConnections[domainChild]
        if conn then
            pcall(function() conn:Disconnect() end)
            DomainConnections[domainChild] = nil
        end
    end)
end
