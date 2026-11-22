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

-- Distance multiplier for a meter value, and whether it was a Perfect hit.
function Meter.TimingMultiplier(value: number): (number, boolean)
	local offCentre = math.abs(value - 0.5)
	if offCentre <= Balance.PerfectWindow then
		return Balance.PerfectMultiplier, true
	end
	-- 1.0 just outside the Perfect window, falling to WorstTimingMultiplier at the edge.
	local t = (offCentre - Balance.PerfectWindow) / (0.5 - Balance.PerfectWindow)
	local mult = 1 - t * (1 - Balance.WorstTimingMultiplier)
	return mult, false
end

return Meter
