version = 20261013.1700
-- INFINITE MINER v5.1
-- Mines forever, listens for Q (or Ctrl+T) to stop, auto-dumps generable
-- blocks into chests and everything else to your dump side.
-- Stops safely if no chest is found ("constipated mode")

local LoopSetup = require("lib.LoopSetup")
local cfg = LoopSetup.defaults()

local COBBLE = "minecraft:cobblestone"
-- Blocks generable from water/lava combos: these go to the chest.
local GENERABLE = {
    ["minecraft:cobblestone"] = true,
    ["minecraft:stone"] = true,
    ["minecraft:basalt"] = true,
    ["minecraft:obsidian"] = true,
}
local mined = 0
local stopFlag = false

-------------------------
--   UI
-------------------------
local function drawUI()
    term.clear()
    term.setCursorPos(1,1)
    print("========================")
    print("=       Mining...      =")
    print("========================")
    print("Blocks mined: "..mined)
    write("press Q (or Ctrl+T) to stop. > ")
end

-------------------------
--  Chest dump helpers
-------------------------
local function isGenerable(i)
    local detail = turtle.getItemDetail(i)
    return detail and detail.name and GENERABLE[detail.name]
end

-- Sorted dump: non-generable clutter goes to the dump side (plain drop,
-- front is never offered as the dump side since that is the mining face);
-- generable blocks go to the auto-detected chest. The dump side is
-- excluded from chest detection for this run.
local function dumpSorted()
    if cfg.dumpSide ~= "none" then
        LoopSetup.dropToward(cfg.dumpSide, function(i)
            local detail = turtle.getItemDetail(i)
            return detail and detail.name and not GENERABLE[detail.name]
        end)
    end
    local chestSide = LoopSetup.findInventory(cfg.dumpSide)
    if not chestSide then
        -- Only stranded generable blocks count as a failure: the
        -- dump-side pass may already have cleared everything else.
        for i = 1, 16 do
            if isGenerable(i) then return false end
        end
        return true
    end
    LoopSetup.dropToward(chestSide, isGenerable)
    return true
end

-- returns TRUE if dump succeeded, FALSE if generable blocks are stranded
local function dumpToChest()
    return dumpSorted()
end

local function getCobbleCount()
    local total = 0
    for i=1,16 do
        local detail = turtle.getItemDetail(i)
        if detail and detail.name == COBBLE then
            total = total + detail.count
        end
    end
    return total
end

local function occupiedSlots()
    local count = 0
    for i=1,16 do
        if turtle.getItemCount(i) > 0 then count = count + 1 end
    end
    return count
end

-------------------------
-- Mining function
-------------------------
local function miningLoop()
    while not stopFlag do
        drawUI()

        -- mine cobblestone
        if turtle.detect() then
            local ok, data = turtle.inspect()
            if ok and GENERABLE[data.name] then
                turtle.dig()
                mined = mined + 1
            end
        end

        -- inventory threshold: 256 cobble, or nearly full of clutter
        if getCobbleCount() >= 256 or occupiedSlots() >= 14 then
            print("\nHold it... gotta 'take a dump.'")
            sleep(1)

            local dumped = dumpToChest()
            if not dumped then
                print("\nOh no! im constipated!")
                stopFlag = true
                return
            end
        end

        sleep(0.1) -- lag prevention
    end
end

-------------------------
-- Key listener
-------------------------
local function stopListener()
    while true do
        local ev, key = os.pullEvent()
        if ev == "terminate" or (ev == "key" and (key == keys.q or key == keys.enter)) then
            stopFlag = true
            print("\nOk fine, stopping. But because I wanted to.")
            return
        end
    end
end

-------------------------
-- Program start
-------------------------
print("actually mine forever?")
local ans = (read() or ""):lower()

while ans ~= "yes" and ans ~= "y" and ans ~= "yey"
  and ans ~= "no" and ans ~= "n" and ans ~= "nay" do
    print("wym. it's a yey or nay question.")
    ans = (read() or ""):lower()
end

if ans == "no" or ans == "n" or ans == "nay" then
    print("then why u calling me??")
    return
end

local scfg = LoopSetup.run({
    blurb = "Mines cobblestone ahead forever. Generable blocks go to a detected chest; anything else goes to your dump side.",
    dumpSide = true,
    noFront = true,
})
if not scfg then
    print("Setup aborted.")
    return
end
cfg = scfg

-- Run mining + key listener together
parallel.waitForAny(miningLoop, stopListener)