-- DinoArt.luau
-- Builds the chunky toy-style dinosaurs out of plain Parts (no uploaded art).
-- Shared, so the server (pedestals) and the client (hatch reveal viewport) draw
-- the same dino. Each dino picks a body plan with `Shape` in Config/Dinos.
--
--   DinoArt.Build(dinoId)            -> Model (PrimaryPart "Body", has Head, EyeL, EyeR)
--   DinoArt.Get(dinoId)              -> a real model from ReplicatedStorage.DinoModels
--                                       if one exists, otherwise Build
--   DinoArt.ApplyMutation(model, id) -> Gold / Rainbow recolour
--   DinoArt.ApplyBaby(model)         -> bigger head and eyes
--
-- Conventions: the dino faces -Z, stands with its feet at the bottom of the
-- bounding box, and every part is anchored. Parts that must keep their colour
-- under a mutation (eyes, teeth, claws, glow) carry the attribute KeepColor.
-- Every other part has a Tone attribute (-1 dark .. +1 light) so a mutation can
-- recolour belly / plates lighter than the body. Parts of the head carry the
-- attribute Head so babies can scale them together.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dinos = require(script.Parent.Config.Dinos)
local Eggs = require(script.Parent.Config.Eggs)

local DinoArt = {}

local ACCENT_TONE = 0.3
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local BONE = Color3.fromRGB(245, 235, 205)

type Ctx = {
	Model: Model,
	K: number,
	Base: Color3,
	Accent: Color3,
	Theme: string?,
	Spots: { Vector3 },
}

type Opts = {
	Tone: number?,
	Accent: boolean?,
	Color: Color3?,
	Material: Enum.Material?,
	Keep: boolean?,
	Head: boolean?,
	Shape: string?,
	Transparency: number?,
}

local function tint(color: Color3, tone: number): Color3
	if tone > 0 then
		return color:Lerp(WHITE, tone)
	elseif tone < 0 then
		return color:Lerp(BLACK, -tone)
	end
	return color
end

-- Building blocks --------------------------------------------------------------------

-- Adds one part. size and pos are in "base units" and get multiplied by ctx.K.
-- Default look is an ellipsoid (a Block with a Sphere mesh); Shape = "Cylinder" gives a real cylinder.
local function add(ctx: Ctx, name: string, size: Vector3, pos: Vector3, rot: Vector3?, opts: Opts?): Part
	local o: Opts = opts or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = o.Material or Enum.Material.SmoothPlastic
	local scaled = size * ctx.K
	part.Size = Vector3.new(math.max(scaled.X, 0.05), math.max(scaled.Y, 0.05), math.max(scaled.Z, 0.05))
	local cf = CFrame.new(pos * ctx.K)
	if rot then
		cf *= CFrame.Angles(rot.X, rot.Y, rot.Z)
	end
	part.CFrame = cf
	if o.Transparency then
		part.Transparency = o.Transparency
	end

	if o.Color then
		part.Color = o.Color
	elseif o.Accent then
		part.Color = ctx.Accent
		part:SetAttribute("Tone", ACCENT_TONE)
	else
		local tone = o.Tone or 0
		part.Color = tint(ctx.Base, tone)
		part:SetAttribute("Tone", tone)
	end
	if o.Keep then
		part:SetAttribute("KeepColor", true)
	end
	if o.Head then
		part:SetAttribute("Head", true)
	end

	if o.Shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	else
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = ctx.Model
	return part
end

-- Adds a left and a right copy (names end in L and R). pos.X is the distance
-- from the middle; rot is the right-hand rotation and gets mirrored for the left.
local function pair(ctx: Ctx, name: string, size: Vector3, pos: Vector3, rot: Vector3?, opts: Opts?)
	for _, sx in { -1, 1 } do
		local r = if rot then Vector3.new(rot.X, sx * rot.Y, sx * rot.Z) else nil
		add(ctx, name .. (if sx < 0 then "L" else "R"), size, Vector3.new(sx * pos.X, pos.Y, pos.Z), r, opts)
	end
end

