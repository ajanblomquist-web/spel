-- NestService.luau
-- Your base: incubators where delivered eggs hatch, and pedestals where
-- hatched dinos stand and earn coins. Dinos can be sold to free a pedestal.
--
-- Incubating eggs keep their timers while you're offline (ReadyAt is a real
-- clock time), so you come back to hatched dinos.
--
-- PvP: other players can hold "Steal egg" on an egg in your incubator and run
-- off with it. The free counter is the nest lock (button shows when you're at
-- home): 60 s of protection, then a cooldown. Fortress Gate makes it 3 min.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local EggRoll = require(script.Parent.Parent.EggRoll)
local Notify = require(script.Parent.Parent.Notify)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Visuals = require(script.Parent.Parent.Visuals)
local Events = require(script.Parent.Parent.Events)

local NestService = {}

local DataService, MapService, MonetizationService, IncomeService, CarryService, IndexService

-- Nest locks, by os.clock() time.
local lockedUntil: { [Player]: number } = {}
local lockReadyAt: { [Player]: number } = {}
local barriers: { [Player]: BasePart } = {}
local lastStealWarning: { [Player]: number } = {}

-- [player] = { Eggs = { Instance }, Dinos = { Instance } }
local spawned: { [Player]: { Eggs: { Instance }, Dinos: { Instance } } } = {}

local ANNOUNCE_FROM = Eggs.RarityById.Legendary.Order -- server-wide shout for Legendary and up

local function clearList(list: { Instance })
	for _, instance in list do
		instance:Destroy()
	end
	table.clear(list)
end

local function visualsFor(player: Player)
	spawned[player] = spawned[player] or { Eggs = {}, Dinos = {} }
	return spawned[player]
end

function NestService.PedestalCapacity(player: Player): number
	local extra = if MonetizationService.Has(player, "ExtraPedestals")
		then Passes.Effects.ExtraPedestals
		else 0
	return Balance.BasePedestals + extra
end

function NestService.IsLocked(player: Player): boolean
	return lockedUntil[player] ~= nil and os.clock() < lockedUntil[player]
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local stealFromNest -- defined below

function NestService.RenderIncubators(player: Player)
	local data = DataService.Get(player)
	local plot = MapService.GetPlot(player)
	if not data or not plot then
		return
	end
	local list = visualsFor(player).Eggs
	clearList(list)

	for i, entry in data.Incubating do
		local nest = plot.Incubators[i]
		if not nest then
			break
		end
		local egg = Visuals.Egg(entry.Egg)
		egg.Anchored = true
		egg.CFrame = CFrame.new(nest.Position + Vector3.new(0, 0.5 + egg.Size.Y / 2, 0))
		local rarity = Eggs.RarityById[entry.Egg.Rarity]
		local label = Visuals.Billboard(egg, {
			{ Text = string.upper(entry.Egg.Rarity) .. " EGG", Color = rarity.Color },
			{ Text = "" },
		}, Vector2.new(6, 2.4), 3, 80)
		-- The client counts down using this (server clock, so it matches for everyone).
		label:SetAttribute("ReadyAtServer", Workspace:GetServerTimeNow() + (entry.ReadyAt - os.time()))

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealNestPrompt"
		prompt.ActionText = "Steal egg"
		prompt.ObjectText = player.DisplayName .. "'s " .. entry.Egg.Rarity .. " egg"
		prompt.HoldDuration = Balance.NestStealHoldSeconds
		prompt.MaxActivationDistance = Balance.NestStealRange
		prompt.RequiresLineOfSight = false
		prompt.Enabled = not NestService.IsLocked(player)
		prompt:SetAttribute("NotForUserId", player.UserId) -- the owner's client hides it
		local eggId = entry.Egg.Id
		prompt.PromptButtonHoldBegan:Connect(function(thief)
			-- Warn the owner so they can rush home and defend.
			local now = os.clock()
			if thief ~= player and (not lastStealWarning[player] or now - lastStealWarning[player] > 5) then
				lastStealWarning[player] = now
				Notify.Player(player, thief.DisplayName .. " is stealing from your nest! Lock it!", "bad")
			end
		end)
		prompt.Triggered:Connect(function(thief)
			stealFromNest(player, thief, eggId)
		end)
		prompt.Parent = egg

		egg.Parent = plot.Model
		table.insert(list, egg)
	end
