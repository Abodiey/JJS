local DomainESP = {}

local Workspace = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))

local Domains = Workspace:WaitForChild("Domains")
local activeEsp = {}

local CULL_DISTANCE = 1000

-- Sphere configuration: UV sphere with latitude rings and longitude lines
local LATITUDE_RINGS = 4
local LONGITUDE_RIBS = 8

local LOCAL_EDGES = {}

-- 1. Generate Latitude Circles
for lat = 1, LATITUDE_RINGS do
	local phi = (lat / (LATITUDE_RINGS + 1)) * math.pi
	local ringRadius = math.sin(phi)
	local y = math.cos(phi)

	for lon = 1, LONGITUDE_RIBS do
		local theta1 = ((lon - 1) / LONGITUDE_RIBS) * (2 * math.pi)
		local theta2 = (lon / LONGITUDE_RIBS) * (2 * math.pi)

		local p1 = Vector3.new(ringRadius * math.cos(theta1), y, ringRadius * math.sin(theta1))
		local p2 = Vector3.new(ringRadius * math.cos(theta2), y, ringRadius * math.sin(theta2))

		table.insert(LOCAL_EDGES, { p1, p2 })
	end
end

-- 2. Generate Longitude Meridians
local topPole = Vector3.new(0, 1, 0)
local bottomPole = Vector3.new(0, -1, 0)

for lon = 1, LONGITUDE_RIBS do
	local theta = ((lon - 1) / LONGITUDE_RIBS) * (2 * math.pi)
	local cosT = math.cos(theta)
	local sinT = math.sin(theta)

	local prevPoint = topPole

	for lat = 1, LATITUDE_RINGS do
		local phi = (lat / (LATITUDE_RINGS + 1)) * math.pi
		local ringRadius = math.sin(phi)
		local y = math.cos(phi)

		local currentPoint = Vector3.new(ringRadius * cosT, y, ringRadius * sinT)
		table.insert(LOCAL_EDGES, { prevPoint, currentPoint })
		prevPoint = currentPoint
	end

	table.insert(LOCAL_EDGES, { prevPoint, bottomPole })
end

local TOTAL_LINES = #LOCAL_EDGES

-- Clip a 3D line segment against the camera near plane
local function clipLineToCamera(p1, p2, camCF, invCF)
	local cp1 = invCF * p1
	local cp2 = invCF * p2

	local nearZ = -0.1

	if cp1.Z > nearZ and cp2.Z > nearZ then
		return nil, nil
	end

	if cp1.Z > nearZ then
		local t = (nearZ - cp1.Z) / (cp2.Z - cp1.Z)
		cp1 = cp1:Lerp(cp2, t)
	elseif cp2.Z > nearZ then
		local t = (nearZ - cp2.Z) / (cp1.Z - cp2.Z)
		cp2 = cp2:Lerp(cp1, t)
	end

	return camCF * cp1, camCF * cp2
end

-- Simple function to find the closest player within 5 studs of a position
local function findClosestPlayer(position)
	local bestDist = 5 -- maximum distance in studs
	local bestPlayer = nil

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
			if hrp then
				local dist = (hrp.Position - position).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestPlayer = player
				end
			end
		end
	end

	return bestPlayer
end

-- Fallback: resolve using DomainTag (original method)
local function resolveCasterViaTag(domain)
	local targetPart = domain:FindFirstChild("DomainCollider") or domain
	if not targetPart or not targetPart:IsA("BasePart") then
		return nil
	end

	local partCF = targetPart.CFrame
	local halfSize = targetPart.Size * 0.5

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local info = character:FindFirstChild("Info")
			local domainTag = info and info:FindFirstChild("DomainTag")
			if domainTag and domainTag:GetAttribute("O") then
				local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
				if hrp then
					local localPos = partCF:PointToObjectSpace(hrp.Position)
					if math.abs(localPos.X) <= halfSize.X 
						and math.abs(localPos.Y) <= halfSize.Y 
						and math.abs(localPos.Z) <= halfSize.Z then
						return {
							PlayerName = player.Name,
							Moveset = tostring(character:GetAttribute("Moveset") or "Unknown")
						}
					end
				end
			end
		end
	end

	return nil
end

