-- RebirthService.luau
-- Rebirth (see Config/Rebirth): reset coins, Strength, rock and shovel for
-- permanent Strength / Coins / Luck bonuses. Shows a "Rebirth N" tag above
-- your head and a Rebirths column on the player list.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local Events = require(script.Parent.Parent.Events)
local Notify = require(script.Parent.Parent.Notify)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RebirthService = {}

local DataService, IncomeService, CarryService

function RebirthService.Multiplier(player: Player, kind: string): number
	local data = DataService.Get(player)
	return Rebirth.Multiplier(data and data.Rebirths or 0, kind)
end

local function tag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local data = DataService.Get(player)
	if not head or not data then
		return
	end
	local old = head:FindFirstChild("RebirthTag")
	if old then
		old:Destroy()
	end
	if data.Rebirths <= 0 then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RebirthTag"
	gui.Size = UDim2.fromOffset(160, 30)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "Rebirth " .. data.Rebirths
	label.TextColor3 = Color3.fromRGB(255, 120, 220)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = head
end

local function rebirth(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not data.ZonesReached[Rebirth.RequiredZone] then
		Notify.Player(player, "Reach Amber Cliffs to unlock rebirth!", "bad")
		return
	end
	if CarryService.IsCarrying(player) then
		Notify.Player(player, "Take your egg home first!", "bad")
		return
	end
	local price = Rebirth.Price(data.Rebirths)
	if not DataService.SpendCoins(player, price) then
		Notify.Player(player, "You need " .. FormatNumber(price) .. " coins to rebirth.", "bad")
		return
	end
	DataService.Set(player, "Coins", 0)
	DataService.Set(player, "Strength", 0)
	DataService.Set(player, "RockTier", 1)
	DataService.Set(player, "ShovelTier", 1)
	DataService.Set(player, "Rebirths", data.Rebirths + 1)
	IncomeService.Recalc(player)
	tag(player)
	DataService.SaveNow(player)

	local n = data.Rebirths
	Remotes.Get("Celebrate"):FireClient(player, "Rebirth", {
		Count = n,
		Strength = Rebirth.Multiplier(n, "Strength"),
		Coins = Rebirth.Multiplier(n, "Coins"),
		Luck = Rebirth.Multiplier(n, "Luck"),
	})
	Notify.All(player.DisplayName .. " reached REBIRTH " .. n .. "!", "epic")
	Events.Fire("Rebirth", player, n)
end

function RebirthService.Init(Services)
	DataService = Services.DataService
	IncomeService = Services.IncomeService
	CarryService = Services.CarryService

	DataService.OnLoaded(function(player, data)
		tag(player)
		player:SetAttribute("ReachedAmber", data.ZonesReached[Rebirth.RequiredZone] == true)
	end)
	Events.On("Fling", function(player, _distance, zoneId)
		if zoneId == Rebirth.RequiredZone then
			player:SetAttribute("ReachedAmber", true)
		end
	end)
end

function RebirthService.Start()
	Remotes.Get("Rebirth").OnServerEvent:Connect(rebirth)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			if DataService.IsLoaded(player) then
				tag(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return RebirthService