-- Big cute eyes on the sides of a head: white ball, black pupil, tiny highlight.
local function eyes(ctx: Ctx, hp: Vector3, hs: Vector3)
	local e = math.min(hs.X, hs.Y) * 0.5
	local yaw, pitch = 0.7, 0.35
	for _, sx in { -1, 1 } do
		local suffix = if sx < 0 then "L" else "R"
		local n = Vector3.new(
			sx * math.sin(yaw) * math.cos(pitch),
			math.sin(pitch),
			-math.cos(yaw) * math.cos(pitch)
		)
		local center = hp + Vector3.new(n.X * hs.X / 2, n.Y * hs.Y / 2, n.Z * hs.Z / 2) * 0.8
		local keep = { Color = WHITE, Keep = true, Head = true }
		add(ctx, "Eye" .. suffix, Vector3.one * e, center, nil, keep)
		local pupilCenter = center + n * (e * 0.24)
		add(
			ctx,
			"Pupil" .. suffix,
			Vector3.one * (e * 0.62),
			pupilCenter,
			nil,
			{ Color = BLACK, Keep = true, Head = true }
		)
		local shineCenter = pupilCenter + n * (e * 0.2) + Vector3.new(-sx * e * 0.06, e * 0.14, 0)
		add(ctx, "Shine" .. suffix, Vector3.one * (e * 0.2), shineCenter, nil, keep)
	end
end

-- Four small white teeth under a snout (carnivores).
local function teeth(ctx: Ctx, sp: Vector3, ss: Vector3)
	for _, sx in { -1, 1 } do
		for i, zf in { 0.3, -0.05 } do
			add(
				ctx,
				"Tooth" .. i .. (if sx < 0 then "L" else "R"),
				Vector3.new(0.2, 0.36, 0.2),
				Vector3.new(sx * ss.X * 0.3, sp.Y - ss.Y * 0.4, sp.Z - ss.Z * zf),
				nil,
				{ Color = WHITE, Keep = true, Head = true }
			)
		end
	end
end

local function claw(ctx: Ctx, name: string, size: Vector3, pos: Vector3, rot: Vector3?)
	add(ctx, name, size, pos, rot, { Color = BONE, Keep = true })
end

-- A snout part in front of a head.
local function snout(
	ctx: Ctx,
	hp: Vector3,
	hs: Vector3,
	length: number,
	widthMul: number?
): (Vector3, Vector3)
	local size = Vector3.new(hs.X * 0.62 * (widthMul or 1), hs.Y * 0.55, length)
	local pos = Vector3.new(0, hp.Y - hs.Y * 0.14, hp.Z - hs.Z * 0.5 - length * 0.5 + 0.35)
	add(ctx, "Snout", size, pos, nil, { Accent = true, Head = true })
	return pos, size
end

-- Spots on the back where zone themes put their decoration.
local function backSpots(ctx: Ctx, y: number, zs: { number })
	for _, z in zs do
		table.insert(ctx.Spots, Vector3.new(0, y, z))
	end
end

-- Quadruped and biped frames ---------------------------------------------------------

type QuadParams = {
	BodySize: Vector3,
	LegHeight: number,
	LegWidth: number?,
	HeadSize: Vector3,
	HeadPos: ((by: number) -> Vector3)?,
	Teeth: boolean?,
	SnoutLength: number?,
	Tail: { { Size: Vector3, Y: number, Z: number } }?,
}

