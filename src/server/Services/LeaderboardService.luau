-- LeaderboardService.luau
-- Global leaderboards on big boards next to the launch pad, shared by every
-- server through OrderedDataStores:
--   * Top Thieves (this week)   eggs stolen from other players
--   * Top Diggers (this week)   eggs dug
--   * Top Collectors            Dino Index boxes (all time)
--   * Richest Nests             coins per second (all time)
--
-- Weeks start Monday 00:00 UTC; weekly boards use a fresh store each week, so
-- they reset by themselves. Scores upload every minute, boards refresh every
-- 90 seconds. If DataStores aren't available (Studio without API access), the
-- boards show the players in this server instead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Index = require(ReplicatedStorage.Shared.Config.Index)
local Events = require(script.Parent.Parent.Events)
local Visuals = require(script.Parent.Parent.Visuals)

local LeaderboardService = {}

local DataService, IncomeService, MapService

local UPLOAD_SECONDS = 60
local REFRESH_SECONDS = 90
local ROWS = 10
local WEEK_SECONDS = 7 * 24 * 3600
local WEEK_OFFSET = 4 * 24 * 3600 -- the Unix epoch was a Thursday; this makes weeks start on Monday

type Board = {
	Key: string,
	Title: string,
	Weekly: boolean,
	Unit: string,
	Color: Color3,
	Value: (Player, any) -> number,
	Position: Vector3,
	Rows: { TextLabel }?,
	Footer: TextLabel?,
}

local BOARDS: { Board } = {
	{
		Key = "Steals",
		Title = "TOP THIEVES\nthis week",
		Weekly = true,
		Unit = " steals",
		Color = Color3.fromRGB(235, 70, 70),
		Value = function(_, data)
			return data.Weekly.Steals
		end,
		Position = Vector3.new(-140, 0, 0),
	},
	{
		Key = "Eggs",
		Title = "TOP DIGGERS\nthis week",
		Weekly = true,
		Unit = " eggs",
		Color = Color3.fromRGB(255, 160, 40),
		Value = function(_, data)
			return data.Weekly.EggsDug
		end,
		Position = Vector3.new(-100, 0, 0),
	},
	{
		Key = "Index",
		Title = "TOP COLLECTORS\nDino Index",
		Weekly = false,
		Unit = " boxes",
		Color = Index.BabyColor,
		Value = function(_, data)
			return Index.Count(data.Index)
		end,
		Position = Vector3.new(100, 0, 0),
	},
	{
		Key = "Income",
		Title = "RICHEST NESTS\ncoins per second",
		Weekly = false,
		Unit = "/s",
		Color = Color3.fromRGB(255, 215, 70),
		Value = function(player)
			return math.floor(IncomeService.Total(player))
		end,
		Position = Vector3.new(140, 0, 0),
	},
}

local RANK_COLORS = {
	Color3.fromRGB(255, 215, 70),
	Color3.fromRGB(210, 210, 225),
	Color3.fromRGB(215, 140, 80),
}

local storesWork = true
local lastUploaded: { [Player]: { [string]: number } } = {}
local nameCache: { [number]: string } = {}

function LeaderboardService.CurrentWeek(): number
	return math.floor((os.time() - WEEK_OFFSET) / WEEK_SECONDS)
end

local function storeFor(board: Board): OrderedDataStore?
	if not storesWork then
		return nil
	end
	local name = Balance.DataStoreName .. "_LB_" .. board.Key
	if board.Weekly then
		name ..= "_W" .. LeaderboardService.CurrentWeek()
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if not ok then
		storesWork = false
		return nil
	end
	return store
end

-- Resets the weekly counters when a new week has started.
local function weeklyData(data)
	local week = LeaderboardService.CurrentWeek()
	if data.Weekly.Week ~= week then
		data.Weekly.Week = week
		data.Weekly.Steals = 0
		data.Weekly.EggsDug = 0
	end
	return data.Weekly
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok and name then name else "Player"
	return nameCache[userId]
end

