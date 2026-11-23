-- GiftService.luau
-- Playtime gifts (Config/Gifts): claim them in order as you keep playing.
-- The client shows a countdown from SessionStartServer and NextGift.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Gifts = require(ReplicatedStorage.Shared.Config.Gifts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Notify)

local GiftService = {}

local DataService, BoostService, NestService

local sessionStart: { [Player]: number } = {}
local nextGift: { [Player]: number } = {}

function GiftService.Grant(player: Player, reward): string
	if reward.Boost then
		BoostService.Add(player, reward.Boost, reward.Seconds)
		return BoostService.Describe(reward.Boost, reward.Seconds)
	elseif reward.Egg then
		local egg = {
			Id = DataService.NewId(),
			Rarity = reward.Egg,
			Size = "Normal",
			Mutation = "None",
		}
		if NestService.TryAddEgg(player, egg) then
			return "a " .. reward.Egg .. " egg (it's in your incubator!)"
		end
		local coins = math.max(2000, math.floor((player:GetAttribute("IncomePerSec") or 0) * 300))
		DataService.AddCoins(player, coins)
		return FormatNumber(coins) .. " coins (your incubators were full)"
	else
		local income = player:GetAttribute("IncomePerSec") or 0
		local coins = math.max(reward.MinCoins or 0, math.floor(income * (reward.IncomeSeconds or 0)))
		DataService.AddCoins(player, coins)
		return FormatNumber(coins) .. " coins"
	end
end

local function claim(player: Player)
	local index = nextGift[player]
	local gift = index and Gifts[index]
	if not gift or not sessionStart[player] then
		return
	end
	local needed = gift.Minutes * 60 * Balance.GiftTimeScale()
	if os.clock() - sessionStart[player] < needed - 1 then
		return
	end
	nextGift[player] = index + 1
	player:SetAttribute("NextGift", index + 1)
	local text = GiftService.Grant(player, gift.Reward)
	Remotes.Get("Celebrate"):FireClient(player, "Gift", { Text = "Gift: " .. text })
	Notify.Player(player, "Gift opened: " .. text, "good")
end

function GiftService.Init(Services)
	DataService = Services.DataService
	BoostService = Services.BoostService
	NestService = Services.NestService

	DataService.OnLoaded(function(player)
		sessionStart[player] = os.clock()
		nextGift[player] = 1
		player:SetAttribute("SessionStartServer", Workspace:GetServerTimeNow())
		player:SetAttribute("GiftTimeScale", Balance.GiftTimeScale())
		player:SetAttribute("NextGift", 1)
	end)
end

function GiftService.Start()
	Remotes.Get("ClaimGift").OnServerEvent:Connect(claim)
	Players.PlayerRemoving:Connect(function(player)
		sessionStart[player] = nil
		nextGift[player] = nil
	end)
end

return GiftService
