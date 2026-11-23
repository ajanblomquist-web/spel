-- MapService.luau
-- Builds the greybox world from code (so there's no place file to keep in sync)
-- and hands each player a base plot.
--
-- Layout, seen from above (+Z is "forward", toward the canyon):
--
--   [ Tar Pits      ]  far end
--   [ Fern Valley   ]
--   [ Sandy Pit     ]
--        LAUNCH PAD      z = 0
--   ROCK   SPAWN
--   [P1][P2]...[P8]      player plots, z = -100
--
-- To swap in real art later, you can delete the greybox parts this builds and
-- place your own models with the same names (TrainingRock, LaunchPad), or just
-- decorate around them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Visuals = require(script.Parent.Parent.Visuals)

local MapService = {}

local PLOT_COUNT = 8
local PLOT_SIZE = 36
local PLOT_Z = -100
local PLOT_SPACING = 40
local CANYON_WIDTH = 160
local HUB_HALF_WIDTH = 180
local HUB_BACK_Z = -130

-- Where flings start measuring distance from (front edge of the pad).
MapService.LaunchOrigin = Vector3.new(0, 0, 2)
MapService.PadPosition = Vector3.new(0, 1.2, -4)
MapService.TrainingRockPosition = Vector3.new(-28, 4, -22)
MapService.CanyonWidth = CANYON_WIDTH

local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(255, 180, 90),
	Color3.fromRGB(255, 230, 100),
	Color3.fromRGB(130, 220, 120),
	Color3.fromRGB(100, 200, 230),
	Color3.fromRGB(120, 140, 255),
	Color3.fromRGB(190, 130, 255),
	Color3.fromRGB(255, 140, 210),
}

-- Pedestal slots in plot-local space. The first Balance.BasePedestals are
-- always shown; the rest appear with the Extra Pedestals pass.
local PEDESTAL_OFFSETS = {
	-- back row: the 6 every player has
	Vector3.new(-15, 0, -12),
	Vector3.new(-9, 0, -12),
	Vector3.new(-3, 0, -12),
	Vector3.new(3, 0, -12),
	Vector3.new(9, 0, -12),
	Vector3.new(15, 0, -12),
	-- middle row: +6 from the Extra Pedestals pass
	Vector3.new(-15, 0, -4.5),
	Vector3.new(-9, 0, -4.5),
	Vector3.new(-3, 0, -4.5),
	Vector3.new(3, 0, -4.5),
	Vector3.new(9, 0, -4.5),
	Vector3.new(15, 0, -4.5),
}
local INCUBATOR_OFFSETS = {
	Vector3.new(-8, 0, 8),
	Vector3.new(0, 0, 8),
	Vector3.new(8, 0, 8),
}

export type Plot = {
	Index: number,
	Model: Model,
	Center: Vector3,
	Floor: BasePart,
	Sign: BasePart,
	Pedestals: { BasePart },
	Incubators: { BasePart },
	SpawnCFrame: CFrame,
	Owner: Player?,
}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

local mapFolder: Folder

local function wall(cframe: CFrame, size: Vector3, parent: Instance)
	local part = Visuals.Part({
		Name = "Wall",
		Size = size,
		CFrame = cframe,
		Color = Color3.fromRGB(150, 120, 95),
		Material = Enum.Material.Rock,
		Transparency = 0.15,
	})
	part.Parent = parent
end

