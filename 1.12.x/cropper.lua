-- CROPPER v0.3 BETA (Quarry Edition)
-- Date: 2025-12-13
-- Inspired by Civilwargeeky's Quarry & AE2 Cluster Scanner
-- v0.3 Changes:
--   - Full Quarry Logic: CLI Args (-length, -width, -wait).
--   - Persistence: Resumes exactly where left off.
--   - Robust Movement: Coordinate-based tracking (x,z).
--   - Auto-Startup: Creates persistent startup file.
--   - Strict Cleanup: Q to Abort deletes all temp files (logs, startup, restore).
--   - Farming: Harvests mature crops (age >= 7) and replants.

local VERSION = "0.3 Beta"
local RESTORE_FILE = ".cropper_restore"
local LOG_FILE = "cropper_log.txt"
local LOG_DIR = "Cropper_Logs"
local cluster_startup = "startup"
local cluster_backup = "startup_old_cropper"

--------------------------------------
-- CONFIGURATION & DEFAULTS
--------------------------------------
local tArgs = { ... }
local Resume = require("lib.Resume")
local params = {
    length = 0,
    width = 0,
    waitTime = 0,
    startDelay = 3,
    debug = false
}

-- Current State (Persisted)
local state = {
    x = 0,
    z = 0,
    facing = 0,     -- 0=Forward, 1=Right, 2=Back, 3=Left
    inventoryFull = false,
    cycleCount = 0,
    totalScanned = 0,
    isReturning = false,
    params = params
}

--------------------------------------
-- LOGGING & UI
--------------------------------------
local function log(message)
    local f = fs.open(LOG_FILE, "a")
    if f then
        f.writeLine("["..os.day().."-"..textutils.formatTime(os.time(), true).."] "..message)
        f.close()
    end
end

local function colorPrint(message, color)
    if term.isColor() then term.setTextColor(color) end
    print(message)
    if term.isColor() then term.setTextColor(colors.white) end
end

local function drawUI()
    term.clear()
    term.setCursorPos(1,1)

    colorPrint("=== CROPPER v"..VERSION.." ===", colors.blue)
    print(string.rep("=",30))

    colorPrint("Cycle: "..state.cycleCount, colors.orange)
    colorPrint("Scanned: "..state.totalScanned, colors.orange)
    print("Pos: "..state.x..","..state.z.." Facing: "..state.facing)

    local fuel = turtle.getFuelLevel()
    local fuelMax = turtle.getFuelLimit()
    io.write("Fuel: ")
    if fuel < 500 then
        colorPrint(fuel.." (LOW)", colors.red)
    else
        colorPrint(fuel.." / "..fuelMax, colors.green)
    end
    
    colorPrint("Press Q 3 sec to Terminate", colors.red)

    if state.isReturning then
        colorPrint(">> RETURNING TO START <<", colors.orange)
    else
        local total = state.params.length * state.params.width
        local percent = 0
        if total > 0 then
            percent = math.floor((state.totalScanned / total) * 100)
        end

        io.write("Progress: [")
        local bars = math.floor(percent / 5)
        for i = 1, 20 do
            if i <= bars then
                if term.isColor() then term.setTextColor(colors.blue) end
                io.write("=")
                if term.isColor() then term.setTextColor(colors.white) end
            else
                io.write(" ")
            end
        end
        print("] "..percent.."%")
    end

    print(string.rep("=",30))
end

--------------------------------------
-- PERSISTENCE & CLEANUP
--------------------------------------
local function saveProgress()
    Resume.save(RESTORE_FILE, state)
end

local function loadProgress()
    local data = Resume.load(RESTORE_FILE)
    if data then
        state = data
            if not state.params.waitTime then state.params.waitTime = 0 end
        return true
    end
    return false
end

local function createStartup()
    Resume.installBootResume("-- Cropper Auto-Resume", cluster_backup)
end

local function cleanupStartup()
    Resume.removeBootResume("-- Cropper Auto-Resume", cluster_backup)
end

local function fullCleanup()
    -- 1. Delete Restore File
    Resume.clear(RESTORE_FILE)
    
    -- 2. Cleanup Startup
    cleanupStartup()
    
    -- 3. Delete Log File
    if fs.exists(LOG_FILE) then fs.delete(LOG_FILE) end
    
    -- 4. Delete Log Directory Contents (Keep Folder)
    if fs.exists(LOG_DIR) and fs.isDir(LOG_DIR) then
        local files = fs.list(LOG_DIR)
        for _, file in ipairs(files) do
            fs.delete(fs.combine(LOG_DIR, file))
        end
    end
