# Verification

All checks run 2026-10-12 under CCEmuX (Xvfb, headless).

## Parse checks (CCEmuX loadfile, the reliable checker here)

`luac` is not usable for this codebase: it false-positives on `\)`
escapes (LuaJ/Cobalt accept them, PUC Lua rejects) and on
`function goto` (CC:Tweaked's Cobalt does not reserve `goto`; verified
`load("function goto() end")` succeeds). Every file was instead loaded
with `loadfile` inside the emulated computer.

- `1.20.x`, CCEmuX-cct build (= CC:Tweaked 1.120.0, Cobalt/Lua 5.2):
  59 Lua files, 0 failures.
- `1.12.x`, CCEmuX-cc build (= ComputerCraft 1.80pr1, LuaJ/Lua 5.1):
  57 Lua files, 0 failures.

Covers all new/modified files: `master.lua`, `startup.lua`,
`scenes/Launcher.lua`, `scenes/Dimensions.lua`, `scenes/CCAI.lua`,
`platformer.lua` (v6.0), `filler.lua`, `cropper.lua`, `cluster.lua`,
`move`, `turn`, the six shims, `lib/Resume.lua`, `lib/clsTurtle.lua`
(#9 fix), `lib/TurtleUtils.lua` (17 cuts), `tk3.lua` (#8 fix),
`updater.lua` (both trees), `cc-ai`.

## Boot test (1.20.x tree, turtle API stubbed)

Drove `master.lua` with queued events:

- boot reaches the Launcher scene: confirmed
- Down + Enter on the 2nd entry (Platformer) opens Dimensions: confirmed
- OK with a filled dialog builds the launch and returns: confirmed
  (the launch actually executed `platformer -length 12`, proving the
  args flow end to end)
- `q` quits cleanly back to the shell: confirmed

## Dimensions dialog unit tests

`Dimensions:tryLaunch` arg building, all pass:

- platformer full: `12/8/hollow/3/true` ->
  `-length 12 -width 8 -mode hollow -height 3 -inverted`
- platformer partial: blanks skipped -> `-length 10`
- bad mode rejected with `Mode: floor/walls/solid/hollow/roof`
- quarry triple: `16 16 10` -> `-dim 16 16 10`

(Caught and fixed during testing: the whitespace stripper was eating
the spaces in the quarry's triple box.)

## Platformer build math

`shouldPlace`/`totalCells` extracted from the shipped file and
brute-force cross-checked: 5 modes x 8 dimension sets (including 1-wide,
1x1x1, multi-layer) = 40 combos. All pass.

(Caught and fixed: `totalCells` undercounted `floor`/`roof` with
height > 1, and the perimeter formula broke on 1-wide areas.)

## cc-ai

`1.20.x/cc-ai` and `1.12.x/cc-ai` are byte-identical to upstream
`RareMojo/cc-ai` `lua/client.lua` at commit 03b57f9 (diff-verified).

## Not covered

- Full interactive runs of quarry/platformer/cropper (need a real
  Minecraft world with blocks, fuel, and chests).
- The `os.epoch("utc")` call in cc-ai on 1.12: present in
  ComputerCraft 1.80pr1 per docs, not exercised here.
- Rednet/GPS quarry paths.
