-- WeaponArt.luau
-- Builds the look of each bonk weapon from Parts welded to the Tool's Handle.
-- The Handle is the shaft you hold (long along Z; the hand grips near the -Z
-- end, see WeaponService), and the weapon's head sits at the +Z end. Skins
-- recolour only the head parts (attribute Head), never the grip.
--
-- To use a real model instead, put a Tool-ready Model named after the weapon Id
-- in ReplicatedStorage > WeaponModels (WeaponService doesn't look for one yet;
-- add it there if you get real art).

local WeaponArt = {}

type Skin = { Color: Color3, Material: Enum.Material }?

local function part(
	handle: BasePart,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	isHead: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = handle.CFrame * offset
	if isHead then
		p:SetAttribute("Head", true)
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	p.Parent = handle
	return p
end

-- Builders get the handle, its length, the weapon's colours and a head(...)
-- helper that adds a skinnable head part.
type Head = (
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
) -> Part

local BUILDERS: { [string]: (handle: BasePart, length: number, head: Head) -> () } = {}

-- A forked branch with a leaf near the tip.
BUILDERS.Stick = function(_handle, length, head)
	local tip = length / 2
	head(
		"Twig",
		Enum.PartType.Block,
		Vector3.new(0.18, 0.18, 0.9),
		CFrame.new(0, 0.25, tip - 0.6) * CFrame.Angles(math.rad(-35), 0, 0),
		Color3.fromRGB(120, 82, 46),
		Enum.Material.Wood
	)
	head(
		"Leaf",
		Enum.PartType.Ball,
		Vector3.new(0.5, 0.12, 0.7),
		CFrame.new(0, 0.55, tip - 0.25),
		Color3.fromRGB(90, 170, 70),
		Enum.Material.SmoothPlastic
	)
	head(
		"Knot",
		Enum.PartType.Ball,
		Vector3.one * 0.55,
		CFrame.new(0, 0, tip),
		Color3.fromRGB(110, 75, 42),
		Enum.Material.Wood
	)
end

-- A big cartoon bone: two knobs at the end.
BUILDERS.BoneClub = function(_handle, length, head)
	local tip = length / 2
	for _, side in { -1, 1 } do
		head(
			"Knob",
			Enum.PartType.Ball,
			Vector3.one * 1.1,
			CFrame.new(side * 0.42, 0, tip - 0.1),
			Color3.fromRGB(240, 232, 210),
			Enum.Material.SmoothPlastic
		)
	end
	head(
		"KnobBack",
		Enum.PartType.Ball,
		Vector3.one * 0.8,
		CFrame.new(0, 0, -tip + 0.9),
		Color3.fromRGB(240, 232, 210),
		Enum.Material.SmoothPlastic
	)
end

-- A spiked ball, like an ankylosaur's tail club.
BUILDERS.TailMace = function(_handle, length, head)
	local tip = length / 2
	local center = CFrame.new(0, 0, tip + 0.3)
	head(
		"Ball",
		Enum.PartType.Ball,
		Vector3.one * 1.6,
		center,
		Color3.fromRGB(100, 120, 76),
		Enum.Material.Slate
	)
	local spikes = {
		CFrame.Angles(0, 0, 0),
		CFrame.Angles(math.pi, 0, 0),
		CFrame.Angles(math.pi / 2, 0, 0),
		CFrame.Angles(-math.pi / 2, 0, 0),
		CFrame.Angles(0, 0, math.pi / 2),
		CFrame.Angles(0, 0, -math.pi / 2),
	}
	for i, rot in spikes do
		-- Each spike points out along the rotated +Y.
		head(
			"Spike" .. i,
			Enum.PartType.Block,
			Vector3.new(0.32, 0.6, 0.32),
			center * rot * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, math.rad(45), 0),
			Color3.fromRGB(225, 215, 190),
			Enum.Material.SmoothPlastic
		)
	end
end

