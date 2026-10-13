version = 20261013.0300
-- PLATFORMER v6.0
-- Date: 2026-10-12
-- Inspired by Cluster Scanner v4.1 Logic
-- v6.1 Changes:
--   - Roof mode rework: start at any level, ascend N
--     blocks, lay one flat LxW layer, descend back. Inverted roof
--     places the ceiling upward from the start level, no climbing.
-- v6.0 Changes:
--   - Build modes: floor (v5 behavior), walls, solid, hollow, roof.
--   - Inverted option: place up / build from head height.
--   - CLI args for dimensions and options; interactive prompts otherwise.
--   - Resume state generalized via lib/Resume.lua (v5 saves migrate).
-- v5.0 Changes:
--   - Major Rewrite: Coordinate-based movement (x,z,facing).
--   - Persistence: Resumes exactly where left off after reboot/term.
--   - Safety: Instant Q to Terminate, Startup/Cleanup management.
--   - Refill: Smart auto-refill logic (returns to start -> sleep -> resume).

local VERSION = "6.1"
local RESTORE_FILE = ".platformer_restore"
local LOG_FILE = "platformer_log.txt"
local LOG_DIR = "Platformer_Logs"
local platform_backup = "startup_old_platformer"

-- Load Allowed Blocks library
local allowedLib = require("lib/allowedBlocks")
local allowedBlocks = allowedLib.allowedBlocks
local Resume = require("lib.Resume")

--------------------------------------
-- CONFIGURATION & DEFAULTS
--------------------------------------
local tArgs = { ... }
local params = {
    length = 0,
    width = 0,
    debug = false,
    mode = nil,      -- floor|walls|solid|hollow|roof (nil = ask interactively)
    height = nil,    -- layers for walls|solid|hollow (nil = ask interactively)
    inverted = nil   -- true = place up instead of down (nil = ask interactively)
}

-- Current State (Persisted)
local state = {
    x = 0,
    z = 0,
    y = 0,          -- vertical offset from start height (up positive)
    facing = 0,     -- 0=Forward (+Z), 1=Right (+X), 2=Back (-Z), 3=Left (-X)
    built = 0,
    layer = 1,          -- current build layer (1-based)
    layerStarted = false,
    isReturning = false,
    params = params
}

--------------------------------------
-- LOGGING & HELPER FUNCTIONS
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

local function saveProgress()
    Resume.save(RESTORE_FILE, state)
end

local function applyParamDefaults()
    -- Fill in v6.0 params missing from older saves; idempotent.
    local p = state.params
    if p.mode == nil then p.mode = "floor" end
    if p.mode == "floor" then p.height = 1 end
    if p.height == nil then p.height = 1 end
    if p.mode == "roof" then
        -- Roof height = blocks to ascend (0 = build at current level).
        if p.height < 0 then p.height = 0 end
    elseif p.height < 1 then
        p.height = 1
    end
    if p.inverted == nil then p.inverted = false end
    if state.y == nil then state.y = 0 end
    if state.layer == nil then state.layer = 1 end
    if state.layerStarted == nil then state.layerStarted = false end
end

local function loadProgress()
    local data = Resume.load(RESTORE_FILE)
    if data then
        state = data
        applyParamDefaults()
        return true
    end
    return false
end

--------------------------------------
-- STARTUP & CLEANUP
--------------------------------------
local function createStartup()
    Resume.installBootResume("-- Platformer Auto-Resume", platform_backup)
end

local function cleanupStartup()
    Resume.removeBootResume("-- Platformer Auto-Resume", platform_backup)
end

local function fullCleanup()
    Resume.clear(RESTORE_FILE)
    cleanupStartup()
    if fs.exists(LOG_FILE) then fs.delete(LOG_FILE) end
    -- Keep LOG_DIR
end

--------------------------------------
-- MOVEMENT (Coordinate System)
--------------------------------------
-- 0:+Z, 1:+X, 2:-Z, 3:-X
local function turnRight()
    turtle.turnRight()
    state.facing = (state.facing + 1) % 4
    saveProgress()
end

local function turnLeft()
    turtle.turnLeft()
    state.facing = (state.facing + 3) % 4
    saveProgress()
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
        local fuel = turtle.getFuelLevel()
        if fuel == 0 then
            error("OutOfFuel", 0)
        else
            turtle.dig()
            turtle.attack()
            sleep(0.5)
        end
    end
    
    if state.facing == 0 then state.z = state.z + 1
    elseif state.facing == 1 then state.x = state.x + 1
    elseif state.facing == 2 then state.z = state.z - 1
    elseif state.facing == 3 then state.x = state.x - 1
    end
    saveProgress()
end

local function up()
    while not turtle.up() do
        turtle.digUp()
        sleep(0.5)
    end
    state.y = state.y + 1
    saveProgress()