end

--------------------------------------
-- MOVEMENT SYSTEM (Coordinate Based)
--------------------------------------
local function turnRight()
    turtle.turnRight()
    state.facing = (state.facing + 1) % 4
    saveProgress()
    drawUI()
end

local function turnLeft()
    turtle.turnLeft()
    state.facing = (state.facing + 3) % 4
    saveProgress()
    drawUI()
end

local function turnTo(targetFace)
    local diff = (targetFace - state.facing) % 4
    if diff == 1 then turnRight()
    elseif diff == 2 then turnRight(); turnRight()
    elseif diff == 3 then turnLeft()
    end
end

local function forward()
    while not turtle.forward() do
        if turtle.getFuelLevel() == 0 then
            log("Out of fuel at "..state.x..","..state.z)
            colorPrint("OUT OF FUEL", colors.red)
            sleep(1)
        else
            turtle.dig(); turtle.attack()
        end
    end
    
    if state.facing == 0 then state.z = state.z + 1
    elseif state.facing == 1 then state.x = state.x + 1
    elseif state.facing == 2 then state.z = state.z - 1
    elseif state.facing == 3 then state.x = state.x - 1
    end
    saveProgress()
    drawUI()
end

local function goTo(tx, tz)
    if state.x < tx then turnTo(1); while state.x < tx do forward() end
    elseif state.x > tx then turnTo(3); while state.x > tx do forward() end end
    
    if state.z < tz then turnTo(0); while state.z < tz do forward() end
    elseif state.z > tz then turnTo(2); while state.z > tz do forward() end end
end

--------------------------------------
-- FARMING LOGIC
--------------------------------------
local crops = {
    vanilla = {
        ["minecraft:wheat"] = true,
        ["minecraft:carrots"] = true,
        ["minecraft:potatoes"] = true,
        ["minecraft:beetroots"] = true
    },
    modded = {}
}

local seeds = {
    vanilla = {
        ["minecraft:wheat"] = "minecraft:wheat_seeds",
        ["minecraft:carrots"] = "minecraft:carrot",
        ["minecraft:potatoes"] = "minecraft:potato",
        ["minecraft:beetroots"] = "minecraft:beetroot_seeds"
    },
    modded = {}
}

local function seedForCrop(name)
    return seeds.vanilla[name] or seeds.modded[name]
end

local function findSeedSlot(seedItem)
    if not seedItem then return nil end
    for s=1,16 do
        local d = turtle.getItemDetail(s)
        if d and d.name == seedItem then return s end
    end
    return nil
end

local function harvestAndReplant()
    local exists, info = turtle.inspectDown()
    if not exists then return end
    
    if (crops.vanilla[info.name] or crops.modded[info.name]) and info.state and info.state.age and info.state.age >= 7 then
        log("Harvesting "..info.name.." at "..state.x..","..state.z)
        turtle.digDown()
        
        -- Replant
        local seedName = seedForCrop(info.name)
        local slot = findSeedSlot(seedName)
        if slot then
            turtle.select(slot)
            turtle.placeDown()
            turtle.select(1)
        end
    end
end

local function isStorage(name)
    if not name then return false end
    return name:find("chest") or name:find("barrel") or name:find("shulker")
end

local function checkInventory()
    local count = 0
    for i=1,16 do if turtle.getItemCount(i) > 0 then count = count + 1 end end
    
    if count >= 16 then
        state.inventoryFull = true
        log("Inventory full at "..state.x..","..state.z)
    end
    
    -- Opportunistic dump
    local has, data = turtle.inspectDown()
    if has and isStorage(data.name) then
        for i=1,16 do turtle.select(i); turtle.dropDown() end
        turtle.select(1)
        state.inventoryFull = false
        log("Dumped items into storage at "..state.x..","..state.z)
    end
end

--------------------------------------
-- LOGGING RUNS
--------------------------------------
local function logRunSummary()
    if not fs.exists(LOG_DIR) then fs.makeDir(LOG_DIR) end
    local n = 1
    while fs.exists(LOG_DIR.."/Run_"..n..".txt") do n = n + 1 end
    
    local f = fs.open(LOG_DIR.."/Run_"..n..".txt", "w")
    f.writeLine("Run Summary")
    f.writeLine("============")
    f.writeLine("Dimensions: "..state.params.length.."x"..state.params.width)
    f.writeLine("Time: "..textutils.formatTime(os.time(), true))
    f.writeLine("Total Scanned: "..state.totalScanned)
    f.close()
