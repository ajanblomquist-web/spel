-- CarryService.luau
-- Dig spots, carrying eggs home, and stealing eggs from players who carry them.
--
-- Flow: FlingService makes a dig spot where your shovel lands -> you hold Dig
-- -> the egg is rolled and sits above your head -> walk home (slower while
-- carrying) -> other players can hold "Steal egg" near you -> reach your plot
-- and the egg goes into a free incubator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local EggRoll = require(script.Parent.Parent.EggRoll)
local Events = require(script.Parent.Parent.Events)
local Notify = require(script.Parent.Parent.Notify)
local Visuals = require(script.Parent.Parent.Visuals)

local CarryService = {}

local DataService, MapService, NestService

type DigSpot = { Part: BasePart, ZoneId: string, Luck: number }
type Carry = { Egg: any, EggPart: BasePart, Prompt: ProximityPrompt, ProtectedUntil: number }

local digSpots: { [Player]: DigSpot } = {}
local carrying: { [Player]: Carry } = {}
local lastFullWarning: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function CarryService.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function CarryService.ClearDigSpot(player: Player)
	local spot = digSpots[player]
	if spot then
		spot.Part:Destroy()
		digSpots[player] = nil
	end
end

function CarryService.StopCarry(player: Player)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	carry.EggPart:Destroy()
	carry.Prompt:Destroy()
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("CarryRarity", nil)
end

local trySteal -- defined below