end

stealFromNest = function(owner: Player, thief: Player, eggId: string)
	if thief == owner or not DataService.IsLoaded(thief) or NestService.IsLocked(owner) then
		return
	end
	if CarryService.IsCarrying(thief) then
		Notify.Player(thief, "Your hands are full! Take your egg home first.", "bad")
		return
	end
	local data = DataService.Get(owner)
	local plot = MapService.GetPlot(owner)
	local root = rootOf(thief)
	if not data or not plot or not root then
		return
	end
	if (root.Position - plot.Center).Magnitude > 40 then
		return
	end
	for i, entry in data.Incubating do
		if entry.Egg.Id == eggId then
			table.remove(data.Incubating, i)
			if not CarryService.StartCarry(thief, entry.Egg, Balance.StealProtectSeconds) then
				table.insert(data.Incubating, i, entry) -- put it back if something went wrong
				return
			end
			NestService.RenderIncubators(owner)
			DataService.Increment(thief, "Steals", 1)
			Events.Fire("Steal", thief, entry.Egg, false)
			Notify.Player(
				owner,
				thief.DisplayName .. " stole a " .. entry.Egg.Rarity .. " egg from your nest!",
				"bad"
			)
			Notify.Player(thief, "You stole a " .. entry.Egg.Rarity .. " egg! Run home!", "good")
			Events.Fire("StolenFrom", owner, "Nest")
			return
		end
	end
end

