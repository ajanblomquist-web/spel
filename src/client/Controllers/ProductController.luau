-- ProductController.luau
-- The Robux sections at the bottom of the Shop: ROBUX DEALS (Starter Pack,
-- built by UIController, and the Rare Egg) and COIN PACKS (5, 10 and 24 hours
-- of your current income; the row shows how many coins that is right now).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Products = require(ReplicatedStorage.Shared.Config.Products)

local player = Players.LocalPlayer

local ProductController = {}

local function priceText(product): string
	if product.ProductId ~= 0 then
		return "R$ " .. product.Price
	end
	return if RunService:IsStudio() then "Test buy" else "Soon"
end

function ProductController.Start(Controllers)
	local UI = Controllers.UIController
	local list = UI.ShopList()

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