local function quad(ctx: Ctx, p: QuadParams): { By: number, Body: Part, HeadPos: Vector3 }
	local bs = p.BodySize
	local by = p.LegHeight + bs.Y / 2 - 0.15
	local body = add(ctx, "Body", bs, Vector3.new(0, by, 0))
	ctx.Model.PrimaryPart = body
	add(
		ctx,
		"Belly",
		Vector3.new(bs.X * 0.8, bs.Y * 0.7, bs.Z * 0.85),
		Vector3.new(0, by - bs.Y * 0.2, -0.05),
		nil,
		{ Accent = true }
	)

	local lw = p.LegWidth or 1
	local lh = p.LegHeight + 0.9
	for _, zf in { -0.3, 0.3 } do
		local z = bs.Z * zf
		local x = bs.X * 0.36
		local tag = if zf < 0 then "F" else "B"
		pair(ctx, "Leg" .. tag, Vector3.new(lw, lh, lw), Vector3.new(x, lh / 2, z))
		pair(ctx, "Foot" .. tag, Vector3.new(lw * 1.2, 0.5, lw * 1.5), Vector3.new(x, 0.25, z - 0.15))
	end

	local hs = p.HeadSize
	local hp = if p.HeadPos then p.HeadPos(by) else Vector3.new(0, by + 0.4, -(bs.Z / 2 + 0.9))
	add(ctx, "Head", hs, hp, nil, { Head = true })
	eyes(ctx, hp, hs)
	if p.SnoutLength then
		local sp, ss = snout(ctx, hp, hs, p.SnoutLength)
		if p.Teeth then
			teeth(ctx, sp, ss)
		end
	elseif p.Teeth then
		teeth(ctx, hp, hs)
	end

	local tail = p.Tail
		or {
			{ Size = Vector3.new(1.4, 1.3, 2.4), Y = by, Z = bs.Z / 2 + 0.9 },
			{ Size = Vector3.new(0.8, 0.8, 2.2), Y = by - 0.1, Z = bs.Z / 2 + 2.5 },
		}
	for i, seg in tail do
		add(ctx, "Tail" .. i, seg.Size, Vector3.new(0, seg.Y, seg.Z))
	end

	backSpots(ctx, by + bs.Y / 2 - 0.05, { -bs.Z * 0.25, 0, bs.Z * 0.25 })
	return { By = by, Body = body, HeadPos = hp }
end

type BipedParams = {
	BodyScale: Vector3?,
	Head: number?, -- head size multiplier
	Arm: number?, -- arm size multiplier
	NoArms: boolean?,
	Neck: number?,
	Snout: number?, -- snout length multiplier
	Teeth: boolean?,
	NoSnout: boolean?,
}

local function biped(ctx: Ctx, p: BipedParams): { By: number, HeadPos: Vector3, HeadSize: Vector3 }
	local bsc = p.BodyScale or Vector3.one
	local h = p.Head or 1
	local neck = p.Neck or 0
	local by = 3.0
	local body = add(ctx, "Body", Vector3.new(2.2, 2.4, 3.4) * bsc, Vector3.new(0, by, 0.2))
	ctx.Model.PrimaryPart = body
	add(
		ctx,
		"Belly",
		Vector3.new(1.7 * bsc.X, 1.7 * bsc.Y, 3.0),
		Vector3.new(0, by - 0.45 * bsc.Y, -0.15),
		nil,
		{ Accent = true }
	)

	-- Head (and neck if the dino has one).
	local hs = Vector3.new(1.9, 1.7, 2.2) * h
	local hp = Vector3.new(0, by + 1.5 + neck + 0.35 * (h - 1), -(1.9 + 0.55 * (h - 1)) - neck * 0.3)
	if neck > 0 then
		local lowY = by + 0.6
		add(
			ctx,
			"Neck",
			Vector3.new(1.1, hp.Y - lowY + 1.2, 1.3),
			Vector3.new(0, (hp.Y + lowY) / 2, (hp.Z - 1.1) / 2 - 0.2),
			nil,
			{ Tone = 0.1 }
		)
	end
	add(ctx, "Head", hs, hp, nil, { Head = true })
	eyes(ctx, hp, hs)
	if not p.NoSnout then
		local sp, ss = snout(ctx, hp, hs, (0.6 + 0.4 * h) * (p.Snout or 1))
		if p.Teeth then
			teeth(ctx, sp, ss)
		end
	end

	-- Legs: thigh, shin, foot (+ a claw on each foot).
	for _, sx in { -1, 1 } do
		local tag = if sx < 0 then "L" else "R"
		add(ctx, "Thigh" .. tag, Vector3.new(1.0, 1.9, 1.5), Vector3.new(sx * 1.05, 1.9, 0.5))
		add(ctx, "Shin" .. tag, Vector3.new(0.55, 1.0, 0.55), Vector3.new(sx * 1.05, 0.85, 0.4))
		add(ctx, "Foot" .. tag, Vector3.new(0.95, 0.6, 1.7), Vector3.new(sx * 1.05, 0.3, -0.1))
		claw(ctx, "Claw" .. tag, Vector3.new(0.22, 0.22, 0.55), Vector3.new(sx * 1.05, 0.28, -1.05))
	end

	-- Tail: three tapering segments.
	add(ctx, "Tail1", Vector3.new(1.5, 1.5, 2.2), Vector3.new(0, 3.0, 2.4))
	add(ctx, "Tail2", Vector3.new(1.05, 1.05, 2.0), Vector3.new(0, 2.85, 3.9))
	add(ctx, "Tail3", Vector3.new(0.65, 0.65, 1.8), Vector3.new(0, 2.7, 5.1))

	if not p.NoArms then
		local a = p.Arm or 1
		pair(
			ctx,
			"Arm",
			Vector3.new(0.4, 0.4, 0.95) * a,
			Vector3.new(1.15 * bsc.X, by - 0.4, -1.5),
			Vector3.new(-0.5, 0, 0)
		)
	end

	backSpots(ctx, by + 1.2 * bsc.Y - 0.05, { -0.8, 0.5, 1.8 })
	return { By = by, HeadPos = hp, HeadSize = hs }
