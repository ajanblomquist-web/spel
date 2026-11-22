-- Balance.luau
-- Every tuning number for the core loop lives here, so you can tweak the game
-- without hunting through scripts. Change a value, save, and Rojo syncs it.

local RunService = game:GetService("RunService")

local Balance = {}

-- Movement
Balance.WalkSpeed = 24
Balance.CarrySpeedMultiplier = 0.75 -- carrying an egg makes you slower

-- Training
Balance.TrainCooldown = 0.3 -- seconds between reps (server enforced)
Balance.TrainRange = 14 -- studs from the training rock

-- Fling
Balance.FlingRange = 14 -- studs from the launch pad
Balance.FlingCooldown = 1.5
Balance.BaseDistance = 30 -- studs a brand-new player flings with a perfect-ish hit
Balance.StrengthScale = 6 -- distance = (Base + StrengthScale * sqrt(Strength)) * shovel power * timing
Balance.MeterCycleSeconds = 0.9 -- time for the needle to go from one side to the other
Balance.PerfectWindow = 0.08 -- how far from the centre (0.5) still counts as Perfect
Balance.PerfectMultiplier = 1.25
Balance.WorstTimingMultiplier = 0.6 -- stopping at the very edge of the meter
Balance.MeterTolerance = 0.25 -- how far the client's meter value may differ from the server's estimate
Balance.AutoFlingTiming = 0.42 -- Auto Fling pass always hits this meter value (good, not perfect)
Balance.FlightSeconds = 2.2 -- how long the shovel is in the air
Balance.DigSpotLifetime = 90 -- seconds before an un-dug spot disappears

-- Stealing
Balance.StealRange = 9
Balance.StealHoldSeconds = 0.6
Balance.StealProtectSeconds = 5 -- after stealing, you can't be stolen from for this long
Balance.NestStealHoldSeconds = 1.5 -- holding "Steal egg" on an egg in someone's incubator
Balance.NestStealRange = 9
Balance.NestLockSeconds = 60 -- free nest lock: nobody can steal from your incubators
Balance.NestLockCooldown = 60 -- wait this long after a lock ends before locking again

-- Base
Balance.BasePedestals = 4
Balance.IncubatorSlots = 3
Balance.DeliveryRadius = 20 -- studs from your plot centre that counts as "home"
Balance.SellSeconds = 120 -- selling a dino pays this many seconds of its income

-- Income
Balance.IncomeTickSeconds = 1
Balance.OfflineRate = 0.5 -- dinos earn 50% while you are offline
Balance.OfflineCapSeconds = 8 * 60 * 60 -- offline income stops after 8 hours

-- Saving
Balance.AutosaveSeconds = 60
Balance.DataStoreName = "PlayerData_v1"

-- Studio testing helpers. These only apply when you press Play in Studio,
-- never in a published game.
Balance.Studio = {
	IncubationScale = 0.1, -- eggs hatch 10x faster while testing
	StartingCoins = 0, -- set to e.g. 100000 to test the shop quickly
}

function Balance.IncubationScale(): number
	if RunService:IsStudio() then
		return Balance.Studio.IncubationScale
	end
	return 1
end

return Balance