-- Puts an egg above the player's head. protectSeconds = time before it can be stolen.
function CarryService.StartCarry(player: Player, egg, protectSeconds: number): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local root = rootOf(player)
	if not head or not root then
		return false
	end
	CarryService.StopCarry(player)

	local eggPart = Visuals.Egg(egg)
	eggPart.Anchored = false
	eggPart.CFrame = head.CFrame * CFrame.new(0, 1 + eggPart.Size.Y / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = eggPart
	weld.Parent = eggPart
	local rarity = Eggs.RarityById[egg.Rarity]
	Visuals.Billboard(
		eggPart,
		{ { Text = string.upper(egg.Rarity) .. " EGG", Color = rarity.Color } },
		Vector2.new(6, 1.2),
		2.6,
		120
	)
	eggPart.Parent = character

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal egg"
	prompt.ObjectText = player.DisplayName .. "'s " .. egg.Rarity .. " egg"
	prompt.HoldDuration = Balance.StealHoldSeconds
	prompt.MaxActivationDistance = Balance.StealRange
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("NotForUserId", player.UserId) -- the carrier's own client hides it
	prompt.Triggered:Connect(function(thief)
		trySteal(thief, player)
	end)
	prompt.Parent = root

	carrying[player] = {
		Egg = egg,
		EggPart = eggPart,
		Prompt = prompt,
		ProtectedUntil = os.clock() + protectSeconds,
	}
	player:SetAttribute("CarryRarity", egg.Rarity)
	player:SetAttribute("Carrying", true)
	return true
end

trySteal = function(thief: Player, victim: Player)
	if thief == victim or not DataService.IsLoaded(thief) then
		return
	end
	local carry = carrying[victim]
	if not carry then
		return
	end
	if carrying[thief] then
		Notify.Player(thief, "Your hands are full! Take your egg home first.", "bad")
		return
	end
	if os.clock() < carry.ProtectedUntil then
		Notify.Player(thief, "Too soon! That egg was just stolen.", "bad")
		return
	end
	local thiefRoot, victimRoot = rootOf(thief), rootOf(victim)
	if not thiefRoot or not victimRoot then
		return
	end
	if (thiefRoot.Position - victimRoot.Position).Magnitude > Balance.StealRange + 4 then
		return
	end
	if MapService.IsHome(victim, victimRoot.Position) then
		return -- safe at home
	end

	local egg = carry.Egg
	CarryService.StopCarry(victim)
	if not CarryService.StartCarry(thief, egg, Balance.StealProtectSeconds) then
		CarryService.StartCarry(victim, egg, 0) -- give it back if something went wrong
		return
	end
	DataService.Increment(thief, "Steals", 1)
	Events.Fire("Steal", thief, egg, false)
	Notify.Player(victim, thief.DisplayName .. " stole your " .. egg.Rarity .. " egg! Chase them!", "bad")
	Notify.Player(thief, "You stole a " .. egg.Rarity .. " egg! Run home!", "good")
end

local function dig(player: Player)
	local spot = digSpots[player]
	if not spot then
		return
	end
	if carrying[player] then
		Notify.Player(player, "Take your egg home before digging again!", "bad")
		return
	end
	local root = rootOf(player)
	if not root or (root.Position - spot.Part.Position).Magnitude > 16 then
		return
	end
	local egg = EggRoll.Roll(spot.Luck, spot.ZoneId)
	local data = DataService.Get(player)
	if not data.FirstEggDone then
		-- Every new player's first egg is a guaranteed Rare that hatches fast.
		data.FirstEggDone = true
		if Eggs.RarityById[egg.Rarity].Order < Eggs.RarityById[Balance.FirstEggRarity].Order then
			egg.Rarity = Balance.FirstEggRarity
		end
		egg.Fast = true
	end
	CarryService.ClearDigSpot(player)
	-- The first egg can't be stolen on the way home: a new player's first loop should feel good.
	local protect = if egg.Fast then 120 else 0
	if CarryService.StartCarry(player, egg, protect) then
		data.Stats.EggsDug += 1
		Events.Fire("Dig", player, egg)
		Notify.Player(player, "You dug up a " .. string.upper(egg.Rarity) .. " egg! Carry it home!", "good")
	end
end

function CarryService.CreateDigSpot(player: Player, position: Vector3, zoneId: string, luck: number)
	CarryService.ClearDigSpot(player)

	local zone = Zones.ForDistance(0)
	for _, z in Zones.List do
		if z.Id == zoneId then
			zone = z
		end
	end

	local part = Visuals.Part({
		Name = "DigSpot_" .. player.UserId,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 7, 7),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = zone.Color:Lerp(Color3.new(0, 0, 0), 0.35),
		Material = Enum.Material.Ground,
		CanCollide = false,
	})
	part:SetAttribute("OwnerUserId", player.UserId)
	Visuals.Billboard(part, {
		{ Text = "DIG HERE", Color = Color3.fromRGB(255, 230, 90) },
		{ Text = player.DisplayName },
	}, Vector2.new(8, 2.6), 4, 600)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DigPrompt"
	prompt.ActionText = "Dig"
	prompt.ObjectText = zone.Name
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", player.UserId) -- other clients hide it
	prompt.Triggered:Connect(function(who)
		if who == player then
			dig(player)
		end
	end)
	prompt.Parent = part

	part.Parent = Workspace:WaitForChild("DigSpots")
	digSpots[player] = { Part = part, ZoneId = zoneId, Luck = luck }

	task.delay(Balance.DigSpotLifetime, function()
		local current = digSpots[player]
		if current and current.Part == part then
			CarryService.ClearDigSpot(player)
			Notify.Player(player, "Your dig spot crumbled away. Fling again!", "info")
		end
	end)
end

local function checkDeliveries()
	for player, carry in carrying do
		local root = rootOf(player)
		if root and MapService.IsHome(player, root.Position) then
			if NestService.TryAddEgg(player, carry.Egg) then
				CarryService.StopCarry(player)
				Events.Fire("Deliver", player, carry.Egg)
				Notify.Player(player, "Egg is in the incubator!", "good")
			else
				local now = os.clock()
				if not lastFullWarning[player] or now - lastFullWarning[player] > 6 then
					lastFullWarning[player] = now
					Notify.Player(player, "All incubators are busy. Wait for one to hatch!", "bad")
				end
			end
		end
	end
end

function CarryService.Init(Services)
	DataService = Services.DataService
	MapService = Services.MapService
	NestService = Services.NestService

	DataService.OnRemoving(function(player)
		CarryService.StopCarry(player)
		CarryService.ClearDigSpot(player)
		lastFullWarning[player] = nil
	end)
end

function CarryService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					if carrying[player] then
						CarryService.StopCarry(player)
						Notify.Player(player, "Oh no, you dropped your egg!", "bad")
					end
				end)
			end
		end)
		player.CharacterRemoving:Connect(function()
			CarryService.StopCarry(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	while true do
		task.wait(0.25)
		checkDeliveries()
	end
end

return CarryService
