-- RebirthController.luau
-- The Rebirth row at the top of the Shop: shows what it costs and gives, and
-- asks "Sure?" on the first tap so nobody rebirths by accident.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local RebirthController = {}

local UI
local frame: Frame
local button: TextButton
local subtitle: TextLabel
local armedAt = 0

local function unlocked(): boolean
	return player:GetAttribute("ReachedAmber") == true or (player:GetAttribute("Rebirths") or 0) > 0
end

local function refresh()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local price = Rebirth.Price(rebirths)
	local coins = player:GetAttribute("Coins") or 0
	local nextCount = rebirths + 1
	subtitle.Text = string.format(
		"Reset coins, Strength & upgrades. Keep dinos. Forever: x%.2f Str, x%.2f Coins",
		Rebirth.Multiplier(nextCount, "Strength"),
		Rebirth.Multiplier(nextCount, "Coins")
	)
	if not unlocked() then
		button.Text = "Reach Amber Cliffs"
		button.BackgroundColor3 = UI.Colors.Grey
	elseif os.clock() - armedAt < 4 then
		button.Text = "Sure? Tap again"
		button.BackgroundColor3 = UI.Colors.Red
	else
		button.Text = FormatNumber(price)
		button.BackgroundColor3 = if coins >= price then UI.Colors.Green else UI.Colors.Orange
	end
end

function RebirthController.Start(Controllers)
	UI = Controllers.UIController
	local title
	frame, button = UI.Row(UI.ShopList(), -10, "REBIRTH", "")
	frame.BackgroundColor3 = Color3.fromRGB(130, 50, 120)
	for _, child in frame:GetChildren() do
		if child:IsA("TextLabel") then
			if child.Text == "REBIRTH" then
				title = child
			else
				subtitle = child
			end
		end
	end
	subtitle.TextScaled = true
	if title then
		title.TextColor3 = Color3.fromRGB(255, 170, 235)
	end

	button.Activated:Connect(function()
		if not unlocked() then
			return
		end
		if os.clock() - armedAt < 4 then
			armedAt = 0
			Remotes.Get("Rebirth"):FireServer()
		else
			armedAt = os.clock()
			task.delay(4.1, refresh)
		end
		refresh()
	end)

	for _, attribute in { "Coins", "Rebirths", "ReachedAmber" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()
end

return RebirthController
