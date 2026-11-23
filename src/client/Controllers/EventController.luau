-- EventController.luau
-- A pill under the top bar while a server event runs: "DOUBLE LUCK 7:42".
-- The start banner comes from RevealController (Celebrate "Event").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldEvents = require(ReplicatedStorage.Shared.Config.WorldEvents)

local EventController = {}

function EventController.Start(Controllers)
	local UI = Controllers.UIController
	local pill = UI.Make("Frame", {
		Name = "EventPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(280, 34),
		BackgroundColor3 = UI.Colors.Orange,
		Visible = false,
		Parent = UI.Gui(),
	}, { UI.Corner(17), UI.Stroke(2) })
	local label = UI.Label({
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -16, 1, -6),
		Text = "",
		Parent = pill,
	})

	task.spawn(function()
		while true do
			local event = WorldEvents.ById[Workspace:GetAttribute("EventId") or ""]
			local left = (Workspace:GetAttribute("EventEndsAt") or 0) - Workspace:GetServerTimeNow()
			if event and left > 0 then
				pill.Visible = true
				pill.BackgroundColor3 = event.Color
				label.Text =
					string.format("%s  %d:%02d", event.Name, math.floor(left / 60), math.floor(left % 60))
			else
				pill.Visible = false
			end
			task.wait(0.5)
		end
	end)
end

return EventController