local function upload(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	weeklyData(data)
	lastUploaded[player] = lastUploaded[player] or {}
	for _, board in BOARDS do
		local value = math.floor(board.Value(player, data))
		local key = board.Key .. (if board.Weekly then "_W" .. data.Weekly.Week else "")
		if value > 0 and lastUploaded[player][key] ~= value then
			local store = storeFor(board)
			if store then
				local ok, err = pcall(function()
					store:SetAsync(tostring(player.UserId), value)
				end)
				if ok then
					lastUploaded[player][key] = value
				else
					warn("[LeaderboardService] Upload failed: " .. tostring(err))
				end
			end
		end
	end
end

-- Top scores: { { Name, Value } }, from the global store or this server.
local function fetch(board: Board): { { Name: string, Value: number } }
	local store = storeFor(board)
	if store then
		local ok, result = pcall(function()
			local pages = store:GetSortedAsync(false, ROWS)
			return pages:GetCurrentPage()
		end)
		if ok then
			local list = {}
			for _, entry in result do
				table.insert(list, { Name = nameOf(tonumber(entry.key) or 0), Value = entry.value })
			end
			return list
		end
		warn("[LeaderboardService] Fetch failed, showing this server only: " .. tostring(result))
		-- In Studio this usually means API access is off; stop trying. Live servers retry next time.
		if RunService:IsStudio() then
			storesWork = false
		end
	end
	local list = {}
	for _, player in DataService.LoadedPlayers() do
		local data = DataService.Get(player)
		if data then
			weeklyData(data)
			local value = math.floor(board.Value(player, data))
			if value > 0 then
				table.insert(list, { Name = player.DisplayName, Value = value })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	while #list > ROWS do
		table.remove(list)
	end
	return list
end

local function resetText(): string
	local nextWeek = (LeaderboardService.CurrentWeek() + 1) * WEEK_SECONDS + WEEK_OFFSET
	local left = nextWeek - os.time()
	local days = math.floor(left / 86400)
	local hours = math.floor((left % 86400) / 3600)
	return "Resets in " .. days .. "d " .. hours .. "h"
end

local function render(board: Board)
	if not board.Rows then
		return
	end
	local list = fetch(board)
	for i, label in board.Rows do
		local entry = list[i]
		if entry then
			label.Text = i .. ". " .. entry.Name .. "   " .. FormatNumber(entry.Value) .. board.Unit
		else
			label.Text = i .. ". -"
		end
	end
	if board.Footer then
		board.Footer.Text = if board.Weekly
			then resetText()
			elseif storesWork then "All servers"
			else "This server (global boards need API access)"
	end
end

local function build(board: Board, parent: Instance)
	local size = Vector3.new(26, 22, 1)
	local part = Visuals.Part({
		Name = "Leaderboard_" .. board.Key,
		Size = size,
		Position = board.Position + Vector3.new(0, size.Y / 2 + 2, 0),
		Color = Color3.fromRGB(40, 34, 50),
	})
	part.Parent = parent
	for _, side in { -1, 1 } do
		Visuals.Part({
			Name = "Post",
			Size = Vector3.new(1.2, 2, 1.2),
			Position = board.Position + Vector3.new(side * (size.X / 2 - 2), 1, 0),
			Color = Color3.fromRGB(90, 60, 40),
		}).Parent =
			part
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- faces the hub (-Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = part

	local function text(props): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		for key, value in props do
			(label :: any)[key] = value
		end
		label.Parent = gui
		return label
	end

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.2, 0)
	header.BackgroundColor3 = board.Color
	header.BorderSizePixel = 0
	header.Parent = gui
	text({ Size = UDim2.new(1, -20, 0.2, -10), Position = UDim2.new(0, 10, 0, 5), Text = board.Title })

	local rows = {}
	local rowHeight = 0.7 / ROWS
	for i = 1, ROWS do
		table.insert(
			rows,
			text({
				Position = UDim2.new(0.05, 0, 0.21 + (i - 1) * rowHeight, 0),
				Size = UDim2.new(0.9, 0, rowHeight, -4),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = RANK_COLORS[i] or Color3.new(1, 1, 1),
				Text = i .. ". -",
			})
		)
	end
	board.Rows = rows
	board.Footer = text({
		Position = UDim2.new(0.05, 0, 0.92, 0),
		Size = UDim2.new(0.9, 0, 0.07, 0),
		TextColor3 = Color3.fromRGB(190, 190, 205),
		Text = "",
	})
end

function LeaderboardService.Init(Services)
	DataService = Services.DataService
	IncomeService = Services.IncomeService
	MapService = Services.MapService

	DataService.OnLoaded(function(_, data)
		weeklyData(data)
	end)
	DataService.OnRemoving(function(player)
		task.spawn(upload, player)
		lastUploaded[player] = nil
	end)
	Events.On("Steal", function(player, _egg, fromNpc)
		local data = DataService.Get(player)
		if data and not fromNpc then
			weeklyData(data).Steals += 1
		end
	end)
	Events.On("Dig", function(player)
		local data = DataService.Get(player)
		if data then
			weeklyData(data).EggsDug += 1
		end
	end)
end

function LeaderboardService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = MapService.Folder()
	for _, board in BOARDS do
		build(board, folder)
	end

	task.spawn(function()
		while true do
			for _, player in DataService.LoadedPlayers() do
				task.spawn(upload, player)
			end
			task.wait(UPLOAD_SECONDS)
		end
	end)
	task.spawn(function()
		task.wait(5) -- let the first uploads land
		while true do
			for _, board in BOARDS do
				render(board)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
