-- IndexController.luau
-- The Dino Index button and panel. A tab per rarity page along the top (with a
-- found count or a tick), opening on the first page that isn't complete. Each
-- page has a progress bar with the page reward, then dinos found everywhere and
-- one quiet section per zone you've reached. A row is the dino's name (rarity
-- colour, or "???" in grey until found) plus three round chips: Gold, Rainbow
-- and Baby, dim until ticked. Zones you haven't reached collapse into one
-- "locked" line; a secret zone is never named or counted until reached. The
-- server sends the reached zones as the third IndexSync argument. A "NEW"
-- badge shows on the button when you've ticked boxes since you last looked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Index = require(ReplicatedStorage.Shared.Config.Index)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local player = Players.LocalPlayer

local IndexController = {}

local UI
local button: TextButton
local badge: TextLabel
local panel: Frame
local list: ScrollingFrame
local tabBar: Frame
local selected: string? = nil -- rarity id of the open page

local entries = {} -- { [dinoId] = { [variantId] = true } }
local pagesDone = {} -- { [rarityId] = true }
local reached = {} -- { [zoneId] = true } zones the player has reached (from the server)
local secretZones = {} -- { [zoneId] = true }
local lastSeenCount: number? = nil

local render: () -> ()

-- Short tab names so seven tabs fit on a phone.
local TAB_NAMES = { Uncommon = "Uncom.", Legendary = "Legend." }

local BOX_OFF = Color3.fromRGB(55, 50, 68)
local CHIP_SIZE, CHIP_GAP = 26, 6
local CHIPS_WIDTH = CHIP_SIZE * 3 + CHIP_GAP * 2

local function zoneName(zoneId: string): string
	for _, zone in Zones.List do
		if zone.Id == zoneId then
			return zone.Name
		end
	end
	return zoneId
end

local function clearList()
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function isFound(dino): boolean
	return entries[dino.Id] ~= nil and entries[dino.Id].Found == true
end

-- A dino is listed when you can work towards it (its zone is reached or it has
-- no zone) or when you already own it. Everything else is "locked".
local function isShown(dino): boolean
	return dino.Zone == nil or reached[dino.Zone] == true or isFound(dino)
end

-- The dinos of a page you can see, and how many are still locked away. Locked
-- dinos of a secret zone aren't counted until the zone is reached.
local function pageDinos(page): ({ any }, number)
	local shown, locked = {}, 0
	for _, dino in page.Dinos do
		if isShown(dino) then
			table.insert(shown, dino)
		elseif not (secretZones[dino.Zone] == true) then
			locked += 1
		end
	end
	return shown, locked
end

local function pageFound(dinos): number
	local found = 0
	for _, dino in dinos do
		if isFound(dino) then
			found += 1
		end
	end
	return found
end

-- Pages with nothing to work towards yet stay hidden (so the Secret page
-- stays hidden until you've hatched one of its dinos).
local function pageVisible(page): boolean
	return #(pageDinos(page)) > 0
end

local function visiblePages()
	local pages = {}
	for _, page in Index.Pages do
		if pageVisible(page) then
			table.insert(pages, page)
		end
	end
	return pages
end

-- Boxes ticked / boxes you can work towards, over the pages you can see.
local function boxTotals(pages): (number, number)
	local have, total = 0, 0
	for _, page in pages do
		for _, dino in (pageDinos(page)) do
			total += #Index.Variants
			for _, variant in Index.Variants do
				if entries[dino.Id] and entries[dino.Id][variant.Id] then
					have += 1
				end
			end
		end
	end
	return have, total
end

-- One quiet line: boxes found and the current Baby odds.
local function header(order: number, pages)
	local have, total = boxTotals(pages)
	local luck = player:GetAttribute("BabyLuck") or 1
	local odds = math.floor(1 / (Index.BabyChance * luck))
	UI.Label({
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 22),
		Text = have .. " / " .. total .. " boxes  -  Baby odds 1 in " .. FormatNumber(odds),
		TextColor3 = UI.Colors.Sand,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = list,
	})
end

