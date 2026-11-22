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
Balance.StrengthScale = 3 -- distance = (Base + StrengthScale * sqrt(Strength)) * shovel power * timing
-- Timing meter. The needle sweeps 0 -> 1 -> 0; 0.5 is the centre.
--   Perfect (green, thin):  |offset| <= PerfectWindow  -> PerfectMultiplier, builds a streak
--   Great (yellow):         |offset| <= GreatWindow    -> 1.0
--   Miss (red):             falls from MissMultiplier at the yellow edge to WorstTimingMultiplier at the end
Balance.MeterCycleSeconds = 0.9 -- time for the needle to go from one side to the other
Balance.PerfectWindow = 0.05 -- about 90 ms at this speed
Balance.GreatWindow = 0.13
Balance.PerfectMultiplier = 1.3
Balance.MissMultiplier = 0.85
Balance.WorstTimingMultiplier = 0.45 -- stopping at the very edge of the meter
-- Perfect streak: each Perfect in a row adds this much (on top of PerfectMultiplier), up to the cap.
Balance.PerfectStreakBonus = 0.05
Balance.PerfectStreakMax = 5 -- so the 6th Perfect in a row and beyond = 1.3 * 1.25
Balance.MeterTolerance = 0.12 -- how far the client's meter value may differ from the server's estimate
Balance.AutoFlingTiming = 0.43 -- Auto Fling pass always hits this meter value (Great, never Perfect)
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
-- First egg: every new player's first egg is a Rare that hatches fast (the 5-minute wow moment).
Balance.FirstEggRarity = "Rare"
Balance.FirstEggHatchSeconds = 8

-- Boosts (from quests, gifts and the Starter Pack)
Balance.BoostMultiplier = 2

-- Practice thief NPC that walks around the hub carrying an egg anyone can steal.
Balance.ThiefWalkSpeed = 13
Balance.ThiefRespawnSeconds = 40

Balance.Studio = {
	IncubationScale = 0.1, -- eggs hatch 10x faster while testing
	StartingCoins = 0, -- set to e.g. 100000 to test the shop quickly
	GiftTimeScale = 1, -- set to 0.1 to make playtime gifts unlock 10x sooner while testing
}

function Balance.GiftTimeScale(): number
	if RunService:IsStudio() then
		return Balance.Studio.GiftTimeScale
	end
	return 1
end

function Balance.IncubationScale(): number
	if RunService:IsStudio() then
		return Balance.Studio.IncubationScale
	end
	return 1
end

return Balance