end

--------------------------------------
-- MAIN LOGIC
--------------------------------------
local function parseArgs()
    for i=1, #tArgs, 2 do
        local k = tArgs[i]
        local v = tArgs[i+1]
        if k == "-length" then params.length = tonumber(v)
        elseif k == "-width" then params.width = tonumber(v)
        elseif k == "-wait" then params.waitTime = tonumber(v)
        end
    end
end

local function getArgsInteractive()
    colorPrint("Enter Field Length:", colors.orange)
    params.length = tonumber(read())
    colorPrint("Enter Field Width:", colors.orange)
    params.width = tonumber(read())
    colorPrint("Wait Time (seconds):", colors.orange)
    params.waitTime = tonumber(read()) or 0
end

local function scanLogic()
    state.totalScanned = 0
    state.isReturning = false
    log("Starting cycle "..state.cycleCount)
    
    for x = 0, state.params.width - 1 do
        goTo(x, state.z)
        local targetZ = (x % 2 == 0) and (state.params.length - 1) or 0
        
        while state.z ~= targetZ do
            harvestAndReplant()
            checkInventory()
            if state.z < targetZ then turnTo(0); forward()
            else turnTo(2); forward() end
            state.totalScanned = state.totalScanned + 1
        end
        harvestAndReplant()
        checkInventory()
    end
    
    log("Cycle complete, returning to start")
    state.isReturning = true
    goTo(0,0)
    turnTo(0)
    
    state.cycleCount = state.cycleCount + 1
    logRunSummary()
    saveProgress()
    
    if state.params.waitTime > 0 then
        log("Waiting "..state.params.waitTime.."s")
        for i=state.params.waitTime, 1, -1 do
            term.clear()
            term.setCursorPos(1,1)
            colorPrint("Waiting: "..i.."s", colors.yellow)
            sleep(1)
        end
    end
end

local function listenForExit()
    local timer
    local holding = false
    while true do
        local ev, p1 = os.pullEvent()
        if ev == "key" and p1 == keys.q then
            if not holding then
                holding = true
                timer = os.startTimer(3)
            end
        elseif ev == "key_up" and p1 == keys.q then
            holding = false
        elseif ev == "timer" and p1 == timer and holding then
            error("Terminated", 0)
        end
    end
end

local function runScan()
    parallel.waitForAny(scanLogic, listenForExit)
end

local function promptStart(resume)
    local timer = os.startTimer(5)
    local msg = resume and "Resuming" or "Starting"
    
    while true do
        term.clear()
        term.setCursorPos(1,1)
        colorPrint("=== CROPPER v"..VERSION.." ===", colors.blue)
        if resume then colorPrint("Previous session restored.", colors.green) end
        
        colorPrint(msg.." in 5 seconds...", colors.yellow)
        colorPrint("Press ENTER to start immediately.", colors.green)
        colorPrint("Press Q to CANCEL and ABORT.", colors.red)
        
        local ev, p1 = os.pullEventRaw() -- Catch terminate during prompt
        if ev == "terminate" then
            fullCleanup()
            colorPrint("\nTerminated by user (Cleanup Complete).", colors.red)
            error("Terminated", 0)
        elseif ev == "timer" and p1 == timer then break
        elseif ev == "key" then
            if p1 == keys.enter then break
            elseif p1 == keys.q then
                fullCleanup()
                colorPrint("\nAborted by user (Safe Cleanup Complete).", colors.red)
                error("", 0)
            end
        end
    end
end

if loadProgress() then promptStart(true) end

if state.x == 0 and state.z == 0 and state.cycleCount == 0 then
    if #tArgs > 0 then parseArgs() else getArgsInteractive() end
    if not params.length or not params.width then
        colorPrint("Invalid arguments.", colors.red)
        return
    end
    state.params = params
    saveProgress()
    createStartup()
    promptStart(false)
end

while true do
    local ok, err = pcall(runScan)
    
    if not ok then
        if err == "Terminated" then
            fullCleanup()
            colorPrint("\nTerminated by user (Cleanup Complete).", colors.red)
            return
        else
            error(err) -- Propagate other errors
        end
    end
end