end

-- Archetypes -------------------------------------------------------------------------

local function raptor(ctx: Ctx)
	biped(ctx, { Teeth = true })
end

local function rex(ctx: Ctx)
	biped(ctx, { Head = 1.6, Arm = 0.6, Teeth = true })
end

-- A sail on the back: one big thin ellipsoid plus a few ribs.
local function sail(ctx: Ctx, y: number, length: number, height: number)
	add(
		ctx,
		"Sail",
		Vector3.new(0.25, height, length),
		Vector3.new(0, y + height * 0.3, 0.2),
		nil,
		{ Accent = true }
	)
	for i = -1, 1 do
		add(
			ctx,
			"SailRib" .. (i + 2),
			Vector3.new(0.2, height * 1.1, 0.2),
			Vector3.new(0, y + height * 0.3, 0.2 + i * length * 0.3),
			nil,
			{ Tone = -0.2 }
		)
	end
end

local function sailBiped(ctx: Ctx)
	local info = biped(ctx, { Snout = 1.8, Teeth = true })
	sail(ctx, info.By + 1.1, 3.4, 2.4)
end

local function dimetrodon(ctx: Ctx)
	local info = quad(ctx, {
		BodySize = Vector3.new(2.4, 1.9, 4.6),
		LegHeight = 0.8,
		HeadSize = Vector3.new(1.7, 1.5, 2.0),
		SnoutLength = 1.0,
		Teeth = true,
		Tail = {
			{ Size = Vector3.new(1.3, 1.2, 2.4), Y = 1.5, Z = 3.1 },
			{ Size = Vector3.new(0.9, 0.9, 2.2), Y = 1.35, Z = 4.7 },
			{ Size = Vector3.new(0.5, 0.5, 1.8), Y = 1.2, Z = 6.0 },
		},
	})
	sail(ctx, info.By + 0.8, 3.4, 2.6)
end

local function horned(ctx: Ctx, small: boolean)
	local info = quad(ctx, {
		BodySize = Vector3.new(3.0, 2.8, 4.2),
		LegHeight = 1.5,
		HeadSize = Vector3.new(2.1, 2.0, 2.4),
		HeadPos = function(by)
			return Vector3.new(0, by + 0.15, -3.1)
		end,
		SnoutLength = 1.2,
	})
	local hp = info.HeadPos
	local frillY = info.By + 1.2
	local fs = if small then Vector3.new(3.0, 2.6, 0.4) else Vector3.new(3.8, 3.4, 0.45)
	add(
		ctx,
		"Frill",
		fs,
		Vector3.new(0, frillY, hp.Z + 1.0),
		Vector3.new(0.3, 0, 0),
		{ Accent = true, Head = true }
	)
	if small then
		add(
			ctx,
			"NoseBump",
			Vector3.new(0.6, 0.6, 0.7),
			Vector3.new(0, hp.Y + 0.1, hp.Z - 2.0),
			nil,
			{ Tone = 0.2, Head = true }
		)
		return
	end
	for i = -2, 2 do
		add(
			ctx,
			"FrillStud" .. (i + 3),
			Vector3.new(0.55, 0.55, 0.55),
			Vector3.new(i * 0.8, frillY + 1.5 * math.cos(i * 0.4), hp.Z + 1.3),
			nil,
			{ Tone = 0.4, Head = true }
		)
	end
	pair(
		ctx,
		"Horn",
		Vector3.new(0.45, 0.45, 1.7),
		Vector3.new(0.75, hp.Y + 1.0, hp.Z - 1.1),
		Vector3.new(0.5, 0, 0),
		{ Color = BONE, Head = true }
	)
	add(
		ctx,
		"NoseHorn",
		Vector3.new(0.45, 0.45, 0.9),
		Vector3.new(0, hp.Y + 0.2, hp.Z - 2.0),
		Vector3.new(0.6, 0, 0),
		{ Color = BONE, Head = true }
	)
