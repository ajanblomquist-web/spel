-- WeaponService.luau
-- Bonk weapons: owning, buying, equipping, the weapon Tool in your hotbar,
-- and the bonk itself (see Config/Weapons). You bonk while holding the tool.
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
local WeaponArt = require(script.Parent.Parent.WeaponArt)

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

-- Gives the equipped weapon as a hotbar Tool (replacing the old one). If the
-- old one was being held, the new one is held too.
local function isWeaponTool(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute("BonkWeapon") ~= nil
end

function WeaponService.Holding(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	for _, child in character:GetChildren() do
		if isWeaponTool(child) then
			return true
		end
	end
	return false
end

local function giveTool(player: Player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not backpack then
		return
	end
	local wasHeld = false
	for _, container in { backpack, character } do
		for _, child in container:GetChildren() do
			if isWeaponTool(child) then
				wasHeld = wasHeld or container == character
				child:Destroy()
			end
		end
	end

	local weapon = WeaponService.Equipped(player)
	local skin = equippedSkin(player)
	local tool = Instance.new("Tool")
	tool.Name = weapon.Name
	tool.ToolTip = "Bonk egg carriers!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("BonkWeapon", weapon.Id)

	-- The handle is the shaft, long along Z; the grip holds it near one end,
	-- pointing up. WeaponArt welds the weapon's head to the other end, and a
	-- skin recolours only that head.
	local length = weapon.Size.Y
	local thickness = math.min(weapon.Size.X, 0.45)
	local handle = Visuals.Part({
		Name = "Handle",
		Size = Vector3.new(thickness, thickness, length),
		Color = weapon.Color,
		Material = if weapon.Material == Enum.Material.Neon
			then Enum.Material.SmoothPlastic
			else weapon.Material,
		Anchored = false,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
	})
	handle.Parent = tool
	WeaponArt.Decorate(handle, weapon.Id, length, skin)
	tool.GripPos = Vector3.new(0, 0, -(length / 2 - 0.4))
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)

	tool.Parent = if wasHeld then character else backpack
end

local function refresh(player: Player)
	publish(player)
	giveTool(player)
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
	if not WeaponService.Holding(attacker) or not CarryService.CanBonk(victim) then
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
			player:WaitForChild("Backpack", 5)
			if DataService.IsLoaded(player) then
				giveTool(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return WeaponService
