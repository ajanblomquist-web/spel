-- NpcService.luau
-- The Egg Thief: an NPC that wanders around the hub carrying an egg that
-- anyone can steal. It teaches stealing in the first minutes and gives solo
-- players something to steal from. Steals from the thief count for quests
-- but not for the Steals leaderboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local WeightedRandom = require(ReplicatedStorage.Shared.Util.WeightedRandom)
local Events = require(script.Parent.Parent.Events)
local Notify = require(script.Parent.Parent.Notify)
local Visuals = require(script.Parent.Parent.Visuals)

local NpcService = {}

local DataService, CarryService

-- The thief carries mostly Common eggs, sometimes better.
local THIEF_EGGS = {
	{ Id = "Common", Weight = 60 },
	{ Id = "Uncommon", Weight = 30 },
	{ Id = "Rare", Weight = 10 },
}
-- Area it wanders in (between the spawn and the plots).
local AREA_MIN = Vector3.new(-140, 0, -72)
local AREA_MAX = Vector3.new(140, 0, -18)

local rng = Random.new()
local thief: Model? = nil
local carried: { Egg: any, Part: BasePart, Prompt: ProximityPrompt }? = nil

local function randomPoint(): Vector3
	return Vector3.new(rng:NextNumber(AREA_MIN.X, AREA_MAX.X), 3, rng:NextNumber(AREA_MIN.Z, AREA_MAX.Z))
end

local function buildThief(): Model
	local model: Model
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = Color3.fromRGB(120, 90, 70)
		description.TorsoColor = Color3.fromRGB(40, 40, 50)
		description.LeftArmColor = Color3.fromRGB(120, 90, 70)
		description.RightArmColor = Color3.fromRGB(120, 90, 70)
		description.LeftLegColor = Color3.fromRGB(30, 30, 35)
		description.RightLegColor = Color3.fromRGB(30, 30, 35)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		model = result
	else
		warn("[NpcService] Couldn't build the thief rig: " .. tostring(result))
		-- Fallback: a simple block character.
		model = Instance.new("Model")
		local root =
			Visuals.Part({ Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), Transparency = 1 })
		root.Anchored = false
		root.Parent = model
		local head =
			Visuals.Part({ Name = "Head", Size = Vector3.new(2, 1, 1), Color = Color3.fromRGB(120, 90, 70) })
		head.Anchored = false
		head.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = head
		head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
		weld.Parent = head
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		model.PrimaryPart = root
	end

	model.Name = "EggThief"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = "Egg Thief"
	humanoid.WalkSpeed = Balance.ThiefWalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge

	local head = model:FindFirstChild("Head") :: BasePart
	Visuals.Billboard(head, {
		{ Text = "Egg Thief", Color = Color3.fromRGB(255, 120, 120) },
	}, Vector2.new(6, 1.2), 5.5, 150)

	model:PivotTo(CFrame.new(randomPoint()))
	model.Parent = Workspace:WaitForChild("NPCs")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil) -- the server moves it, so it looks smooth for everyone
	end)
	return model
end

local giveEgg -- defined below

local function onStolen(player: Player)
	local current = carried
	if not current or not thief then
		return
	end
	if not DataService.IsLoaded(player) then
		return
	end
	if CarryService.IsCarrying(player) then
		Notify.Player(player, "Your hands are full! Take your egg home first.", "bad")
		return
	end
	local root = thief:FindFirstChild("HumanoidRootPart") :: BasePart
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not playerRoot or (playerRoot.Position - root.Position).Magnitude > 16 then
		return
	end

	carried = nil
	current.Part:Destroy()
	current.Prompt:Destroy()
	if CarryService.StartCarry(player, current.Egg, Balance.StealProtectSeconds) then
		Events.Fire("Steal", player, current.Egg, true)
		Notify.Player(player, "You stole the Egg Thief's " .. current.Egg.Rarity .. " egg! Run home!", "good")
	end
	task.delay(Balance.ThiefRespawnSeconds, giveEgg)
end

giveEgg = function()
	if not thief or carried then
		return
	end
	local head = thief:FindFirstChild("Head") :: BasePart
	local root = thief:FindFirstChild("HumanoidRootPart") :: BasePart
	local rarity = WeightedRandom.Pick(THIEF_EGGS, rng).Id
	local egg = { Id = DataService.NewId(), Rarity = rarity, Size = "Normal", Mutation = "None" }

	local part = Visuals.Egg(egg)
	part.Anchored = false
	part.CFrame = head.CFrame * CFrame.new(0, 1 + part.Size.Y / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	Visuals.Billboard(part, {
		{ Text = string.upper(rarity) .. " EGG", Color = Eggs.RarityById[rarity].Color },
	}, Vector2.new(6, 1.2), 2.6, 150)
	part.Parent = thief

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealThiefPrompt"
	prompt.ActionText = "Steal egg"
	prompt.ObjectText = "Egg Thief's " .. rarity .. " egg"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onStolen)
	prompt.Parent = root

	carried = { Egg = egg, Part = part, Prompt = prompt }
end

local function wander()
	while true do
		if not thief or not thief.Parent then
			thief = buildThief()
			carried = nil
			giveEgg()
		end
		local humanoid = (thief :: Model):FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(randomPoint())
			local finished = false
			local connection = humanoid.MoveToFinished:Connect(function()
				finished = true
			end)
			local started = os.clock()
			while not finished and os.clock() - started < 10 do
				task.wait(0.2)
			end
			connection:Disconnect()
		end
		task.wait(rng:NextNumber(0.3, 1.5))
	end
end

function NpcService.Init(Services)
	DataService = Services.DataService
	CarryService = Services.CarryService
	local folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = Workspace
end

function NpcService.Start()
	task.spawn(wander)
end

return NpcService