end

local function down()
    while not turtle.down() do
        turtle.digDown()
        sleep(0.5)
    end
    state.y = state.y - 1
    saveProgress()
end

local function changeLayer()
    -- Move to the next build layer: up normally, down when inverted.
    if state.params.inverted then
        down()
    else
        up()
    end
end

local function goTo(tx, tz)
    -- Align X
    if state.x < tx then
        turnTo(1)
        while state.x < tx do forward() end
    elseif state.x > tx then
        turnTo(3)
        while state.x > tx do forward() end
    end
    
    -- Align Z
    if state.z < tz then
        turnTo(0)
        while state.z < tz do forward() end
    elseif state.z > tz then
        turnTo(2)
        while state.z > tz do forward() end
    end
end

--------------------------------------
-- PLATFORM LOGIC
--------------------------------------
local function drawUI()
    term.clear()
    term.setCursorPos(1,1)
    colorPrint("=== PLATFORMER v"..VERSION.." ===", colors.blue)
    print(string.rep("=",30))
    
    local total = totalCells()
    local percent = 0
    if total > 0 then percent = math.floor((state.built / total) * 100) end

    colorPrint("Built: "..state.built.." / "..total, colors.orange)
    print("Pos: "..state.x..","..state.z..","..state.y.." Facing: "..state.facing)
    local modeLine = "Mode: "..state.params.mode
    if state.params.mode == "roof" then
        modeLine = modeLine.."  Up: "..state.y.."/"..state.params.height..
            (state.params.inverted and " (from below)" or "")
    else
        modeLine = modeLine.."  Layer: "..
            math.min(state.layer, state.params.height).."/"..state.params.height
    end
    print(modeLine)
    
    local fuel = turtle.getFuelLevel()
    local fuelMax = turtle.getFuelLimit()
    io.write("Fuel: ")
    if fuel < 500 then
        colorPrint(fuel.." (LOW)", colors.red)
    else
        colorPrint(fuel.." / "..fuelMax, colors.green)
    end
    
    colorPrint("Press Q (Instant) to Terminate", colors.red)
    
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
    print(string.rep("=",30))
    
    if state.isReturning then
        colorPrint(">> RETURNING TO ".. (state.x == 0 and state.z == 0 and "REFILL" or "WORK").. " <<", colors.magenta)
    end
end

local function selectAllowedBlock()
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail and allowedBlocks(detail.name) then
            turtle.select(slot)
            return true
        end
    end
    return false
end

local function performRefillSequence()
    local returnX, returnZ = state.x, state.z
    local returnFacing = state.facing
    
    log("Refill required at "..state.x..","..state.z)
    state.isReturning = true
    goTo(0,0)
    
    -- Search for blocks loop
    while not selectAllowedBlock() do
        -- Try grabbing from chest (Front, Up, Down)
        turtle.suck()
        turtle.suckUp()
        turtle.suckDown()
        
        term.clear()
        term.setCursorPos(1,1)
        colorPrint("=== WAITING FOR BLOCKS ===", colors.red)
        print("Turtle returned to 0,0 for refill.")
        print("Please add ALLOWED blocks to inventory")
        print("or place chest next to turtle.")
        print("")
        print("Next check in 30 seconds...")
        
        sleep(30)
    end
    
    log("Refill successful. Returning to work.")
    colorPrint("Resuming...", colors.green)
    goTo(returnX, returnZ)
    turnTo(returnFacing)
    state.isReturning = false
end

local function placeSmart()
    -- Debug / Dry Run Mode
    if state.params.debug then
        return
    end

    local placeUp = state.params.inverted
    local exists, data
    if placeUp then
        exists, data = turtle.inspectUp()
    else
        exists, data = turtle.inspectDown()
    end
    if exists then
        if not allowedBlocks(data.name) then
            if placeUp then turtle.digUp() else turtle.digDown() end
        else
            return -- Already valid block
        end
    end

    -- Ensure we have blocks
    while not selectAllowedBlock() do
        performRefillSequence()
    end

    if placeUp then turtle.placeUp() else turtle.placeDown() end
end

local function isPerimeter(x, z)
    return x == 0 or x == state.params.width - 1
        or z == 0 or z == state.params.length - 1
end

local function shouldPlace(x, z, layer)
    local mode = state.params.mode
    if mode == "walls" then
        return isPerimeter(x, z)
    elseif mode == "hollow" then
        local h = state.params.height
        if layer == 1 or layer == h then
            return true -- floor and roof layers are solid
        end
        return isPerimeter(x, z)
    end
    return true -- floor, roof, solid place every cell
end

