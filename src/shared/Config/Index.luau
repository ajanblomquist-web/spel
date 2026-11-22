-- Index.luau
-- The Dino Index: a collection book with one row per dino and one box per
-- variant. Hatching a dino ticks every box it matches, so a Colossal Gold Baby
-- Triceratops ticks "Found", "Gold", "Colossal" and "Baby" in one go.
--
-- Pages are rarities. Finding every dino on a page (the "Found" box) pays a
-- one-time coin reward and permanently raises your Baby odds.
--
-- Baby dinos: an extra roll on every hatch (about 1 in 500). Babies earn 3x,
-- look small with a big head, get their own reveal and a server-wide shout.
-- They are never sold for Robux.

local Dinos = require(script.Parent.Dinos)
local Eggs = require(script.Parent.Eggs)

local Index = {}

Index.BabyChance = 1 / 500
Index.BabyIncomeMultiplier = 3
Index.BabyScale = 0.6
Index.BabyColor = Color3.fromRGB(255, 140, 200)
Index.BabyLuckPerPage = 0.1 -- +10% Baby odds for each completed page

-- The boxes on each dino's row, in order. Short is the text inside the box.
Index.Variants = {
	{ Id = "Found", Short = "Dino", Color = Color3.fromRGB(120, 200, 120) },
	{ Id = "Gold", Short = "Gold", Color = Eggs.MutationById.Gold.Color },
	{ Id = "Lava", Short = "Lava", Color = Eggs.MutationById.Lava.Color },
	{ Id = "Frozen", Short = "Ice", Color = Eggs.MutationById.Frozen.Color },
	{ Id = "Crystal", Short = "Crys", Color = Eggs.MutationById.Crystal.Color },
	{ Id = "Rainbow", Short = "Rbow", Color = Eggs.MutationById.Rainbow.Color },
	{ Id = "Colossal", Short = "Huge", Color = Color3.fromRGB(255, 170, 60) },
	{ Id = "Baby", Short = "Baby", Color = Index.BabyColor },
}

-- One-time coins for completing a page (finding every dino of that rarity).
Index.PageCoins = {
	Common = 500,
	Uncommon = 2000,
	Rare = 10000,
	Epic = 50000,
	Legendary = 300000,
	Mythic = 2000000,
	Secret = 20000000,
}

-- Pages in rarity order: { Rarity = "Common", Dinos = { dino, ... } }
Index.Pages = {}
for _, rarity in Eggs.Rarities do
	local page = { Rarity = rarity.Id, Dinos = {} }
	for _, dino in Dinos.List do
		if dino.Rarity == rarity.Id then
			table.insert(page.Dinos, dino)
		end
	end
	if #page.Dinos > 0 then
		table.insert(Index.Pages, page)
	end
end

Index.TotalEntries = #Dinos.List * #Index.Variants

-- The variant boxes a hatched dino record ticks.
function Index.KeysFor(record): { string }
	local keys = { "Found" }
	if record.Mutation and record.Mutation ~= "None" then
		table.insert(keys, record.Mutation)
	end
	if record.Size == "Colossal" then
		table.insert(keys, "Colossal")
	end
	if record.Baby then
		table.insert(keys, "Baby")
	end
	return keys
end

-- entries: { [dinoId] = { [variantId] = true } }
function Index.Count(entries): number
	local count = 0
	for _, row in entries do
		for _ in row do
			count += 1
		end
	end
	return count
end

function Index.PageComplete(page, entries): boolean
	for _, dino in page.Dinos do
		local row = entries[dino.Id]
		if not row or not row.Found then
			return false
		end
	end
	return true
end

return Index
