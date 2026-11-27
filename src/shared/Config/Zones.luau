-- Zones.luau
-- Dig zones laid out in a straight canyon in front of the launch pad.
-- Distances are studs measured from the launch pad. The map is built from
-- this list, so adding a zone here adds it to the world too.
--
-- Toughness: how hard the shovel flies through a zone. Each stud of the zone
-- costs this many studs of fling power, so a tough zone takes much more
-- Strength (and a better shovel) to cross. 1 = normal.
-- Luck rises the deeper you land in a zone (see LuckAt), so a longer fling
-- always pays, even inside the last zone.

export type Zone = {
	Id: string,
	Name: string,
	StartDistance: number,
	EndDistance: number,
	Luck: number, -- multiplies the chance of rarer eggs (at the start of the zone)
	Toughness: number?,
	Secret: boolean?, -- name hidden ("???") on signs until the player reaches it
	Color: Color3,
	Material: Enum.Material,
}

local Zones: { Zone } = {
	{
		Id = "SandyPit",
		Name = "Sandy Pit",
		StartDistance = 0,
		EndDistance = 120,
		Luck = 1,
		Color = Color3.fromRGB(226, 199, 143),
		Material = Enum.Material.Sand,
	},
	{
		Id = "FernValley",
		Name = "Fern Valley",
		StartDistance = 120,
		EndDistance = 300,
		Luck = 1.6,
		Color = Color3.fromRGB(108, 168, 88),
		Material = Enum.Material.Grass,
	},
	{
		Id = "TarPits",
		Name = "Tar Pits",
		StartDistance = 300,
		EndDistance = 550,
		Luck = 2.6,
		Color = Color3.fromRGB(58, 52, 60),
		Material = Enum.Material.Slate,
	},
	{
		Id = "AmberCliffs",
		Name = "Amber Cliffs",
		StartDistance = 550,
		EndDistance = 850,
		Luck = 4,
		Toughness = 6.5, -- the far edge takes about as long as a first rebirth
		Color = Color3.fromRGB(235, 160, 50),
		Material = Enum.Material.Sandstone,
	},
	-- Past Amber Cliffs: reached around the first rebirth (Frozen Tundra) and
	-- after a couple of rebirths (Volcano Rim). Each has its own dinos.
	{
		Id = "FrozenTundra",
		Name = "Frozen Tundra",
		StartDistance = 850,
		EndDistance = 1150,
		Luck = 6,
		Toughness = 10,
		Color = Color3.fromRGB(225, 240, 255),
		Material = Enum.Material.Snow,
	},
	{
		Id = "VolcanoRim",
		Name = "Volcano Rim",
		StartDistance = 1150,
		EndDistance = 1450,
		Luck = 9,
		Toughness = 40, -- many hours and several rebirths
		Color = Color3.fromRGB(70, 35, 30),
		Material = Enum.Material.CrackedLava,
	},
	-- The far end: each one takes more rebirths. Sky Island is the secret last
	-- zone: signs show "???" until you've landed there once.
	{
		Id = "CrystalCaves",
		Name = "Crystal Caves",
		StartDistance = 1450,
		EndDistance = 1750,
		Luck = 13,
		Toughness = 60,
		Color = Color3.fromRGB(120, 90, 190),
		Material = Enum.Material.Slate,
	},
	{
		Id = "MeteorCrater",
		Name = "Meteor Crater",
		StartDistance = 1750,
		EndDistance = 2050,
		Luck = 19,
		Toughness = 100,
		Color = Color3.fromRGB(60, 60, 75),
		Material = Enum.Material.Basalt,
	},
	{
		Id = "SkyIsland",
		Name = "Sky Island",
		StartDistance = 2050,
		EndDistance = 2350,
		Luck = 28,
		Toughness = 130, -- the end of the map: about 40 hours and 7 rebirths
		Secret = true,
		Color = Color3.fromRGB(150, 220, 120),
		Material = Enum.Material.Grass,
	},
}

local ZoneModule = {}
ZoneModule.List = Zones
ZoneModule.MaxDistance = Zones[#Zones].EndDistance

-- Returns the zone a distance lands in (the last zone if past the end).
function ZoneModule.ForDistance(distance: number): Zone
	for _, zone in Zones do
		if distance < zone.EndDistance then
			return zone
		end
	end
	return Zones[#Zones]
end

-- How far a fling with this much power (studs, before zones) actually goes.
function ZoneModule.DistanceFor(power: number): number
	local distance = 0
	for _, zone in Zones do
		local length = zone.EndDistance - zone.StartDistance
		local cost = length * (zone.Toughness or 1)
		if power <= cost then
			return distance + power / (zone.Toughness or 1)
		end
		power -= cost
		distance += length
	end
	return distance
end

-- Luck where a fling lands: the zone's Luck at its start, rising halfway to the
-- next zone's at its end (the last zone rises to 1.5x).
function ZoneModule.LuckAt(distance: number): number
	for i, zone in Zones do
		if distance < zone.EndDistance or i == #Zones then
			local nextLuck = if Zones[i + 1] then Zones[i + 1].Luck else zone.Luck * 2
			local depth =
				math.clamp((distance - zone.StartDistance) / (zone.EndDistance - zone.StartDistance), 0, 1)
			return zone.Luck + (nextLuck - zone.Luck) * 0.5 * depth
		end
	end
	return 1
end

-- "x4-6 luck" for zone signs.
function ZoneModule.LuckText(zone): string
	local low = ZoneModule.LuckAt(zone.StartDistance)
	local high = ZoneModule.LuckAt(zone.EndDistance - 0.01)
	return string.format("x%g-%g luck", math.floor(low * 10 + 0.5) / 10, math.floor(high * 10 + 0.5) / 10)
end

return ZoneModule