local function totalCells()
    local L, W, H = state.params.length, state.params.width, state.params.height
    local perim
    if L == 1 or W == 1 then
        perim = L * W -- 1-wide: every cell is on the edge
    else
        perim = 2 * L + 2 * W - 4
    end
    local mode = state.params.mode
    if mode == "walls" then
        return perim * H
    elseif mode == "solid" then
        return L * W * H
    elseif mode == "hollow" then
        if H <= 1 then return L * W end
        if H == 2 then return 2 * L * W end
        return 2 * L * W + (H - 2) * perim
    elseif mode == "roof" then
        return L * W -- one flat layer at the roof level
    end
    return L * W * H -- floor slab, every cell every layer
end

local function doSnakeLayer(layer)
    -- Coordinate Loop (Snake Pattern)
    -- We assume 0,0 is the layer start.
    for x = 0, state.params.width - 1 do
        -- Only move if we are not already at the correct column start (resume support)
        if x >= state.x then
             goTo(x, state.z)

             local targetZ = (x % 2 == 0) and (state.params.length - 1) or 0

             -- Scanning the row/column
             while state.z ~= targetZ do
                 if shouldPlace(state.x, state.z, layer) then
                     placeSmart()
                     state.built = state.built + 1
                 end
                 drawUI()

                 local moveDir = (state.z < targetZ) and 0 or 2
                 turnTo(moveDir)
                 forward()
             end
             -- Place at end of row
             if shouldPlace(state.x, state.z, layer) then
                 placeSmart()
                 state.built = state.built + 1
             end
             drawUI()
        end
    end
end

local function buildRoof()
    -- Roof spec: start at ANY level. Non-inverted: ascend
    -- height-up blocks, lay one flat LxW layer, descend back to the
    -- start level. Inverted: place the ceiling upward from the start
    -- level, no climbing. Every step is resume-aware via state.y
    -- and state.layer.
    log("Starting roof build, height-up=" .. state.params.height ..
        (state.params.inverted and " (inverted, from below)" or ""))
    if not state.params.inverted then
        while state.y < state.params.height and not state.descending do up() end
    end
    if state.layer <= 1 then
        if not state.layerStarted then
            goTo(0, 0)
            state.layerStarted = true
            saveProgress()
        end
        doSnakeLayer(1)
        state.layer = 2
        state.layerStarted = false
        saveProgress()
    end
    if not state.params.inverted and state.params.height > 0 then
        -- Step off the roof footprint before descending; the column we
        -- ascended through is now roofed over.
        state.descending = true
        saveProgress()
        goTo(state.params.width, 0)
        while state.y > 0 do down() end
        state.descending = false
        saveProgress()
        goTo(0, 0)
    end
end

local function buildLogic()
    log("Starting build cycle, mode=" .. state.params.mode)
    state.isReturning = false

    if state.params.mode == "roof" then
        buildRoof()
    else
    for layer = 1, state.params.height do
        if layer < state.layer then
            -- Layer already completed in a previous session (resume); skip.
        else
            if not state.layerStarted then
                goTo(0, 0)
                state.layerStarted = true
                saveProgress()
            end
            doSnakeLayer(layer)
            state.layer = layer + 1
            state.layerStarted = false
            saveProgress()
            if layer < state.params.height then
                changeLayer()
            end
        end
    end
    end

    drawUI()
    log("Build complete.")
    state.isReturning = true
    goTo(0, 0)
    -- Best-effort return to start height: move toward y=0 but stop rather
    -- than dig through the structure (matters for solid mode).
    while state.y > 0 and not turtle.detectDown() do
        if not turtle.down() then break end
        state.y = state.y - 1
        saveProgress()
    end
    while state.y < 0 and not turtle.detectUp() do
        if not turtle.up() then break end
        state.y = state.y + 1
        saveProgress()
    end
    turnTo(0)

    colorPrint("Build Completed Successfully!", colors.green)
    fullCleanup()
    state.built = totalCells() -- Ensure 100%
end

local function listenForExit()
    while true do
        local ev, p1 = os.pullEvent()
        if ev == "key" and p1 == keys.q then
            error("Terminated", 0)
        end
    end
end

local function runBuild()
    parallel.waitForAny(buildLogic, listenForExit)
end

--------------------------------------
-- ENTRY POINTS
--------------------------------------
local function parseArgs()
    -- CLI: platformer -length 20 -width 12 [-mode walls] [-height 5] [-inverted]
    for i = 1, #tArgs, 2 do
        local k = tArgs[i]
        local v = tArgs[i + 1]
        if k == "-length" then params.length = tonumber(v) or 0
        elseif k == "-width" then params.width = tonumber(v) or 0
        elseif k == "-mode" then params.mode = tostring(v or ""):lower()
        elseif k == "-height" then params.height = math.floor(tonumber(v) or 0)
        elseif k == "-inverted" then params.inverted = true
        end
    end
    -- Interactive fallback for anything not given on the command line
    if params.length == 0 then
        colorPrint("Enter Platform Length (Z):", colors.orange)
        params.length = tonumber(read()) or 0
    end
    if params.width == 0 then
        colorPrint("Enter Platform Width  (X):", colors.orange)
        params.width = tonumber(read()) or 0
    end
    
    if #tArgs > 0 then
         for _,v in ipairs(tArgs) do
             if v == "-debug" then params.debug = true end
         end
    end
