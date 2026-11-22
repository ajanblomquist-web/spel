-- WeaponService.luau
-- Bonk weapons: owning, buying, equipping, the weapon in your hand, and the
-- bonk itself (see Config/Weapons).
--
-- Saved data: data.Weapons = { Owned = { [weaponId] = true }, Equipped, Skin }
-- Robux weapons and skins are game passes, so they're not in Owned.
--
-- Attributes for the client: Weapon, WeaponSkin, WeaponsOwned ("Stick,BoneClub").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Events = require(script.Parent.Parent.Events)
local Notify = require(script.Parent.Parent.Notify)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Visuals = require(script.Parent.Parent.Visuals)

local WeaponService = {}

local DataService, MonetizationService, CarryService

local lastBonk: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function WeaponService.Owns(player: Player, weaponId: string): boolean
	local weapon = Weapons.ById[weaponId]
	local data = DataService.Get(player)
	if not weapon or not data then
		return false
	end
	if weapon.Pass then
		return MonetizationService.Has(player, weapon.Pass)
	end
	return weapon.Coins == 0 or data.Weapons.Owned[weaponId] == true
end

function WeaponService.Equipped(player: Player)
	local data = DataService.Get(player)
	local id = data and data.Weapons.Equipped
	if id and WeaponService.Owns(player, id) then
		return Weapons.ById[id]
	end
	return Weapons.ById[Weapons.Default]
end

local function equippedSkin(player: Player)
	local data = DataService.Get(player)
	local skin = data and data.Weapons.Skin and Weapons.SkinById[data.Weapons.Skin]
	if skin and MonetizationService.Has(player, skin.Pass) then
		return skin
	end
	return nil
end

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local owned = {}
	for _, weapon in Weapons.List do
		if WeaponService.Owns(player, weapon.Id) then
			table.insert(owned, weapon.Id)
		end
	end
	player:SetAttribute("WeaponsOwned", table.concat(owned, ","))
	player:SetAttribute("Weapon", WeaponService.Equipped(player).Id)
	local skin = equippedSkin(player)
	player:SetAttribute("WeaponSkin", skin and skin.Id or nil)
end

-- Puts the equipped weapon in the character's right hand.
local function attach(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("BonkWeapon")
	if old then
		old:Destroy()
	end
	local weapon = WeaponService.Equipped(player)
	local skin = equippedSkin(player)
	local part = Visuals.Part({
		Name = "BonkWeapon",
		Size = weapon.Size,
		Color = if skin then skin.Color else weapon.Color,
		Material = if skin then skin.Material else weapon.Material,
		Anchored = false,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
	})
	-- Held like a club: handle in the hand, pointing up and forward.
	local weld = Instance.new("Weld")
	weld.Name = "Grip"
	weld.Part0 = hand
	weld.Part1 = part
	weld.C0 = CFrame.new(0, -hand.Size.Y / 2, -0.3) * CFrame.Angles(math.rad(-90), 0, 0)
	weld.C1 = CFrame.new(0, -weapon.Size.Y / 2 + 0.3, 0)
	weld.Parent = part
	part.Parent = character
end

local function refresh(player: Player)
	publish(player)
	attach(player)
end

local function buy(player: Player, weaponId: any)
	local weapon = type(weaponId) == "string" and Weapons.ById[weaponId]
	local data = DataService.Get(player)
	if not weapon or not data or weapon.Pass or WeaponService.Owns(player, weapon.Id) then
		return
	end
	if not DataService.SpendCoins(player, weapon.Coins or 0) then
		Notify.Player(player, "Not enough coins for the " .. weapon.Name .. "!", "bad")
		return
	end
	data.Weapons.Owned[weapon.Id] = true
	data.Weapons.Equipped = weapon.Id
	refresh(player)
	Notify.Player(player, "You got the " .. weapon.Name .. "! Bonk egg carriers to make them drop.", "epic")
	Events.Fire("Buy", player, "Weapons", weapon.Order)
end

local function equip(player: Player, weaponId: any)
	local data = DataService.Get(player)
	if data and type(weaponId) == "string" and WeaponService.Owns(player, weaponId) then
		data.Weapons.Equipped = weaponId
		refresh(player)
	end
end

local function equipSkin(player: Player, skinId: any)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if skinId == nil or skinId == false then
		data.Weapons.Skin = nil
	elseif type(skinId) == "string" then
		local skin = Weapons.SkinById[skinId]
		if not skin or not MonetizationService.Has(player, skin.Pass) then
			return
		end
		data.Weapons.Skin = skinId
	end
	refresh(player)
end

local function bonk(attacker: Player, victim: any)
	if typeof(victim) ~= "Instance" or not victim:IsA("Player") or victim == attacker then
		return
	end
	if not DataService.IsLoaded(attacker) then
		return
	end
	local weapon = WeaponService.Equipped(attacker)
	local now = os.clock()
	if lastBonk[attacker] and now - lastBonk[attacker] < weapon.Cooldown - 0.2 then
		return
	end
	local a, v = rootOf(attacker), rootOf(victim)
	if not a or not v or (a.Position - v.Position).Magnitude > weapon.Range + 4 then
		return
	end
	if not CarryService.CanBonk(victim) then
		return
	end
	lastBonk[attacker] = now
	if not CarryService.DropFromBonk(victim) then
		return
	end
	local away = (v.Position - a.Position) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	Remotes.Get("Bonk"):FireAllClients(attacker, victim, away)
	Notify.Player(victim, attacker.DisplayName .. " bonked you! Grab your egg back!", "bad")
	Events.Fire("Bonk", attacker, victim)
end

function WeaponService.Init(Services)
	DataService = Services.DataService
	MonetizationService = Services.MonetizationService
	CarryService = Services.CarryService

	DataService.OnLoaded(function(player)
		refresh(player)
	end)
	DataService.OnRemoving(function(player)
		lastBonk[player] = nil
	end)
	MonetizationService.OnPassChanged(function(player, key)
		for _, weapon in Weapons.List do
			if weapon.Pass == key then
				local data = DataService.Get(player)
				if data and MonetizationService.Has(player, key) then
					data.Weapons.Equipped = weapon.Id -- equip a weapon right after buying it
				end
			end
		end
		for _, skin in Weapons.Skins do
			if skin.Pass == key then
				local data = DataService.Get(player)
				if data and MonetizationService.Has(player, key) then
					data.Weapons.Skin = skin.Id
				end
			end
		end
		refresh(player)
	end)
end

function WeaponService.Start()
	Remotes.Get("BuyWeapon").OnServerEvent:Connect(buy)
	Remotes.Get("EquipWeapon").OnServerEvent:Connect(equip)
	Remotes.Get("EquipSkin").OnServerEvent:Connect(equipSkin)
	Remotes.Get("Bonk").OnServerEvent:Connect(bonk)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			character:WaitForChild("RightHand", 5)
			if DataService.IsLoaded(player) then
				attach(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return WeaponService
