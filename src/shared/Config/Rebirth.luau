-- Rebirth.luau
-- Rebirth: once you've reached Amber Cliffs you can pay coins to start over
-- (coins, Strength, rock and shovel go back to the start) for permanent
-- bonuses. You keep your dinos, Index, eggs, passes and weapons.

local Rebirth = {}

Rebirth.RequiredZone = "AmberCliffs"
Rebirth.BasePrice = 500000
Rebirth.PriceGrowth = 3 -- each rebirth costs 3x the last

-- Permanent bonuses per rebirth (added up: 2 rebirths = +100% Strength).
Rebirth.StrengthPerRebirth = 0.5
Rebirth.CoinsPerRebirth = 0.25
Rebirth.LuckPerRebirth = 0.1

function Rebirth.Price(rebirths: number): number
	return Rebirth.BasePrice * Rebirth.PriceGrowth ^ rebirths
end

-- Multiplier for "Strength" | "Coins" | "Luck" after this many rebirths.
function Rebirth.Multiplier(rebirths: number, kind: string): number
	local per = if kind == "Strength"
		then Rebirth.StrengthPerRebirth
		elseif kind == "Coins" then Rebirth.CoinsPerRebirth
		elseif kind == "Luck" then Rebirth.LuckPerRebirth
		else 0
	return 1 + rebirths * per
end

return Rebirth
