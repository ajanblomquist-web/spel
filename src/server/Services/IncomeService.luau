-- IncomeService.luau
-- Dinos on pedestals earn coins every second, and some while you're offline.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local IncomeService = {}

local DataService, MonetizationService, NestService
local fractions: { [Player]: number } = {}

-- Income of one dino before pass multipliers.
function IncomeService.BaseIncome(record): number
	local dino = Dinos.ById[record.DinoId]
	local size = Eggs.SizeById[record.Size]
	local mutation = Eggs.MutationById[record.Mutation]
	if not dino then
		return 0
	end
	return dino.Income * (size and size.Multiplier or 1) * (mutation and mutation.Multiplier or 1)
end

-- Coin multiplier from passes.
function IncomeService.Multiplier(player: Player): number
	local mult = 1
	if MonetizationService.Has(player, "DoubleCoins") then
		mult *= Passes.Effects.CoinMultiplier
	end
	if MonetizationService.Has(player, "VIP") then
		mult *= Passes.Effects.VIPCoinMultiplier
	end
	return mult
end

function IncomeService.DinoIncome(player: Player, record): number
	return IncomeService.BaseIncome(record) * IncomeService.Multiplier(player)
end

function IncomeService.Total(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local capacity = NestService.PedestalCapacity(player)
	local total = 0
	for i, record in data.Dinos do
		if i > capacity then
			break
		end
		total += IncomeService.BaseIncome(record)
	end
	return total * IncomeService.Multiplier(player)
end

function IncomeService.Recalc(player: Player)
	player:SetAttribute("IncomePerSec", IncomeService.Total(player))
end

local function payOffline(player: Player, data)
	if data.LastOnline <= 0 then
		return
	end
	local away = math.clamp(os.time() - data.LastOnline, 0, Balance.OfflineCapSeconds)
	local earned = math.floor(IncomeService.Total(player) * Balance.OfflineRate * away)
	if earned >= 1 then
		DataService.AddCoins(player, earned)
		Remotes.Get("OfflineEarned"):FireClient(player, earned, away)
	end
end

function IncomeService.Init(Services)
	DataService = Services.DataService
	MonetizationService = Services.MonetizationService
	NestService = Services.NestService

	DataService.OnLoaded(function(player, data)
		fractions[player] = 0
		IncomeService.Recalc(player)
		payOffline(player, data)
	end)
	DataService.OnRemoving(function(player)
		fractions[player] = nil
	end)
	MonetizationService.OnPassChanged(function(player, key)
		if key == "DoubleCoins" or key == "VIP" or key == "ExtraPedestals" then
			IncomeService.Recalc(player)
		end
	end)
end

function IncomeService.Start()
	while true do
		task.wait(Balance.IncomeTickSeconds)
		for _, player in DataService.LoadedPlayers() do
			local income = (player:GetAttribute("IncomePerSec") or 0) * Balance.IncomeTickSeconds
			if income > 0 then
				-- Keep coins whole numbers; carry the fraction to the next tick.
				local total = income + (fractions[player] or 0)
				local whole = math.floor(total)
				fractions[player] = total - whole
				if whole > 0 then
					DataService.AddCoins(player, whole)
				end
			end
		end
	end
end

return IncomeService
