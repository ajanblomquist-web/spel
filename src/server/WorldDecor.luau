-- WorldDecor.luau
-- Dresses the greybox world so it looks finished, using only code-built Parts
-- (no uploaded assets). MapService calls this after it builds the gameplay
-- parts, and none of the gameplay parts are touched here.
--   * WorldDecor.Zones   scatters rocks, plants, bones, crystals and so on along
--                        every zone in Zones.luau, plus a gate sign at each zone
--                        start. Each zone's look is a table in THEMES (keyed by
--                        zone Id); a zone with no entry gets FALLBACK_THEME, so a
--                        new zone is dressed automatically.
--   * WorldDecor.Hub     the paleontologist camp: paths, tents, campfire, fossil
--                        display, training ground, nicer launch pad, big sign.
--   * WorldDecor.Landscape  the world around the play area: ground out to the
--                        horizon, cliffs along the canyon, distant mountains, a
--                        huge volcano, lakes and a river, palms, big trees and
--                        slow clouds (cheap, big, far-away shapes).
--   * WorldDecor.Plot    fence, corner lanterns, nest straw and colourable border
--                        strips (named "Border") for one player plot.
-- Everything is Anchored and uses a seeded Random, so every server gets the
-- same world. Small props never collide, can't be clicked or hit by raycasts and
-- cast no shadow, so they can't block walking, digging or prompts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local WorldDecor = {}

export type Config = {
	Origin: Vector3, -- where distances are measured from (LaunchOrigin)
	CanyonWidth: number,
	PadPosition: Vector3,
	RockPosition: Vector3,
	HubHalfWidth: number,
	HubBackZ: number,
	PlotZ: number,
	PlotCount: number,
	PlotSpacing: number,
	PlotSize: number,
}

local FONT = Enum.Font.FredokaOne
local WOOD = Color3.fromRGB(120, 82, 52)
local DARK_WOOD = Color3.fromRGB(78, 54, 38)
local STONE = Color3.fromRGB(150, 146, 138)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- Part helpers ---------------------------------------------------------------

type Extra = { [string]: any }