-- Three curved claws fanning out from a knuckle.
BUILDERS.RaptorClaw = function(_handle, length, head)
	local tip = length / 2
	head(
		"Knuckle",
		Enum.PartType.Ball,
		Vector3.new(1.2, 0.7, 0.8),
		CFrame.new(0, 0, tip),
		Color3.fromRGB(190, 190, 200),
		Enum.Material.Metal
	)
	for i, x in { -0.4, 0, 0.4 } do
		local base = CFrame.new(x, 0.1, tip + 0.35) * CFrame.Angles(0, math.rad(x * -25), 0)
		head(
			"ClawBase" .. i,
			Enum.PartType.Block,
			Vector3.new(0.22, 0.3, 0.7),
			base * CFrame.new(0, 0, 0.3),
			Color3.fromRGB(235, 235, 240),
			Enum.Material.Metal
		)
		-- The tip bends down to make the hook.
		head(
			"ClawTip" .. i,
			Enum.PartType.Block,
			Vector3.new(0.16, 0.22, 0.55),
			base * CFrame.new(0, -0.1, 0.8) * CFrame.Angles(math.rad(30), 0, 0),
			Color3.fromRGB(235, 235, 240),
			Enum.Material.Metal
		)
	end
end

-- A hammer with a glowing amber block (with a tiny bug trapped inside).
BUILDERS.AmberHammer = function(handle, length, head)
	local tip = length / 2
	local center = CFrame.new(0, 0, tip)
	head(
		"Block",
		Enum.PartType.Block,
		Vector3.new(2.2, 1.1, 1.1),
		center,
		Color3.fromRGB(255, 165, 35),
		Enum.Material.Glass
	).Transparency =
		0.15
	head(
		"Band",
		Enum.PartType.Block,
		Vector3.new(0.3, 1.2, 1.2),
		center,
		Color3.fromRGB(120, 80, 40),
		Enum.Material.Wood
	)
	head(
		"Bug",
		Enum.PartType.Ball,
		Vector3.new(0.3, 0.2, 0.4),
		center * CFrame.new(0.6, 0, 0),
		Color3.fromRGB(40, 30, 25),
		Enum.Material.SmoothPlastic
	)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 60)
	glow.Range = 6
	glow.Brightness = 0.8
	glow.Parent = handle
end

-- A thick bat with chunks of meteor rock and glowing cracks.
BUILDERS.MeteorBat = function(_handle, length, head)
	local tip = length / 2
	head(
		"Barrel",
		Enum.PartType.Cylinder,
		Vector3.new(1.6, 1.15, 1.15),
		CFrame.new(0, 0, tip - 0.5) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(70, 50, 110),
		Enum.Material.Slate
	)
	for i, offset in
		{ Vector3.new(0.45, 0.35, tip - 0.7), Vector3.new(-0.4, -0.3, tip - 0.2), Vector3.new(0, 0.5, tip) }
	do
		head(
			"Rock" .. i,
			Enum.PartType.Block,
			Vector3.new(0.6, 0.5, 0.6),
			CFrame.new(offset) * CFrame.Angles(0.4 * i, 0.7 * i, 0.2),
			Color3.fromRGB(60, 55, 70),
			Enum.Material.Basalt
		)
		head(
			"Crack" .. i,
			Enum.PartType.Block,
			Vector3.new(0.65, 0.08, 0.2),
			CFrame.new(offset + Vector3.new(0, 0.26, 0)) * CFrame.Angles(0, 0.7 * i, 0),
			Color3.fromRGB(170, 90, 255),
			Enum.Material.Neon
		)
	end
end

-- Adds the weapon's head parts to its Handle. A skin recolours only the head.
function WeaponArt.Decorate(handle: BasePart, weaponId: string, length: number, skin: Skin)
	local builder = BUILDERS[weaponId]
	if not builder then
		return
	end
	local function head(name, shape, size, offset, color, material)
		local p = part(handle, name, shape, size, offset, color, material, true)
		if skin and p.Material ~= Enum.Material.Neon then
			p.Color = skin.Color
			p.Material = skin.Material
		end
		return p
	end
	builder(handle, length, head)
end

return WeaponArt
