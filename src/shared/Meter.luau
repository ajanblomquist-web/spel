-- Meter.luau
-- The fling timing meter, shared so the client draws exactly what the server
-- checks. The needle bounces 0 -> 1 -> 0 ... ; 0.5 is the centre (Perfect).

local Balance = require(script.Parent.Config.Balance)

local Meter = {}

-- Needle position (0..1) after `elapsed` seconds.
function Meter.ValueAt(elapsed: number): number
	local phase = (elapsed / Balance.MeterCycleSeconds) % 2
	if phase > 1 then
		phase = 2 - phase
	end
	return phase
end

-- Distance multiplier for a meter value, and its grade: "Perfect" | "Great" | "Miss".
-- (Perfect streak bonus is added by the server on top of this.)
function Meter.TimingMultiplier(value: number): (number, string)
	local offCentre = math.abs(value - 0.5)
	if offCentre <= Balance.PerfectWindow then
		return Balance.PerfectMultiplier, "Perfect"
	elseif offCentre <= Balance.GreatWindow then
		return 1, "Great"
	end
	-- MissMultiplier just outside yellow, falling to WorstTimingMultiplier at the edge.
	local t = (offCentre - Balance.GreatWindow) / (0.5 - Balance.GreatWindow)
	local mult = Balance.MissMultiplier - t * (Balance.MissMultiplier - Balance.WorstTimingMultiplier)
	return mult, "Miss"
end

return Meter
