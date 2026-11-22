-- Events.luau
-- A tiny event bus so gameplay services can announce what happened
-- ("Hatch", "Fling", ...) and QuestService can listen without everything
-- depending on everything else.
--
-- Events used:
--   TrainRep (player, gain)
--   Fling    (player, distance, zoneId, grade)     grade = "Perfect" | "Great" | "Miss"
--   Dig      (player, egg)
--   Deliver  (player, egg)
--   Hatch    (player, record)
--   Steal    (player, egg, fromNpc)
--   LockNest (player)
--   Buy      (player, category, tier)               category = "Rocks" | "Shovels"

local Events = {}

local listeners: { [string]: { (...any) -> () } } = {}

function Events.On(name: string, callback: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

function Events.Fire(name: string, ...: any)
	for _, callback in listeners[name] or {} do
		task.spawn(callback, ...)
	end
end

return Events
