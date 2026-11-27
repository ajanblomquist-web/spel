-- DataService.luau
-- Loads, holds and saves each player's data. Other services read and change
-- data through this module so the leaderboard and player attributes (which the
-- client UI reads) always stay in sync.
--
-- Saving uses ProfileStore (src/server/Vendor): it autosaves, saves on leave
-- and on shutdown, and session-locks each save so a player hopping servers fast
-- can't load the same save twice and duplicate items. If the same save is
-- opened on another server, this server lets go of it and kicks the player.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Index = require(ReplicatedStorage.Shared.Config.Index)
local Notify = require(script.Parent.Parent.Notify)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

local DataService = {}

type Entry = {
	Data: any,
	Profile: any, -- the ProfileStore profile
	RemovingDone: boolean, -- OnRemoving callbacks have run
}

local profiles: { [Player]: Entry } = {}
local loadedCallbacks = {}
local removingCallbacks = {}
local store = nil -- the ProfileStore for player data, made in Start

-- How many developer-product purchase IDs to remember per player. Roblox
-- retries an unfinished purchase within days, so the newest ones are enough.
local KEEP_PURCHASES = 100

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
		Codes = {}, -- { [CODE] = true }, redeemed codes
		PendingEggs = {}, -- bought eggs waiting for a free incubator (same shape as Egg)
		LastOnline = 0,
		Quest = { Index = 1, Progress = 0 }, -- position in Config/Quests
		Boosts = {}, -- { [boostName] = unix time it ends }
		FirstEggDone = false, -- the guaranteed Rare first egg has been given
		ZonesReached = {}, -- { [zoneId] = true }, for NEW ZONE banners
		Purchases = {}, -- { [purchaseId] = true }, so a developer product is never granted twice
		PurchaseOrder = {}, -- purchase IDs oldest first, to forget the oldest past KEEP_PURCHASES
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

local function runRemoving(player: Player)
	local entry = profiles[player]
	if not entry or entry.RemovingDone then
		return
	end
	entry.RemovingDone = true
	for _, callback in removingCallbacks do
		local ok, err = xpcall(callback, debug.traceback, player)
		if not ok then
			warn("[DataService] OnRemoving callback error: " .. tostring(err))
		end
	end
end

local function loadPlayer(player: Player)
	local profile = store:StartSessionAsync(keyFor(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("We couldn't load your save. Please rejoin in a moment!")
		end
		return
	end
	profile:AddUserId(player.UserId) -- lets Roblox data-deletion requests find this save
	local canSave = ProfileStore.DataStoreState == "Access"

	local data = profile.Data
	-- Saves from milestone 1 have no Quest field: those players skip the tutorial.
	local isMilestone1Save = type(data) == "table" and data.Quest == nil
	data = reconcile(data, defaultData())
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
	-- Lava, Frozen and Crystal were removed: those dinos and eggs become Gold,
	-- and their Index boxes (and the old Colossal box) are dropped.
	for _, record in data.Dinos do
		record.Mutation = Eggs.RetiredMutations[record.Mutation] or record.Mutation
	end
	for _, entry in data.Incubating do
		entry.Egg.Mutation = Eggs.RetiredMutations[entry.Egg.Mutation] or entry.Egg.Mutation
	end
	for _, row in data.Index do
		for key in row do
			if not Index.VariantById[key] then
				row[key] = nil
			end
		end
	end

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end

	profiles[player] = { Data = data, Profile = profile, RemovingDone = false }

	-- Right before every save, stamp the time. Right before the last save (leaving,
	-- shutdown, or the save opening elsewhere), let services write their state.
	profile.OnSave:Connect(function()
		data.LastOnline = os.time()
	end)
	profile.OnLastSave:Connect(function()
		runRemoving(player)
	end)
	profile.OnSessionEnd:Connect(function()
		if profiles[player] and profiles[player].Profile == profile then
			profiles[player] = nil
			if player.Parent == Players then
				player:Kick("Your save was opened on another server. Please rejoin!")
			end
		end
	end)

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

local function removePlayer(player: Player)
	local entry = profiles[player]
	if not entry then
		return
	end
	runRemoving(player)
	profiles[player] = nil
	entry.Profile:EndSession() -- saves one last time and releases the session lock
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

-- Saves right away (used after Robux purchases and other big moments).
function DataService.SaveNow(player: Player)
	local entry = profiles[player]
	if entry then
		entry.Profile:Save()
	end
end

-- Remembers a developer-product purchase ID (forgetting the oldest ones).
function DataService.RecordPurchase(player: Player, purchaseId: string)
	local data = DataService.Get(player)
	if not data or data.Purchases[purchaseId] then
		return
	end
	data.Purchases[purchaseId] = true
	table.insert(data.PurchaseOrder, purchaseId)
	while #data.PurchaseOrder > KEEP_PURCHASES do
		data.Purchases[table.remove(data.PurchaseOrder, 1)] = nil
	end
end

-- Saves and waits until the save that reached the DataStore includes this
-- purchase. Returns false if the player left first (Roblox retries later).
function DataService.WaitForPurchaseSaved(player: Player, purchaseId: string): boolean
	local entry = profiles[player]
	if not entry then
		return false
	end
	local profile = entry.Profile
	profile:Save()
	while true do
		if not profile:IsActive() then
			return false
		end
		local saved = profile.LastSavedData
		if saved and saved.Purchases and saved.Purchases[purchaseId] then
			return true
		end
		profile.OnAfterSave:Wait()
	end
end

function DataService.NewId(): string
	return HttpService:GenerateGUID(false)
end

function DataService.Start()
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Balance.AutosaveSeconds)
	store = ProfileStore.New(Balance.DataStoreName, defaultData())

	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	-- Shutdown saving is handled by ProfileStore (OnLastSave runs the OnRemoving
	-- callbacks first).
end

return DataService
