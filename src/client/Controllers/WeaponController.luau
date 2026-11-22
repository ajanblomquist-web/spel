-- WeaponController.luau
-- The BONK! action button (shows when an egg carrier is in reach), the hit
-- effects everyone sees, the knockback when you get bonked, and the weapon and
-- skin rows in the Shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local player = Players.LocalPlayer

local WeaponController = {}

local UI
local lastBonk = 0
local weaponRows = {} -- { [weaponId] = TextButton }
local skinRows = {} -- { [skinId] = TextButton }

local function rootOf(who: Player): BasePart?
	local character = who.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function equipped()
	return Weapons.ById[player:GetAttribute("Weapon") or Weapons.Default] or Weapons.ById[Weapons.Default]
end

local function owns(weaponId: string): boolean
	local list = player:GetAttribute("WeaponsOwned") or ""
	return table.find(string.split(list, ","), weaponId) ~= nil
end

-- The nearest carrier you could bonk right now, or nil.
local function findTarget(range: number): Player?
	local me = rootOf(player)
	if not me then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	local best, bestDistance = nil, range
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Carrying") then
			local root = rootOf(other)
			local protectedUntil = other:GetAttribute("CarryProtectedUntil") or 0
			if root and protectedUntil <= now then
				local distance = (root.Position - me.Position).Magnitude
				if distance <= bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

-- Effects --------------------------------------------------------------------------

local function swing(attacker: Player)
	local character = attacker.Character
	local weapon = character and character:FindFirstChild("BonkWeapon")
	local grip = weapon and weapon:FindFirstChild("Grip") :: Weld?
	if not grip then
		return
	end
	local rest = grip.C0
	local tween =
		TweenService:Create(grip, TweenInfo.new(0.1), { C0 = rest * CFrame.Angles(math.rad(110), 0, 0) })
	tween:Play()
	tween.Completed:Once(function()
		TweenService:Create(grip, TweenInfo.new(0.25, Enum.EasingStyle.Back), { C0 = rest }):Play()
	end)
end

local function bonkText(victim: Player)
	local character = victim.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = UI.Font
	label.TextScaled = true
	label.Text = "BONK!"
	label.TextColor3 = Color3.fromRGB(255, 230, 60)
	label.TextStrokeTransparency = 0
	label.Rotation = math.random(-12, 12)
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.9), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 })
		:Play()
	task.delay(1, function()
		gui:Destroy()
	end)
end

local function knockback(direction: Vector3)
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = direction * Weapons.KnockbackSpeed + Vector3.new(0, 28, 0)
	root.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	-- A quick camera shake so it really lands.
	local camera = Workspace.CurrentCamera
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > 0.35 or not camera then
			connection:Disconnect()
			return
		end
		local power = (0.35 - t) * 1.2
		camera.CFrame *= CFrame.new(math.random(-10, 10) / 10 * power, math.random(-10, 10) / 10 * power, 0)
	end)
	task.delay(Weapons.StunSeconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Shop rows ------------------------------------------------------------------------------

local function priceText(pass): string
	if pass.GamePassId ~= 0 then
		return "R$ " .. pass.Price
	end
	return if RunService:IsStudio() then "Test it" else "Soon"
end

local function refreshShop()
	local coins = player:GetAttribute("Coins") or 0
	local current = equipped().Id
	for id, button in weaponRows do
		local weapon = Weapons.ById[id]
		if id == current then
			button.Text = "Equipped"
			button.BackgroundColor3 = UI.Colors.Grey
		elseif owns(id) then
			button.Text = "Equip"
			button.BackgroundColor3 = UI.Colors.Blue
		elseif weapon.Pass then
			button.Text = priceText(Passes.ByKey[weapon.Pass])
			button.BackgroundColor3 = UI.Colors.Purple
		else
			button.Text = FormatNumber(weapon.Coins or 0)
			button.BackgroundColor3 = if coins >= (weapon.Coins or 0)
				then UI.Colors.Green
				else UI.Colors.Orange
		end
	end
	local currentSkin = player:GetAttribute("WeaponSkin")
	for id, button in skinRows do
		local skin = Weapons.SkinById[id]
		if currentSkin == id then
			button.Text = "Take off"
			button.BackgroundColor3 = UI.Colors.Grey
		elseif UI.OwnsPass(skin.Pass) then
			button.Text = "Wear"
			button.BackgroundColor3 = UI.Colors.Blue
		else
			button.Text = priceText(Passes.ByKey[skin.Pass])
			button.BackgroundColor3 = UI.Colors.Purple
		end
	end
end

local function buildShopRows()
	local list = UI.ShopList()
	local order = 500
	local header = UI.Make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 50),
		BackgroundColor3 = UI.Colors.Red,
		ZIndex = 12,
		Parent = list,
	}, { UI.Corner(14) })
	UI.Label({
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 1, -8),
		Text = "WEAPONS: bonk egg carriers to make them drop!",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = header,
	})

	for _, weapon in Weapons.List do
		order += 1
		local subtitle = "Reach " .. weapon.Range .. " · bonk every " .. weapon.Cooldown .. "s"
		local _, button = UI.Row(list, order, weapon.Name, subtitle)
		button.Activated:Connect(function()
			if owns(weapon.Id) then
				Remotes.Get("EquipWeapon"):FireServer(weapon.Id)
			elseif weapon.Pass then
				UI.PromptPass(weapon.Pass)
			else
				Remotes.Get("BuyWeapon"):FireServer(weapon.Id)
			end
		end)
		weaponRows[weapon.Id] = button
	end
	for _, skin in Weapons.Skins do
		order += 1
		local _, button = UI.Row(list, order, skin.Name, "Works on every weapon. Looks only.")
		button.Activated:Connect(function()
			if player:GetAttribute("WeaponSkin") == skin.Id then
				Remotes.Get("EquipSkin"):FireServer(nil)
			elseif UI.OwnsPass(skin.Pass) then
				Remotes.Get("EquipSkin"):FireServer(skin.Id)
			else
				UI.PromptPass(skin.Pass)
			end
		end)
		skinRows[skin.Id] = button
	end
	refreshShop()
end

-- Start ------------------------------------------------------------------------------------

function WeaponController.Start(Controllers)
	UI = Controllers.UIController
	buildShopRows()

	-- BONK! shows when a carrier is in reach (above FLING, below STOP!).
	UI.RegisterAction(60, function()
		local weapon = equipped()
		local target = findTarget(weapon.Range)
		if not target then
			return nil
		end
		local wait = weapon.Cooldown - (os.clock() - lastBonk)
		if wait > 0 then
			return { Text = "Bonk in " .. math.ceil(wait) .. "s", Color = Color3.fromRGB(110, 110, 120) }
		end
		return {
			Text = "BONK!",
			Color = Color3.fromRGB(235, 70, 70),
			Callback = function()
				local now = findTarget(weapon.Range + 2)
				if now then
					lastBonk = os.clock()
					Remotes.Get("Bonk"):FireServer(now)
				end
			end,
		}
	end)

	Remotes.Get("Bonk").OnClientEvent:Connect(function(attacker: Player, victim: Player, direction: Vector3)
		swing(attacker)
		bonkText(victim)
		if victim == player then
			knockback(direction)
		end
	end)

	player.AttributeChanged:Connect(function(name)
		if
			name == "Coins"
			or name == "Weapon"
			or name == "WeaponsOwned"
			or name == "WeaponSkin"
			or string.sub(name, 1, 5) == "Pass_"
		then
			refreshShop()
		end
	end)
end

return WeaponController