-- Progress bar for the open page: "Found 5 / 9", the page reward, a tick when done.
local function progressBar(order: number, page, dinos)
	local rarity = Eggs.RarityById[page.Rarity]
	local found = pageFound(dinos)
	local done = pagesDone[page.Rarity] == true
	local fraction = if #dinos > 0 then math.clamp(found / #dinos, 0, 1) else 0
	local frame = UI.Make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 44),
		BackgroundColor3 = UI.Colors.PanelLight,
		ZIndex = 12,
		Parent = list,
	}, { UI.Corner(12) })
	UI.Label({
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(0.5, -12, 0, 20),
		Text = (if done then "✓ " else "") .. "Found " .. found .. " / " .. #dinos,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
	UI.Label({
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.5, -12, 0, 20),
		Text = if done
			then "✓ Page complete"
			else "Page reward: +" .. FormatNumber(Index.PageCoins[page.Rarity] or 0) .. " 🪙",
		TextColor3 = if done then UI.Colors.Coins else UI.Colors.Sand,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 13,
		Parent = frame,
	})
	local track = UI.Make("Frame", {
		Position = UDim2.new(0, 12, 0, 29),
		Size = UDim2.new(1, -24, 0, 8),
		BackgroundColor3 = UI.Colors.PanelDark,
		ZIndex = 13,
		Parent = frame,
	}, { UI.Corner(4) })
	UI.Make("Frame", {
		Size = UDim2.fromScale(fraction, 1),
		BackgroundColor3 = rarity.Color,
		ZIndex = 14,
		Parent = track,
	}, { UI.Corner(4) })
end

-- One compact row: the name on the left, three small round chips on the right.
local function dinoRow(order: number, dino)
	local row = entries[dino.Id] or {}
	local known = row.Found == true
	local rarity = Eggs.RarityById[dino.Rarity]
	local frame = UI.Make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 34),
		BackgroundColor3 = UI.Colors.PanelLight,
		ZIndex = 12,
		Parent = list,
	}, { UI.Corner(10) })
	UI.Label({
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -(CHIPS_WIDTH + 28), 1, -10),
		Text = if known then dino.Name else "???",
		TextColor3 = if known then rarity.Color else Color3.fromRGB(150, 150, 160),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
	local chips = UI.Make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(CHIPS_WIDTH, CHIP_SIZE),
		BackgroundTransparency = 1,
		ZIndex = 13,
		Parent = frame,
	}, {
		UI.Make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, CHIP_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, variant in Index.Variants do
		if variant.Id ~= "Found" then
			local have = row[variant.Id] == true
			UI.Make("TextLabel", {
				LayoutOrder = i,
				Size = UDim2.fromOffset(CHIP_SIZE, CHIP_SIZE),
				BackgroundColor3 = if have then variant.Color else BOX_OFF,
				BackgroundTransparency = if have then 0 else 0.3,
				Font = UI.Font,
				Text = variant.Icon,
				TextTransparency = if have then 0 else 0.7,
				TextScaled = true,
				ZIndex = 14,
				Parent = chips,
			}, {
				UI.Corner(CHIP_SIZE / 2),
				UI.Make("UIPadding", {
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				}),
			})
		end
	end
end

-- A small, quiet label that starts a group of rows.
local function subHeader(order: number, text: string)
	UI.Label({
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 18),
		Text = string.upper(text),
		TextColor3 = Color3.fromRGB(190, 175, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = list,
	})
end

-- Opens on the first page you haven't finished.
local function defaultPage(pages): string
	for _, page in pages do
		if not pagesDone[page.Rarity] then
			return page.Rarity
		end
	end
	return pages[1].Rarity
end

local function renderTabs(pages)
	for _, child in tabBar:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for i, page in pages do
		local rarity = Eggs.RarityById[page.Rarity]
		local done = pagesDone[page.Rarity] == true
		local open = page.Rarity == selected
		local dinos = pageDinos(page)
		local tab = UI.Make("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(1 / #pages, -4, 1, if open then 0 else -6),
			BackgroundColor3 = rarity.Color,
			AutoButtonColor = true,
			Font = UI.Font,
			Text = (TAB_NAMES[page.Rarity] or page.Rarity) .. "\n" .. (if done
				then "✓"
				else pageFound(dinos) .. "/" .. #dinos),
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.3,
			ZIndex = 13,
			Parent = tabBar,
		}, {
			UI.Corner(10),
			UI.Stroke(
				if open then 3 else 1,
				if open then Color3.new(1, 1, 1) else Color3.fromRGB(30, 25, 40)
			),
			UI.Make("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
			}),
		})
		tab.Activated:Connect(function()
			selected = page.Rarity
			list.CanvasPosition = Vector2.zero
			render()
		end)
	end
end

