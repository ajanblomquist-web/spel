-- QuestService.luau
-- Runs the quest chain from Config/Quests. The first quests are the guided
-- tutorial. Progress comes from gameplay Events; the current quest is mirrored
-- to player attributes (QuestText, QuestProgress, QuestTarget, QuestGuide, ...)
-- for the quest card and guide line on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Index = require(ReplicatedStorage.Shared.Config.Index)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Events = require(script.Parent.Parent.Events)

local QuestService = {}

local DataService, BoostService

-- Quests that complete in one go show progress 0/1.
local ONE_SHOT =
	{ RockTier = true, ShovelTier = true, HatchRarity = true, HatchZone = true, IndexPage = true }

local function current(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil, nil
	end
	return Quests[data.Quest.Index], data
end

function QuestService.RewardText(reward): string
	if reward.Coins then
		return "+" .. FormatNumber(reward.Coins) .. " coins"
	elseif reward.Boost then
		return BoostService.Describe(reward.Boost, reward.Seconds)
	end
	return ""
end

local function publish(player: Player)
	local quest, data = current(player)
	if not data then
		return
	end
	if not quest then
		player:SetAttribute("QuestText", "All quests done! More coming soon.")
		player:SetAttribute("QuestProgress", 1)
		player:SetAttribute("QuestTarget", 1)
		player:SetAttribute("QuestGuide", nil)
		player:SetAttribute("QuestReward", nil)
		player:SetAttribute("QuestTutorial", false)
		return
	end
	local target = if ONE_SHOT[quest.Type] then 1 else quest.Target
	if quest.Type == "IndexCount" then
		data.Quest.Progress = math.min(Index.Count(data.Index), target) -- boxes you already have count
	end
	player:SetAttribute("QuestIndex", data.Quest.Index)
	player:SetAttribute("QuestText", quest.Text)
	player:SetAttribute("QuestProgress", math.min(data.Quest.Progress, target))
	player:SetAttribute("QuestTarget", target)
	player:SetAttribute("QuestUnit", if quest.Type == "Distance" then "m" else "")
	player:SetAttribute("QuestGuide", quest.Guide)
	player:SetAttribute("QuestReward", QuestService.RewardText(quest.Reward))
	player:SetAttribute("QuestTutorial", quest.Tutorial == true)
end

local checkInstant -- defined below

local function complete(player: Player)
	local quest, data = current(player)
	if not quest or not data then
		return
	end
	local reward = quest.Reward
	if reward.Coins then
		DataService.AddCoins(player, reward.Coins)
	elseif reward.Boost then
		BoostService.Add(player, reward.Boost, reward.Seconds)
	end
	local finishedTutorial = quest.Tutorial and not (Quests[data.Quest.Index + 1] or {}).Tutorial
	Remotes.Get("Celebrate"):FireClient(player, "Quest", {
		Text = quest.Text,
		Reward = QuestService.RewardText(reward),
		TutorialDone = finishedTutorial,
	})
	data.Quest.Index += 1
	data.Quest.Progress = 0
	publish(player)
	checkInstant(player)
end

local function addProgress(player: Player, questType: string, amount: number)
	local quest, data = current(player)
	if not quest or quest.Type ~= questType then
		return
	end
	data.Quest.Progress += amount
	if data.Quest.Progress >= quest.Target then
		complete(player)
	else
		publish(player)
	end
end

-- Quests about something you may already have (an upgrade) finish right away.
local function alreadyDone(quest, data): boolean
	return (quest.Type == "RockTier" and data.RockTier >= quest.Target)
		or (quest.Type == "ShovelTier" and data.ShovelTier >= quest.Target)
		or (quest.Type == "Distance" and data.Stats.BestDistance >= quest.Target)
		or (quest.Type == "IndexCount" and Index.Count(data.Index) >= quest.Target)
		or (quest.Type == "IndexPage" and data.IndexPages[quest.Target] == true)
end

checkInstant = function(player: Player)
	local quest, data = current(player)
	if not quest or not alreadyDone(quest, data) then
		return
	end
	-- A short gap so two celebrations don't overlap. Re-check in case it was
	-- already completed in the meantime.
	task.delay(1.5, function()
		local now, nowData = current(player)
		if now == quest and alreadyDone(now, nowData) then
			complete(player)
		end
	end)
end

function QuestService.Init(Services)
	DataService = Services.DataService
	BoostService = Services.BoostService

	DataService.OnLoaded(function(player)
		publish(player)
		checkInstant(player)
	end)

	Events.On("TrainRep", function(player)
		addProgress(player, "Reps", 1)
	end)
	Events.On("Fling", function(player, distance, _zoneId, grade)
		addProgress(player, "Fling", 1)
		if grade == "Perfect" then
			addProgress(player, "Perfect", 1)
		end
		local quest, data = current(player)
		if quest and quest.Type == "Distance" then
			if distance >= quest.Target then
				complete(player)
			elseif distance > data.Quest.Progress then
				data.Quest.Progress = math.floor(distance)
				publish(player)
			end
		end
	end)
	Events.On("Dig", function(player)
		addProgress(player, "Dig", 1)
	end)
	Events.On("Deliver", function(player)
		addProgress(player, "Deliver", 1)
	end)
	Events.On("Hatch", function(player, record)
		addProgress(player, "Hatch", 1)
		local quest = current(player)
		if not quest then
			return
		end
		if quest.Type == "HatchRarity" then
			if Eggs.RarityById[record.Rarity].Order >= Eggs.RarityById[quest.Target].Order then
				complete(player)
			end
		elseif quest.Type == "HatchZone" and record.Zone == quest.Target then
			complete(player)
		end
	end)
	Events.On("IndexNew", function(player)
		local quest = current(player)
		if quest and quest.Type == "IndexCount" then
			publish(player)
			checkInstant(player)
		end
	end)
	Events.On("IndexPage", function(player)
		checkInstant(player)
	end)
	Events.On("Steal", function(player)
		addProgress(player, "Steal", 1)
	end)
	Events.On("LockNest", function(player)
		addProgress(player, "LockNest", 1)
	end)
	Events.On("Buy", function(player)
		checkInstant(player)
	end)
end

return QuestService
