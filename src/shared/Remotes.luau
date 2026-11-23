-- Remotes.luau
-- One place that lists every RemoteEvent. The server creates them on start;
-- the client waits for them. Use Remotes.Get("Name") on either side.
--
-- Direction notes:
--   Train          client -> server   do one training rep
--   StartFling     client -> server   start the timing meter ({ auto = true } for Auto Fling)
--   StopFling      client -> server   meter value 0..1 where the player tapped
--   FlingResult    server -> all      a shovel flight to animate
--   BuyUpgrade     client -> server   ("Rocks" | "Shovels", tier)
--   LockNest       client -> server   lock your incubators against thieves
--   Notify         server -> client   toast message (text, kind)
--   OfflineEarned  server -> client   (coins, seconds) welcome-back popup
--   StudioSetPass  client -> server   Studio only: toggle a pass for testing
--   Hatched        server -> client   (record, incomePerSecond, isFirst) for the hatch reveal
--   Celebrate      server -> client   (kind, data) big moments: "NewZone", "Breakthrough", "Quest"
--   ClaimGift      client -> server   claim a playtime gift (index)
--   StudioBuyProduct client -> server Studio only: grant a developer product for testing
--   IndexSync      server -> client   (index, pagesDone) the player's whole Dino Index
--   BuyWeapon      client -> server   (weaponId) buy a coin weapon
--   EquipWeapon    client -> server   (weaponId)
--   EquipSkin      client -> server   (skinId or nil)
--   Bonk           client -> server   (victim) bonk an egg carrier
--                  server -> all      (attacker, victim, direction) play the hit
--   Hint           server -> client   (text, passKey or "Group") a pass hint card
--   GroupCheck     client -> server   re-check group membership after the join prompt
--   Rebirth        client -> server   rebirth (pay coins, reset, get permanent bonuses)
--   ClaimDaily     client -> server   claim today's login streak reward
--   RedeemCode     client -> server   redeem a code from the Shop's Codes box

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Train",
	"StartFling",
	"StopFling",
	"FlingResult",
	"BuyUpgrade",
	"LockNest",
	"Notify",
	"OfflineEarned",
	"StudioSetPass",
	"Hatched",
	"Celebrate",
	"ClaimGift",
	"StudioBuyProduct",
	"IndexSync",
	"BuyWeapon",
	"EquipWeapon",
	"EquipSkin",
	"Bonk",
	"Hint",
	"GroupCheck",
	"Rebirth",
	"ClaimDaily",
	"RedeemCode",
}

local FOLDER_NAME = "Remotes"

local Remotes = {}

function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup is server only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.Get(name: string): RemoteEvent
	assert(table.find(NAMES, name), "Unknown remote: " .. name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
