# Master Turtle: what changed from the zip

This pack unifies Daniel's `MasterTurtle.zip` (his programs plus
Inksaver's toolkit) into a public repo with a launcher, an updater, and
two version trees. Everything below is relative to the zip contents.

## Removed

- `tk.lua` (Inksaver's older toolkit): the version-detection bug
  (`mcMajorVersion < 1.7 and mcMajorVersion >= 1.18`, impossible, so the
  1.18+ bedrock/ceiling values and the 1.16+ nether brick name never
  applied) plus the stale-API rot made it unshippable. `tk3.lua` is the
  kept toolkit. The same impossible conditions existed in `tk3.lua`
  and were fixed there.
- `menu.old.lua`, `old_platform.lua`: superseded copies.
- `logs/`: runtime logs, not source.
- 17 dead functions with zero call sites anywhere in the tree
  (verified by grep before cutting): `U.charCount`, `U.deepCopyTable`,
  `U.padCenter`, `U.removeDigits`, `U.stackSize`, `U.findSmeltItem`,
  `U.getAvailable`, `U.getCategoryTable`, `U.getCurrentCursor`,
  `U.getEmptyChests`, `U.getInventoryContents`, `U.getItemCategory`,
  `U.getSlotOneContains`, `U.refineTemplate`, `U.emptySmelters`,
  `U.removeFromStorageFile` (all in `lib/TurtleUtils.lua`) and
  `getItemsForInventory` (in `tk3.lua`).
- 21 more `T:` methods in `lib/clsTurtle.lua` also have zero call sites
  (`setY`, `setZ`, `getCoords`, `getTotalItemCount`, `isAdvanced`,
  `getInventoryData`, etc.) but they look like public API Daniel may
  call interactively, so they were kept. List available on request.

## Fixed

- `cropper.lua` ended with a stray markdown ```` ``` ```` fence that
  made the whole file unparseable. Removed.
- `lib/clsTurtle.lua` `chestSort`: `until not success or message ~= nil`
  referenced an undefined global `message` (always nil, so the clause
  was dead). Now `until not success`, matching the identical loop
  elsewhere in the same file.
- Issue #9 (sortInventory chest use): the upstream fix (guard chest
  lookup behind `useChest`) was already present; confirmed, not
  re-applied.
- Issue #1 (menu nil text): the crashing path was tk.lua's task menu,
  which is cut. tk3's spawner tasks go through the scene UI, and
  `menu.lua`'s `colourText` already guards nil text.
- Issue #10 (`plantTreefarm`): it is an internal tk3 task function, not
  a standalone program; it runs from tk3's menu, not from the launcher.
- Issue #2 (updater): rewritten to install from
  `DaniCePe/Master-Turtle` (`main/1.12.x/` or `main/1.20.x/`). It can
  never overwrite our tree from Inksaver's repos again.
- `updater.lua` manifest now covers every shipped file, including the
  new `master.lua`, `startup.lua`, `move`/`turn`, `cc-ai`,
  `lib/Resume.lua`, `lib/allowedBlocks.lua`, `data.lua`, and the new
  scenes. Daniel's extensionless programs (`attack`, `buckRef`,
  `framer`, `trump`, `vacuum`) got `version =` headers so the updater's
  version check actually updates them. The quarry (third-party) is
  install-if-missing only, never modified.

## New: launcher

- `master.lua`: boots the GUI menu listing every shipped program.
  Keyboard (arrows/Enter/Q) and mouse. Programs needing dimensions get
  a prompt dialog first; answers become command-line args. `[LOOP]`
  tags the intentional run-until-stopped programs. The registry lives
  in `_G.MasterTurtle.programs`.
- `startup.lua`: boots `master.lua`. Quarry safety net: if
  `Civil_Quarry_Restore` exists but the quarry's own `startup` stub
  does not, it offers the resume (5-second window) instead of the menu.
- `scenes/Launcher.lua`, `scenes/Dimensions.lua`, `scenes/CCAI.lua`.
- cc-ai ships as the `cc-ai` program (verbatim upstream client) plus
  `optional/cc-ai/SERVER_SETUP.md` and `version.txt` (pinned commit).
  The launcher lists it only when the file exists.

## New: dimensions

Programs whose working size depends on the build now take optional
command-line args and prompt interactively when args are absent:

- quarry: `-dim L W H` (already had it; now in the GUI too)
- platformer: `-length -width -height -mode -inverted` (new)
- cropper, cluster, filler, vacuum: `-length -width` (new)
- trump: `-length -height -depth` (new)
- framer: `-size` (new)

Left hardcoded (fixed by game mechanics, not by the build):

- `flint`: processes one gravel per cycle by design.
- `buckRef` / `lavaRefuel`: refuel the turtle's own tank; no area.
- `go`, `data`: single interactions.
- `b/d/f/u/l/r/p/x`: you pass N every time; nothing to default.
- `chopchop`, `cranker`, `attack`, `cobble`: run-until-stopped loops
  with no area concept.

## New: resume library

- `lib/Resume.lua`: `save/load/clear` a state table plus
  `installBootResume`/`removeBootResume`, which manage an extensionless
  `startup` stub (takes boot precedence over our `startup.lua`) that
  re-runs the program with `-resume` after a 5-second abort window.
- Wired into `platformer`, `filler`, `cropper`, `cluster` as thin
  wrappers; their behavior is otherwise identical. Each keeps its own
  save-file name and migration of the old format.
- The quarry was deliberately NOT rewired: its resume serializes the
  whole global environment, which the generic library cannot do.

## Quarry resume: how it works (preserved exactly)

The crown jewel, untouched:

1. `saveProgress()` (every so often and on the way home) serializes the
   entire global environment into `Civil_Quarry_Restore` via
   `textutils.serialize(getfenv(1))`, after stamping a fuel nudge: the
   saved position is one step back along the dig path, so on resume the
   turtle re-verifies the block it was about to dig.
2. `-resume` does `os.run(getfenv(1), saveFile)`: executing the save
   file as code inside the live global env restores every variable,
   then replays the event queue so rednet/GPS state continues.
3. `-autoResume` writes the extensionless `startup` stub: on boot it
   gives a 5-second keypress window, then runs `quarry -resume`.
4. No GPS, no mods, no peripherals required. Position is dead-reckoned
   from the saved state.

Session persistence across crashes comes free: the save file is always
newer than the last reboot.

## Platformer v6.0 (builder)

Rewritten around the quarry's options pattern (CLI args with the same
`-flag value` style, interactive prompts otherwise, `-resume` support):

- Modes: `floor` (solid slab), `walls` (perimeter ring), `solid`
  (everything), `hollow` (solid top/bottom, walls between), `roof`
  (solid cap). `-height` sets layers; `-inverted` builds downward.
- `placeSmart()` picks up/down/forward placement; `changeLayer()`
  steps between layers; per-layer resume via the save file.
- v5 save files migrate automatically.
- The old behavior (clear a floor area) is `mode=floor`, the default.
- Build math (`shouldPlace`/`totalCells`) is brute-force cross-checked
  for all 5 modes over 40 dimension sets including 1-wide and 1x1x1.

## Move/turn consolidation

`b/d/f/u` are now one-line `shell.run("move", ...)` shims over the new
`move` program (b.lua's engine plus f.lua's `+-` above/below digging);
`l/r` are shims over the new `turn` program. Behavior identical,
`p.lua`/`x.lua` untouched.

## Version trees

`1.12.x` and `1.20.x` ship identical programs except `tk3.lua`, which
needs modern peripheral APIs (`peripheral.find` is function-scoped in
tk3, so it loads on 1.12 but its features need 1.20+). The launcher
hides the Toolkit entry when `tk3.lua` is absent. All other code is
5.1-compatible and shared.
