-- Notify.luau
-- Sends toast messages to players. kind: "info" | "good" | "bad" | "epic"

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local Notify = {}

function Notify.Player(player: Player, text: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, text, kind or "info")
end

function Notify.All(text: string, kind: string?)
	Remotes.Get("Notify"):FireAllClients(text, kind or "info")
end

return Notify