end

local function armored(ctx: Ctx)
	ctx.K = 0.85
	local info = quad(ctx, {
		BodySize = Vector3.new(4.2, 2.2, 4.6),
		LegHeight = 0.9,
		LegWidth = 1.2,
		HeadSize = Vector3.new(1.9, 1.6, 2.0),
		HeadPos = function(by)
			return Vector3.new(0, by + 0.1, -3.0)
		end,
		SnoutLength = 0.8,
		Tail = {
			{ Size = Vector3.new(1.4, 1.2, 2.4), Y = 1.85, Z = 3.5 },
			{ Size = Vector3.new(0.8, 0.8, 2.0), Y = 1.8, Z = 5.0 },
		},
	})
	local by = info.By
	add(ctx, "Shell", Vector3.new(4.3, 1.3, 4.7), Vector3.new(0, by + 0.7, 0), nil, { Tone = -0.25 })
	for _, sx in { -1, 1 } do
		for i, z in { -1.3, 0, 1.3 } do
			add(
				ctx,
				"Stud" .. i .. (if sx < 0 then "L" else "R"),
				Vector3.new(0.8, 0.8, 0.8),
				Vector3.new(sx * 1.2, by + 1.35, z),
				nil,
				{ Tone = 0.3 }
			)
		end
	end
	add(ctx, "TailClub", Vector3.new(2.0, 1.5, 2.0), Vector3.new(0, 1.8, 6.4), nil, { Tone = -0.15 })
	for _, sx in { -1, 1 } do
		add(
			ctx,
			"ClubSpike" .. (if sx < 0 then "L" else "R"),
			Vector3.new(0.4, 0.4, 0.8),
			Vector3.new(sx * 1.0, 1.9, 6.4),
			Vector3.new(0, sx * 0.9, 0),
			{ Color = BONE }
		)
	end
end

local function plated(ctx: Ctx)
	local info = quad(ctx, {
		BodySize = Vector3.new(2.6, 2.7, 4.6),
		LegHeight = 1.4,
		HeadSize = Vector3.new(1.6, 1.5, 2.2),
		HeadPos = function(by)
			return Vector3.new(0, by - 0.4, -3.3)
		end,
		SnoutLength = 0.7,
	})
	local by = info.By
	local heights = { 1.4, 2.0, 2.4, 2.0, 1.4 }
	for i, h in heights do
		add(
			ctx,
			"Plate" .. i,
			Vector3.new(0.3, h, 1.2),
			Vector3.new(if i % 2 == 0 then 0.3 else -0.3, by + 1.35 + h / 2 - 0.3, -1.6 + (i - 1) * 0.85),
			nil,
			{ Accent = true }
		)
	end
	for _, z in { 4.2, 5.2 } do
		pair(
			ctx,
			"TailSpike" .. (if z < 5 then 1 else 2),
			Vector3.new(0.3, 0.3, 1.3),
			Vector3.new(0.5, by + 0.25, z),
			Vector3.new(-0.4, 0.35, 0),
			{ Color = BONE }
		)
	end
end

