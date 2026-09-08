local AntiBlackHole = {}

local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Knit = ReplicatedStorage:WaitForChild("Knit")
local YukiService = Knit and Knit:WaitForChild("Knit"):WaitForChild("Services"):WaitForChild("YukiService")
local EffectsEvent = YukiService and YukiService:WaitForChild("RE"):WaitForChild("Effects")

local effects = workspace:WaitForChild("Effects", 9999)

local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart", 9999)
local humanoid = character:WaitForChild("Humanoid", 9999)

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	hrp = newCharacter:WaitForChild("HumanoidRootPart", 9999)
	humanoid = newCharacter:WaitForChild("Humanoid", 9999)
end)

function AntiBlackHole.Init(State)
	if not EffectsEvent then return end
	local Connection = EffectsEvent.OnClientEvent:Connect(function(effectName, blackHolePart)
		local Enabled = State.Toggles.AntiBlackhole.Value
		if not Enabled or effectName ~= "BlackHole" or not blackHolePart then return end

		if character and blackHolePart:IsDescendantOf(character) then 
			return 
		end

		local startTime = os.clock()
		local duration = 3.8
		local internalConnection

		internalConnection = RunService.Stepped:Connect(function(_, deltaTime)
			if not State.Toggles.AntiBlackhole.Value then
				internalConnection:Disconnect()
				return
			end

			local blackHoleVfx = effects and effects:FindFirstChild("BlackHole2")

			if os.clock() - startTime >= duration or not blackHolePart.Parent or not blackHoleVfx then
				internalConnection:Disconnect()
				return
			end

			if not (hrp and humanoid and hrp.Parent and humanoid.Parent) then return end

			local targetPos = blackHolePart.Position
			local distance = (hrp.Position - targetPos).Magnitude

			if distance <= 100 then
				local pullFactor = 1 - math.clamp(distance / 100, 0, 1)
				local lookDirection = CFrame.lookAt(hrp.Position, targetPos).LookVector

				local baseMultiplier = (humanoid.FloorMaterial == Enum.Material.Air) and 300 or 2000
				local counterVelocity = lookDirection * (pullFactor * baseMultiplier * deltaTime)

				if distance <= 25 and distance > 10 then
					local pushDirection = -lookDirection
					local escapeVelocity = pushDirection * ((1 - (distance / 25)) * 120)
					hrp.AssemblyLinearVelocity = (hrp.AssemblyLinearVelocity - counterVelocity) + escapeVelocity
				else
					hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity - counterVelocity
				end
			end
		end)
	end)

	table.insert(State.Connections, Connection)
end

return AntiBlackHole
