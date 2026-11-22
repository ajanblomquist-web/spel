-- HintController.luau
-- The small hint card (bottom right) that points at a pass or the group at
-- the moment it would help, and the "Join our group" row in the Passes menu.
-- The server decides when hints show (see HintService); the card closes by
-- itself after a few seconds.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Social = require(ReplicatedStorage.Shared.Config.Social)

local player = Players.LocalPlayer

local HintController = {}

local UI
local current: Frame? = nil

function HintController.PromptGroup()
	if Social.GroupId == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			GroupService:PromptJoinAsync(Social.GroupId)
		end)
		Remotes.Get("GroupCheck"):FireServer()
	end)
end

local function close(card: Frame)
	if card.Parent then
		local scale = card:FindFirstChildOfClass("UIScale")
		if scale then
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
		end
		task.delay(0.2, function()
			card:Destroy()
		end)
	end
	if current == card then
		current = nil
	end
end

local function show(text: string, passKey: string)
	if current then
		close(current)
	end
	local card = UI.Make("Frame", {
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -130),
		Size = UDim2.fromOffset(300, 96),
		BackgroundColor3 = UI.Colors.Panel,
		ZIndex = 30,
		Parent = UI.Gui(),
	}, { UI.Corner(16), UI.Stroke(3, UI.Colors.Purple) })
	current = card
	local scale = UI.Make("UIScale", { Scale = 0.2, Parent = card })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	UI.Label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -54, 0, 44),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		ZIndex = 31,
		Parent = card,
	})
	local go = UI.Button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.fromOffset(150, 36),
		Text = if passKey == "Group" then "Join group" else "See it",
		BackgroundColor3 = UI.Colors.Green,
		ZIndex = 31,
		Parent = card,
	})
	local x = UI.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(36, 36),
		Text = "X",
		BackgroundColor3 = UI.Colors.Grey,
		ZIndex = 31,
		Parent = card,
	})
	go.Activated:Connect(function()
		close(card)
		if passKey == "Group" then
			HintController.PromptGroup()
		else
			UI.PromptPass(passKey)
		end
	end)
	x.Activated:Connect(function()
		close(card)
	end)
	task.delay(Social.HintShowSeconds, function()
		close(card)
	end)
end

-- "Join our group" at the top of the Passes menu (hidden once you're in).
local function buildGroupRow()
	if Social.GroupId == 0 then
		return
	end
	local list = UI.PassesList()
	local frame, button = UI.Row(list, -1, "Join our group", "Free! 15 min of 2x Luck + a pile of coins.")
	frame.BackgroundColor3 = Color3.fromRGB(40, 110, 70)
	button.Text = "Join"
	button.BackgroundColor3 = UI.Colors.Green
	button.Activated:Connect(HintController.PromptGroup)
	local function refresh()
		frame.Visible = player:GetAttribute("GroupRewardClaimed") ~= true
	end
	refresh()
	player:GetAttributeChangedSignal("GroupRewardClaimed"):Connect(refresh)
end

function HintController.Start(Controllers)
	UI = Controllers.UIController
	buildGroupRow()
	Remotes.Get("Hint").OnClientEvent:Connect(show)
end

return HintController