local function longNeck(ctx: Ctx)
	ctx.K = 0.85
	local info = quad(ctx, {
		BodySize = Vector3.new(3.4, 3.0, 4.6),
		LegHeight = 2.3,
		LegWidth = 1.4,
		HeadSize = Vector3.new(1.3, 1.1, 1.9),
		HeadPos = function(by)
			return Vector3.new(0, by + 5.4, -3.9)
		end,
		Tail = {
			{ Size = Vector3.new(1.6, 1.5, 2.4), Y = 3.55, Z = 3.3 },
			{ Size = Vector3.new(1.1, 1.0, 2.4), Y = 3.35, Z = 5.0 },
			{ Size = Vector3.new(0.6, 0.6, 2.0), Y = 3.15, Z = 6.6 },
		},
	})
	local by = info.By
	add(ctx, "Neck1", Vector3.new(1.5, 2.0, 1.6), Vector3.new(0, by + 1.2, -2.2), nil, { Tone = 0.05 })
	add(ctx, "Neck2", Vector3.new(1.2, 2.0, 1.3), Vector3.new(0, by + 2.8, -2.9), nil, { Tone = 0.05 })
	add(ctx, "Neck3", Vector3.new(1.0, 1.8, 1.1), Vector3.new(0, by + 4.3, -3.4), nil, { Tone = 0.05 })
end

local function crested(ctx: Ctx)
	local info = biped(ctx, { Arm = 1.4 })
	local hp, hs = info.HeadPos, info.HeadSize
	add(
		ctx,
		"Crest",
		Vector3.new(0.55, 0.55, 3.2),
		Vector3.new(0, hp.Y + hs.Y * 0.4, hp.Z + 1.5),
		Vector3.new(-0.45, 0, 0),
		{ Accent = true, Head = true }
	)
	add(
		ctx,
		"Bill",
		Vector3.new(1.5, 0.6, 1.1),
		Vector3.new(0, hp.Y - 0.35, hp.Z - 1.9),
		nil,
		{ Accent = true, Head = true }
	)
end

local function flyer(ctx: Ctx)
	ctx.K = 0.85
	local body = add(ctx, "Body", Vector3.new(1.9, 2.1, 2.7), Vector3.new(0, 2.9, 0.1))
	ctx.Model.PrimaryPart = body
	add(ctx, "Belly", Vector3.new(1.5, 1.6, 2.2), Vector3.new(0, 2.6, -0.15), nil, { Accent = true })

	local hs = Vector3.new(1.5, 1.4, 1.7)
	local hp = Vector3.new(0, 4.5, -1.5)
	add(ctx, "Neck", Vector3.new(0.9, 1.4, 0.9), Vector3.new(0, 3.9, -0.9), nil, { Tone = 0.05 })
	add(ctx, "Head", hs, hp, nil, { Head = true })
	eyes(ctx, hp, hs)
	add(
		ctx,
		"Beak",
		Vector3.new(0.6, 0.5, 2.6),
		Vector3.new(0, hp.Y - 0.15, hp.Z - 2.0),
		Vector3.new(0.12, 0, 0),
		{ Accent = true, Head = true }
	)
	add(
		ctx,
		"Crest",
		Vector3.new(0.35, 0.6, 2.2),
		Vector3.new(0, hp.Y + 0.55, hp.Z + 1.5),
		Vector3.new(-0.3, 0, 0),
		{ Tone = -0.15, Head = true }
	)

	pair(ctx, "Leg", Vector3.new(0.5, 2.0, 0.5), Vector3.new(0.5, 1.0, 0.2))
	pair(ctx, "Foot", Vector3.new(0.7, 0.3, 1.2), Vector3.new(0.5, 0.15, 0.0))

	-- Wings spread wide: arm bone, membrane and tip on each side.
	pair(ctx, "WingArm", Vector3.new(3.4, 0.4, 0.8), Vector3.new(2.7, 3.7, 0.1), Vector3.new(0, 0, 0.18))
	pair(
		ctx,
		"WingMembrane",
		Vector3.new(3.8, 0.15, 2.6),
		Vector3.new(3.1, 3.45, 0.9),
		Vector3.new(0, 0, 0.14),
		{ Accent = true }
	)
	pair(
		ctx,
		"WingTip",
		Vector3.new(2.4, 0.15, 1.3),
		Vector3.new(5.5, 3.75, 0.9),
		Vector3.new(0, -0.3, 0.2),
		{ Accent = true }
	)
	add(ctx, "Tail", Vector3.new(0.5, 0.5, 1.6), Vector3.new(0, 2.6, 1.9), nil, { Tone = -0.1 })

	backSpots(ctx, 3.9, { -0.5, 0.4, 1.2 })