local function buildHub()
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = mapFolder

	local depth = MapService.LaunchOrigin.Z - HUB_BACK_Z
	Visuals.Part({
		Name = "HubFloor",
		Size = Vector3.new(HUB_HALF_WIDTH * 2, 1, depth),
		CFrame = CFrame.new(0, -0.5, HUB_BACK_Z + depth / 2),
		Color = Color3.fromRGB(205, 185, 140),
		Material = Enum.Material.Ground,
	}).Parent =
		hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, -40)
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(240, 240, 240)
	spawn.Parent = hub

	-- Perimeter walls (the canyon side stays open).
	local h = 10
	wall(CFrame.new(0, h / 2, HUB_BACK_Z), Vector3.new(HUB_HALF_WIDTH * 2, h, 2), hub)
	wall(CFrame.new(-HUB_HALF_WIDTH, h / 2, HUB_BACK_Z + depth / 2), Vector3.new(2, h, depth), hub)
	wall(CFrame.new(HUB_HALF_WIDTH, h / 2, HUB_BACK_Z + depth / 2), Vector3.new(2, h, depth), hub)
	local sideWidth = HUB_HALF_WIDTH - CANYON_WIDTH / 2
	local frontZ = MapService.LaunchOrigin.Z
	wall(CFrame.new(-(CANYON_WIDTH / 2 + sideWidth / 2), h / 2, frontZ), Vector3.new(sideWidth, h, 2), hub)
	wall(CFrame.new(CANYON_WIDTH / 2 + sideWidth / 2, h / 2, frontZ), Vector3.new(sideWidth, h, 2), hub)

	-- Training rock
	local rock = Visuals.Part({
		Name = "TrainingRock",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 8, 8),
		Position = MapService.TrainingRockPosition,
		Color = Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.Rock,
	})
	rock.Parent = mapFolder
	Visuals.Billboard(
		rock,
		{ { Text = "TRAIN" }, { Text = "Strength", Color = Color3.fromRGB(255, 220, 120) } },
		nil,
		7,
		250
	)

	-- Launch pad
	local pad = Visuals.Part({
		Name = "LaunchPad",
		Size = Vector3.new(12, 1.2, 12),
		Position = MapService.PadPosition - Vector3.new(0, 0.6, 0),
		Color = Color3.fromRGB(255, 140, 40),
		Material = Enum.Material.Neon,
	})
	pad.Parent = mapFolder
	local arrow = Visuals.Part({
		Name = "Arrow",
		Size = Vector3.new(3, 0.3, 6),
		Position = MapService.PadPosition + Vector3.new(0, 0.15, 0),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	arrow.Parent = pad
	Visuals.Billboard(
		pad,
		{ { Text = "FLING" }, { Text = "Stand here", Color = Color3.fromRGB(255, 220, 120) } },
		nil,
		6,
		250
	)
end

local function buildCanyon()
	local canyon = Instance.new("Folder")
	canyon.Name = "Canyon"
	canyon.Parent = mapFolder

	local origin = MapService.LaunchOrigin
	for _, zone in Zones.List do
		local length = zone.EndDistance - zone.StartDistance
		local floor = Visuals.Part({
			Name = zone.Id,
			Size = Vector3.new(CANYON_WIDTH, 1, length),
			CFrame = CFrame.new(origin.X, -0.5, origin.Z + zone.StartDistance + length / 2),
			Color = zone.Color,
			Material = zone.Material,
		})
		floor:SetAttribute("ZoneId", zone.Id)
		floor.Parent = canyon

		if zone.StartDistance > 0 then
			local post = Visuals.Part({
				Name = zone.Id .. "Sign",
				Size = Vector3.new(1, 12, 1),
				Position = Vector3.new(-CANYON_WIDTH / 2 + 6, 6, origin.Z + zone.StartDistance),
				Color = Color3.fromRGB(90, 60, 40),
			})
			post.Parent = canyon
			Visuals.Billboard(post, {
				{ Text = zone.Name },
				{ Text = "x" .. zone.Luck .. " luck", Color = Color3.fromRGB(120, 255, 140) },
			}, Vector2.new(16, 5), 9, 600)
		end
	end

	-- Distance markers every 50 studs on the right wall.
	for d = 50, Zones.MaxDistance - 1, 50 do
		local marker = Visuals.Part({
			Name = "Marker" .. d,
			Size = Vector3.new(1, 6, 1),
			Position = Vector3.new(CANYON_WIDTH / 2 - 4, 3, origin.Z + d),
			Color = Color3.new(1, 1, 1),
		})
		marker.Parent = canyon
		Visuals.Billboard(marker, { { Text = d .. "m" } }, Vector2.new(6, 2), 4.5, 400)
	end

	local h = 14
	local total = Zones.MaxDistance
	wall(CFrame.new(-CANYON_WIDTH / 2, h / 2, origin.Z + total / 2), Vector3.new(2, h, total), canyon)
	wall(CFrame.new(CANYON_WIDTH / 2, h / 2, origin.Z + total / 2), Vector3.new(2, h, total), canyon)
	wall(CFrame.new(0, h / 2, origin.Z + total), Vector3.new(CANYON_WIDTH, h, 2), canyon)
end

local function buildPlot(index: number): Plot
	local x = -((PLOT_COUNT - 1) * PLOT_SPACING) / 2 + (index - 1) * PLOT_SPACING
	local center = Vector3.new(x, 0, PLOT_Z)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)

	local floor = Visuals.Part({
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, 0.4, PLOT_SIZE),
		Position = center + Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(170, 170, 170),
		Material = Enum.Material.SmoothPlastic,
	})
	floor.Parent = model
	model.PrimaryPart = floor

	local sign = Visuals.Part({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		Position = center + Vector3.new(PLOT_SIZE / 2 - 2, 4, PLOT_SIZE / 2 - 1),
		Color = Color3.fromRGB(90, 60, 40),
	})
	sign.Parent = model
	Visuals.Billboard(sign, { { Text = "Free plot" } }, Vector2.new(10, 2), 5.5, 200)

	local pedestals = {}
	for i, offset in PEDESTAL_OFFSETS do
		local pedestal = Visuals.Part({
			Name = "Pedestal" .. i,
			Size = Vector3.new(5, 1.2, 5),
			Position = center + offset + Vector3.new(0, 1, 0),
			Color = Color3.fromRGB(235, 230, 220),
			Material = Enum.Material.Marble,
		})
		pedestal:SetAttribute("Index", i)
		pedestal.Parent = model
		pedestals[i] = pedestal
	end

	local incubators = {}
	for i, offset in INCUBATOR_OFFSETS do
		local nest = Visuals.Part({
			Name = "Incubator" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 5, 5),
			CFrame = CFrame.new(center + offset + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(140, 95, 55),
			Material = Enum.Material.WoodPlanks,
		})
		nest:SetAttribute("Index", i)
		nest.Parent = model
		incubators[i] = nest
	end

	model.Parent = Workspace:WaitForChild("Plots")

	return {
		Index = index,
		Model = model,
		Center = center,
		Floor = floor,
		Sign = sign,
		Pedestals = pedestals,
		Incubators = incubators,
		SpawnCFrame = CFrame.new(
			center + Vector3.new(0, 4, PLOT_SIZE / 2 - 4),
			center + Vector3.new(0, 4, 100)
		),
		Owner = nil,
	}