local function createEsp(domain)
	if activeEsp[domain] then return end

	local lines = table.create(TOTAL_LINES)
	for i = 1, TOTAL_LINES do
		local line = Drawing.new("Line")
		line.Thickness = 1.5
		line.Transparency = 1
		line.Visible = false
		lines[i] = line
	end

	local textLabel = Drawing.new("Text")
	textLabel.Text = "Domain"
	textLabel.Size = 16
	textLabel.Center = true
	textLabel.Outline = true
	textLabel.Color = Color3.fromRGB(255, 255, 255)
	textLabel.Visible = false

	local espData = {
		Lines = lines,
		Text = textLabel,
		CasterInfo = nil,        -- will be set when found
		Connections = {},
	}
	activeEsp[domain] = espData

	local function updateColor()
		local color = domain.CanCollide and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
		for i = 1, TOTAL_LINES do
			lines[i].Color = color
		end
	end
	updateColor()

	table.insert(espData.Connections, domain:GetPropertyChangedSignal("CanCollide"):Connect(updateColor))

	-- Try to find the caster immediately (if the player is already within 5 studs)
	local closest = findClosestPlayer(domain.Position)
	if closest then
		local character = closest.Character
		espData.CasterInfo = {
			PlayerName = closest.Name,
			Moveset = tostring(character and character:GetAttribute("Moveset") or "Unknown")
		}
	end
end

local function removeEsp(domain)
	local espData = activeEsp[domain]
	if not espData then return end

	for _, conn in ipairs(espData.Connections) do 
		conn:Disconnect() 
	end
	for i = 1, TOTAL_LINES do 
		espData.Lines[i]:Remove() 
	end
	if espData.Text then 
		espData.Text:Remove() 
	end

	activeEsp[domain] = nil
end

function DomainESP.Init(State)
	local toggleObject = State.Toggles.DomainESP

	local renderConn = RunService.RenderStepped:Connect(function()
		if not toggleObject.Value then
			for _, espData in pairs(activeEsp) do
				for i = 1, TOTAL_LINES do 
					espData.Lines[i].Visible = false 
				end
				if espData.Text then 
					espData.Text.Visible = false 
				end
			end
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then return end

		local camCF = camera.CFrame
		local cameraPos = camCF.Position
		local invCF = camCF:Inverse()

		for domain, espData in pairs(activeEsp) do
			if domain and domain.Parent then
				local cframe = domain.CFrame
				local pos = cframe.Position
				local distance = (pos - cameraPos).Magnitude

				if distance <= CULL_DISTANCE then
					local size = domain.Size
					local radius = math.max(size.X, math.max(size.Y, size.Z)) * 0.5

					-- If we haven't found the caster yet, try to find it now
					if not espData.CasterInfo then
						-- 1. Try closest player within 5 studs
						local closest = findClosestPlayer(pos)
						if closest then
							local character = closest.Character
							espData.CasterInfo = {
								PlayerName = closest.Name,
								Moveset = tostring(character and character:GetAttribute("Moveset") or "Unknown")
							}
						else
							-- 2. Fallback to DomainTag method (for when the player is inside but not at center)
							local tagInfo = resolveCasterViaTag(domain)
							if tagInfo then
								espData.CasterInfo = tagInfo
							end
						end
					end

					local playerName = espData.CasterInfo and espData.CasterInfo.PlayerName or "Unknown"
					local moveset = espData.CasterInfo and espData.CasterInfo.Moveset or "Unknown"

					espData.Text.Text = string.format("%s's Domain [%s]", playerName, moveset)

					-- Text projection
					local textPoint, textOnScreen = camera:WorldToViewportPoint(pos + Vector3.new(0, radius + 1, 0))
					if textOnScreen and textPoint.Z > 0 then
						espData.Text.Position = Vector2.new(textPoint.X, textPoint.Y)
						espData.Text.Visible = true
					else
						espData.Text.Visible = false
					end

					-- Wireframe projection
					for i = 1, TOTAL_LINES do
						local edge = LOCAL_EDGES[i]
						local w1 = cframe * (edge[1] * radius)
						local w2 = cframe * (edge[2] * radius)

						local clipped1, clipped2 = clipLineToCamera(w1, w2, camCF, invCF)
						local line = espData.Lines[i]

						if clipped1 and clipped2 then
							local s1 = camera:WorldToViewportPoint(clipped1)
							local s2 = camera:WorldToViewportPoint(clipped2)
							line.From = Vector2.new(s1.X, s1.Y)
							line.To = Vector2.new(s2.X, s2.Y)
							line.Visible = true
						else
							line.Visible = false
						end
					end
				else
					espData.Text.Visible = false
					for i = 1, TOTAL_LINES do
						espData.Lines[i].Visible = false
					end
				end
			end
		end
	end)

	table.insert(State.Connections, renderConn)
	table.insert(State.Connections, Domains.ChildAdded:Connect(createEsp))
	table.insert(State.Connections, Domains.ChildRemoved:Connect(removeEsp))

	for _, child in ipairs(Domains:GetChildren()) do
		createEsp(child)
	end
end

return DomainESP
