-- Visuals.luau
-- Builds eggs, dinos and labels. Dinos are drawn in code by Shared/DinoArt. If you have real models,
-- drop them into ReplicatedStorage > DinoModels (named by dino Id, e.g. "TRex")
-- or ReplicatedStorage > EggModel and they're used automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local DinoArt = require(ReplicatedStorage.Shared.DinoArt)
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

local EGG_MATERIALS: { [string]: Enum.Material } = {
	Common = Enum.Material.SmoothPlastic,
	Uncommon = Enum.Material.SmoothPlastic,
	Rare = Enum.Material.Marble,
	Epic = Enum.Material.Foil,
	Legendary = Enum.Material.Foil,
	Mythic = Enum.Material.Foil,
	Secret = Enum.Material.Neon,
}

-- Epic and up sparkle softly, Legendary and up also glow.
local function addEggEffects(part: BasePart, rarity)
	if rarity.Order < 4 then
		return
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Color = ColorSequence.new(rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4))
	sparkles.LightEmission = 1
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Rate = if rarity.Order >= 5 then 8 else 4
	sparkles.Speed = NumberRange.new(0.3, 1)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.Parent = part
	if rarity.Order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 8
		light.Brightness = 1
		light.Parent = part
	end
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
		-- A block with a sphere mesh and a taller Y: an egg shape that stays one part.
		part = Visuals.Part({
			Name = "Egg",
			Size = Vector3.new(2.4, 3, 2.4),
			Color = rarity.Color,
			Material = EGG_MATERIALS[egg.Rarity] or Enum.Material.SmoothPlastic,
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
	part.CastShadow = false
	part:SetAttribute("Rarity", egg.Rarity)
	addEggEffects(part, rarity)
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

-- A code-built dinosaur (or the real model if one exists), already scaled for its size.
function Visuals.Dino(record, incomePerSecond: number): Model
	local size = Eggs.SizeById[record.Size]
	local rarity = Eggs.RarityById[record.Rarity]

	local model = DinoArt.Get(record.DinoId)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end

	DinoArt.ApplyMutation(model, record.Mutation)

	-- Babies: big head and eyes, pink glow.
	if record.Baby then
		DinoArt.ApplyBaby(model)
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