end

local function promptOptions()
    -- Quarry-style options: only ask for what the command line did not set.
    local validModes = { floor = true, walls = true, solid = true, hollow = true, roof = true }
    if params.mode == nil or not validModes[params.mode] then
        colorPrint("Build mode:", colors.orange)
        colorPrint("  1) Floor  - single layer platform", colors.lightGray)
        colorPrint("  2) Walls  - perimeter walls, H layers high", colors.lightGray)
        colorPrint("  3) Solid  - filled LxWxH block", colors.lightGray)
        colorPrint("  4) Hollow - shell: floor + walls + roof", colors.lightGray)
        colorPrint("  5) Roof   - go up N blocks, flat roof, come back", colors.lightGray)
        io.write("Enter mode [1-5] (default 1): ")
        local modes = { "floor", "walls", "solid", "hollow", "roof" }
        local m = (read() or ""):lower()
        local n = tonumber(m)
        if n and modes[n] then
            params.mode = modes[n]
        elseif validModes[m] then
            params.mode = m
        else
            params.mode = "floor"
        end
    end
    if params.mode == "roof" then
        -- Roof spec: start at any level. Non-inverted: ascend N blocks,
        -- lay one flat layer, descend back. Inverted: place the ceiling
        -- upward from the start level, no climbing.
        if params.inverted == nil then
            io.write("Build from below (place up, no climbing)? [y/N]: ")
            local ans = (read() or ""):lower()
            params.inverted = ans:sub(1, 1) == "y"
        end
        if not params.inverted and params.height == nil then
            io.write("How many blocks up to the roof level? ")
            params.height = math.floor(tonumber(read()) or 0)
            if params.height < 0 then params.height = 0 end
        end
        if params.height == nil then params.height = 0 end
    else
        if params.mode ~= "floor" and params.height == nil then
            io.write("Enter height in layers: ")
            params.height = math.floor(tonumber(read()) or 1)
            if params.height < 1 then params.height = 1 end
        end
        if params.inverted == nil then
            io.write("Inverted (place up instead of down)? [y/N]: ")
            local ans = (read() or ""):lower()
            params.inverted = ans:sub(1, 1) == "y"
        end
    end
end

local function promptStart(resume)
    if not resume then
        term.clear()
        term.setCursorPos(1,1)
        colorPrint("=== PLATFORMER v"..VERSION.." ===", colors.blue)
        colorPrint("Start Position: 0, 0 (Bottom-Left)", colors.yellow)
        colorPrint("Facing: FORWARD (+Z)", colors.yellow)
        colorPrint("Mode: "..state.params.mode..
            (state.params.height > 1 and (" x"..state.params.height.." layers") or "")..
            (state.params.inverted and " (inverted)" or ""), colors.yellow)
        print("Required: ".. totalCells() .. " blocks")
        
        if params.debug then colorPrint("DEBUG MODE: DRY RUN (NO PLACE)", colors.magenta) end
        
        local have = 0
        for i=1,16 do 
            local detail = turtle.getItemDetail(i)
            if detail and allowedBlocks(detail.name) then
                have = have + detail.count
            end
        end
        
        if have < 64 and not params.debug then
             colorPrint("WARNING: Low block count ("..have..")", colors.red)
             colorPrint("Press ENTER to Start Anyway or Ctrl+T to cancel", colors.orange)
             if read() == nil then return end
        else
             print("Press ENTER to Start")
             read()
        end
    end
    
    colorPrint(resume and "Resuming..." or "Starting...", colors.green)
    sleep(1)
end

-- MAIN EXECUTION
if loadProgress() then
    createStartup()
    promptStart(true)
else
    parseArgs()
    promptOptions()
    applyParamDefaults()
    if params.length > 0 and params.width > 0 then
        createStartup()
        promptStart(false)
        saveProgress() -- Save initial params
    else
        colorPrint("Invalid Dimensions.", colors.red)
        return
    end
end

while true do
    local ok, err = pcall(runBuild)
    if not ok then
        if err == "Terminated" then
            fullCleanup()
            colorPrint("\nTerminated by user.", colors.red)
            return
        elseif err == "OutOfFuel" then
            saveProgress()
            colorPrint("\nOut of fuel. Refuel and re-run to resume.", colors.red)
            return
        else
            error(err)
        end
    else
        break -- Success
    end
end