local function setBarrier(player: Player, on: boolean)
	if barriers[player] then
		barriers[player]:Destroy()
		barriers[player] = nil
	end
	local plot = MapService.GetPlot(player)
	if on and plot then
		local barrier = Visuals.Part({
			Name = "NestLock",
			Size = Vector3.new(38, 12, 38),
			Position = plot.Center + Vector3.new(0, 6, 0),
			Color = Color3.fromRGB(90, 170, 255),
			Material = Enum.Material.ForceField,
			Transparency = 0.3,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		barrier.Parent = plot.Model
		barriers[player] = barrier
	end
end

local function lockNest(player: Player)
	local root = rootOf(player)
	if not DataService.IsLoaded(player) or not root or not MapService.IsHome(player, root.Position) then
		return
	end
	local now = os.clock()
	if NestService.IsLocked(player) or (lockReadyAt[player] and now < lockReadyAt[player]) then
		return
	end
	local duration = if MonetizationService.Has(player, "FortressGate")
		then Passes.Effects.FortressLockSeconds
		else Balance.NestLockSeconds
	local untilTime = now + duration
	lockedUntil[player] = untilTime
	lockReadyAt[player] = untilTime + Balance.NestLockCooldown
	local serverNow = Workspace:GetServerTimeNow()
	player:SetAttribute("NestLockedUntil", serverNow + duration)
	player:SetAttribute("NestLockReadyAt", serverNow + duration + Balance.NestLockCooldown)
	setBarrier(player, true)
	NestService.RenderIncubators(player)
	Notify.Player(player, "Nest locked for " .. duration .. " seconds!", "good")
	Events.Fire("LockNest", player)

	task.delay(duration, function()
		if lockedUntil[player] == untilTime and player.Parent == Players then
			lockedUntil[player] = nil
			setBarrier(player, false)
			NestService.RenderIncubators(player)
			Notify.Player(player, "Your nest lock wore off!", "bad")
		end
	end)
end

local function sellDino(player: Player, dinoId: string)
	local data = DataService.Get(player)
	if not data then
		return
	end
	for i, record in data.Dinos do
		if record.Id == dinoId then
			local value = math.floor(IncomeService.DinoIncome(player, record) * Balance.SellSeconds)
			table.remove(data.Dinos, i)
			DataService.AddCoins(player, value)
			Notify.Player(
				player,
				"Sold " .. Visuals.DinoDisplayName(record) .. " for " .. FormatNumber(value) .. " coins",
				"good"
			)
			NestService.RenderPedestals(player)
			IncomeService.Recalc(player)
			return
		end
	end
end

function NestService.RenderPedestals(player: Player)
	local data = DataService.Get(player)
	local plot = MapService.GetPlot(player)
	if not data or not plot then
		return
	end
	local capacity = NestService.PedestalCapacity(player)
	MapService.SetPedestalCount(plot, capacity)

	local list = visualsFor(player).Dinos
	clearList(list)

	for i, record in data.Dinos do
		local pedestal = plot.Pedestals[i]
		if i > capacity or not pedestal then
			break
		end
		local income = IncomeService.DinoIncome(player, record)
		local model = Visuals.Dino(record, income)

		-- Stand it on the pedestal, facing the front of the plot.
		local boxCFrame, boxSize = model:GetBoundingBox()
		local pivotAboveBottom = model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
		local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
		model:PivotTo(CFrame.new(top + Vector3.new(0, pivotAboveBottom, 0)) * CFrame.Angles(0, math.pi, 0))

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SellPrompt"
		prompt.ActionText = "Sell"
		prompt.ObjectText = Visuals.DinoDisplayName(record)
			.. " ("
			.. FormatNumber(math.floor(income * Balance.SellSeconds))
			.. ")"
		prompt.HoldDuration = 1.2
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("OwnerOnly", player.UserId) -- client hides it for everyone else
		prompt.Parent = model.PrimaryPart
		local dinoId = record.Id
		prompt.Triggered:Connect(function(who)
			if who == player then
				sellDino(player, dinoId)
			end
		end)

		model.Parent = plot.Model
		table.insert(list, model)
	end
end

-- Puts an egg in a free incubator. Returns false if all incubators are busy.
function NestService.TryAddEgg(player: Player, egg): boolean
	local data = DataService.Get(player)
	if not data or #data.Incubating >= Balance.IncubatorSlots then
		return false
	end
	local rarity = Eggs.RarityById[egg.Rarity]
	local duration = rarity.IncubateSeconds * Balance.IncubationScale()
	if MonetizationService.Has(player, "FastIncubator") then
		duration /= Passes.Effects.IncubationSpeed
	end
	if egg.Fast then
		duration = math.min(duration, Balance.FirstEggHatchSeconds)
	end
	table.insert(data.Incubating, { Egg = egg, ReadyAt = os.time() + math.max(1, math.ceil(duration)) })
	NestService.RenderIncubators(player)
	return true
end

local function hatch(player: Player, data, egg)
	local record = {
		Id = egg.Id,
		DinoId = EggRoll.PickDino(egg.Rarity, egg.Zone),
		Rarity = egg.Rarity,
		Size = egg.Size,
		Mutation = egg.Mutation,
		Zone = egg.Zone,
		Baby = if IndexService.RollBaby(player) then true else nil,
	}
	table.insert(data.Dinos, record)
	data.Stats.DinosHatched += 1

	local name = Visuals.DinoDisplayName(record)
	local rarity = Eggs.RarityById[record.Rarity]
	if record.Baby then
		Notify.All(
			player.DisplayName
				.. " hatched a BABY "
				.. name
				.. "! ("
				.. IndexService.BabyOddsText(player)
				.. ")",
			"epic"
		)
	elseif rarity.Order >= ANNOUNCE_FROM then
		Notify.All(
			player.DisplayName .. " hatched a " .. string.upper(record.Rarity) .. " " .. name .. "!",
			"epic"
		)
	end
	-- Full-screen reveal on the owner's screen.
	Remotes.Get("Hatched")
		:FireClient(player, record, IncomeService.DinoIncome(player, record), egg.Fast == true)
	Events.Fire("Hatch", player, record)
end

-- Hatches every egg whose timer is done, if there's a free pedestal.
local function processHatching(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local now = os.time()
	local capacity = NestService.PedestalCapacity(player)
	local hatchedAny = false
	local waiting = false

	local i = 1
	while i <= #data.Incubating do
		local entry = data.Incubating[i]
		if entry.ReadyAt <= now then
			if #data.Dinos < capacity then
				table.remove(data.Incubating, i)
				hatch(player, data, entry.Egg)
				hatchedAny = true
				continue
			end
			waiting = true
		end
		i += 1
	end

	if hatchedAny then
		NestService.RenderIncubators(player)
		NestService.RenderPedestals(player)
		IncomeService.Recalc(player)
	end
	if waiting ~= (player:GetAttribute("PedestalsFull") == true) then
		player:SetAttribute("PedestalsFull", waiting)
		if waiting then
			Notify.Player(player, "Your pedestals are full! Sell a dino to hatch your egg.", "bad")
		end
	end
end

function NestService.Init(Services)
	DataService = Services.DataService
	MapService = Services.MapService
	MonetizationService = Services.MonetizationService
	IncomeService = Services.IncomeService
	CarryService = Services.CarryService
	IndexService = Services.IndexService

	DataService.OnLoaded(function(player)
		NestService.RenderPedestals(player)
		NestService.RenderIncubators(player)
	end)
	DataService.OnRemoving(function(player)
		local v = spawned[player]
		if v then
			clearList(v.Eggs)
			clearList(v.Dinos)
			spawned[player] = nil
		end
		setBarrier(player, false)
		lockedUntil[player] = nil
		lockReadyAt[player] = nil
		lastStealWarning[player] = nil
	end)
	MonetizationService.OnPassChanged(function(player, key)
		if key == "ExtraPedestals" or key == "DoubleCoins" or key == "VIP" then
			NestService.RenderPedestals(player)
		end
	end)
end

-- Studio only: type "/dino TRex" (add gold, rainbow, baby or huge etc. if you like)
-- to put that dino on your first pedestal, to look at new models.
local function testDinoCommand(player: Player, message: string)
	local words = string.split(string.lower(message), " ")
	if words[1] ~= "/dino" or not words[2] then
		return
	end
	local dino
	for _, d in Dinos.List do
		if string.lower(d.Id) == words[2] then
			dino = d
		end
	end
	local data = DataService.Get(player)
	if not dino or not data then
		Notify.Player(player, "Unknown dino. Use its Id, like /dino TRex", "bad")
		return
	end
	local record = {
		Id = HttpService:GenerateGUID(false),
		DinoId = dino.Id,
		Rarity = dino.Rarity,
		Size = "Normal",
		Mutation = "None",
		Zone = dino.Zone,
		Baby = nil :: boolean?,
	}
	for i = 3, #words do
		for _, size in Eggs.Sizes do
			if string.lower(size.Id) == words[i] then
				record.Size = size.Id
			end
		end
		for _, mutation in Eggs.Mutations do
			if string.lower(mutation.Id) == words[i] then
				record.Mutation = mutation.Id
			end
		end
		if words[i] == "baby" then
			record.Baby = true
		end
	end
	table.insert(data.Dinos, 1, record)
	NestService.RenderPedestals(player)
end

function NestService.Start()
	Remotes.Get("LockNest").OnServerEvent:Connect(lockNest)
	if RunService:IsStudio() then
		local function onPlayer(player: Player)
			player.Chatted:Connect(function(message)
				testDinoCommand(player, message)
			end)
		end
		Players.PlayerAdded:Connect(onPlayer)
		for _, player in Players:GetPlayers() do
			onPlayer(player)
		end
	end
	while true do
		task.wait(1)
		for _, player in DataService.LoadedPlayers() do
			if player.Parent == Players then
				processHatching(player)
			end
		end
	end
end

return NestService
