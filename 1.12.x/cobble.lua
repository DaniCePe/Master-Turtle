-- INFINITE MINER v5.0
-- Mines forever, listens for Enter to stop, auto-dumps 4+ stacks into chests.
-- Stops safely if no chest is found ("constipated mode")

local COBBLE = "minecraft:cobblestone"
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
    write("press enter to stop. > ")
end

-------------------------
--  Chest dump helpers
-------------------------
local function tryDump(inspectFunc, dropFunc)
    local ok, data = inspectFunc()
    if ok and data.name and data.name:find("chest") then
        for i=1,16 do
            local detail = turtle.getItemDetail(i)
            if detail and detail.name == COBBLE then
                turtle.select(i)
                dropFunc()
            end
        end
        turtle.select(1)
        print("\nDumped in chest. Back to work ig")
        sleep(1)
        return true
    end
    return false
end

-- returns TRUE if dump succeeded, FALSE if no chest found
local function dumpToChest()
    -- forward
    if tryDump(turtle.inspect, turtle.drop) then return true end
    -- up
    if tryDump(turtle.inspectUp, turtle.dropUp) then return true end
    -- down
    if tryDump(turtle.inspectDown, turtle.dropDown) then return true end

    -- left
    turtle.turnLeft()
    if tryDump(turtle.inspect, turtle.drop) then turtle.turnRight() return true end

    -- right
    turtle.turnRight(); turtle.turnRight()
    if tryDump(turtle.inspect, turtle.drop) then
        turtle.turnLeft()
        return true
    end

    -- restore facing
    turtle.turnLeft()

    -- none found
    return false
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

-------------------------
-- Mining function
-------------------------
local function miningLoop()
    while not stopFlag do
        drawUI()

        -- mine cobblestone
        if turtle.detect() then
            local ok, data = turtle.inspect()
            if ok and data.name == COBBLE then
                turtle.dig()
                mined = mined + 1
            end
        end

        -- inventory threshold
        if getCobbleCount() >= 256 then
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
        local event, key = os.pullEvent("key")
        if key == keys.enter then
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
local ans = read():lower()

while ans ~= "yes" and ans ~= "y" and ans ~= "yey"
  and ans ~= "no" and ans ~= "n" and ans ~= "nay" do
    print("wym. it's a yey or nay question.")
    ans = read():lower()
end

if ans == "no" or ans == "n" or ans == "nay" then
    print("then why u calling me??")
    return
end

-- Run mining + key listener together
parallel.waitForAny(miningLoop, stopListener)