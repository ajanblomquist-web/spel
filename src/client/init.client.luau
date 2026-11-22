-- Client entry point. Starts each controller in order.

local Controllers = {}
local ORDER = {
	"UIController",
	"WorldController",
	"RevealController",
	"QuestController",
	"TrainingController",
	"FlingController",
}

for _, name in ORDER do
	Controllers[name] = require(script.Controllers[name])
end
for _, name in ORDER do
	Controllers[name].Start(Controllers)
end
