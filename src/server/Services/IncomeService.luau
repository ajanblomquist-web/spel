-- IncomeService.luau
-- Dinos on pedestals earn coins every second, and some while you're offline.
-- Playing with Roblox friends in the same server adds a friend boost
-- (Balance.FriendBoost*); the client shows it from the FriendsInServer attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Index = require(ReplicatedStorage.Shared.Config.Index)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Notify)

local IncomeService = {}

local DataService, MonetizationService, NestService, BoostService
local RebirthService, EventService
local fractions: { [Player]: number } = {}
local friendsOf: { [Player]: { [Player]: boolean } } = {} -- friends in this server

local function friendCount(player: Player): number
	local count = 0
	for other in friendsOf[player] or {} do
		if other.Parent == Players then
			count += 1
		end
	end
	return math.min(count, Balance.FriendBoostMaxFriends)
end

local function publishFriends(player: Player)
	player:SetAttribute("FriendsInServer", friendCount(player))
end

-- Checks who in the server is friends with a player who just joined.
local function checkFriends(player: Player)
	friendsOf[player] = friendsOf[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player and friendsOf[other] then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			local already = friendsOf[player][other] == true
			if ok and isFriend and not already and player.Parent == Players and other.Parent == Players then
				friendsOf[player][other] = true
				friendsOf[other][player] = true
				publishFriends(player)
				publishFriends(other)
				Notify.Player(other, "Your friend " .. player.DisplayName .. " joined: +10% coins!", "good")
				Notify.Player(player, "Playing with " .. other.DisplayName .. ": +10% coins!", "good")
			end
		end
	end
end

-- Income of one dino before pass multipliers.
function IncomeService.BaseIncome(record): number
	local dino = Dinos.ById[record.DinoId]
	local size = Eggs.SizeById[record.Size]
	local mutation = Eggs.MutationById[record.Mutation]
	if not dino then
		return 0
	end
	local baby = if record.Baby then Index.BabyIncomeMultiplier else 1
	return dino.Income * (size and size.Multiplier or 1) * (mutation and mutation.Multiplier or 1) * baby
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
	mult *= BoostService.Multiplier(player, "Coins")
	mult *= RebirthService.Multiplier(player, "Coins")
	mult *= EventService.Multiplier("Coins")
	mult *= 1 + friendCount(player) * Balance.FriendBoostPerFriend
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
	BoostService = Services.BoostService
	RebirthService = Services.RebirthService
	EventService = Services.EventService

	DataService.OnLoaded(function(player, data)
		fractions[player] = 0
		IncomeService.Recalc(player)
		payOffline(player, data) -- before the friend check, so offline pay has no friend boost
		task.spawn(checkFriends, player)
	end)
	DataService.OnRemoving(function(player)
		fractions[player] = nil
		for other in friendsOf[player] or {} do
			if friendsOf[other] then
				friendsOf[other][player] = nil
				publishFriends(other)
			end
		end
		friendsOf[player] = nil
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
			-- Recalculated every tick so boosts starting or ending show up at once.
			IncomeService.Recalc(player)
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
