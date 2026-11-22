-- Zones.luau
-- Dig zones laid out in a straight canyon in front of the launch pad.
-- Distances are studs measured from the launch pad. The map is built from
-- this list, so adding a zone here adds it to the world too.

export type Zone = {
	Id: string,
	Name: string,
	StartDistance: number,
	EndDistance: number,
	Luck: number, -- multiplies the chance of rarer eggs
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

return ZoneModule