end

local function claw3(ctx: Ctx)
	local info = biped(ctx, {
		BodyScale = Vector3.new(1.45, 1.3, 1.1),
		Head = 0.7,
		Neck = 1.3,
		NoArms = true,
		NoSnout = true,
	})
	local by = info.By
	local rotX = -0.8
	local dir = Vector3.new(0, math.sin(rotX), -math.cos(rotX))
	for _, sx in { -1, 1 } do
		local tag = if sx < 0 then "L" else "R"
		local shoulder = Vector3.new(sx * 1.8, by + 0.3, -1.0)
		add(
			ctx,
			"Arm" .. tag,
			Vector3.new(0.6, 0.6, 2.2),
			shoulder + dir * 1.1,
			Vector3.new(rotX, 0, 0),
			{ Tone = 0.05 }
		)
		local tip = shoulder + dir * 2.3
		for i, off in { -0.22, 0.22 } do
			claw(
				ctx,
				"Claw" .. i .. tag,
				Vector3.new(0.18, 0.18, 1.5),
				tip + dir * 0.55 + Vector3.new(off, 0, 0),
				Vector3.new(rotX, 0, 0)
			)
		end
	end
end

local function generic(ctx: Ctx)
	quad(ctx, {
		BodySize = Vector3.new(2.8, 2.6, 4.2),
		LegHeight = 1.5,
		HeadSize = Vector3.new(2.0, 1.9, 2.3),
		SnoutLength = 1.0,
	})
end

local BUILDERS: { [string]: (Ctx) -> () } = {
	Raptor = raptor,
	Rex = rex,
	Horned = function(ctx)
		horned(ctx, ctx.Model.Name == "Protoceratops")
	end,
	Armored = armored,
	Plated = plated,
	Sail = function(ctx)
		if ctx.Model.Name == "Dimetrodon" then
			dimetrodon(ctx)
		else
			sailBiped(ctx)
		end
	end,
	LongNeck = longNeck,
	Crested = crested,
	Flyer = flyer,
	Claw = claw3,
}

-- Zone themes -------------------------------------------------------------------------

