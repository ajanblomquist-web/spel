-- CodeService.luau
-- Redeems codes from the Shop's Codes box (see Config/Codes). Each code works
-- once per player; answers come back as toasts.
--
-- Saved data: data.Codes = { [CODE] = true }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage.Shared.Config.Codes)
local Notify = require(script.Parent.Parent.Notify)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CodeService = {}

local DataService, GiftService

local lastTry: { [Player]: number } = {}

local function normalize(text: string): string
	return string.upper((string.gsub(text, "%s", "")))
end

local byCode = {}
for _, entry in Codes do
	byCode[normalize(entry.Code)] = entry
end

local function redeem(player: Player, text: any)
	if type(text) ~= "string" or #text > 40 then
		return
	end
	local now = os.clock()
	if lastTry[player] and now - lastTry[player] < 2 then
		return
	end
	lastTry[player] = now
	local data = DataService.Get(player)
	if not data then
		return
	end
	local code = normalize(text)
	local entry = byCode[code]
	if not entry or (entry.Expires and os.time() > entry.Expires) then
		Notify.Player(player, "That code doesn't work. Check the spelling!", "bad")
		return
	end
	if data.Codes[code] then
		Notify.Player(player, "You already used " .. code .. "!", "bad")
		return
	end
	data.Codes[code] = true
	local got = GiftService.Grant(player, entry.Reward)
	DataService.SaveNow(player)
	Notify.Player(player, "Code " .. code .. ": you got " .. got .. "!", "epic")
end

function CodeService.Init(Services)
	DataService = Services.DataService
	GiftService = Services.GiftService
	DataService.OnRemoving(function(player)
		lastTry[player] = nil
	end)
end

function CodeService.Start()
	Remotes.Get("RedeemCode").OnServerEvent:Connect(redeem)
end

return CodeService
