local AntiVoid = {}

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))

local LocalPlayer = Players.LocalPlayer

local CENTER_POINT = Vector3.new(0, 0, 5)
local MAP_RADIUS_X = 349
local MAP_RADIUS_Z = 353
local TELEPORT_THRESHOLD = 100 

local MIN_X = CENTER_POINT.X - MAP_RADIUS_X
local MAX_X = CENTER_POINT.X + MAP_RADIUS_X
local MIN_Z = CENTER_POINT.Z - MAP_RADIUS_Z
local MAX_Z = CENTER_POINT.Z + MAP_RADIUS_Z

local lastPosition = nil

function AntiVoid.Init(State)
	local Connection = RunService.Heartbeat:Connect(function()
		local Enabled = State.Toggles.AntiVoid.Value
		
		if not Enabled then 
			lastPosition = nil
			return 
		end
		
		local Character = LocalPlayer.Character
		if not Character then 
			lastPosition = nil
			return 
		end
		
		-- Check if dead
		if Character:GetAttribute("Dead") then
			lastPosition = nil
			return
		end
		
		local RootPart = Character:FindFirstChild("HumanoidRootPart")
		if not RootPart then 
			lastPosition = nil
			return 
		end
		
		local currentPosition = RootPart.Position
		
		-- Check if in domain using absolute values
		if math.abs(currentPosition.X) > 2000 or math.abs(currentPosition.Z) > 2000 then
			lastPosition = nil
			return
		end
		
		if lastPosition then
			local distanceMoved = (currentPosition - lastPosition).Magnitude
			if distanceMoved > TELEPORT_THRESHOLD then
				lastPosition = currentPosition
				return
			end
		end
		
		if currentPosition.X < MIN_X or currentPosition.X > MAX_X or currentPosition.Z < MIN_Z or currentPosition.Z > MAX_Z then
			local clampedX = math.clamp(currentPosition.X, MIN_X, MAX_X)
			local clampedZ = math.clamp(currentPosition.Z, MIN_Z, MAX_Z)
			
			local targetPosition = Vector3.new(clampedX, currentPosition.Y, clampedZ)
			
			local currentCFrame = Character:GetPivot()
			Character:PivotTo(CFrame.new(targetPosition) * currentCFrame.Rotation)
			
			RootPart.AssemblyLinearVelocity = Vector3.zero
			RootPart.AssemblyAngularVelocity = Vector3.zero
			
			lastPosition = targetPosition
		else
			lastPosition = currentPosition
		end
	end)
	
	table.insert(State.Connections, Connection)
end

return AntiVoid
