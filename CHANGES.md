# Master Turtle: what changed from the zip

This pack unifies Daniel's `MasterTurtle.zip` (his programs plus
Inksaver's toolkit) into a public repo with a launcher, an updater, and
two version trees. Everything below is relative to the zip contents.

## v1.2 (2026-10-13): loop starter prompts, tags, refuel

Autonomy rule: every question is answered once at the startup prompt.
Mid-run, the turtle never waits for input. Only the movers (vacuum,
cluster, cropper) get fuel questions; turning, attacking, and placing
cost no fuel. chopchop and cranker are untouched.

- New `lib/LoopSetup.lua` (both trees): options-driven starter prompt.
  Prints a usage blurb, then asks only what each program needs: trash
  side + item-ID tags, dump side, burn-found-fuel yes/no, fuel tags,
  lava source (side at start, and/or below while traveling; never
  above). Comma-separated tags, substring matched. Also provides shared
  `dropToward` / `findSide` helpers used by attack and cobble.
- New `lib/LoopFuel.lua` (both trees): quarry-inspired refuel for the
  roamers. `ensure` burns tagged fuel one item at a time until the fuel
  target is met (never burns untagged items); `stage` consolidates
  found fuel into the bucket slot so dumps never throw it away;
  `fillFrom` / `fillAtStart` handle the lava bucket workflow (empty
  bucket + lava -> fill, then burn). Slot 16 rule: a bucket there
  means the lava workflow, an empty slot may stage found fuel.
- `attack` v2.2: trash side + trash tags prompt. Tagged loot goes to
  the trash side; everything else to the auto-detected chest. The trash
  side is excluded from chest detection for that run, so a chest on the
  trash side is never mistaken for the dump chest.
- `cobble` v5.1: dump-side prompt (front excluded, it is the mining
  face). Cobblestone, stone, basalt, and obsidian go to the detected
  chest; anything else goes to the dump side instead of clogging the
  inventory. Dump side excluded from chest detection. Also fixes the
  missed v1.1 stop upgrade: Q / Enter / Ctrl+T now stop cleanly.
- `vacuum` v1.1: checks below for a chest/barrel on every cell and
  dumps on find (fuel/bucket slot excluded). Refuels via LoopFuel when
  empty instead of digging forever: burns tagged fuel found anywhere,
  refills the bucket from the stated lava side at start or lava below
  while traveling.
- `cluster` v4.3: same dump and fuel treatment as vacuum. Setup
  answers are saved in the restore file, so resumes never re-ask.
- `cropper` v0.4: same dump and fuel treatment as vacuum. Stop now
  preserves the save (like cluster) instead of wiping it; single Q or
  Ctrl+T.

## Planned (not yet built)

- Opportunistic lava refills for the roaming loop programs (vacuum,
  cluster, cropper): while traveling, if the block below is a lava
  source and slot 16 holds an empty bucket, pause, fill the bucket,
  and burn it for fuel. The stated lava source at the start position
  remains the primary refill; this is the opportunistic backup.
- Turtle interaction pause: if possible, detect when a player
  right-clicks the turtle (opening its menu) and pause all movement and
  actions until the menu closes, giving the user a chance to stop the
  turtle before it leaves reach. Feasibility not yet confirmed.

## v1.1 (2026-10-12): Daniel's answers round 1

- `os.epoch("utc")` in the cc-ai client: verified empirically under
  ComputerCraft 1.80pr1 (the 1.12.x target) via CCEmuX; it exists and
  returns a millisecond timestamp. No fallback needed, nothing changed.
- Platformer roof mode reworked to Daniel's spec (v6.1): start at any
  level, give `-height N` as blocks-up, the turtle ascends N blocks,
  lays one flat LxW roof, descends back to its start level (stepping
  off the footprint first so it never digs through its own roof).
  `-inverted` roof places the ceiling upward from the start level with
  no climbing. Resume-aware throughout.
- Quarry vs upstream 3.7.0 Beta: ported `paramAlias("autoResume",
  "autoRestore")`, the sorted precise-totals end display (the flag
  previously tracked exact totals but never showed them), and a missing
  trailing newline. Deliberately skipped: the rewritten help browser
  (ours works; large UI rewrite, not a fix), `quarryConfig.qc`
  auto-load (uncertain resume interaction), `preciseTotals` default
  flip to true (behavior change). Resume system verified
  byte-identical between versions; untouched.
- tk3 vs upstream (20260526): no ports. Upstream still has the
  impossible version conditions we fixed, and its 410 diverging hunks
  are design/version differences, not clear bug fixes. Its 10 new
  functions (composter, createClayfarm, createDiveColumn, findSeabed,
  makeMud, createBubbleLiftOLD, utils.createBasement,
  utils.getRoofStats, utils.getItemsForInventory, utils.logRvalues)
  are available on request.
- Graceful stop for every `[LOOP]` program (chopchop, cranker, attack,
  vacuum, cluster): Q or Ctrl+T now stops cleanly (previously Enter
  only, and Ctrl+T was ignored). Cluster saves its resume state on
  stop instead of wiping it; the 3-second hold-Q is gone.
- Self-update URLs: `go.lua`, `lavaRefuel.lua`, and `tk3.lua` had
  runtime fallbacks downloading from Inksaver's GitHub; all repointed
  to `DaniCePe/Master-Turtle/main/<tree>/`. No runtime references to
  Inksaver's raw URLs remain (comment examples untouched).
- Quarry Lua 5.2 fix (1.20.x; no-op on 1.12.x): the
  `disable_lua51_features` config toggle was removed in CC:Tweaked
  1.108.4, and on 1.109+ `setfenv(1, ...)` throws instead of sandboxing
  the program, so the quarry could not start at all on modern
  CC:Tweaked. The fix is in the quarry itself: a top-of-file shim
  restores `loadstring`/`unpack` when missing, and the `setfenv(1, ...)`
  call is wrapped in `pcall`; when it fails, the quarry relaunches
  itself via `os.run` with the sandbox table as its environment and
  returns the result. On 5.1 `setfenv` succeeds and the original path
  runs unchanged. The resume/save logic is untouched. `master.lua`
  also had a bare `unpack(...)` call that broke launching anything with
  args on 1.20.x; now `(table.unpack or unpack)(...)`.

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
