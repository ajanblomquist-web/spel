-- ProductController.luau
-- The Robux sections at the bottom of the Shop: ROBUX DEALS (Starter Pack,
-- built by UIController, and the Rare Egg) and COIN PACKS (5, 10 and 24 hours
-- of your current income; the row shows how many coins that is right now),
-- plus the Codes box at the very top of the Shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local ProductController = {}

local function priceText(product): string
	if product.ProductId ~= 0 then
		return "R$ " .. product.Price
	end
	return if RunService:IsStudio() then "Test buy" else "Soon"
end

-- A text box and a Redeem button, above everything else in the Shop.
local function buildCodes(UI, list)
	UI.SectionHeader(list, -30, "CODES", UI.Colors.Blue)
	local frame = UI.Make("Frame", {
		LayoutOrder = -29,
		Size = UDim2.new(1, -12, 0, 74),
		BackgroundColor3 = UI.Colors.PanelLight,
		ZIndex = 12,
		Parent = list,
	}, { UI.Corner(14) })
	local box = UI.Make("TextBox", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -190, 1, -16),
		BackgroundColor3 = Color3.fromRGB(25, 22, 32),
		Font = UI.Font,
		PlaceholderText = "Type a code",
		PlaceholderColor3 = Color3.fromRGB(140, 135, 155),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		ClearTextOnFocus = false,
		ZIndex = 13,
		Parent = frame,
	}, {
		UI.Corner(10),
		UI.Make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	local button = UI.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(160, 58),
		Text = "Redeem",
		BackgroundColor3 = UI.Colors.Green,
		ZIndex = 13,
		Parent = frame,
	})
	local function send()
		if box.Text ~= "" then
			Remotes.Get("RedeemCode"):FireServer(box.Text)
			box.Text = ""
		end
	end
	button.Activated:Connect(send)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			send()
		end
	end)
end

function ProductController.Start(Controllers)
	local UI = Controllers.UIController
	local list = UI.ShopList()
	buildCodes(UI, list)

	UI.SectionHeader(list, 900, "ROBUX DEALS", Color3.fromRGB(40, 150, 70))
	local rare = Products.RareEgg
	local _, rareButton = UI.Row(list, 902, rare.Name, rare.Description)
	rareButton.Text = priceText(rare)
	rareButton.BackgroundColor3 = UI.Colors.Green
	rareButton.Activated:Connect(function()
		UI.PromptProduct(rare.Key)
	end)

	UI.SectionHeader(list, 910, "COIN PACKS", Color3.fromRGB(190, 150, 30))
	local subtitles = {}
	local order = 910
	for _, product in Products.List do
		if product.Hours then
			order += 1
			local frame, button = UI.Row(list, order, product.Name, "")
			button.Text = priceText(product)
			button.BackgroundColor3 = UI.Colors.Green
			button.Activated:Connect(function()
				UI.PromptProduct(product.Key)
			end)
			subtitles[product] = frame:FindFirstChild("Subtitle") :: TextLabel
		end
	end

	local function refresh()
		local income = player:GetAttribute("IncomePerSec") or 0
		for product, label in subtitles do
			label.Text = "+" .. FormatNumber(Products.CoinPackAmount(product, income)) .. " coins right now"
		end
	end
	refresh()
	player:GetAttributeChangedSignal("IncomePerSec"):Connect(refresh)
end

return ProductController
