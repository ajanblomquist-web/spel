-- StarterPackService.luau
-- The one-time Starter Pack (Config/Products), offered once right after a
-- player's first hatch, when they've just felt the payoff. It's shown once and
-- can be closed with "Maybe later"; after that it stays in the Passes menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Events = require(script.Parent.Parent.Events)
local Notify = require(script.Parent.Parent.Notify)

local StarterPackService = {}

local DataService, BoostService, NestService

local OFFER_DELAY = 7 -- seconds after the hatch, so the reveal plays first
local OFFER_AFTER_HATCHES = 3

function StarterPackService.Init(Services)
	DataService = Services.DataService
	BoostService = Services.BoostService
	NestService = Services.NestService

	DataService.OnLoaded(function(player, data)
		player:SetAttribute("StarterPackBought", data.StarterPackBought)
	end)

	Services.MonetizationService.OnProduct("StarterPack", function(player, data)
		if data.StarterPackBought then
			-- Bought twice somehow: give coins so it's never wasted.
			DataService.AddCoins(player, 5000)
			return
		end
		data.StarterPackBought = true
		player:SetAttribute("StarterPackBought", true)
		BoostService.Add(player, "Coins", 30 * 60)
		DataService.AddCoins(player, 1000)
		local egg = { Id = DataService.NewId(), Rarity = "Rare", Size = "Normal", Mutation = "None" }
		if not NestService.TryAddEgg(player, egg) then
			DataService.AddCoins(player, 1500) -- incubators full: coins instead of the egg
		end
		Notify.Player(player, "Starter Pack unlocked! Enjoy 2x Coins!", "epic")
	end)

	Events.On("Hatch", function(player)
		local data = DataService.Get(player)
		-- Offered after the 3rd hatch, not the first, so it never lands on top of
		-- the first-egg reveal and the tutorial.
		if not data or data.StarterOfferShown or data.StarterPackBought then
			return
		end
		if data.Stats.DinosHatched < OFFER_AFTER_HATCHES then
			return
		end
		data.StarterOfferShown = true
		task.delay(OFFER_DELAY, function()
			if player.Parent then
				Remotes.Get("Celebrate"):FireClient(player, "StarterOffer", {})
			end
		end)
	end)
end

return StarterPackService
