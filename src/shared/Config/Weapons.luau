-- Weapons.luau
-- Bonk weapons and skins. A bonk hits a player who is carrying an egg: they get
-- knocked back and drop the egg, and anyone can grab it. Better weapons reach
-- further and bonk more often.
--
-- Weapons cost coins or are game passes (Pass = key in Config/Passes). Robux
-- weapons are only as strong as the best coin weapon: paying is a shortcut,
-- not a win button. Skins are game passes that change only the look and work
-- on every weapon.

local Weapons = {}

export type Weapon = {
	Id: string,
	Name: string,
	Range: number, -- studs to the target
	Cooldown: number, -- seconds between bonks
	Coins: number?, -- price in coins (0 = free)
	Pass: string?, -- game pass key, for Robux weapons
	Color: Color3,
	Material: Enum.Material,
	Size: Vector3, -- greybox handle size (long side is Y)
}

Weapons.List = {
	{
		Id = "Stick",
		Name = "Stick",
		Range = 12,
		Cooldown = 10,
		Coins = 0,
		Color = Color3.fromRGB(130, 90, 50),
		Material = Enum.Material.Wood,
		Size = Vector3.new(0.4, 3, 0.4),
	},
	{
		Id = "BoneClub",
		Name = "Bone Club",
		Range = 14,
		Cooldown = 9,
		Coins = 5000,
		Color = Color3.fromRGB(235, 225, 200),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(0.7, 3.4, 0.7),
	},
	{
		Id = "TailMace",
		Name = "Tail Mace",
		Range = 16,
		Cooldown = 8,
		Coins = 60000,
		Color = Color3.fromRGB(90, 110, 70),
		Material = Enum.Material.Slate,
		Size = Vector3.new(1, 3.8, 1),
	},
	{
		Id = "RaptorClaw",
		Name = "Raptor Claw",
		Range = 18,
		Cooldown = 7,
		Coins = 600000,
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Metal,
		Size = Vector3.new(0.5, 3.2, 1.2),
	},
	{
		Id = "AmberHammer",
		Name = "Amber Hammer",
		Range = 18,
		Cooldown = 7,
		Pass = "AmberHammer",
		Color = Color3.fromRGB(255, 160, 30),
		Material = Enum.Material.Glass,
		Size = Vector3.new(1.4, 3.6, 1.4),
	},
	{
		Id = "MeteorBat",
		Name = "Meteor Bat",
		Range = 18,
		Cooldown = 7,
		Pass = "MeteorBat",
		Color = Color3.fromRGB(120, 60, 200),
		Material = Enum.Material.Neon,
		Size = Vector3.new(0.9, 4, 0.9),
	},
}

-- Skins recolor whatever weapon you hold.
Weapons.Skins = {
	{
		Id = "Golden",
		Name = "Golden skin",
		Pass = "SkinGolden",
		Color = Color3.fromRGB(255, 200, 50),
		Material = Enum.Material.Foil,
	},
	{
		Id = "Lava",
		Name = "Lava skin",
		Pass = "SkinLava",
		Color = Color3.fromRGB(255, 90, 20),
		Material = Enum.Material.Neon,
	},
	{
		Id = "Crystal",
		Name = "Crystal skin",
		Pass = "SkinCrystal",
		Color = Color3.fromRGB(200, 150, 255),
		Material = Enum.Material.Glass,
	},
	{
		Id = "Rainbow",
		Name = "Rainbow skin",
		Pass = "SkinRainbow",
		Color = Color3.fromRGB(255, 120, 220),
		Material = Enum.Material.ForceField,
	},
}

Weapons.ById = {}
for order, weapon in Weapons.List do
	weapon.Order = order
	Weapons.ById[weapon.Id] = weapon
end
Weapons.SkinById = {}
for _, skin in Weapons.Skins do
	Weapons.SkinById[skin.Id] = skin
end

Weapons.Default = "Stick"
Weapons.KnockbackSpeed = 45 -- how hard a bonk pushes the victim
Weapons.StunSeconds = 0.8 -- the victim can't move for this long
Weapons.DropSeconds = 25 -- a dropped egg goes back to its carrier if nobody grabs it
Weapons.GrabProtectSeconds = 4 -- a grabbed egg can't be bonked or stolen for this long

return Weapons
