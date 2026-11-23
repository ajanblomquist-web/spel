-- IndexController.luau
-- The Dino Index button and panel. A tab per rarity page along the top; each
-- page splits into dinos found everywhere and one section per zone with its
-- own dinos. One row per
-- dino, one box per variant (lit when you've hatched it). Dinos you haven't
-- found yet show as "???", and the Secret page is hidden until you find one. A "NEW" badge shows on the button when you've
-- ticked boxes since you last looked.

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
local lastSeenCount: number? = nil

local render: () -> ()

-- Short tab names so seven tabs fit on a phone.
local TAB_NAMES = { Uncommon = "Uncom.", Legendary = "Legend." }

local BOX_OFF = Color3.fromRGB(55, 50, 68)

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

-- The Secret page stays hidden until you've hatched one of its dinos.
local function pageVisible(page): boolean
	if page.Rarity ~= "Secret" then
		return true
	end
	for _, dino in page.Dinos do
		if entries[dino.Id] and entries[dino.Id].Found then
			return true
		end
	end
	return false
end

local function visibleTotal(): number
	local total = 0
	for _, page in Index.Pages do
		if pageVisible(page) then
			total += #page.Dinos * #Index.Variants
		end
	end
	return total
end

local function header(order: number)
	local count = Index.Count(entries)
	local luck = player:GetAttribute("BabyLuck") or 1
	local odds = math.floor(1 / (Index.BabyChance * luck))
	local frame = UI.Make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 56),
		BackgroundColor3 = UI.Colors.PanelLight,
		ZIndex = 12,
		Parent = list,
	}, { UI.Corner(14) })
	UI.Label({
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 26),
		Text = count .. " / " .. visibleTotal() .. " boxes found",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
	UI.Label({
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "Baby odds: 1 in " .. FormatNumber(odds) .. "  (complete pages to improve)",
		TextColor3 = Index.BabyColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
end

local function pageHeader(order: number, page)
	local rarity = Eggs.RarityById[page.Rarity]
	local found = 0
	for _, dino in page.Dinos do
		if entries[dino.Id] and entries[dino.Id].Found then
			found += 1
		end
	end
	local done = pagesDone[page.Rarity] == true
	local reward = if done
		then "Page complete!"
		else "Find all: +" .. FormatNumber(Index.PageCoins[page.Rarity] or 0) .. " coins & better Baby odds"
	local frame = UI.Make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 50),
		BackgroundColor3 = rarity.Color,
		ZIndex = 12,
		Parent = list,
	}, { UI.Corner(14), UI.Stroke(3) })
	UI.Label({
		Position = UDim2.fromOffset(12, 2),
		Size = UDim2.new(1, -24, 0, 26),
		Text = string.upper(page.Rarity) .. "  " .. found .. "/" .. #page.Dinos,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
	UI.Label({
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 18),
		Text = reward,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
end

local function dinoRow(order: number, dino)
	local row = entries[dino.Id] or {}
	local known = row.Found == true
	local title = if known then dino.Name else "???"
	local frame = UI.Make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 72),
		BackgroundColor3 = UI.Colors.PanelLight,
		ZIndex = 12,
		Parent = list,
	}, { UI.Corner(14) })
	UI.Label({
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 26),
		Text = title,
		TextColor3 = if known then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 160),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
	local boxes = UI.Make("Frame", {
		Position = UDim2.fromOffset(10, 36),
		Size = UDim2.new(1, -20, 0, 28),
		BackgroundTransparency = 1,
		ZIndex = 13,
		Parent = frame,
	}, {
		UI.Make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, variant in Index.Variants do
		local have = row[variant.Id] == true
		UI.Make("TextLabel", {
			LayoutOrder = i,
			Size = UDim2.new(1 / #Index.Variants, -4, 1, 0),
			BackgroundColor3 = if have then variant.Color else BOX_OFF,
			Font = UI.Font,
			Text = variant.Short,
			TextScaled = true,
			TextColor3 = if have then Color3.new(1, 1, 1) else Color3.fromRGB(120, 115, 135),
			ZIndex = 14,
			Parent = boxes,
		}, {
			UI.Corner(8),
			UI.Make("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
			}),
		})
	end
end

-- A thin label that starts a group of rows ("Found everywhere", "Amber Cliffs only").
local function subHeader(order: number, text: string)
	UI.Label({
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 26),
		Text = text,
		TextColor3 = Color3.fromRGB(210, 205, 225),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = list,
	})
end

local function pageFound(page): number
	local found = 0
	for _, dino in page.Dinos do
		if entries[dino.Id] and entries[dino.Id].Found then
			found += 1
		end
	end
	return found
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
		local tab = UI.Make("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(1 / #pages, -4, 1, if open then 0 else -6),
			BackgroundColor3 = rarity.Color,
			AutoButtonColor = true,
			Font = UI.Font,
			Text = (TAB_NAMES[page.Rarity] or page.Rarity) .. "\n" .. (if done
				then "DONE"
				else pageFound(page) .. "/" .. #page.Dinos),
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

	local order = 1
	header(order)
	order += 1
	pageHeader(order, page)

	-- Dinos found everywhere first, then a section per zone with its own dinos.
	local groups, zoneOrder = { [""] = {} }, {}
	for _, dino in page.Dinos do
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
		subHeader(order, zoneName(zoneId) .. " only")
		for _, dino in groups[zoneId] do
			order += 1
			dinoRow(order, dino)
		end
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
			render()
		end
		refreshButton()
	end)
end

function IndexController.Start(Controllers)
	UI = Controllers.UIController
	build()
	refreshButton()

	Remotes.Get("IndexSync").OnClientEvent:Connect(function(newEntries, newPages)
		local before = Index.Count(entries)
		entries = newEntries or {}
		pagesDone = newPages or {}
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
