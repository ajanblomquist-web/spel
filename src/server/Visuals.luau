-- Visuals.luau
-- Builds the greybox look of eggs, dinos and labels. When you get real models,
-- drop them into ReplicatedStorage > DinoModels (named by dino Id, e.g. "TRex")
-- or ReplicatedStorage > EggModel and they're used automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Index = require(ReplicatedStorage.Shared.Config.Index)

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
	local name = table.concat(parts, " ")
	return if record.Baby then "Baby " .. name else name
end
Visuals.DinoDisplayName = dinoDisplayName

local BABY_HEAD_GROWTH = 1.6
local DEFAULT_MODEL_HEIGHT = 6 -- studs, same as the greybox dino
local CREAM = Color3.fromRGB(245, 236, 215)
local EYE_COLOR = Color3.fromRGB(25, 20, 28)

-- The colour of an imported model's part, from its name (see tools/blender/dino_maker.py).
local function partColor(partName: string, dino): Color3?
	local base = dino and dino.Color or Color3.fromRGB(150, 150, 150)
	local role = if string.sub(partName, 1, 4) == "Head" and #partName > 4
		then string.sub(partName, 5)
		else partName
	if string.sub(role, 1, 8) == "EyeShine" then
		return Color3.new(1, 1, 1)
	elseif string.sub(role, 1, 3) == "Eye" then
		return EYE_COLOR
	elseif role == "Body" or role == "Head" then
		return base
	elseif role == "Belly" then
		return dino and dino.Belly or base:Lerp(CREAM, 0.65)
	elseif role == "Accent" then
		return dino and dino.Accent or base:Lerp(Color3.new(0, 0, 0), 0.35)
	elseif role == "Bone" then
		return CREAM
	end
	return nil -- unknown part: keep whatever colour it was imported with
end

-- Colours, sizes and turns a model imported from Blender so it acts like the greybox:
-- PrimaryPart is "Body", it faces -Z (head in front) and stands DEFAULT_MODEL_HEIGHT tall.
local function prepareImportedModel(model: Model, dino)
	local body = (model.PrimaryPart or model:FindFirstChild("Body", true)) :: BasePart
	model.PrimaryPart = body
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			local color = partColor(d.Name, dino)
			if color then
				d.Color = color
				d.Material = Enum.Material.SmoothPlastic
				local surface = d:FindFirstChildOfClass("SurfaceAppearance")
				if surface then
					surface:Destroy() -- so the colour above shows
				end
			end
		end
	end

	-- Point the pivot so the head is in front, whatever way the file was exported.
	local head = model:FindFirstChild("Head", true)
	local forward = Vector3.new(0, 0, -1)
	if head and head:IsA("BasePart") then
		local flat = (head.Position - body.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.01 then
			forward = flat.Unit
		end
	end
	local boxCFrame = model:GetBoundingBox()
	local pivot = CFrame.lookAt(boxCFrame.Position, boxCFrame.Position + forward)
	body.PivotOffset = body.CFrame:ToObjectSpace(pivot)

	local _, size = model:GetBoundingBox()
	local height = dino and dino.Height or DEFAULT_MODEL_HEIGHT
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * height / size.Y)
	end
end

-- A greybox dinosaur (or the real model if one exists), already scaled for its size.
function Visuals.Dino(record, incomePerSecond: number): Model
	local dino = Dinos.ById[record.DinoId]
	local size = Eggs.SizeById[record.Size]
	local mutation = Eggs.MutationById[record.Mutation]
	local rarity = Eggs.RarityById[record.Rarity]

	local modelsFolder = ReplicatedStorage:FindFirstChild("DinoModels")
	local template = modelsFolder and modelsFolder:FindFirstChild(record.DinoId)

	local model: Model
	if
		template
		and template:IsA("Model")
		and (template.PrimaryPart or template:FindFirstChild("Body", true))
	then
		model = template:Clone()
		prepareImportedModel(model, dino)
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

	-- Babies: small body, big head, pink glow. Everything named Head* or Eye*
	-- grows around the head's centre, so eyes, horns and teeth stay in place.
	if record.Baby then
		local head = model:FindFirstChild("Head", true)
		if head and head:IsA("BasePart") then
			local headHeight = head.Size.Y
			local centre = head.Position
			for _, d in model:GetDescendants() do
				if
					d:IsA("BasePart")
					and (string.sub(d.Name, 1, 4) == "Head" or string.sub(d.Name, 1, 3) == "Eye")
				then
					local rotation = d.CFrame - d.Position
					local position = centre + (d.Position - centre) * BABY_HEAD_GROWTH
					d.Size *= BABY_HEAD_GROWTH
					d.CFrame = CFrame.new(position + Vector3.new(0, headHeight * 0.25, 0)) * rotation
				end
			end
		end
		local glow = Instance.new("Highlight")
		glow.FillTransparency = 1
		glow.OutlineColor = Index.BabyColor
		glow.Parent = model
	end

	local scale = (size and size.Scale or 1) * (if record.Baby then Index.BabyScale else 1)
	if scale ~= 1 then
		model:ScaleTo(scale)
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
		{
			Text = if record.Baby
				then "BABY " .. string.upper(record.Rarity)
				else string.upper(record.Rarity),
			Color = if record.Baby then Index.BabyColor else rarity.Color,
		},
		{ Text = "+" .. FormatNumber(incomePerSecond) .. "/s", Color = Color3.fromRGB(255, 230, 90) },
	}, Vector2.new(7, 3), extents.Y / 2 + 2, 80)

	return model
end

return Visuals
