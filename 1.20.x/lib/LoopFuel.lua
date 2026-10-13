version = 20261013.1200
-- lib/LoopFuel.lua: quarry-inspired refuel helper for roaming loop programs.
-- Autonomy rule: never prompts mid-run. All choices come from cfg (LoopSetup).
--
-- SmartFuel port (see analysis/quarry-architecture.md section 4):
--   * turtle.refuel(0) as the non-consuming burnability probe
--   * burn one item, measure oneFuel, then burn the exact count needed
--   * target is 2x the trip estimate, capped at the fuel limit
--   * a lava bucket burns like any fuel when needed (never hoarded), but
--     never tops up the last 500 below the cap (quarry lavaBuffer)
-- Fixed refuel point: fuel chest and/or lava source at the start block.
-- Startup never exits for lack of fuel; it refuels from the fixed point
-- first, then waits for fuel items at the start where the user can reach
-- the turtle. Mid-run, programs evacuate home while they still can
-- (needEvac) instead of waiting stranded.
--
-- Usage:
--   local LoopFuel = require("lib.LoopFuel")
--   LoopFuel.stage(cfg)                 -- consolidate tagged fuel into bucketSlot
--   LoopFuel.ensure(cfg, tripEst)       -- 2x SmartFuel startup; false if aborted
--   LoopFuel.refuelAtStart(cfg, target) -- suck chest, fill lava, burn; at start
--   LoopFuel.waitForFuel(cfg, target)   -- wait loop for fuel items; false if Q
--   if LoopFuel.needEvac(distHome) then -- evacuate now end
--
-- Works on Lua 5.1 and 5.2. No em dashes anywhere.

local LoopSetup = require("lib.LoopSetup")
local LoopFuel = {}

local EMPTY_BUCKET = "minecraft:bucket"
local LAVA_BUCKET = "minecraft:lava_bucket"
local LAVA_BUFFER = 500 -- never top up the last 500 below cap with lava
local COAL_STACK_FUEL = 5120 -- a stack of coal; above this, suggest lava

local function fuelLevel()
    local f = turtle.getFuelLevel()
    if type(f) ~= "number" then return math.huge end
    return f
end

local function fuelLimit()
    local l = turtle.getFuelLimit()
    if type(l) ~= "number" then return math.huge end
    return l
end

local function face(side)
    if side == "left" then turtle.turnLeft()
    elseif side == "right" then turtle.turnRight()
    elseif side == "back" then turtle.turnLeft(); turtle.turnLeft() end
end

local function unface(side)
    if side == "left" then turtle.turnRight()
    elseif side == "right" then turtle.turnLeft()
    elseif side == "back" then turtle.turnRight(); turtle.turnRight() end
end

-- Cap a move estimate at the fuel limit.
function LoopFuel.capEst(est)
    return math.min(est, fuelLimit())
end

-- If the bucket slot is empty, move the first tagged-fuel stack there so
-- later dumps (which exclude the bucket slot) never throw fuel away.
function LoopFuel.stage(cfg)
    local slot = cfg.bucketSlot or 16
    if turtle.getItemCount(slot) > 0 then turtle.select(1) return end
    for i = 1, 16 do
        if i ~= slot then
            local d = turtle.getItemDetail(i)
            if d and d.name and LoopSetup.matches(d.name, cfg.fuelTags) then
                turtle.select(i)
                turtle.transferTo(slot)
                break
            end
        end
    end
    turtle.select(1)
end

-- Burn fuel until fuel >= target. Empirical SmartFuel: probe burnability
-- with refuel(0), burn one item to measure oneFuel, then burn the exact
-- count needed. The lava bucket burns first when needed (never hoarded),
-- unless it would waste fuel topping up the cap.
-- counts: optional snapshot table; when given, only slots holding MORE
-- than the snapshot may burn, and the burnFuel flag is ignored (the fuel
-- came from a user-designated source: fuel chest, or items the user added
-- when asked). Without counts, only tagged fuel burns and burnFuel applies.
-- Returns true when fuel >= target.
function LoopFuel.burnUpTo(cfg, target, counts)
    local explicit = counts ~= nil
    if not explicit and not cfg.burnFuel then return fuelLevel() >= target end
    local slot = cfg.bucketSlot or 16
    local limit = fuelLimit()
    if target > limit - 1 then target = limit - 1 end
    if fuelLevel() >= target then return true end
    -- Lava bucket first: a big gulp already in hand gets used.
    local d = turtle.getItemDetail(slot)
    local base = (counts and counts[slot]) or 0
    if d and d.name == LAVA_BUCKET and turtle.getItemCount(slot) > base
        and fuelLevel() + LAVA_BUFFER < limit then
        turtle.select(slot)
        turtle.refuel()
        turtle.select(1)
    end
    if fuelLevel() >= target then return true end
    for i = 1, 16 do
        if i ~= slot and fuelLevel() < target then
            local arrived = (counts and counts[i]) or 0
            if not explicit or turtle.getItemCount(i) > arrived then
                local d2 = turtle.getItemDetail(i)
                if d2 and d2.name
                    and (explicit or LoopSetup.matches(d2.name, cfg.fuelTags)) then
                    turtle.select(i)
                    if turtle.refuel(0) then
                        local oneFuel = 0
                        while turtle.getItemCount(i) > arrived and oneFuel <= 0 do
                            local before = fuelLevel()
                            if not turtle.refuel(1) then break end
                            oneFuel = fuelLevel() - before
                        end
                        if oneFuel > 0 then
                            local need = math.ceil((target - fuelLevel()) / oneFuel)
                            local have = turtle.getItemCount(i) - arrived
                            if need > 0 and have > 0 then
                                turtle.refuel(math.min(need, have))
                            end
                        end
                    end
                end
            end
        end
    end
    turtle.select(1)
    return fuelLevel() >= target
