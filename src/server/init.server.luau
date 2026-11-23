-- Server entry point. Loads every service, runs Init on all of them (so they can
-- find each other), then Start on all of them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.Setup()

local ORDER = {
	"DataService",
	"MonetizationService",
	"BoostService",
	"MapService",
	"MovementService",
	"NestService",
	"IncomeService",
	"TrainingService",
	"CarryService",
	"FlingService",
	"ShopService",
	"QuestService",
	"IndexService",
	"LeaderboardService",
	"GiftService",
	"StarterPackService",
	"ProductService",
	"CodeService",
	"NpcService",
	"WeaponService",
	"HintService",
	"RebirthService",
	"DailyService",
	"EventService",
}

local Services = {}
for _, name in ORDER do
	Services[name] = require(script.Services[name])
end

for _, name in ORDER do
	local service = Services[name]
	if service.Init then
		service.Init(Services)
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print("[Fling for Fossils] server started")
