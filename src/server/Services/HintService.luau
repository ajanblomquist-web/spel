-- HintService.luau
-- Pass hints at the moment a pass would help, and the one-time group reward.
-- Rules (see Config/Social): never during the tutorial, at most one hint every
-- few minutes, each hint once per session, never for something you own.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Social = require(ReplicatedStorage.Shared.Config.Social)
local Events = require(script.Parent.Parent.Events)
local Notify = require(script.Parent.Parent.Notify)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local HintService = {}

local DataService, MonetizationService, IncomeService, BoostService

type Session =
	{ Shown: { [string]: boolean }, LastHint: number, Reps: number, Flings: number, Commons: number }
local sessions: { [Player]: Session } = {}
local lastGroupCheck: { [Player]: number } = {}

local function inGroup(player: Player): boolean
	if Social.GroupId == 0 then
		return false
	end
	-- GetGroupsAsync isn't cached, so it sees a join that just happened.
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if not ok then
		return player:GetAttribute("InGroup") == true
	end
	for _, group in groups do
		if group.Id == Social.GroupId then
			return true
		end
	end
	return false
end

-- Gives the one-time reward the first time we see the player in the group.
local function checkGroup(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local member = inGroup(player)
	player:SetAttribute("InGroup", member)
	player:SetAttribute("GroupRewardClaimed", data.GroupRewardClaimed == true)
	if not member or data.GroupRewardClaimed then
		return
	end
	data.GroupRewardClaimed = true
	player:SetAttribute("GroupRewardClaimed", true)
	local reward = Social.GroupReward
	local coins = math.max(reward.MinCoins, math.floor(IncomeService.Total(player) * reward.IncomeSeconds))
	DataService.AddCoins(player, coins)
	BoostService.Add(player, "Luck", reward.BoostSeconds)
	DataService.SaveNow(player)
	Notify.Player(
		player,
		"Thanks for joining the group! +" .. FormatNumber(coins) .. " coins and 2x Luck!",
		"epic"
	)
end

-- Shows a hint if the rules allow it.
function HintService.Try(player: Player, key: string)
	local session = sessions[player]
	local hint = Social.Hints[key]
	if not session or not hint or session.Shown[key] then
		return
	end
	if player:GetAttribute("QuestTutorial") then
		return
	end
	if os.clock() - session.LastHint < Social.HintGapSeconds then
		return
	end
	if hint.Pass == "Group" then
		if
			Social.GroupId == 0
			or player:GetAttribute("InGroup")
			or player:GetAttribute("GroupRewardClaimed")
		then
			return
		end
	elseif MonetizationService.Has(player, hint.Pass) then
		return
	end
	session.Shown[key] = true
	session.LastHint = os.clock()
	Remotes.Get("Hint"):FireClient(player, hint.Text, hint.Pass)
end

function HintService.Init(Services)
	DataService = Services.DataService
	MonetizationService = Services.MonetizationService
	IncomeService = Services.IncomeService
	BoostService = Services.BoostService

	DataService.OnLoaded(function(player)
		-- Start as if a hint was just shown, so the first one waits a few minutes.
		sessions[player] = {
			Shown = {},
			LastHint = os.clock() - Social.HintGapSeconds / 2,
			Reps = 0,
			Flings = 0,
			Commons = 0,
		}
		task.spawn(checkGroup, player)
		player:GetAttributeChangedSignal("PedestalsFull"):Connect(function()
			if player:GetAttribute("PedestalsFull") then
				HintService.Try(player, "PedestalsFull")
			end
		end)
		player:GetAttributeChangedSignal("QuestTutorial"):Connect(function()
			if player:GetAttribute("QuestTutorial") == false then
				task.delay(Social.GroupHintDelay, function()
					if player.Parent == Players then
						HintService.Try(player, "Group")
					end
				end)
			end
		end)
	end)
	DataService.OnRemoving(function(player)
		sessions[player] = nil
		lastGroupCheck[player] = nil
	end)

	Events.On("IncubatorsFull", function(player)
		HintService.Try(player, "IncubatorsFull")
	end)
	Events.On("StolenFrom", function(player, where)
		HintService.Try(player, if where == "Nest" then "NestRobbed" else "CarryRobbed")
	end)
	Events.On("TrainRep", function(player)
		local session = sessions[player]
		if session then
			session.Reps += 1
			if session.Reps >= Social.TrainingRepsForHint then
				HintService.Try(player, "LotsOfTraining")
			end
		end
	end)
	Events.On("Fling", function(player)
		local session = sessions[player]
		if session then
			session.Flings += 1
			if session.Flings >= Social.FlingsForHint then
				HintService.Try(player, "LotsOfFlings")
			end
		end
	end)
	Events.On("Dig", function(player, egg)
		local session = sessions[player]
		if session and egg.Rarity == "Common" then
			session.Commons += 1
			if session.Commons >= Social.CommonsForHint then
				HintService.Try(player, "ManyCommons")
			end
		end
	end)
end

function HintService.Start()
	-- The client asks for a re-check after the join-group prompt closes.
	Remotes.Get("GroupCheck").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastGroupCheck[player] and now - lastGroupCheck[player] < 10 then
			return
		end
		lastGroupCheck[player] = now
		checkGroup(player)
	end)
end

return HintService