end

local SIDE_SUCK = {
    front = "suck", back = "suck", left = "suck", right = "suck",
    top = "suckUp", bottom = "suckDown",
}

-- Suck everything from the stated fuel chest side into inventory.
-- Returns true if anything arrived.
function LoopFuel.suckFuelChest(cfg)
    local side = cfg.fuelChestSide
    if not side or side == "none" then return false end
    local fn = SIDE_SUCK[side]
    if not fn then return false end
    face(side)
    local got = false
    for i = 1, 16 do
        turtle.select(i)
        while turtle.getItemCount(i) < 64 do
            if not turtle[fn]() then break end
            got = true
        end
    end
    turtle.select(1)
    unface(side)
    return got
end

-- If the bucket slot holds an EMPTY bucket and inspectFn sees lava,
-- placeFn to fill it. Returns true if the bucket is now full.
function LoopFuel.fillFrom(inspectFn, placeFn, cfg)
    local slot = cfg.bucketSlot or 16
    local d = turtle.getItemDetail(slot)
    if not d or d.name ~= EMPTY_BUCKET then return false end
    local ok, data = inspectFn()
    if not (ok and data and data.name and data.name:find("lava")) then
        return false
    end
    turtle.select(slot)
    placeFn()
    turtle.select(1)
    local d2 = turtle.getItemDetail(slot)
    return d2 and d2.name == LAVA_BUCKET
end

-- Refill the bucket from the lava side stated at startup. Assumes the
-- turtle is at the start position facing its start direction (the stated
-- side is relative to that). Turns toward the side and back.
function LoopFuel.fillAtStart(cfg)
    local side = cfg.lavaSide
    if not side or side == "none" then return false end
    if side == "front" then
        return LoopFuel.fillFrom(turtle.inspect, turtle.place, cfg)
    elseif side == "bottom" then
        return LoopFuel.fillFrom(turtle.inspectDown, turtle.placeDown, cfg)
    else
        face(side)
        local filled = LoopFuel.fillFrom(turtle.inspect, turtle.place, cfg)
        unface(side)
        return filled
    end
end

-- Fixed-point refuel at the start position: suck the fuel chest, fill the
-- bucket from the lava side, burn what arrived. Only newly sucked items
-- burn here, so a burnFuel=false inventory is left alone.
-- Returns true when fuel >= target.
function LoopFuel.refuelAtStart(cfg, target)
    local counts = {}
    for i = 1, 16 do counts[i] = turtle.getItemCount(i) end
    LoopFuel.suckFuelChest(cfg)
    LoopFuel.fillAtStart(cfg)
    return LoopFuel.burnUpTo(cfg, target, counts)
end

-- Wait for the user to add fuel, burning new arrivals until target.
-- Yields every 1.5s, wakes early on turtle_inventory, Q aborts (false).
-- Ctrl+T terminates as usual. Returns true when fuel >= target.
function LoopFuel.waitForFuel(cfg, target)
    local counts = {}
    for i = 1, 16 do counts[i] = turtle.getItemCount(i) end
    local missing = target - fuelLevel()
    print("Need " .. math.floor(missing) .. " more fuel.")
    if missing > COAL_STACK_FUEL then
        print("That is more than a stack of coal.")
        print("A lava bucket and a lava source block will cover it.")
    end
    print("Put fuel in any slot. Press Q to stop.")
    while fuelLevel() < target do
        if LoopFuel.burnUpTo(cfg, target, counts) then return true end
        local timer = os.startTimer(1.5)
        while true do
            local e, p = os.pullEvent()
            if e == "timer" and p == timer then break end
            if e == "key" and p == keys.q then
                print("Stopped waiting for fuel.")
                return false
            end
            if e == "turtle_inventory" then break end
        end
    end
    return true
end

-- Startup SmartFuel: target is 2x the trip estimate, capped at the limit.
-- Burns inventory fuel, then the fixed point (chest/lava), then waits for
-- fuel items at the start. Never exits just because fuel is short; returns
-- false only when the user aborts the wait.
function LoopFuel.ensure(cfg, tripEst)
    tripEst = tripEst or 0
    local limit = fuelLimit()
    local target = 2 * tripEst
    if target > limit - 1 then target = limit - 1 end
    if target < 0 then target = 0 end
    if fuelLevel() >= target then return true end
    if LoopFuel.burnUpTo(cfg, target) then return true end
    if LoopFuel.refuelAtStart(cfg, target) then return true end
    return LoopFuel.waitForFuel(cfg, target)
end

-- Quarry idiom (quarry:1799): head home while the trip is still affordable.
-- Call per step with the Manhattan distance back to the start.
function LoopFuel.needEvac(distHome)
    return fuelLevel() <= distHome + 10
end

return LoopFuel