function render()
	if not list then
		return
	end
	clearList()
	local pages = visiblePages()
	if #pages == 0 then
		renderTabs(pages)
		return
	end
	local page
	for _, p in pages do
		if p.Rarity == selected then
			page = p
		end
	end
	if not page then
		selected = defaultPage(pages)
		return render()
	end
	renderTabs(pages)

	local dinos, locked = pageDinos(page)
	local order = 1
	header(order, pages)
	order += 1
	progressBar(order, page, dinos)

	-- Dinos found everywhere first, then a section per reached zone.
	local groups, zoneOrder = { [""] = {} }, {}
	for _, dino in dinos do
		local key = dino.Zone or ""
		if not groups[key] then
			groups[key] = {}
			table.insert(zoneOrder, key)
		end
		table.insert(groups[key], dino)
	end
	if #groups[""] > 0 then
		order += 1
		subHeader(order, "Found everywhere")
		for _, dino in groups[""] do
			order += 1
			dinoRow(order, dino)
		end
	end
	for _, zoneId in zoneOrder do
		order += 1
		subHeader(order, zoneName(zoneId))
		for _, dino in groups[zoneId] do
			order += 1
			dinoRow(order, dino)
		end
	end
	if locked > 0 then
		order += 1
		UI.Label({
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 26),
			Text = "🔒 "
				.. locked
				.. (if locked == 1 then " more dino" else " more dinos")
				.. " in zones you haven't reached",
			TextColor3 = Color3.fromRGB(150, 140, 130),
			ZIndex = 12,
			Parent = list,
		})
	end
end

local function refreshButton()
	local count = Index.Count(entries)
	button.Text = "Index\n" .. (player:GetAttribute("IndexPercent") or 0) .. "%"
	-- Hidden during the tutorial so new players see one thing at a time.
	button.Visible = not player:GetAttribute("QuestTutorial")
	badge.Visible = lastSeenCount ~= nil and count > lastSeenCount and not panel.Visible
end

local function build()
	local gui = UI.Gui()
	button = UI.Button({
		Name = "Index",
		Position = UDim2.fromOffset(10, 266),
		Size = UDim2.fromOffset(86, 86),
		Text = "Index",
		BackgroundColor3 = Color3.fromRGB(200, 90, 160),
		Parent = gui,
	})
	badge = UI.Make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(50, 26),
		BackgroundColor3 = UI.Colors.Red,
		Font = UI.Font,
		Text = "NEW",
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = button,
	}, { UI.Corner(10), UI.Stroke(2) })

	panel, list = UI.BuildPanel("IndexPanel", "Dino Index")
	-- Rarity tabs between the title and the list.
	list.Position = UDim2.fromOffset(14, 130)
	list.Size = UDim2.new(1, -28, 1, -144)
	tabBar = UI.Make("Frame", {
		Position = UDim2.fromOffset(14, 68),
		Size = UDim2.new(1, -28, 0, 56),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = panel,
	}, {
		UI.Make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	button.Activated:Connect(function()
		UI.TogglePanel(panel)
		if panel.Visible then
			lastSeenCount = Index.Count(entries)
			selected = nil -- open on the first page that isn't complete
			list.CanvasPosition = Vector2.zero
			render()
		end
		refreshButton()
	end)
end

function IndexController.Start(Controllers)
	UI = Controllers.UIController
	for _, zone in Zones.List do
		if zone.StartDistance == 0 then
			reached[zone.Id] = true -- the starting zone is always open
		end
		if zone.Secret then
			secretZones[zone.Id] = true
		end
	end
	build()
	refreshButton()

	Remotes.Get("IndexSync").OnClientEvent:Connect(function(newEntries, newPages, newZones)
		local before = Index.Count(entries)
		entries = newEntries or {}
		pagesDone = newPages or {}
		reached = {}
		if type(newZones) == "table" then
			for _, zoneId in newZones do
				reached[zoneId] = true
			end
		end
		if lastSeenCount == nil then
			lastSeenCount = Index.Count(entries) -- first sync: nothing is "new" yet
		elseif Index.Count(entries) > before then
			local scale = button:FindFirstChildOfClass("UIScale") or UI.Make("UIScale", { Parent = button })
			scale.Scale = 1.25
			TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		if panel.Visible then
			lastSeenCount = Index.Count(entries)
			render()
		end
		refreshButton()
	end)
	for _, attribute in { "IndexPercent", "QuestTutorial", "BabyLuck" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshButton)
	end
end

return IndexController
