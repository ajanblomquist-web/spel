-- Visuals.luau
-- Builds the greybox look of eggs, dinos and labels. When you get real models,
-- drop them into ReplicatedStorage > DinoModels (named by dino Id, e.g. "TRex")
-- or ReplicatedStorage > EggModel and they're used automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)

local Visuals = {}

local FONT = Enum.Font.FredokaOne

function Visuals.Part(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- A floating label. lines = { { Text = "...", Color = Color3 }, ... }
-- Each line gets a TextLabel named Line1, Line2... so scripts can update them.
function Visuals.Billboard(
	adornee: BasePart,
	lines: { { Text: string, Color: Color3? } },
	size: Vector2?,
	offsetY: number?,
	maxDistance: number?
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	local s = size or Vector2.new(8, 1.4 * #lines)
	gui.Size = UDim2.new(s.X, 0, s.Y, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY or 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 150
	gui.Adornee = adornee

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui

	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. i
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1 / #lines, 0)
		label.Font = FONT
		label.TextScaled = true
		label.Text = line.Text
		label.TextColor3 = line.Color or Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
		label.Parent = gui
	end

	gui.Parent = adornee
	return gui
end

-- An egg. Shows its rarity colour; size and mutation stay a surprise until it hatches.
function Visuals.Egg(egg): BasePart
	local rarity = Eggs.RarityById[egg.Rarity]
	local template = ReplicatedStorage:FindFirstChild("EggModel")
	local part: BasePart
	if template and template:IsA("BasePart") then
		part = template:Clone()
		part.Color = rarity.Color
	else
		part = Visuals.Part({
			Name = "Egg",
			Size = Vector3.new(2.4, 3, 2.4),
			Color = rarity.Color,
			Material = if egg.Rarity == "Secret" then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Name = "Egg"
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part:SetAttribute("Rarity", egg.Rarity)
	return part
end

local function dinoDisplayName(record): string
	local dino = Dinos.ById[record.DinoId]
	local parts = {}
	if record.Size ~= "Normal" then
		table.insert(parts, record.Size)
	end
	if record.Mutation ~= "None" then
		table.insert(parts, record.Mutation)
	end
	table.insert(parts, dino and dino.Name or record.DinoId)
	return table.concat(parts, " ")
end
Visuals.DinoDisplayName = dinoDisplayName

-- A greybox dinosaur (or the real model if one exists), already scaled for its size.
function Visuals.Dino(record, incomePerSecond: number): Model
	local dino = Dinos.ById[record.DinoId]
	local size = Eggs.SizeById[record.Size]
	local mutation = Eggs.MutationById[record.Mutation]
	local rarity = Eggs.RarityById[record.Rarity]

	local modelsFolder = ReplicatedStorage:FindFirstChild("DinoModels")
	local template = modelsFolder and modelsFolder:FindFirstChild(record.DinoId)

	local model: Model
	if template and template:IsA("Model") and template.PrimaryPart then
		model = template:Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	else
		model = Instance.new("Model")
		local color = dino and dino.Color or Color3.new(0.5, 0.5, 0.5)
		local body = Visuals.Part({ Name = "Body", Size = Vector3.new(3, 2.6, 5), Color = color })
		body.Parent = model
		model.PrimaryPart = body
		local function add(name, size3, offset)
			local p = Visuals.Part({ Name = name, Size = size3, Color = color })
			p.CFrame = body.CFrame * CFrame.new(offset)
			p.Parent = model
		end
		add("Head", Vector3.new(2, 2, 2.6), Vector3.new(0, 1.8, -3.2))
		add("Tail", Vector3.new(1.2, 1.2, 4), Vector3.new(0, 0.4, 4.2))
		add("LegFL", Vector3.new(0.8, 2, 0.8), Vector3.new(-1, -2.2, -1.5))
		add("LegFR", Vector3.new(0.8, 2, 0.8), Vector3.new(1, -2.2, -1.5))
		add("LegBL", Vector3.new(0.8, 2, 0.8), Vector3.new(-1, -2.2, 1.5))
		add("LegBR", Vector3.new(0.8, 2, 0.8), Vector3.new(1, -2.2, 1.5))
		add("EyeL", Vector3.new(0.3, 0.4, 0.3), Vector3.new(-0.9, 2.3, -4.2))
		add("EyeR", Vector3.new(0.3, 0.4, 0.3), Vector3.new(0.9, 2.3, -4.2))
		for _, name in { "EyeL", "EyeR" } do
			(model:FindFirstChild(name) :: BasePart).Color = Color3.new(0, 0, 0)
		end
	end

	if mutation and mutation.Id ~= "None" then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and not string.find(d.Name, "Eye") then
				d.Color = mutation.Color
				d.Material = mutation.Material
			end
		end
	end

	if size and size.Scale ~= 1 then
		model:ScaleTo(size.Scale)
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end

	model.Name = record.DinoId
	local _, extents = model:GetBoundingBox()
	Visuals.Billboard(model.PrimaryPart :: BasePart, {
		{ Text = dinoDisplayName(record) },
		{ Text = string.upper(record.Rarity), Color = rarity.Color },
		{ Text = "+" .. FormatNumber(incomePerSecond) .. "/s", Color = Color3.fromRGB(255, 230, 90) },
	}, Vector2.new(7, 3), extents.Y / 2 + 2, 80)

	return model
end

return Visuals
