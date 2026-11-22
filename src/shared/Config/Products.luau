-- Products.luau
-- Developer products (can be bought more than once, or once if OneTime).
-- Create them in Creator Hub (your experience > Monetization > Developer
-- Products) and paste each ID into ProductId. ID 0 = not set up yet; in Studio
-- the "Test buy" button grants it without Robux.
--
-- Nothing here is a random roll: every product gives exactly what it says.

return {
	StarterPack = {
		Key = "StarterPack",
		Name = "Starter Pack",
		Description = "2x Coins for 30 min, a Rare egg and 1,000 coins.",
		ProductId = 0,
		Price = 99,
		OneTime = true,
	},
}
