# Fling for Fossils (Roblox, Rojo)

README.md has the full file map ("Where things are") and play-test steps. Read that section instead of exploring the tree.

## Layout
- `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client (see `default.project.json`).
- The whole world is built in code (`MapService`). There's no place file to edit; `.rbxl` files are gitignored.

## Conventions
- **Services** (`src/server/Services`): a module table with optional `Init(Services)` and `Start()`. New services must be added to `ORDER` in `src/server/init.server.luau`.
- **Controllers** (`src/client/Controllers`) handle client UI and input.
- **Remotes**: add the name to `NAMES` *and* a line to the direction notes in `src/shared/Remotes.luau`. Use `Remotes.Get("Name")` on both sides.
- **Cross-service events** go through `src/server/Events.luau`. Document any new event in its header comment.
- **Tuning numbers** live in `src/shared/Config/*`, never hard-coded in services.
- **Player data** is read and changed only through `DataService`.
- **Studio-only test helpers** are gated by `RunService:IsStudio()` (see `Balance.Studio`).
- Every file starts with a short plain-language comment saying what it does. Keep it up to date.
- Formatting: tabs, double quotes, always use call parentheses (`stylua.toml`).

## Luau / Roblox
- Use `task.wait`, `task.spawn` and `task.delay`, never `wait`, `spawn` or `delay`.
- Use constraints (`LinearVelocity`, `AlignPosition`, `AlignOrientation`), not `BodyVelocity`, `BodyGyro` or other deprecated Body movers.
- Use `game:GetService(...)` and generalized iteration (`for _, x in t`), matching the existing code.
- Add type annotations where the surrounding code uses them.

## Security (keep this work with the main model, not helpers)
- The server is authoritative. Every roll, reward and purchase happens on the server; the client only sends intent ("I tapped the meter at X").
- In every `OnServerEvent` handler, check argument types and ranges, ownership, cooldowns and distance where relevant. Never trust client-sent coins, distances or results.
- Treat changes to `DataService`, `MonetizationService`, `StarterPackService`, `Meter.luau` and any Robux or receipt handling as high-risk. Review them carefully.

## Checks
- After editing Luau, run `stylua src` and `selene src`. The tools are in `~/.rokit/bin` if they aren't on PATH. If missing, run `rokit install`. Selene needs `selene generate-roblox-std` once first.
- After price or progression changes, mirror the prices at the top of `tools/curve_sim.py` and run `python3 tools/curve_sim.py`.
- Claude can't run Roblox Studio. After a change, tell me exactly what to play-test in Studio.

## Delegation for this project
- `grunt` (Haiku): adding entries to Config tables (dinos, quests, weapons, gifts) that follow an existing pattern, registering remote names, summarizing Studio Output logs I paste.
- `builder` (Sonnet): a new Controller or Service from a clear spec, or UI work.
- Main model: game design, balancing decisions, debugging, and everything in the Security section.
