-- DataService.luau
-- Loads, holds and saves each player's data. Other services read and change
-- data through this module so the leaderboard and player attributes (which the
-- client UI reads) always stay in sync.
--
-- Saving uses DataStoreService directly with retries, autosave and a save on
-- shutdown. Before a public launch, swap this for ProfileStore to get session
-- locking (stops item duplication if a player hops servers very fast).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Notify = require(script.Parent.Parent.Notify)

local DataService = {}

type Profile = {
	Data: any,
	CanSave: boolean,
}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks = {}
local removingCallbacks = {}
local store: DataStore? = nil

-- Fields that are mirrored onto the Player as attributes for the client UI.
local REPLICATED = { "Coins", "Strength", "RockTier", "ShovelTier", "Rebirths" }
-- Fields shown on the leaderboard.
local LEADERSTATS = { "Coins", "Strength", "Steals", "Rebirths" }

local function defaultData()
	return {
		Version = 1,
		Coins = if RunService:IsStudio() then Balance.Studio.StartingCoins else 0,
		Strength = 0,
		RockTier = 1,
		ShovelTier = 1,
		Steals = 0, -- eggs stolen from other players (shown on the leaderboard)
		Dinos = {}, -- { { Id, DinoId, Rarity, Size, Mutation, Zone, Baby } }, one per pedestal
		Incubating = {}, -- { { Egg = { Id, Rarity, Size, Mutation }, ReadyAt = unix time } }
		LastOnline = 0,
		Quest = { Index = 1, Progress = 0 }, -- position in Config/Quests
		Boosts = {}, -- { [boostName] = unix time it ends }
		FirstEggDone = false, -- the guaranteed Rare first egg has been given
		ZonesReached = {}, -- { [zoneId] = true }, for NEW ZONE banners
		Purchases = {}, -- { [purchaseId] = true }, so a developer product is never granted twice
		StarterPackBought = false,
		StarterOfferShown = false,
		Index = {}, -- Dino Index: { [dinoId] = { [variantId] = true } }
		IndexPages = {}, -- { [rarityId] = true }, Index pages whose reward was paid
		Weekly = { Week = 0, Steals = 0, EggsDug = 0 }, -- weekly leaderboard counters
		Weapons = { Owned = {}, Equipped = "Stick" }, -- bonk weapons (+ Skin = skinId)
		GroupRewardClaimed = false, -- the one-time reward for joining the group
		Rebirths = 0,
		Daily = { Streak = 0, LastDay = 0 }, -- login streak; LastDay = UTC day number of the last claim
		Stats = {
			Flings = 0,
			BestDistance = 0,
			EggsDug = 0,
			EggsStolen = 0,
			DinosHatched = 0,
		},
	}
end

-- Adds any keys that are missing from saved data (e.g. after we add a new field).
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function withRetries(label: string, fn: () -> any, attempts: number?): (boolean, any)
	local maxAttempts = attempts or 3
	local ok, result
	for attempt = 1, maxAttempts do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[DataService] %s failed (attempt %d): %s", label, attempt, tostring(result)))
		if attempt < maxAttempts then
			task.wait(2 ^ attempt)
		end
	end
	return false, result
end

local function setupLeaderstats(player: Player, data)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, field in LEADERSTATS do
		local value = Instance.new("NumberValue")
		value.Name = field
		value.Value = data[field]
		value.Parent = folder
	end
	folder.Parent = player
end

local function replicate(player: Player, field: string, value: any)
	if table.find(REPLICATED, field) then
		player:SetAttribute(field, value)
	end
	if table.find(LEADERSTATS, field) then
		local stats = player:FindFirstChild("leaderstats")
		local stat = stats and stats:FindFirstChild(field)
		if stat then
			(stat :: NumberValue).Value = value
		end
	end
end

