-- WeightedRandom.luau
-- Picks one entry from a list of tables that each have a Weight.
-- An optional weightFn lets the caller adjust weights (used for luck).

local WeightedRandom = {}

function WeightedRandom.Pick<T>(list: { T }, rng: Random, weightFn: ((T) -> number)?): T
	local total = 0
	local weights = table.create(#list)
	for i, entry in list do
		local w = if weightFn then weightFn(entry) else (entry :: any).Weight
		w = math.max(w, 0)
		weights[i] = w
		total += w
	end

	local roll = rng:NextNumber() * total
	for i, entry in list do
		roll -= weights[i]
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

return WeightedRandom
