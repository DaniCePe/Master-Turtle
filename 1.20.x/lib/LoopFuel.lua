version = 20261013.0300
-- lib/LoopFuel.lua: quarry-inspired refuel helper for roaming loop programs.
-- Autonomy rule: never prompts. All choices come from cfg (LoopSetup).
--
-- Usage:
--   local LoopFuel = require("lib.LoopFuel")
--   LoopFuel.stage(cfg)                    -- consolidate tagged fuel into bucketSlot
--   if LoopFuel.ensure(cfg, minFuel) then  -- burn tagged fuel until minFuel
--   LoopFuel.fillAtStart(cfg)              -- refill bucket from stated lava side
--   LoopFuel.fillFrom(turtle.inspectDown, turtle.placeDown, cfg)  -- opportunistic
--
-- Slot rule: a bucket in the bucket slot means the lava workflow (fill when
-- empty, burn when full). An empty bucket slot may stage found tagged fuel.
-- Never burns anything not matching the fuel tags.
--
-- Works on Lua 5.1 and 5.2. No em dashes anywhere.

local LoopSetup = require("lib.LoopSetup")
local LoopFuel = {}

local EMPTY_BUCKET = "minecraft:bucket"
local LAVA_BUCKET = "minecraft:lava_bucket"

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

-- Burn tagged fuel one item at a time until fuel >= minFuel.
-- A full lava bucket in the bucket slot is burned first.
-- Returns true when fuel >= minFuel.
function LoopFuel.ensure(cfg, minFuel)
    minFuel = minFuel or 0
    local slot = cfg.bucketSlot or 16
    if not cfg.burnFuel then return fuelLevel() >= minFuel end
    if fuelLevel() >= minFuel then return true end
    local d = turtle.getItemDetail(slot)
    if d and d.name == LAVA_BUCKET then
        turtle.select(slot)
        turtle.refuel(1)
        turtle.select(1)
    end
    local limit = fuelLimit()
    for i = 1, 16 do
        if i ~= slot then
            local d2 = turtle.getItemDetail(i)
            if d2 and d2.name and LoopSetup.matches(d2.name, cfg.fuelTags) then
                turtle.select(i)
                while turtle.getItemCount(i) > 0
                    and fuelLevel() < minFuel and fuelLevel() < limit do
                    if not turtle.refuel(1) then break end
                end
                turtle.select(1)
                if fuelLevel() >= minFuel then return true end
            end
        end
    end
    return fuelLevel() >= minFuel
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
        if side == "left" then turtle.turnLeft()
        elseif side == "right" then turtle.turnRight()
        elseif side == "back" then turtle.turnLeft(); turtle.turnLeft() end
        local filled = LoopFuel.fillFrom(turtle.inspect, turtle.place, cfg)
        if side == "left" then turtle.turnRight()
        elseif side == "right" then turtle.turnLeft()
        elseif side == "back" then turtle.turnRight(); turtle.turnRight() end
        return filled
    end
end

return LoopFuel