local function loadPlayer(player: Player)
	local data
	local canSave = true

	if store then
		local ok, result = withRetries("Load " .. player.Name, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end, if RunService:IsStudio() then 1 else 3)
		if ok then
			data = result
		elseif RunService:IsStudio() then
			canSave = false
			warn("[DataService] Could not load data in Studio. Playing with fresh data that won't save.")
		else
			player:Kick("We couldn't load your save. Please rejoin in a moment!")
			return
		end
	else
		canSave = false
	end

	-- Saves from milestone 1 have no Quest field: those players skip the tutorial.
	local isMilestone1Save = type(data) == "table" and data.Quest == nil
	data = reconcile(if type(data) == "table" then data else defaultData(), defaultData())
	if isMilestone1Save and data.Stats.EggsDug > 0 then
		data.FirstEggDone = true
		data.Quest.Index = 6
	end
	-- The "Tiny" size was renamed to "Small".
	for _, record in data.Dinos do
		if record.Size == "Tiny" then
			record.Size = "Small"
		end
	end
	for _, entry in data.Incubating do
		if entry.Egg.Size == "Tiny" then
			entry.Egg.Size = "Small"
		end
	end

	if player.Parent == nil then
		return -- left while loading
	end

	profiles[player] = { Data = data, CanSave = canSave }

	setupLeaderstats(player, data)
	for _, field in REPLICATED do
		player:SetAttribute(field, data[field])
	end

	-- Run the other services' setup in order. Each one is protected so one
	-- bug can't stop the rest from loading.
	for _, callback in loadedCallbacks do
		local ok, err = xpcall(callback, debug.traceback, player, data)
		if not ok then
			warn("[DataService] OnLoaded callback error: " .. tostring(err))
		end
	end

	player:SetAttribute("Loaded", true)

	if not canSave then
		task.delay(3, function()
			Notify.Player(
				player,
				"Saving is OFF. In Studio: Game Settings > Security > Enable Studio Access to API Services.",
				"bad"
			)
		end)
	end
end

local function savePlayer(player: Player)
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return
	end
	profile.Data.LastOnline = os.time()
	local data = profile.Data
	withRetries("Save " .. player.Name, function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
end

local function removePlayer(player: Player)
	if not profiles[player] then
		return
	end
	for _, callback in removingCallbacks do
		local ok, err = xpcall(callback, debug.traceback, player)
		if not ok then
			warn("[DataService] OnRemoving callback error: " .. tostring(err))
		end
	end
	savePlayer(player)
	profiles[player] = nil
end

-- Public API -----------------------------------------------------------------

-- callback(player, data) runs once a player's data is ready, in the order
-- services registered (services register in Init, which follows server load order).
function DataService.OnLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
end

-- callback(player) runs just before a leaving player's data is saved.
function DataService.OnRemoving(callback: (Player) -> ())
	table.insert(removingCallbacks, callback)
end

function DataService.Get(player: Player): any
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.LoadedPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

function DataService.Set(player: Player, field: string, value: any)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data[field] = value
	replicate(player, field, value)
end

function DataService.Increment(player: Player, field: string, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	DataService.Set(player, field, data[field] + amount)
end

function DataService.AddCoins(player: Player, amount: number)
	DataService.Increment(player, "Coins", amount)
end

-- Returns true and takes the coins if the player can afford it.
function DataService.SpendCoins(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or data.Coins < amount then
		return false
	end
	DataService.Set(player, "Coins", data.Coins - amount)
	return true
end

-- Saves right away (used after Robux purchases).
function DataService.SaveNow(player: Player)
	task.spawn(savePlayer, player)
end

function DataService.NewId(): string
	return HttpService:GenerateGUID(false)
end

function DataService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Balance.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable: " .. tostring(result))
	end

	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(Balance.AutosaveSeconds)
			for player in profiles do
				task.spawn(savePlayer, player)
			end
		end
	end)

	-- Save everyone when the server shuts down.
	game:BindToClose(function()
		local remaining = 0
		for player in profiles do
			remaining += 1
			task.spawn(function()
				removePlayer(player)
				remaining -= 1
			end)
		end
		local started = os.clock()
		while remaining > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