local function themeOf(dinoId: string): string?
	for _, prefix in { "Frost", "Snow", "Glacier", "Blizzard" } do
		if string.sub(dinoId, 1, #prefix) == prefix then
			return "Ice"
		end
	end
	for _, prefix in { "Ember", "Magma", "Inferno", "Volcano", "Meteor" } do
		if string.sub(dinoId, 1, #prefix) == prefix then
			return "Fire"
		end
	end
	if string.sub(dinoId, 1, 5) == "Amber" then
		return "Amber"
	end
	for prefix, theme in { Crystal = "Crystal", Geode = "Crystal", Prism = "Crystal", Amethyst = "Crystal" } do
		if string.sub(dinoId, 1, #prefix) == prefix then
			return theme
		end
	end
	for _, prefix in { "Star", "Comet", "Orbit" } do
		if string.sub(dinoId, 1, #prefix) == prefix then
			return "Star"
		end
	end
	for _, prefix in { "Cloud", "Sky", "Aurora", "Celestial" } do
		if string.sub(dinoId, 1, #prefix) == prefix then
			return "Sky"
		end
	end
	return nil
end

local function decorate(ctx: Ctx)
	for i, spot in ctx.Spots do
		if ctx.Theme == "Ice" then
			add(
				ctx,
				"IceSpike" .. i,
				Vector3.new(0.5, 1.2, 0.5),
				spot + Vector3.new(0, 0.5, 0),
				nil,
				{ Color = Color3.fromRGB(190, 235, 255), Material = Enum.Material.Ice, Transparency = 0.15 }
			)
		elseif ctx.Theme == "Fire" then
			add(
				ctx,
				"LavaCrack" .. i,
				Vector3.new(0.7, 0.4, 1.0),
				spot + Vector3.new(0, 0.1, 0),
				nil,
				{ Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon, Keep = true }
			)
		elseif ctx.Theme == "Amber" then
			add(ctx, "AmberGem" .. i, Vector3.new(0.7, 0.7, 0.7), spot + Vector3.new(0, 0.15, 0), nil, {
				Color = Color3.fromRGB(255, 185, 50),
				Material = Enum.Material.Glass,
				Transparency = 0.2,
				Keep = true,
			})
		elseif ctx.Theme == "Crystal" then
			add(ctx, "CrystalGem" .. i, Vector3.new(0.5, 1.1, 0.5), spot + Vector3.new(0, 0.45, 0), nil, {
				Color = Color3.fromRGB(200, 140, 255),
				Material = Enum.Material.Glass,
				Transparency = 0.15,
				Keep = true,
			})
		elseif ctx.Theme == "Star" then
			add(ctx, "StarGlow" .. i, Vector3.new(0.45, 0.45, 0.45), spot + Vector3.new(0, 0.2, 0), nil, {
				Color = Color3.fromRGB(130, 230, 255),
				Material = Enum.Material.Neon,
				Keep = true,
			})
		elseif ctx.Theme == "Sky" then
			add(ctx, "SkyPuff" .. i, Vector3.new(0.9, 0.5, 0.9), spot + Vector3.new(0, 0.2, 0), nil, {
				Color = Color3.fromRGB(255, 245, 200),
				Material = Enum.Material.Neon,
				Keep = true,
			})
		end
	end
end

-- Public -----------------------------------------------------------------------------

function DinoArt.Build(dinoId: string): Model
	local dino = Dinos.ById[dinoId]
	local base = if dino then dino.Color else Color3.fromRGB(130, 150, 110)
	local model = Instance.new("Model")
	model.Name = dinoId
	local ctx: Ctx = {
		Model = model,
		K = 1,
		Base = base,
		Accent = if dino and dino.Accent then dino.Accent else tint(base, 0.35),
		Theme = themeOf(dinoId),
		Spots = {},
	}
	local builder = BUILDERS[if dino and dino.Shape then dino.Shape else "Generic"] or generic
	builder(ctx)
	decorate(ctx)
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChild("Body") :: BasePart
	end
	return model
end

-- A hand-made model from ReplicatedStorage.DinoModels wins over the code-built one.
function DinoArt.Get(dinoId: string): Model
	local folder = ReplicatedStorage:FindFirstChild("DinoModels")
	local template = folder and folder:FindFirstChild(dinoId)
	if template and template:IsA("Model") and template.PrimaryPart then
		return template:Clone()
	end
	return DinoArt.Build(dinoId)
end

-- Gold = foil gold, Rainbow = a hue cycle along the body, others use Config/Eggs.
function DinoArt.ApplyMutation(model: Instance, mutationId: string?)
	local mutation = if mutationId then Eggs.MutationById[mutationId] else nil
	if not mutation or mutation.Id == "None" then
		return
	end
	local rainbow = mutation.Id == "Rainbow"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d:GetAttribute("KeepColor") then
			local tone = d:GetAttribute("Tone") or 0
			local color = mutation.Color or d.Color
			if rainbow then
				local hue = (d.Position.Z * 0.09 + d.Position.Y * 0.06) % 1
				color = Color3.fromHSV(hue, 0.6, 1)
			end
			d.Color = tint(color, tone)
			d.Material = if rainbow then Enum.Material.SmoothPlastic else (mutation.Material or d.Material)
		end
	end
end

-- Babies: head (with eyes, snout, horns...) 1.5x and lifted, eyes a bit bigger still.
function DinoArt.ApplyBaby(model: Model)
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local body = model.PrimaryPart
	if not body then
		return
	end
	local factor = 1.5
	local oldCF = head.CFrame
	local lift = body.CFrame:VectorToWorldSpace(Vector3.new(0, 0.6, -0.4))
	local newCF = oldCF + lift
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and (d == head or d:GetAttribute("Head") or d.Name == "EyeL" or d.Name == "EyeR")
		then
			local rel = oldCF:ToObjectSpace(d.CFrame)
			d.Size *= factor
			d.CFrame = newCF * CFrame.new(rel.Position * factor) * rel.Rotation
			if string.find(d.Name, "Eye") or string.find(d.Name, "Pupil") or string.find(d.Name, "Shine") then
				d.Size *= 1.25
			end
		end
	end
end

return DinoArt
