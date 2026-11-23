-- EggRoll.luau
-- Server-only egg rolls. Luck makes rarer eggs more likely:
-- each rarity's weight is multiplied by luck ^ LuckPower (see Config/Eggs).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local WeightedRandom = require(ReplicatedStorage.Shared.Util.WeightedRandom)

local EventService = require(script.Parent.Services.EventService)

local EggRoll = {}

local rng = Random.new()

export type Egg = {
	Id: string,
	Rarity: string,
	Size: string,
	Mutation: string,
	Zone: string,
}

function EggRoll.Roll(luck: number, zoneId: string): Egg
	local rarity = WeightedRandom.Pick(Eggs.Rarities, rng, function(entry)
		return entry.Weight * luck ^ entry.LuckPower
	end)
	local size = WeightedRandom.Pick(Eggs.Sizes, rng)
	-- Events like Golden Hour make mutations more likely.
	local mutationBoost = EventService.Multiplier("Mutation")
	local mutation = WeightedRandom.Pick(Eggs.Mutations, rng, function(entry)
		return if entry.Id == "None" then entry.Weight else entry.Weight * mutationBoost
	end)
	return {
		Id = HttpService:GenerateGUID(false),
		Rarity = rarity.Id,
		Size = size.Id,
		Mutation = mutation.Id,
		Zone = zoneId,
	}
end

-- Which dinosaur hatches from an egg: any dino of the egg's rarity, plus the
-- zone's exclusives if it was dug in a zone that has them.
function EggRoll.PickDino(rarityId: string, zoneId: string?): string
	local options = Dinos.Pool(rarityId, zoneId)
	return options[rng:NextInteger(1, #options)].Id
end

return EggRoll
