-- IndexService.luau
-- Keeps each player's Dino Index up to date, pays page rewards, and decides
-- the Baby roll on hatch (see Config/Index for the rules).
--
-- Saved data:
--   data.Index      { [dinoId] = { [variantId] = true } }
--   data.IndexPages { [rarityId] = true }  pages whose reward was paid
--
-- The client gets the whole index through the IndexSync remote (it's small),
-- plus the IndexPercent and BabyLuck attributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Index = require(ReplicatedStorage.Shared.Config.Index)
local Events = require(script.Parent.Parent.Events)
local Notify = require(script.Parent.Parent.Notify)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local IndexService = {}

local EventService = require(script.Parent.EventService)

local DataService

local rng = Random.new()

local function pagesDone(data): number
	local count = 0
	for _ in data.IndexPages do
		count += 1
	end
	return count
end

-- Baby odds multiplier from completed pages (1 = base odds).
function IndexService.BabyLuck(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	return 1 + pagesDone(data) * Index.BabyLuckPerPage
end

function IndexService.RollBaby(player: Player): boolean
	if RunService:IsStudio() and Balance.Studio.BabyChance > 0 then
		return rng:NextNumber() < Balance.Studio.BabyChance
	end
	return rng:NextNumber()
		< Index.BabyChance * IndexService.BabyLuck(player) * EventService.Multiplier("Baby")
end

local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local count = Index.Count(data.Index)
	player:SetAttribute("IndexCount", count)
	player:SetAttribute("IndexPercent", math.floor(count / Index.TotalEntries * 100))
	player:SetAttribute("BabyLuck", IndexService.BabyLuck(player))
	Remotes.Get("IndexSync"):FireClient(player, data.Index, data.IndexPages)
end

-- Ticks the boxes for a record. Returns the variant ids that were new.
local function register(data, record): { string }
	if not Dinos.ById[record.DinoId] then
		return {}
	end
	local row = data.Index[record.DinoId]
	if not row then
		row = {}
		data.Index[record.DinoId] = row
	end
	local new = {}
	for _, key in Index.KeysFor(record) do
		if not row[key] then
			row[key] = true
			table.insert(new, key)
		end
	end
	return new
end

-- Pays any page that is complete but not yet rewarded.
local function checkPages(player: Player, data, celebrate: boolean)
	for _, page in Index.Pages do
		if not data.IndexPages[page.Rarity] and Index.PageComplete(page, data.Index) then
			data.IndexPages[page.Rarity] = true
			local coins = Index.PageCoins[page.Rarity] or 0
			DataService.AddCoins(player, coins)
			if celebrate then
				Remotes.Get("Celebrate"):FireClient(player, "IndexPage", {
					Rarity = page.Rarity,
					Coins = coins,
					BabyLuck = IndexService.BabyLuck(player),
				})
				Notify.All(
					player.DisplayName .. " completed the " .. page.Rarity .. " page of the Dino Index!",
					"epic"
				)
			end
			Events.Fire("IndexPage", player, page.Rarity)
		end
	end
end

local function variantName(key: string): string
	if key == "Found" then
		return ""
	end
	return key .. " "
end

function IndexService.Init(Services)
	DataService = Services.DataService

	DataService.OnLoaded(function(player, data)
		-- Backfill from dinos you already own (saves from before the Index).
		for _, record in data.Dinos do
			register(data, record)
		end
		checkPages(player, data, false)
		sync(player)
	end)

	Events.On("Hatch", function(player, record)
		local data = DataService.Get(player)
		if not data then
			return
		end
		local new = register(data, record)
		if #new == 0 then
			return
		end
		local dino = Dinos.ById[record.DinoId]
		local name = dino and dino.Name or record.DinoId
		-- One toast per new box (after the hatch reveal has had a moment).
		task.delay(1.5, function()
			for _, key in new do
				local text = if key == "Found"
					then "NEW in your Index: " .. name .. "!"
					else "NEW in your Index: " .. variantName(key) .. name .. "!"
				Notify.Player(player, text, "epic")
			end
		end)
		Events.Fire("IndexNew", player, #new)
		checkPages(player, data, true)
		sync(player)
	end)
end

function IndexService.Start() end

-- Used by the hatch shout so everyone sees how rare Babies are.
function IndexService.BabyOddsText(player: Player): string
	return "1 in " .. FormatNumber(math.floor(1 / (Index.BabyChance * IndexService.BabyLuck(player))))
end

return IndexService