end

local function setSign(plot: Plot, text: string)
	local label = plot.Sign:FindFirstChild("Label")
	if label then
		(label:FindFirstChild("Line1") :: TextLabel).Text = text
	end
end

local function moveToPlot(player: Player, character: Model)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		task.wait() -- let the default spawn finish first
		character:PivotTo(plot.SpawnCFrame)
	end
end

-- Public API -----------------------------------------------------------------

function MapService.GetPlot(player: Player): Plot?
	return plotByPlayer[player]
end

-- Shows the first `count` pedestals and hides the rest.
function MapService.SetPedestalCount(plot: Plot, count: number)
	for i, pedestal in plot.Pedestals do
		local visible = i <= count
		pedestal.Transparency = if visible then 0 else 1
		pedestal.CanCollide = visible
	end
end

function MapService.IsHome(player: Player, position: Vector3): boolean
	local plot = plotByPlayer[player]
	if not plot then
		return false
	end
	local offset = position - plot.Center
	local limit = PLOT_SIZE / 2 + 2
	return math.abs(offset.X) <= limit and math.abs(offset.Z) <= limit
end

function MapService.Init(Services)
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	local digFolder = Instance.new("Folder")
	digFolder.Name = "DigSpots"
	digFolder.Parent = Workspace

	buildHub()
	buildCanyon()
	for i = 1, PLOT_COUNT do
		plots[i] = buildPlot(i)
	end

	Services.DataService.OnLoaded(function(player)
		for i, plot in plots do
			if plot.Owner == nil then
				plot.Owner = player
				plotByPlayer[player] = plot
				plot.Floor.Color = PLOT_COLORS[i]
				plot.Model:SetAttribute("OwnerUserId", player.UserId)
				setSign(plot, player.DisplayName .. "'s Nest")
				player:SetAttribute("PlotIndex", i)
				break
			end
		end
		if not plotByPlayer[player] then
			warn("[MapService] No free plot for " .. player.Name)
			return
		end
		if player.Character then
			task.spawn(moveToPlot, player, player.Character)
		end
	end)

	Services.DataService.OnRemoving(function(player)
		local plot = plotByPlayer[player]
		if plot then
			plot.Owner = nil
			plot.Floor.Color = Color3.fromRGB(170, 170, 170)
			plot.Model:SetAttribute("OwnerUserId", nil)
			setSign(plot, "Free plot")
			plotByPlayer[player] = nil
		end
	end)
end

-- The Workspace folder that holds the world (for other services' props).
function MapService.Folder(): Folder
	return mapFolder
end

function MapService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			moveToPlot(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	-- Keep server size in line with plot count (set Max Players to 8 in Game Settings too).
	if Players.MaxPlayers > PLOT_COUNT then
		warn(
			string.format(
				"[MapService] Max Players is %d but there are only %d plots. Set Max Players to %d in Game Settings.",
				Players.MaxPlayers,
				PLOT_COUNT,
				PLOT_COUNT
			)
		)
	end
end

return MapService