-- Makes one anchored, non-colliding decoration part. kind: Block, Ball,
-- Cylinder (its length runs along the part's X axis) or Wedge.
local function make(
	parent: Instance,
	kind: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	extra: Extra?
): any
	local part: any
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		if kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if extra then
		for key, value in extra do
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A vertical cylinder standing on `base`.
local function post(
	parent: Instance,
	base: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	extra: Extra?
): any
	return make(
		parent,
		"Cylinder",
		Vector3.new(height, diameter, diameter),
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		extra
	)
end

-- A flat disc lying on the ground (thickness is its height).
local function disc(
	parent: Instance,
	center: Vector3,
	diameter: number,
	thickness: number,
	yaw: number,
	color: Color3,
	material: Enum.Material?,
	extra: Extra?
): any
	return make(
		parent,
		"Cylinder",
		Vector3.new(thickness, diameter, diameter),
		CFrame.new(center.X, center.Y + thickness / 2, center.Z) * CFrame.Angles(0, yaw, math.rad(90)),
		color,
		material,
		extra
	)
end

local function upFor(direction: Vector3): Vector3
	if math.abs(direction.Unit.Y) > 0.99 then
		return Vector3.xAxis
	end
	return Vector3.yAxis
end

-- A cylinder running from point a to point b.
local function beam(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	extra: Extra?
): any
	local mid = (a + b) / 2
	local cframe = CFrame.lookAt(mid, b, upFor(b - a)) * CFrame.Angles(0, math.rad(90), 0)
	return make(
		parent,
		"Cylinder",
		Vector3.new((b - a).Magnitude, diameter, diameter),
		cframe,
		color,
		material,
		extra
	)
end

-- A square-section bar running from point a to point b.
local function rod(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	width: number,
	thickness: number,
	color: Color3,
	material: Enum.Material?,
	extra: Extra?
): any
	local mid = (a + b) / 2
	local cframe = CFrame.lookAt(mid, b, upFor(b - a))
	return make(
		parent,
		"Block",
		Vector3.new(width, thickness, (b - a).Magnitude),
		cframe,
		color,
		material,
		extra
	)
end

local function shade(color: Color3, rng: Random, amount: number): Color3
	local k = rng:NextNumber(-amount, amount)
	if k >= 0 then
		return color:Lerp(WHITE, k)
	end
	return color:Lerp(BLACK, -k)
end

local function pick(rng: Random, list: { any }): any
	return list[rng:NextInteger(1, #list)]
end

-- A sign board with text on both faces. lines = { { Text, Color, Height } } where
-- Height is the share of the board's height for that line.
local function signBoard(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	background: Color3,
	lines: { { Text: string, Color: Color3, Height: number } }
): any
	local board =
		make(parent, "Block", size, cframe, background, Enum.Material.WoodPlanks, { CastShadow = true })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0.3
		gui.MaxDistance = 400
		gui.Parent = board
		local y = 0.06
		for _, line in lines do
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(0.04, y)
			label.Size = UDim2.fromScale(0.92, line.Height)
			label.Font = FONT
			label.TextScaled = true
			label.Text = line.Text
			label.TextColor3 = line.Color
			label.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Color = Color3.fromRGB(40, 24, 14)
			stroke.Parent = label
			y += line.Height
		end
	end
	return board
end

local function light(part: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
end

-- Props (all take a ground position and a scale) -------------------------------

type Ctx = { Parent: Instance, Rng: Random, LightsLeft: number }

-- A chunky rock: one or two tilted blocks.
local function rock(ctx: Ctx, pos: Vector3, scale: number, color: Color3, material: Enum.Material)
	local rng = ctx.Rng
	local tilt = CFrame.Angles(
		rng:NextNumber(-0.18, 0.18),
		rng:NextNumber(0, math.pi * 2),
		rng:NextNumber(-0.18, 0.18)
	)
	local main = make(
		ctx.Parent,
		"Block",
		Vector3.new(
			scale * rng:NextNumber(0.9, 1.4),
			scale * rng:NextNumber(0.6, 1),
			scale * rng:NextNumber(0.9, 1.3)
		),
		CFrame.new(pos + Vector3.new(0, scale * 0.25, 0)) * tilt,
		shade(color, rng, 0.12),
		material,
		{ CastShadow = scale > 2.5 }
	)
	if scale > 1.8 then
		local side = rng:NextNumber(0, math.pi * 2)
		make(
			ctx.Parent,
			"Block",
			Vector3.new(scale * 0.6, scale * 0.45, scale * 0.6),
			CFrame.new(
				pos + Vector3.new(math.cos(side) * scale * 0.8, scale * 0.12, math.sin(side) * scale * 0.8)
			) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), 0),
			shade(color, rng, 0.15),
			material
		)
	end
	return main
end

-- A bone half buried in the ground: a shaft with a knob at each end.
local function bone(ctx: Ctx, pos: Vector3, scale: number, color: Color3)
	local rng = ctx.Rng
	local angle = rng:NextNumber(0, math.pi * 2)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local half = rng:NextNumber(1.6, 2.6) * scale
	local a = pos - direction * half + Vector3.new(0, 0.2 * scale, 0)
	local b = pos + direction * half + Vector3.new(0, rng:NextNumber(0.3, 0.9) * scale, 0)
	local c = shade(color, rng, 0.06)
	beam(ctx.Parent, a, b, 0.55 * scale, c, Enum.Material.Slate)
	make(ctx.Parent, "Ball", Vector3.one * 0.95 * scale, CFrame.new(a), c, Enum.Material.Slate)
	make(ctx.Parent, "Ball", Vector3.one * 0.95 * scale, CFrame.new(b), c, Enum.Material.Slate)
end

local function cactus(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local green = shade(Color3.fromRGB(84, 140, 82), rng, 0.1)
	local height = 4 * scale * rng:NextNumber(0.8, 1.2)
	post(ctx.Parent, pos, height, 1.2 * scale, green, Enum.Material.Slate, { CastShadow = scale > 1.5 })
	make(
		ctx.Parent,
		"Ball",
		Vector3.one * 1.2 * scale,
		CFrame.new(pos + Vector3.new(0, height, 0)),
		green,
		Enum.Material.Slate
	)
	local angle = rng:NextNumber(0, math.pi * 2)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.4 * scale
	local armBase = pos + Vector3.new(0, height * 0.5, 0)
	beam(ctx.Parent, armBase, armBase + out, 0.7 * scale, green, Enum.Material.Slate)
	post(ctx.Parent, armBase + out, 1.4 * scale, 0.7 * scale, green, Enum.Material.Slate)
end

-- A stacked rock tower (mesas, cliff pillars, spires).
local function tower(ctx: Ctx, pos: Vector3, scale: number, color: Color3, material: Enum.Material)
	local rng = ctx.Rng
	local yaw = rng:NextNumber(0, math.pi)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local s = scale
	make(
		ctx.Parent,
		"Block",
		Vector3.new(s * 1.1, s * 1.8, s * 1),
		base * CFrame.new(0, s * 0.9, 0),
		shade(color, rng, 0.08),
		material,
		{ CastShadow = true }
	)
	make(
		ctx.Parent,
		"Block",
		Vector3.new(s * 0.85, s * 1.5, s * 0.8),
		base * CFrame.new(s * 0.05, s * 2.55, 0) * CFrame.Angles(0, 0.3, 0),
		shade(color:Lerp(WHITE, 0.08), rng, 0.08),
		material,
		{ CastShadow = true }
	)
	make(
		ctx.Parent,
		"Block",
		Vector3.new(s * 0.55, s * 0.9, s * 0.5),
		base * CFrame.new(-s * 0.05, s * 3.7, 0) * CFrame.Angles(0, 0.6, 0),
		shade(color:Lerp(WHITE, 0.15), rng, 0.08),
		material,
		{ CastShadow = true }
	)
end

local function fern(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local base = rng:NextNumber(0, math.pi * 2)
	local color = shade(Color3.fromRGB(70, 150, 70), rng, 0.12)
	local length = 1.6 * scale
	local tilt = math.rad(30)
	for i = 0, 4 do
		local angle = base + i * (math.pi * 2 / 5) + rng:NextNumber(-0.2, 0.2)
		make(
			ctx.Parent,
			"Block",
			Vector3.new(0.5 * scale, 0.08, length * 2),
			CFrame.new(pos)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0.1 + length * math.sin(tilt), -length * math.cos(tilt))
				* CFrame.Angles(tilt, 0, 0),
			color,
			Enum.Material.Grass
		)
	end
end

local function flower(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	post(ctx.Parent, pos, 1 * scale, 0.12 * scale, Color3.fromRGB(70, 130, 60), Enum.Material.Grass)
	local head = pick(rng, {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 225, 90),
		Color3.fromRGB(250, 250, 250),
		Color3.fromRGB(190, 130, 255),
	})
	make(
		ctx.Parent,
		"Ball",
		Vector3.one * 0.5 * scale,
		CFrame.new(pos + Vector3.new(0, 1 * scale, 0)),
		head,
		Enum.Material.SmoothPlastic
	)
end

local function tree(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local height = 5 * scale
	post(ctx.Parent, pos, height, 1 * scale, DARK_WOOD, Enum.Material.Wood, { CastShadow = true })
	local green = Color3.fromRGB(70, 150, 66)
	local top = pos + Vector3.new(0, height + 1.2 * scale, 0)
	make(
		ctx.Parent,
		"Ball",
		Vector3.one * 7 * scale,
		CFrame.new(top),
		shade(green, rng, 0.1),
		Enum.Material.Grass,
		{ CastShadow = true }
	)
	for i = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		make(
			ctx.Parent,
			"Ball",
			Vector3.one * 5 * scale,
			CFrame.new(
				top
					+ Vector3.new(
						math.cos(angle) * 2.4 * scale,
						-1.2 * scale * i / 2,
						math.sin(angle) * 2.4 * scale
					)
			),
			shade(green, rng, 0.12),
			Enum.Material.Grass,
			{ CastShadow = true }
		)
	end
end

local function deadTree(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local height = 6 * scale
	local wood = shade(Color3.fromRGB(66, 52, 44), rng, 0.08)
	post(ctx.Parent, pos, height, 0.9 * scale, wood, Enum.Material.Wood, { CastShadow = true })
	for _ = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local from = pos + Vector3.new(0, height * rng:NextNumber(0.55, 0.9), 0)
		local to = from
			+ Vector3.new(
				math.cos(angle) * 2.4 * scale,
				rng:NextNumber(0.8, 2) * scale,
				math.sin(angle) * 2.4 * scale
			)
		beam(ctx.Parent, from, to, 0.35 * scale, wood, Enum.Material.Wood)
	end
end

local function tarPuddle(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local tar = Color3.fromRGB(18, 16, 22)
	local size = 5 * scale
	disc(
		ctx.Parent,
		pos + Vector3.new(0, 0.01, 0),
		size,
		0.1,
		rng:NextNumber(0, 3),
		tar,
		Enum.Material.SmoothPlastic,
		{ Reflectance = 0.3 }
	)
	for _ = 1, rng:NextInteger(1, 2) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0.4, 0.9) * scale
		make(
			ctx.Parent,
			"Ball",
			Vector3.new(d, d * 0.8, d),
			CFrame.new(pos + Vector3.new(math.cos(angle) * size * 0.25, 0.1, math.sin(angle) * size * 0.25)),
			Color3.fromRGB(34, 32, 40),
			Enum.Material.SmoothPlastic,
			{ Reflectance = 0.35 }
		)
	end
end

-- A glowing crystal cluster. Used for amber and (in ice colours) ice spikes.
local function crystals(
	ctx: Ctx,
	pos: Vector3,
	scale: number,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	glow: boolean
)
	local rng = ctx.Rng
	local count = rng:NextInteger(3, 4)
	local first: any = nil
	for i = 1, count do
		local height = rng:NextNumber(2, 4) * scale * (if i == 1 then 1.3 else 1)
		local width = rng:NextNumber(0.5, 0.8) * scale
		local lean = if i == 1 then 0.05 else rng:NextNumber(0.2, 0.5)
		local angle = rng:NextNumber(0, math.pi * 2)
		local offset = if i == 1 then 0 else scale * 0.6
		local shard = make(
			ctx.Parent,
			"Block",
			Vector3.new(width, height, width),
			CFrame.new(pos + Vector3.new(math.cos(angle) * offset, height * 0.42, math.sin(angle) * offset))
				* CFrame.Angles(math.cos(angle) * lean, rng:NextNumber(0, math.pi), math.sin(angle) * lean),
			shade(color, rng, 0.06),
			material,
			{
				Transparency = transparency,
				CastShadow = scale > 1.5,
				Reflectance = if material == Enum.Material.Neon then 0 else 0.15,
			}
		)
		first = first or shard
	end
	if glow and first and ctx.LightsLeft > 0 and rng:NextNumber() < 0.25 then
		ctx.LightsLeft -= 1
		light(first, color, 16, 1.2)
	end
end

local function snowDrift(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local white = Color3.fromRGB(240, 246, 255)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	make(
		ctx.Parent,
		"Ball",
		Vector3.new(6 * scale, 2 * scale, 4.5 * scale),
		CFrame.new(pos + Vector3.new(0, 0.1, 0)) * yaw,
		white,
		Enum.Material.Snow
	)
	make(
		ctx.Parent,
		"Ball",
		Vector3.new(3.4 * scale, 1.4 * scale, 3 * scale),
		CFrame.new(pos + Vector3.new(2 * scale, 0, 1.2 * scale)) * yaw,
		shade(white, rng, 0.03),
		Enum.Material.Snow
	)
end

local function lavaCrack(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local angle = rng:NextNumber(0, math.pi * 2)
	local from = pos + Vector3.new(0, 0.12, 0)
	local color = pick(rng, { Color3.fromRGB(255, 110, 30), Color3.fromRGB(255, 150, 40) })
	for _ = 1, 3 do
		angle += rng:NextNumber(-0.8, 0.8)
		local to = from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(3, 6) * scale
		rod(ctx.Parent, from, to, 0.5 * scale, 0.1, color, Enum.Material.Neon)
		from = to
	end
end

local function lavaPool(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local yaw = rng:NextNumber(0, 3)
	disc(ctx.Parent, pos, 8 * scale, 0.14, yaw, Color3.fromRGB(30, 22, 22), Enum.Material.Basalt)
	local lava = disc(ctx.Parent, pos, 6 * scale, 0.18, yaw, Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	if ctx.LightsLeft > 0 and rng:NextNumber() < 0.3 then
		ctx.LightsLeft -= 1
		light(lava, Color3.fromRGB(255, 120, 40), 18, 1.2)
	end
end

-- A big volcano with a glowing crater and a puff of smoke (two ParticleEmitters
-- on one invisible part). `base` is on the ground.
local function volcano(parent: Instance, base: Vector3, scale: number)
	local near = scale < 3 -- far-away giants skip shadows
	local stone = Color3.fromRGB(46, 38, 38)
	local y = 0
	local layers = { { 46, 12 }, { 36, 12 }, { 26, 12 }, { 16, 10 } }
	for _, layer in layers do
		local d, h = layer[1] * scale, layer[2] * scale
		post(
			parent,
			base + Vector3.new(0, y, 0),
			h,
			d,
			stone:Lerp(WHITE, y / (60 * scale) * 0.2),
			Enum.Material.Basalt,
			{ CastShadow = near }
		)
		y += h
	end
	local crater = disc(
		parent,
		base + Vector3.new(0, y, 0),
		10 * scale,
		0.4,
		0,
		Color3.fromRGB(255, 110, 30),
		Enum.Material.Neon
	)
	light(crater, Color3.fromRGB(255, 120, 40), math.min(60, 40 * scale), 1.5)

	local emitterPart = make(
		parent,
		"Block",
		Vector3.one,
		CFrame.new(base + Vector3.new(0, y + 1, 0)),
		WHITE,
		nil,
		{ Transparency = 1 }
	)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(86, 80, 80))
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(6, 9)
	smoke.Speed = NumberRange.new(6 * math.sqrt(scale), 10 * math.sqrt(scale))
	smoke.SpreadAngle = Vector2.new(14, 14)
	smoke.Acceleration = Vector3.new(2, 2, 0)
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5 * scale),
		NumberSequenceKeypoint.new(1, 22 * scale),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.7, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.LightInfluence = 0.6
	smoke.Parent = emitterPart
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50))
	embers.LightEmission = 1
	embers.Rate = 4
	embers.Lifetime = NumberRange.new(2, 4)
	embers.Speed = NumberRange.new(10 * math.sqrt(scale), 18 * math.sqrt(scale))
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0, -4, 0)
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	embers.Parent = emitterPart
end

-- Themes ------------------------------------------------------------------------
-- Each prop: Make(ctx, position, scale), Where ("lane" = anywhere on the
-- floor, kept low or small; "edge" = along the canyon walls, off the landing
-- lanes; "back" = behind the walls as a backdrop), Per100 (props per 100 studs
-- of zone length) and Scale (min, max). Add a theme here for a new zone, or
-- let it use FALLBACK_THEME.

type Prop = {
	Make: (Ctx, Vector3, number) -> (),
	Where: string,
	Per100: number,
	Scale: { number },
}

type Theme = {
	Props: { Prop },
	Patches: { Color3 }, -- ground colour variation (flat discs)
	Backdrop: Color3, -- colour of the ground behind the canyon walls
	Volcanoes: boolean?,
}

local BONE_COLOR = Color3.fromRGB(235, 226, 204)

local function rocks(color: Color3, material: Enum.Material)
	return function(ctx: Ctx, pos: Vector3, scale: number)
		rock(ctx, pos, scale, color, material)
	end
end

local function towers(color: Color3, material: Enum.Material)
	return function(ctx: Ctx, pos: Vector3, scale: number)
		tower(ctx, pos, scale, color, material)
	end
end

local function bones(color: Color3)
	return function(ctx: Ctx, pos: Vector3, scale: number)
		bone(ctx, pos, scale, color)
	end
end

local function crystalCluster(color: Color3, material: Enum.Material, transparency: number, glow: boolean)
	return function(ctx: Ctx, pos: Vector3, scale: number)
		crystals(ctx, pos, scale, color, material, transparency, glow)
	end
end

local function mossyRock(ctx: Ctx, pos: Vector3, scale: number)
	local main = rock(ctx, pos, scale, Color3.fromRGB(122, 124, 116), Enum.Material.Rock)
	make(
		ctx.Parent,
		"Block",
		Vector3.new(main.Size.X * 0.85, 0.3, main.Size.Z * 0.8),
		CFrame.new(main.Position + Vector3.new(0, main.Size.Y * 0.5 - 0.05, 0)),
		Color3.fromRGB(86, 150, 70),
		Enum.Material.Grass
	)
end

local THEMES: { [string]: Theme } = {
	SandyPit = {
		Backdrop = Color3.fromRGB(214, 186, 132),
		Patches = {
			Color3.fromRGB(238, 214, 160),
			Color3.fromRGB(205, 175, 122),
			Color3.fromRGB(196, 160, 110),
		},
		Props = {
			{
				Make = rocks(Color3.fromRGB(205, 160, 105), Enum.Material.Sandstone),
				Where = "edge",
				Per100 = 9,
				Scale = { 2.5, 6 },
			},
			{
				Make = rocks(Color3.fromRGB(205, 160, 105), Enum.Material.Sandstone),
				Where = "lane",
				Per100 = 6,
				Scale = { 0.8, 1.6 },
			},
			{ Make = bones(BONE_COLOR), Where = "lane", Per100 = 7, Scale = { 0.8, 1.3 } },
			{ Make = cactus, Where = "edge", Per100 = 6, Scale = { 1.2, 1.8 } },
			{ Make = cactus, Where = "lane", Per100 = 3, Scale = { 0.35, 0.55 } },
			{
				Make = towers(Color3.fromRGB(196, 140, 92), Enum.Material.Sandstone),
				Where = "back",
				Per100 = 5,
				Scale = { 6, 12 },
			},
		},
	},
	FernValley = {
		Backdrop = Color3.fromRGB(96, 150, 78),
		Patches = { Color3.fromRGB(128, 188, 98), Color3.fromRGB(92, 150, 74), Color3.fromRGB(150, 176, 90) },
		Props = {
			{ Make = fern, Where = "lane", Per100 = 7, Scale = { 0.8, 1.3 } },
			{ Make = flower, Where = "lane", Per100 = 5, Scale = { 0.9, 1.4 } },
			{ Make = mossyRock, Where = "edge", Per100 = 4, Scale = { 2, 4.5 } },
			{ Make = tree, Where = "edge", Per100 = 4, Scale = { 0.9, 1.3 } },
			{ Make = tree, Where = "back", Per100 = 3, Scale = { 1.2, 1.9 } },
			{ Make = fern, Where = "edge", Per100 = 4, Scale = { 1.4, 2 } },
		},
	},
	TarPits = {
		Backdrop = Color3.fromRGB(70, 64, 72),
		Patches = { Color3.fromRGB(44, 40, 48), Color3.fromRGB(72, 66, 72), Color3.fromRGB(52, 48, 40) },
		Props = {
			{ Make = tarPuddle, Where = "lane", Per100 = 8, Scale = { 0.9, 2 } },
			{ Make = deadTree, Where = "edge", Per100 = 4, Scale = { 0.8, 1.3 } },
			{ Make = deadTree, Where = "back", Per100 = 3, Scale = { 1.3, 2 } },
			{
				Make = rocks(Color3.fromRGB(66, 62, 70), Enum.Material.Slate),
				Where = "edge",
				Per100 = 5,
				Scale = { 2, 5 },
			},
			{ Make = bones(Color3.fromRGB(190, 180, 160)), Where = "lane", Per100 = 4, Scale = { 0.9, 1.4 } },
			{
				Make = rocks(Color3.fromRGB(46, 42, 50), Enum.Material.Slate),
				Where = "back",
				Per100 = 3,
				Scale = { 6, 12 },
			},
		},
	},
	AmberCliffs = {
		Backdrop = Color3.fromRGB(206, 138, 56),
		Patches = { Color3.fromRGB(246, 182, 80), Color3.fromRGB(208, 130, 44), Color3.fromRGB(180, 112, 52) },
		Props = {
			{
				Make = towers(Color3.fromRGB(214, 128, 52), Enum.Material.Sandstone),
				Where = "edge",
				Per100 = 3,
				Scale = { 3, 5 },
			},
			{
				Make = towers(Color3.fromRGB(198, 116, 48), Enum.Material.Sandstone),
				Where = "back",
				Per100 = 5,
				Scale = { 7, 14 },
			},
			{
				Make = crystalCluster(Color3.fromRGB(255, 176, 40), Enum.Material.Neon, 0.15, true),
				Where = "lane",
				Per100 = 4,
				Scale = { 0.5, 0.8 },
			},
			{
				Make = crystalCluster(Color3.fromRGB(255, 176, 40), Enum.Material.Neon, 0.15, true),
				Where = "edge",
				Per100 = 5,
				Scale = { 1.2, 2.2 },
			},
			{
				Make = rocks(Color3.fromRGB(176, 104, 52), Enum.Material.Sandstone),
				Where = "edge",
				Per100 = 5,
				Scale = { 2, 5 },
			},
			{
				Make = rocks(Color3.fromRGB(176, 104, 52), Enum.Material.Sandstone),
				Where = "lane",
				Per100 = 5,
				Scale = { 0.8, 1.5 },
			},
		},
	},
	FrozenTundra = {
		Backdrop = Color3.fromRGB(214, 230, 245),
		Patches = {
			Color3.fromRGB(250, 252, 255),
			Color3.fromRGB(196, 222, 244),
			Color3.fromRGB(176, 206, 232),
		},
		Props = {
			{ Make = snowDrift, Where = "lane", Per100 = 8, Scale = { 0.7, 1.4 } },
			{
				Make = crystalCluster(Color3.fromRGB(170, 224, 255), Enum.Material.Ice, 0.25, false),
				Where = "lane",
				Per100 = 4,
				Scale = { 0.5, 0.8 },
			},
			{
				Make = crystalCluster(Color3.fromRGB(170, 224, 255), Enum.Material.Ice, 0.25, false),
				Where = "edge",
				Per100 = 6,
				Scale = { 1.4, 2.6 },
			},
			{ Make = bones(Color3.fromRGB(205, 228, 244)), Where = "lane", Per100 = 4, Scale = { 0.9, 1.4 } },
			{
				Make = rocks(Color3.fromRGB(190, 204, 220), Enum.Material.Slate),
				Where = "edge",
				Per100 = 5,
				Scale = { 2, 5 },
			},
			{
				Make = crystalCluster(Color3.fromRGB(150, 210, 250), Enum.Material.Glass, 0.35, false),
				Where = "back",
				Per100 = 4,
				Scale = { 4, 8 },
			},
		},
	},
	VolcanoRim = {
		Backdrop = Color3.fromRGB(52, 36, 34),
		Patches = { Color3.fromRGB(40, 28, 28), Color3.fromRGB(84, 46, 36), Color3.fromRGB(58, 40, 40) },
		Volcanoes = true,
		Props = {
			{
				Make = rocks(Color3.fromRGB(38, 34, 36), Enum.Material.Basalt),
				Where = "edge",
				Per100 = 7,
				Scale = { 2, 5.5 },
			},
			{
				Make = rocks(Color3.fromRGB(38, 34, 36), Enum.Material.Basalt),
				Where = "lane",
				Per100 = 5,
				Scale = { 0.8, 1.6 },
			},
			{ Make = lavaCrack, Where = "lane", Per100 = 8, Scale = { 0.8, 1.4 } },
			{ Make = lavaPool, Where = "lane", Per100 = 3, Scale = { 0.8, 1.5 } },
			{
				Make = towers(Color3.fromRGB(34, 30, 32), Enum.Material.Basalt),
				Where = "back",
				Per100 = 5,
				Scale = { 6, 12 },
			},
		},
	},
}

-- Used for any zone without a THEMES entry: rocks in the zone's own colour.
local function fallbackTheme(zone: Zones.Zone): Theme
	return {
		Backdrop = zone.Color:Lerp(BLACK, 0.1),
		Patches = { zone.Color:Lerp(WHITE, 0.12), zone.Color:Lerp(BLACK, 0.12) },
		Props = {
			{
				Make = rocks(zone.Color:Lerp(BLACK, 0.2), zone.Material),
				Where = "edge",
				Per100 = 7,
				Scale = { 2, 5 },
			},
			{
				Make = rocks(zone.Color:Lerp(BLACK, 0.2), zone.Material),
				Where = "lane",
				Per100 = 6,
				Scale = { 0.8, 1.5 },
			},
			{ Make = bones(BONE_COLOR), Where = "lane", Per100 = 4, Scale = { 0.8, 1.3 } },
			{
				Make = towers(zone.Color:Lerp(BLACK, 0.15), zone.Material),
				Where = "back",
				Per100 = 4,
				Scale = { 6, 12 },
			},
		},
	}
end

-- Zone dressing -----------------------------------------------------------------

local EDGE_MIN, EDGE_MAX = 70, 77.5 -- just outside the landing lanes (flings land within +-68)
local BACK_MIN, BACK_MAX = 165, 300 -- behind the cliff wall (see Landscape)

local function samplePosition(rng: Random, where: string, z0: number, z1: number, origin: Vector3): Vector3
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local x: number
	if where == "edge" then
		x = side * rng:NextNumber(EDGE_MIN, EDGE_MAX)
	elseif where == "back" then
		x = side * rng:NextNumber(BACK_MIN, BACK_MAX)
	else
		x = rng:NextNumber(-66, 66)
	end
	return Vector3.new(origin.X + x, 0, rng:NextNumber(z0, z1))
end

-- One gate at the start of a zone: two tall pillars at the canyon edges, each
-- holding a board with the zone name and luck.
local function zoneGate(parent: Instance, zone: Zones.Zone, z: number, cfg: Config)
	local halfWidth = cfg.CanyonWidth / 2
	local accent = zone.Color:Lerp(WHITE, 0.15)
	for _, side in { -1, 1 } do
		local x = cfg.Origin.X + side * (halfWidth - 14)
		local base = Vector3.new(x, 0, z)
		make(
			parent,
			"Block",
			Vector3.new(6, 2.5, 6),
			CFrame.new(base + Vector3.new(0, 1.25, 0)),
			STONE,
			Enum.Material.Cobblestone,
			{ CastShadow = true }
		)
		post(
			parent,
			base + Vector3.new(0, 2.5, 0),
			20,
			3,
			Color3.fromRGB(122, 100, 82),
			Enum.Material.Wood,
			{ CastShadow = true }
		)
		make(
			parent,
			"Ball",
			Vector3.one * 4,
			CFrame.new(base + Vector3.new(0, 23.5, 0)),
			accent,
			Enum.Material.Neon
		)
		local boardCenter = Vector3.new(x - side * 11, 17, z)
		signBoard(parent, CFrame.new(boardCenter), Vector3.new(20, 8.4, 1), Color3.fromRGB(86, 60, 42), {
			{ Text = string.upper(zone.Name), Color = WHITE, Height = 0.58 },
			{ Text = Zones.LuckText(zone), Color = Color3.fromRGB(130, 255, 150), Height = 0.3 },
		})
		make(
			parent,
			"Block",
			Vector3.new(20.6, 0.8, 1.4),
			CFrame.new(boardCenter + Vector3.new(0, 4.5, 0)),
			accent,
			Enum.Material.Neon
		)
	end
end

-- The glowing lava material would light up huge flat areas, so it is swapped for
-- plain basalt on discs and the ground behind the walls.
local function groundMaterial(zone: Zones.Zone): Enum.Material
	if zone.Material == Enum.Material.CrackedLava then
		return Enum.Material.Basalt
	end
	return zone.Material
end

local function dressZone(parent: Instance, zone: Zones.Zone, index: number, cfg: Config)
	local folder = Instance.new("Folder")
	folder.Name = "Dressing_" .. zone.Id
	folder.Parent = parent

	local theme = THEMES[zone.Id] or fallbackTheme(zone)
	local rng = Random.new(7919 * index + 104729)
	local ctx: Ctx = { Parent = folder, Rng = rng, LightsLeft = 6 }
	local origin = cfg.Origin
	local zStart = origin.Z + zone.StartDistance
	local zEnd = origin.Z + zone.EndDistance
	local length = zone.EndDistance - zone.StartDistance
	local z0, z1 = zStart + 8, zEnd - 4

	-- Ground behind the walls, so the canyon doesn't float in the void.
	local outer = theme.Backdrop
	for _, side in { -1, 1 } do
		make(
			folder,
			"Block",
			Vector3.new(340, 1, length),
			CFrame.new(origin.X + side * (cfg.CanyonWidth / 2 + 1 + 170), -0.5, zStart + length / 2),
			outer,
			groundMaterial(zone),
			{ CanCollide = true }
		)
	end

	-- Plain ground further out, so the horizon never shows a void.
	for _, side in { -1, 1 } do
		make(
			folder,
			"Block",
			Vector3.new(1380, 1, length),
			CFrame.new(origin.X + side * (421 + 690), -0.5, zStart + length / 2),
			outer:Lerp(Color3.fromRGB(170, 180, 150), 0.25),
			groundMaterial(zone),
			{ CanCollide = true }
		)
	end

	-- Ground colour variation: big flat discs of slightly different colour.
	local patchCount = math.floor(length / 14)
	for _ = 1, patchCount do
		local pos = Vector3.new(origin.X + rng:NextNumber(-76, 76), 0, rng:NextNumber(zStart + 4, zEnd - 4))
		disc(
			folder,
			pos,
			rng:NextNumber(10, 30),
			rng:NextNumber(0.03, 0.08),
			rng:NextNumber(0, 3),
			pick(rng, theme.Patches),
			groundMaterial(zone)
		)
	end

	for _, prop in theme.Props do
		local count = math.floor(prop.Per100 * length / 100 + 0.5)
		for _ = 1, count do
			local pos = samplePosition(rng, prop.Where, z0, z1, origin)
			local scale = rng:NextNumber(prop.Scale[1], prop.Scale[2])
			prop.Make(ctx, pos, scale)
		end
	end

	if theme.Volcanoes then
		for i = 1, 2 do
			local side = if i == 1 then -1 else 1
			volcano(folder, Vector3.new(origin.X + side * 150, 0, zStart + length * (0.3 + 0.4 * (i - 1))), 1)
		end
	end

	zoneGate(folder, zone, zStart + (if zone.StartDistance == 0 then 10 else 0), cfg)
end

function WorldDecor.Zones(parent: Instance, cfg: Config)
	for index, zone in Zones.List do
		dressZone(parent, zone, index, cfg)
	end

	-- A wall of mountains at the far end of the map.
	local folder = Instance.new("Folder")
	folder.Name = "Dressing_FarEnd"
	folder.Parent = parent
	local endZ = cfg.Origin.Z + Zones.MaxDistance
	local rng = Random.new(4242)
	for i = -4, 4 do
		local height = rng:NextNumber(60, 130)
		local width = rng:NextNumber(90, 150)
		make(
			folder,
			"Block",
			Vector3.new(width, height, width),
			CFrame.new(cfg.Origin.X + i * 80, height / 2 - 2, endZ + 90 + rng:NextNumber(0, 40))
				* CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
			Color3.fromRGB(50, 36, 36),
			Enum.Material.Basalt,
			{ CastShadow = true }
		)
	end
	make(
		folder,
		"Block",
		Vector3.new(3600, 1, 1200),
		CFrame.new(cfg.Origin.X, -0.5, endZ + 600),
		Color3.fromRGB(52, 36, 34),
		Enum.Material.Basalt
	)
end

-- Hub ---------------------------------------------------------------------------

local function tent(parent: Instance, center: Vector3, yaw: number, color: Color3)
	local base = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	local angle = math.rad(50)
	local length = 5
	local halfSpan = length / 2 * math.cos(angle)
	local rise = length / 2 * math.sin(angle)
	for _, side in { -1, 1 } do
		make(
			parent,
			"Block",
			Vector3.new(length, 0.25, 6),
			base * CFrame.new(side * halfSpan, rise, 0) * CFrame.Angles(0, 0, -side * angle),
			if side == 1 then color else color:Lerp(WHITE, 0.15),
			Enum.Material.Fabric,
			{ CastShadow = true }
		)
	end
	make(
		parent,
		"Block",
		Vector3.new(2.2, 1.3, 5.8),
		base * CFrame.new(0, 0.65, 0),
		Color3.fromRGB(40, 30, 28),
		Enum.Material.Fabric
	)
	make(
		parent,
		"Block",
		Vector3.new(0.4, 0.4, 6.2),
		base * CFrame.new(0, rise * 2, 0),
		DARK_WOOD,
		Enum.Material.Wood
	)
end

local function crate(parent: Instance, pos: Vector3, size: number, yaw: number)
	local c = make(
		parent,
		"Block",
		Vector3.one * size,
		CFrame.new(pos + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, yaw, 0),
		Color3.fromRGB(150, 104, 62),
		Enum.Material.WoodPlanks,
		{ CastShadow = true }
	)
	return c
end

local function barrel(parent: Instance, pos: Vector3)
	post(parent, pos, 3, 2.2, Color3.fromRGB(122, 84, 52), Enum.Material.Wood, { CastShadow = true })
	post(parent, pos + Vector3.new(0, 0.6, 0), 0.3, 2.35, Color3.fromRGB(60, 56, 56), Enum.Material.Metal)
	post(parent, pos + Vector3.new(0, 2.1, 0), 0.3, 2.35, Color3.fromRGB(60, 56, 56), Enum.Material.Metal)
end

local function lantern(parent: Instance, base: Vector3, lit: boolean)
	post(parent, base, 6, 0.4, DARK_WOOD, Enum.Material.Wood)
	rod(
		parent,
		base + Vector3.new(0, 5.8, 0),
		base + Vector3.new(0.9, 5.8, 0),
		0.25,
		0.25,
		DARK_WOOD,
		Enum.Material.Wood
	)
	local glass = make(
		parent,
		"Ball",
		Vector3.one * 1.3,
		CFrame.new(base + Vector3.new(0.9, 5.2, 0)),
		Color3.fromRGB(255, 214, 120),
		Enum.Material.Neon
	)
	if lit then
		light(glass, Color3.fromRGB(255, 200, 120), 22, 0.9)
	end
end

local function fenceLine(parent: Instance, from: Vector3, to: Vector3, spacing: number)
	local delta = to - from
	local count = math.max(1, math.floor(delta.Magnitude / spacing))
	for i = 0, count do
		post(parent, from + delta * (i / count), 3, 0.5, DARK_WOOD, Enum.Material.Wood)
	end
	for _, y in { 1.2, 2.3 } do
		rod(
			parent,
			from + Vector3.new(0, y, 0),
			to + Vector3.new(0, y, 0),
			0.3,
			0.3,
			WOOD,
			Enum.Material.Wood
		)
	end
end

local function bush(parent: Instance, pos: Vector3, rng: Random)
	local d = rng:NextNumber(2.5, 4.2)
	make(
		parent,
		"Ball",
		Vector3.new(d, d * 0.8, d),
		CFrame.new(pos + Vector3.new(0, d * 0.3, 0)),
		shade(Color3.fromRGB(72, 142, 64), rng, 0.12),
		Enum.Material.Grass
	)
end

local function pathStrip(parent: Instance, center: Vector3, size: Vector3, color: Color3)
	local strip = make(
		parent,
		"Block",
		size,
		CFrame.new(center.X, 0.04 + size.Y / 2, center.Z),
		color,
		Enum.Material.Cobblestone
	)
	-- darker edging along both long sides
	local alongX = size.X > size.Z
	for _, side in { -1, 1 } do
		local offset = if alongX
			then Vector3.new(0, 0, side * (size.Z / 2))
			else Vector3.new(side * (size.X / 2), 0, 0)
		local edgeSize = if alongX then Vector3.new(size.X, 0.3, 0.7) else Vector3.new(0.7, 0.3, size.Z)
		make(
			parent,
			"Block",
			edgeSize,
			CFrame.new(Vector3.new(center.X, 0.12, center.Z) + offset),
			Color3.fromRGB(104, 96, 88),
			Enum.Material.Slate
		)
	end
	return strip
end

local function dumbbell(parent: Instance, pos: Vector3, yaw: number)
	local base = CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, yaw, 0)
	make(parent, "Cylinder", Vector3.new(4, 0.5, 0.5), base, Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
	for _, side in { -1, 1 } do
		make(
			parent,
			"Cylinder",
			Vector3.new(0.9, 1.8, 1.8),
			base * CFrame.new(side * 1.8, 0, 0),
			Color3.fromRGB(46, 46, 52),
			Enum.Material.Metal
		)
		make(
			parent,
			"Cylinder",
			Vector3.new(0.5, 2.3, 2.3),
			base * CFrame.new(side * 2.5, 0, 0),
			Color3.fromRGB(46, 46, 52),
			Enum.Material.Metal
		)
	end
end

local function launchPadDressing(parent: Instance, cfg: Config)
	local center = cfg.PadPosition
	-- Hazard stripes around the pad: alternating yellow and dark tiles.
	local half = 7.5
	local tile = 2.5
	local steps = math.floor(half * 2 / tile + 0.5)
	for i = 0, steps - 1 do
		local t = -half + tile / 2 + i * tile
		local colorA = if i % 2 == 0 then Color3.fromRGB(255, 205, 40) else Color3.fromRGB(40, 36, 36)
		local colorB = if i % 2 == 0 then Color3.fromRGB(40, 36, 36) else Color3.fromRGB(255, 205, 40)
		make(
			parent,
			"Block",
			Vector3.new(tile, 0.5, 1.6),
			CFrame.new(center.X + t, 0.25, center.Z - half),
			colorA,
			Enum.Material.Concrete
		)
		make(
			parent,
			"Block",
			Vector3.new(tile, 0.5, 1.6),
			CFrame.new(center.X + t, 0.25, center.Z + half),
			colorB,
			Enum.Material.Concrete
		)
		make(
			parent,
			"Block",
			Vector3.new(1.6, 0.5, tile),
			CFrame.new(center.X - half, 0.25, center.Z + t),
			colorB,
			Enum.Material.Concrete
		)
		make(
			parent,
			"Block",
			Vector3.new(1.6, 0.5, tile),
			CFrame.new(center.X + half, 0.25, center.Z + t),
			colorA,
			Enum.Material.Concrete
		)
	end

	-- Chevrons on the pad and leading out into the canyon (point toward +Z).
	local function chevron(z: number, width: number, y: number, color: Color3)
		for _, side in { -1, 1 } do
			local tip = Vector3.new(center.X, y, z)
			local tail = Vector3.new(center.X + side * width, y, z - width * 0.8)
			rod(parent, tail, tip, 0.9, 0.12, color, Enum.Material.Neon)
		end
	end
	for i = 0, 1 do
		chevron(center.Z - 1 + i * 3.4, 2.4, 1.28, Color3.fromRGB(255, 255, 255))
	end
	for i = 0, 3 do
		chevron(cfg.Origin.Z + 10 + i * 9, 5 - i * 0.6, 0.15, Color3.fromRGB(255, 160, 60))
	end

	-- Glow
	local glow = make(
		parent,
		"Cylinder",
		Vector3.new(0.2, 15, 15),
		CFrame.new(center.X, 0.15, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 150, 50),
		Enum.Material.Neon,
		{ Transparency = 0.7 }
	)
	light(glow, Color3.fromRGB(255, 160, 70), 26, 1.2)

	-- Flag poles at the back corners
	for _, side in { -1, 1 } do
		local base = Vector3.new(center.X + side * 9.5, 0, center.Z - 7)
		post(parent, base, 12, 0.5, WOOD, Enum.Material.Wood)
		make(
			parent,
			"Block",
			Vector3.new(0.2, 2.6, 4.4),
			CFrame.new(base + Vector3.new(0, 10.4, -2.4)),
			Color3.fromRGB(255, 130, 40),
			Enum.Material.Fabric
		)
		make(
			parent,
			"Ball",
			Vector3.one * 0.9,
			CFrame.new(base + Vector3.new(0, 12.2, 0)),
			Color3.fromRGB(255, 220, 90),
			Enum.Material.Neon
		)
	end
end

local function trainingGround(parent: Instance, cfg: Config)
	local center = cfg.RockPosition * Vector3.new(1, 0, 1)
	disc(
		parent,
		center + Vector3.new(0, 0.02, 0),
		24,
		0.3,
		0,
		Color3.fromRGB(150, 142, 128),
		Enum.Material.Slate
	)
	disc(
		parent,
		center + Vector3.new(0, 0.3, 0),
		17,
		0.15,
		0,
		Color3.fromRGB(184, 172, 150),
		Enum.Material.Pebble
	)
	local rng = Random.new(31)
	-- ring of boulders and a fence with a gap toward the path (east side)
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		if i ~= 0 then
			local pos = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 15
			rock(
				{ Parent = parent, Rng = rng, LightsLeft = 0 },
				pos,
				rng:NextNumber(1.2, 2),
				Color3.fromRGB(140, 138, 132),
				Enum.Material.Rock
			)
		end
	end
	for i = 1, 11 do
		local a0 = (i - 0.5) / 12 * math.pi * 2
		local a1 = (i + 0.5) / 12 * math.pi * 2
		fenceLine(
			parent,
			center + Vector3.new(math.cos(a0), 0, math.sin(a0)) * 17,
			center + Vector3.new(math.cos(a1), 0, math.sin(a1)) * 17,
			4
		)
	end
	dumbbell(parent, center + Vector3.new(-8, 0, -6), 0.5)
	dumbbell(parent, center + Vector3.new(7, 0, 8), -0.4)
	-- sign
	local signBase = center + Vector3.new(-10, 0, 17)
	post(parent, signBase + Vector3.new(-5, 0, 0), 9, 0.7, WOOD, Enum.Material.Wood)
	post(parent, signBase + Vector3.new(5, 0, 0), 9, 0.7, WOOD, Enum.Material.Wood)
	signBoard(
		parent,
		CFrame.new(signBase + Vector3.new(0, 7.2, 0)),
		Vector3.new(12, 3.6, 0.8),
		Color3.fromRGB(96, 68, 46),
		{
			{ Text = "TRAINING GROUND", Color = WHITE, Height = 0.88 },
		}
	)
end

local function campfire(parent: Instance, pos: Vector3)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		make(
			parent,
			"Block",
			Vector3.new(1.3, 0.9, 1),
			CFrame.new(pos + Vector3.new(math.cos(angle) * 2.2, 0.45, math.sin(angle) * 2.2))
				* CFrame.Angles(0, angle, 0),
			Color3.fromRGB(120, 116, 110),
			Enum.Material.Rock
		)
	end
	for i = 0, 2 do
		local angle = i / 3 * math.pi
		local d = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.4
		beam(
			parent,
			pos + d + Vector3.new(0, 0.5, 0),
			pos - d + Vector3.new(0, 0.9, 0),
			0.5,
			Color3.fromRGB(80, 56, 40),
			Enum.Material.Wood
		)
	end
	local flame = make(
		parent,
		"Block",
		Vector3.new(1.2, 2.2, 1.2),
		CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0.7, 0),
		Color3.fromRGB(255, 140, 40),
		Enum.Material.Neon
	)
	make(
		parent,
		"Block",
		Vector3.new(0.7, 1.5, 0.7),
		CFrame.new(pos + Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, 0.2, 0),
		Color3.fromRGB(255, 210, 80),
		Enum.Material.Neon
	)
	light(flame, Color3.fromRGB(255, 150, 70), 30, 1.4)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80))
	sparks.LightEmission = 1
	sparks.Rate = 5
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(20, 20)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = flame
end

local function ribcage(parent: Instance, base: Vector3)
	local bonec = Color3.fromRGB(236, 228, 206)
	make(
		parent,
		"Block",
		Vector3.new(14, 1.2, 8),
		CFrame.new(base + Vector3.new(0, 0.6, 0)),
		Color3.fromRGB(150, 140, 126),
		Enum.Material.Cobblestone
	)
	local spineA, spineB = base + Vector3.new(-6, 5.5, 0), base + Vector3.new(6, 5.5, 0)
	beam(parent, spineA, spineB, 0.9, bonec, Enum.Material.Slate)
	for i = 0, 5 do
		local x = -4.5 + i * 1.8
		local top = base + Vector3.new(x, 5.5, 0)
		local reach = 3.8 - math.abs(i - 2.5) * 0.35
		for _, side in { -1, 1 } do
			local mid = top + Vector3.new(0, -1.2, side * reach)
			beam(parent, top, mid, 0.35, bonec, Enum.Material.Slate)
			beam(
				parent,
				mid,
				mid + Vector3.new(0, -2.4, -side * reach * 0.35),
				0.3,
				bonec,
				Enum.Material.Slate
			)
		end
	end
	-- skull
	make(
		parent,
		"Block",
		Vector3.new(3.2, 1.8, 2),
		CFrame.new(base + Vector3.new(8.2, 5.4, 0)),
		bonec,
		Enum.Material.Slate
	)
	make(
		parent,
		"Block",
		Vector3.new(2.4, 0.6, 1.6),
		CFrame.new(base + Vector3.new(8.4, 4.3, 0)),
		bonec,
		Enum.Material.Slate
	)
end

local function hubBackdrop(parent: Instance, cfg: Config)
	local rng = Random.new(2024)
	local half = cfg.HubHalfWidth
	local grass = Color3.fromRGB(122, 160, 88)
	-- Ground around the hub (the canyon's own ground starts at the front wall)
	local zBack, zFront = cfg.HubBackZ - 1, cfg.Origin.Z
	for _, side in { -1, 1 } do
		make(
			parent,
			"Block",
			Vector3.new(420, 1, zFront - zBack),
			CFrame.new(side * (half + 1 + 210), -0.5, (zBack + zFront) / 2),
			grass,
			Enum.Material.Grass,
			{ CanCollide = true }
		)
	end
	make(
		parent,
		"Block",
		Vector3.new(3602, 1, 1400),
		CFrame.new(0, -0.5, zBack - 700),
		grass,
		Enum.Material.Grass,
		{ CanCollide = true }
	)
	for _, side in { -1, 1 } do
		make(
			parent,
			"Block",
			Vector3.new(1200, 1, zFront - zBack),
			CFrame.new(side * (601 + 600), -0.5, (zBack + zFront) / 2),
			grass:Lerp(Color3.fromRGB(170, 180, 150), 0.25),
			Enum.Material.Grass,
			{ CanCollide = true }
		)
	end

	-- Hills and trees behind the hub
	for _ = 1, 12 do
		local w = rng:NextNumber(60, 120)
		local pos = Vector3.new(rng:NextNumber(-380, 380), 0, cfg.HubBackZ - rng:NextNumber(60, 260))
		make(
			parent,
			"Ball",
			Vector3.new(w, w * rng:NextNumber(0.35, 0.6), w),
			CFrame.new(pos),
			shade(Color3.fromRGB(118, 160, 90), rng, 0.1),
			Enum.Material.Grass,
			{ CastShadow = true }
		)
	end
	local ctx: Ctx = { Parent = parent, Rng = rng, LightsLeft = 0 }
	for _ = 1, 38 do
		local pos = Vector3.new(rng:NextNumber(-340, 340), 0, cfg.HubBackZ - rng:NextNumber(8, 90))
		if math.abs(pos.X) < half + 8 or rng:NextNumber() < 0.5 then
			tree(ctx, pos, rng:NextNumber(1.2, 2))
		end
	end
	for _ = 1, 18 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		tree(
			ctx,
			Vector3.new(
				side * rng:NextNumber(half + 10, half + 120),
				0,
				rng:NextNumber(cfg.HubBackZ + 20, -10)
			),
			rng:NextNumber(1.4, 2.2)
		)
	end
	-- Far mountains
	for i = -3, 3 do
		local h = rng:NextNumber(70, 140)
		local w = rng:NextNumber(110, 170)
		make(
			parent,
			"Block",
			Vector3.new(w, h, w),
			CFrame.new(i * 130, h / 2 - 2, cfg.HubBackZ - 330 - rng:NextNumber(0, 40))
				* CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
			Color3.fromRGB(120, 130, 150),
			Enum.Material.Rock,
			{ CastShadow = true }
		)
	end
end

-- Fills the hub's empty floor: grass and dirt patches, pebbles and grass tufts,
-- so no big flat area is left bare.
local function hubFill(parent: Instance, cfg: Config, rng: Random)
	local half = cfg.HubHalfWidth
	local colors = {
		Color3.fromRGB(112, 162, 84),
		Color3.fromRGB(136, 174, 92),
		Color3.fromRGB(198, 178, 130),
		Color3.fromRGB(168, 148, 104),
		Color3.fromRGB(150, 182, 102),
	}
	for _ = 1, 80 do
		local pos = Vector3.new(rng:NextNumber(-half + 4, half - 4), 0, rng:NextNumber(cfg.HubBackZ + 3, -3))
		disc(
			parent,
			pos,
			rng:NextNumber(8, 26),
			rng:NextNumber(0.02, 0.07),
			rng:NextNumber(0, 3),
			pick(rng, colors),
			Enum.Material.Grass
		)
	end
	for _ = 1, 50 do
		local pos = Vector3.new(rng:NextNumber(-half + 4, half - 4), 0, rng:NextNumber(cfg.HubBackZ + 3, -3))
		local d = rng:NextNumber(0.7, 1.6)
		make(
			parent,
			"Ball",
			Vector3.new(d, d * 0.6, d * 1.2),
			CFrame.new(pos + Vector3.new(0, d * 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color3.fromRGB(140, 136, 128),
			Enum.Material.Rock
		)
	end
	local ctx: Ctx = { Parent = parent, Rng = rng, LightsLeft = 0 }
	for _ = 1, 28 do
		local pos = Vector3.new(rng:NextNumber(-half + 6, half - 6), 0, rng:NextNumber(cfg.HubBackZ + 4, -6))
		fern(ctx, pos, rng:NextNumber(0.45, 0.7))
	end
end

function WorldDecor.Hub(parent: Instance, cfg: Config)
	local folder = Instance.new("Folder")
	folder.Name = "HubDecor"
	folder.Parent = parent
	local rng = Random.new(777)
	local cobble = Color3.fromRGB(168, 156, 138)

	-- Paths
	local frontOfPlots = cfg.PlotZ + 23
	local padBack = cfg.PadPosition.Z - 6
	pathStrip(
		folder,
		Vector3.new(0, 0, (frontOfPlots + padBack) / 2),
		Vector3.new(10, 0.08, padBack - frontOfPlots),
		cobble
	)

	-- Paths between the plots
	for i = 1, cfg.PlotCount - 1 do
		local x = -((cfg.PlotCount - 1) * cfg.PlotSpacing) / 2 + (i - 0.5) * cfg.PlotSpacing
		make(
			folder,
			"Block",
			Vector3.new(cfg.PlotSpacing - cfg.PlotSize, 0.1, cfg.PlotSize + 4),
			CFrame.new(x, 0.05, cfg.PlotZ),
			cobble,
			Enum.Material.Cobblestone
		)
	end
	pathStrip(folder, Vector3.new(0, 0, frontOfPlots - 0.5), Vector3.new(300, 0.08, 9), cobble)
	pathStrip(folder, Vector3.new(0, 0, -14), Vector3.new(300, 0.08, 6), cobble)
	local rockPath = cfg.RockPosition
	pathStrip(
		folder,
		Vector3.new(rockPath.X / 2, 0, rockPath.Z),
		Vector3.new(math.abs(rockPath.X) - 4, 0.08, 6),
		cobble
	)

	-- Lanterns along the main path
	local lampIndex = 0
	for z = cfg.PlotZ + 28, -20, 14 do
		for _, side in { -1, 1 } do
			lampIndex += 1
			lantern(folder, Vector3.new(side * 8, 0, z), lampIndex % 2 == 0)
		end
	end

	-- Welcome arch over the path
	local archZ = cfg.PlotZ + 36
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * 18, 0, archZ)
		make(
			folder,
			"Block",
			Vector3.new(5, 2, 5),
			CFrame.new(base + Vector3.new(0, 1, 0)),
			STONE,
			Enum.Material.Cobblestone,
			{ CastShadow = true }
		)
		post(folder, base + Vector3.new(0, 2, 0), 26, 2.4, WOOD, Enum.Material.Wood, { CastShadow = true })
		make(
			folder,
			"Ball",
			Vector3.one * 3.2,
			CFrame.new(base + Vector3.new(0, 29.5, 0)),
			Color3.fromRGB(255, 214, 110),
			Enum.Material.Neon
		)
	end
	make(
		folder,
		"Block",
		Vector3.new(42, 2.4, 2.6),
		CFrame.new(0, 26.5, archZ),
		WOOD,
		Enum.Material.Wood,
		{ CastShadow = true }
	)
	signBoard(folder, CFrame.new(0, 33, archZ), Vector3.new(44, 12, 1.4), Color3.fromRGB(86, 60, 42), {
		{ Text = "FLING FOR FOSSILS", Color = Color3.fromRGB(255, 226, 120), Height = 0.62 },
		{ Text = "Fling. Dig. Hatch. Collect!", Color = WHITE, Height = 0.3 },
	})
	-- bones crossing on top of the sign
	local boneCtx: Ctx = { Parent = folder, Rng = rng, LightsLeft = 0 }
	for _, side in { -1, 1 } do
		beam(
			folder,
			Vector3.new(side * 19, 38.5, archZ),
			Vector3.new(side * 7, 41.5, archZ),
			1,
			BONE_COLOR,
			Enum.Material.Slate
		)
		make(
			folder,
			"Ball",
			Vector3.one * 1.8,
			CFrame.new(side * 19, 38.5, archZ),
			BONE_COLOR,
			Enum.Material.Slate
		)
		make(
			folder,
			"Ball",
			Vector3.one * 1.8,
			CFrame.new(side * 7, 41.5, archZ),
			BONE_COLOR,
			Enum.Material.Slate
		)
	end

	-- Launch pad and training ground
	launchPadDressing(folder, cfg)
	trainingGround(folder, cfg)

	-- East camp: tent, campfire, crates, barrels, log seats
	tent(folder, Vector3.new(46, 0, -44), -0.3, Color3.fromRGB(220, 96, 70))
	tent(folder, Vector3.new(58, 0, -30), 0.5, Color3.fromRGB(80, 150, 190))
	campfire(folder, Vector3.new(40, 0, -28))
	for _, offset in { Vector3.new(-5, 0, 0), Vector3.new(4.6, 0, 3) } do
		local pos = Vector3.new(40, 0, -28) + offset
		beam(
			folder,
			pos + Vector3.new(0, 0.7, -2),
			pos + Vector3.new(0, 0.7, 2),
			1.4,
			Color3.fromRGB(110, 78, 52),
			Enum.Material.Wood
		)
	end
	crate(folder, Vector3.new(52, 0, -52), 3.2, 0.2)
	crate(folder, Vector3.new(55.5, 0, -51), 2.6, 0.5)
	crate(folder, Vector3.new(53, 3.2, -51.5), 2.2, 0.9)
	barrel(folder, Vector3.new(49, 0, -54))
	barrel(folder, Vector3.new(58, 0, -50))

	-- West camp: tent, fossil display, supplies
	tent(folder, Vector3.new(-48, 0, -50), 0.3, Color3.fromRGB(230, 190, 90))
	ribcage(folder, Vector3.new(-66, 0, -34))
	crate(folder, Vector3.new(-60, 0, -46), 3, 0.1)
	crate(folder, Vector3.new(-60.5, 0, -42), 2.4, 0.6)
	barrel(folder, Vector3.new(-40, 0, -56))
	local signPos = Vector3.new(-66, 0, -14)
	post(folder, signPos + Vector3.new(-5, 0, 0), 7, 0.6, WOOD, Enum.Material.Wood)
	post(folder, signPos + Vector3.new(5, 0, 0), 7, 0.6, WOOD, Enum.Material.Wood)
	signBoard(
		folder,
		CFrame.new(signPos + Vector3.new(0, 5.6, 0)),
		Vector3.new(12, 3, 0.8),
		Color3.fromRGB(96, 68, 46),
		{
			{ Text = "FOSSIL CAMP", Color = WHITE, Height = 0.86 },
		}
	)
	fenceLine(folder, Vector3.new(-78, 0, -60), Vector3.new(-78, 0, -22), 5)
	fenceLine(folder, Vector3.new(78, 0, -60), Vector3.new(78, 0, -22), 5)

	-- Bushes and flowers around the edge of the hub
	local half = cfg.HubHalfWidth
	for x = -half + 6, half - 6, 12 do
		bush(folder, Vector3.new(x + rng:NextNumber(-2, 2), 0, cfg.HubBackZ + 5), rng)
	end
	for z = cfg.HubBackZ + 12, -8, 12 do
		bush(folder, Vector3.new(-half + 5, 0, z + rng:NextNumber(-2, 2)), rng)
		bush(folder, Vector3.new(half - 5, 0, z + rng:NextNumber(-2, 2)), rng)
	end
	for _ = 1, 24 do
		local pos = Vector3.new(rng:NextNumber(-170, 170), 0, rng:NextNumber(-70, -18))
		if math.abs(pos.X) > 14 and math.abs(pos.X - 45) > 20 and math.abs(pos.X + 45) > 20 then
			flower(boneCtx, pos, rng:NextNumber(1, 1.6))
		end
	end

	hubFill(folder, cfg, rng)
	hubBackdrop(folder, cfg)
end

-- Landscape ---------------------------------------------------------------------

local HAZE = Color3.fromRGB(150, 165, 190)

local function cliffMaterial(zone: Zones.Zone): Enum.Material
	if zone.Material == Enum.Material.Grass or zone.Material == Enum.Material.Ground then
		return Enum.Material.Rock
	elseif zone.Material == Enum.Material.Sand then
		return Enum.Material.Sandstone
	end
	return groundMaterial(zone)
end

local function zoneAt(z: number, origin: Vector3): Zones.Zone?
	local distance = z - origin.Z
	if distance < 0 or distance >= Zones.MaxDistance then
		return nil
	end
	return Zones.ForDistance(distance)
end

-- A far-away mountain: three narrowing blocks.
local function mountain(
	parent: Instance,
	pos: Vector3,
	width: number,
	height: number,
	color: Color3,
	yaw: number
)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local y = 0
	local tiers = { { 1, 0.45 }, { 0.68, 0.35 }, { 0.38, 0.3 } }
	for i, tier in tiers do
		local w, h = width * tier[1], height * tier[2]
		make(
			parent,
			"Block",
			Vector3.new(w, h, w),
			base * CFrame.new(0, y + h / 2 - 2, 0) * CFrame.Angles(0, i * 0.4, 0),
			color:Lerp(WHITE, (i - 1) * 0.12),
			Enum.Material.Rock
		)
		y += h
	end
end

local function palm(ctx: Ctx, pos: Vector3, scale: number)
	local rng = ctx.Rng
	local height = rng:NextNumber(11, 15) * scale
	local lean = rng:NextNumber(-3, 3) * scale
	local angle = rng:NextNumber(0, math.pi * 2)
	local mid = pos + Vector3.new(math.cos(angle) * lean * 0.3, height * 0.55, math.sin(angle) * lean * 0.3)
	local top = pos + Vector3.new(math.cos(angle) * lean, height, math.sin(angle) * lean)
	local wood = Color3.fromRGB(128, 98, 66)
	beam(ctx.Parent, pos, mid, 1.1 * scale, wood, Enum.Material.Wood)
	beam(ctx.Parent, mid, top, 0.9 * scale, wood, Enum.Material.Wood)
	local length = 5 * scale
	local tilt = -math.rad(28)
	for i = 0, 6 do
		make(
			ctx.Parent,
			"Block",
			Vector3.new(1.4 * scale, 0.12, length * 2),
			CFrame.new(top)
				* CFrame.Angles(0, i / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2), 0)
				* CFrame.new(0, length * math.sin(tilt), -length * math.cos(tilt))
				* CFrame.Angles(tilt, 0, 0),
			shade(Color3.fromRGB(62, 150, 70), rng, 0.1),
			Enum.Material.Grass
		)
	end
end

local function lake(parent: Instance, center: Vector3, width: number, depth: number)
	local sand = Color3.fromRGB(222, 204, 150)
	disc(parent, center + Vector3.new(0, 0.02, 0), width + 14, 0.05, 0, sand, Enum.Material.Sand)
	disc(
		parent,
		center + Vector3.new(width * 0.2, 0.02, depth * 0.1),
		depth + 14,
		0.05,
		1,
		sand,
		Enum.Material.Sand
	)
	for i = 1, 2 do
		local d = if i == 1 then width else depth
		disc(
			parent,
			center + Vector3.new(if i == 1 then 0 else width * 0.2, 0.1, if i == 1 then 0 else depth * 0.1),
			d,
			0.2,
			i,
			Color3.fromRGB(64, 156, 206),
			Enum.Material.Glass,
			{ Transparency = 0.3, Reflectance = 0.15 }
		)
	end
end

function WorldDecor.Landscape(parent: Instance, cfg: Config)
	local folder = Instance.new("Folder")
	folder.Name = "Landscape"
	folder.Parent = parent
	local rng = Random.new(90210)
	local origin = cfg.Origin
	local endZ = origin.Z + Zones.MaxDistance
	local backZ = cfg.HubBackZ

	-- Cliff walls along both sides of the fling field (two terraces, taller behind).
	for index, zone in Zones.List do
		local theme = THEMES[zone.Id] or fallbackTheme(zone)
		local length = zone.EndDistance - zone.StartDistance
		local segments = math.ceil(length / 90)
		local segLength = length / segments
		local material = cliffMaterial(zone)
		local color = theme.Backdrop:Lerp(BLACK, 0.22)
		for i = 1, segments do
			local z = origin.Z + zone.StartDistance + (i - 0.5) * segLength
			for _, side in { -1, 1 } do
				local near = rng:NextNumber(14, 28)
				make(
					folder,
					"Block",
					Vector3.new(24, near, segLength * 1.04),
					CFrame.new(origin.X + side * 93, near / 2 - 1, z),
					shade(color, rng, 0.06),
					material
				)
				if rng:NextNumber() > 0.2 then
					local far = rng:NextNumber(36, 70) * (1 + index * 0.04)
					make(
						folder,
						"Block",
						Vector3.new(56, far, segLength * 1.02),
						CFrame.new(origin.X + side * 133, far / 2 - 1, z + rng:NextNumber(-8, 8)),
						shade(color:Lerp(HAZE, 0.12), rng, 0.06),
						material
					)
				end
			end
		end
	end

	-- Distant mountains on the horizon: both sides, behind the hub, past the end.
	local function addMountain(x: number, z: number)
		local zone = zoneAt(z, origin)
		local base = if zone
			then zone.Color:Lerp(Color3.fromRGB(70, 60, 60), 0.4)
			else Color3.fromRGB(112, 134, 112)
		if zone and zone.Id == "FernValley" then
			base = Color3.fromRGB(96, 124, 90)
		end
		local size = rng:NextNumber(200, 380)
		mountain(
			folder,
			Vector3.new(x, 0, z),
			size,
			size * rng:NextNumber(0.5, 0.8),
			base:Lerp(HAZE, 0.5),
			rng:NextNumber(0, 1.5)
		)
	end
	local z = backZ - 400
	while z < endZ + 900 do
		addMountain(-rng:NextNumber(700, 1150), z)
		addMountain(rng:NextNumber(700, 1150), z)
		z += 230
	end
	for x = -1100, 1100, 240 do
		addMountain(x + rng:NextNumber(-40, 40), backZ - rng:NextNumber(700, 1000))
	end
	for x = -1100, 1100, 260 do
		addMountain(x + rng:NextNumber(-40, 40), endZ + rng:NextNumber(750, 1000))
	end

	-- A smoking volcano beyond Volcano Rim, with two smaller ones beside it.
	volcano(folder, Vector3.new(origin.X, 0, endZ + 430), 7)
	volcano(folder, Vector3.new(origin.X - 420, 0, endZ + 330), 3)
	volcano(folder, Vector3.new(origin.X + 420, 0, endZ + 330), 3)

	-- Lakes and a river around the hub, with palms on their banks.
	local lakeA = Vector3.new(-330, 0, -60)
	local lakeB = Vector3.new(340, 0, -90)
	lake(folder, lakeA, 150, 110)
	lake(folder, lakeB, 130, 100)
	local riverZ = backZ - 150
	make(
		folder,
		"Block",
		Vector3.new(3000, 0.1, 76),
		CFrame.new(0, 0.05, riverZ),
		Color3.fromRGB(222, 204, 150),
		Enum.Material.Sand
	)
	make(
		folder,
		"Block",
		Vector3.new(3000, 0.3, 50),
		CFrame.new(0, 0.15, riverZ),
		Color3.fromRGB(64, 156, 206),
		Enum.Material.Glass,
		{ Transparency = 0.3, Reflectance = 0.15 }
	)
	local ctx: Ctx = { Parent = folder, Rng = rng, LightsLeft = 0 }
	for _, lakeCenter in { lakeA, lakeB } do
		for _ = 1, 6 do
			local angle = rng:NextNumber(0, math.pi * 2)
			palm(
				ctx,
				lakeCenter + Vector3.new(math.cos(angle) * 88, 0, math.sin(angle) * 66),
				rng:NextNumber(1.1, 1.6)
			)
		end
	end
	for _ = 1, 10 do
		palm(
			ctx,
			Vector3.new(
				rng:NextNumber(-500, 500),
				0,
				riverZ + (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(42, 56)
			),
			rng:NextNumber(1.1, 1.6)
		)
	end

	-- Big trees around the hub
	for _ = 1, 24 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		tree(
			ctx,
			Vector3.new(side * rng:NextNumber(200, 520), 0, rng:NextNumber(backZ - 110, 0)),
			rng:NextNumber(2.5, 3.6)
		)
	end

	-- Low clouds (static here; the client drifts them slowly, see EffectsController)
	local clouds = Instance.new("Folder")
	clouds.Name = "Clouds"
	clouds.Parent = folder
	for i = 1, 28 do
		local cloud = Instance.new("Model")
		cloud.Name = "Cloud" .. i
		local center = Vector3.new(
			rng:NextNumber(-1400, 1400),
			rng:NextNumber(230, 340),
			rng:NextNumber(backZ - 600, endZ + 700)
		)
		for _ = 1, rng:NextInteger(3, 4) do
			make(
				cloud,
				"Ball",
				Vector3.new(rng:NextNumber(70, 130), rng:NextNumber(16, 26), rng:NextNumber(50, 90)),
				CFrame.new(
					center
						+ Vector3.new(rng:NextNumber(-60, 60), rng:NextNumber(-6, 6), rng:NextNumber(-30, 30))
				),
				WHITE,
				Enum.Material.SmoothPlastic,
				{ Transparency = 0.4 }
			)
		end
		cloud.Parent = clouds
	end
end

-- Plots -------------------------------------------------------------------------

-- Adds the decorations for one plot to `model`. Returns nothing; the coloured
-- border strips are named "Border" so MapService can recolour them per owner.
function WorldDecor.Plot(model: Model, center: Vector3, size: number, nestOffsets: { Vector3 })
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = model
	local half = size / 2

	-- Colour strips along the front and sides of the floor
	for _, side in { -1, 1 } do
		make(
			folder,
			"Block",
			Vector3.new(0.8, 0.2, size),
			CFrame.new(center + Vector3.new(side * (half - 0.4), 0.5, 0)),
			Color3.fromRGB(200, 196, 188),
			Enum.Material.Neon,
			{ Name = "Border" }
		)
	end
	make(
		folder,
		"Block",
		Vector3.new(size, 0.2, 0.8),
		CFrame.new(center + Vector3.new(0, 0.5, half - 0.4)),
		Color3.fromRGB(200, 196, 188),
		Enum.Material.Neon,
		{ Name = "Border" }
	)
	make(
		folder,
		"Block",
		Vector3.new(size, 0.2, 0.8),
		CFrame.new(center + Vector3.new(0, 0.5, -half + 0.4)),
		Color3.fromRGB(200, 196, 188),
		Enum.Material.Neon,
		{ Name = "Border" }
	)

	-- Low fence along the back and a lantern post in each corner
	fenceLine(
		folder,
		center + Vector3.new(-half + 1, 0, -half + 1.2),
		center + Vector3.new(half - 1, 0, -half + 1.2),
		4.5
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			if sx == 1 and sz == 1 then
				continue -- the plot sign stands here
			end
			local base = center + Vector3.new(sx * (half - 1), 0, sz * (half - 1))
			post(folder, base, 4.5, 0.5, DARK_WOOD, Enum.Material.Wood)
			make(
				folder,
				"Ball",
				Vector3.one * 1.1,
				CFrame.new(base + Vector3.new(0, 4.9, 0)),
				Color3.fromRGB(255, 214, 120),
				Enum.Material.Neon,
				{ Name = "Border" }
			)
		end
	end

	-- Straw under each incubator
	for _, offset in nestOffsets do
		disc(
			folder,
			center + offset + Vector3.new(0, 0.4, 0),
			8,
			0.12,
			0,
			Color3.fromRGB(226, 198, 110),
			Enum.Material.Fabric
		)
	end
end

return WorldDecor
