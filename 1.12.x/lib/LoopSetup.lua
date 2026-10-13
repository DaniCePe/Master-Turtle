version = 20261013.1200
-- lib/LoopSetup.lua: shared starter prompt for run-until-stopped programs.
-- Autonomy rule: every question is answered ONCE here. Mid-run, the
-- turtle never waits for input.
--
-- Usage:
--   local LoopSetup = require("lib.LoopSetup")
--   local cfg = LoopSetup.run({
--     blurb = "one-paragraph usage text",
--     trash = true,      -- ask trash side + item-ID tags
--     dumpSide = true,   -- ask dump side for non-primary items
--     noFront = true,    -- exclude front from side choices
--     fuel = true,       -- ask: burn tagged fuel found while working?
--     fuelTags = true,   -- ask: which item IDs are OK to burn
--     fuelChest = true,   -- ask: fuel chest side at the start (for refills)
--     lava = true,       -- ask lava source: side at start / under while traveling
--     bucketSlot = 16,   -- designated fuel/bucket slot
--   })
--   if not cfg then return end  -- user aborted
--
-- Works on Lua 5.1 and 5.2. No em dashes anywhere.

local LoopSetup = {}

local SIDE_ORDER = { "front", "back", "left", "right", "top", "bottom" }

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Split comma-separated tags; lowercase, trimmed, empties dropped.
function LoopSetup.splitTags(s)
    local tags = {}
    for part in (s .. ","):gmatch("([^,]*),") do
        part = trim(part:lower())
        if part ~= "" then tags[#tags + 1] = part end
    end
    return tags
end

-- Substring match of an item name against a tag list.
function LoopSetup.matches(name, tags)
    if not name or not tags then return false end
    local n = name:lower()
    for _, t in ipairs(tags) do
        if n:find(t, 1, true) then return true end
    end
    return false
end

-- Raw ask; returns nil on "q" or terminated read (abort).
local function ask(prompt)
    io.write(prompt .. " ")
    local s = read()
    if s == nil then return nil end
    s = trim(s)
    if s:lower() == "q" then return nil end
    return s
end

local function askSide(prompt, opts)
    opts = opts or {}
    print(prompt)
    local choices = {}
    for _, side in ipairs(SIDE_ORDER) do
        if not (opts.exclude and opts.exclude[side]) then
            choices[#choices + 1] = side
            print("  " .. #choices .. ") " .. side)
        end
    end
    if opts.allowNone ~= false then
        choices[#choices + 1] = "none"
        print("  " .. #choices .. ") none")
    end
    while true do
        local s = ask("Pick [1-" .. #choices .. "] (name or q to abort):")
        if s == nil then return nil end
        local n = tonumber(s)
        if n and n >= 1 and n <= #choices then return choices[n] end
        s = s:lower()
        for _, c in ipairs(choices) do
            if c == s then return c end
        end
        print("Pick a number 1-" .. #choices .. ", a side name, or q.")
    end
end

local function askYesNo(prompt, default)
    local hint = default and "[Y/n]" or "[y/N]"
    while true do
        local s = ask(prompt .. " " .. hint)
        if s == nil then return nil end
        s = s:lower()
        if s == "" then return default end
        if s == "y" or s == "yes" then return true end
        if s == "n" or s == "no" then return false end
        print("Answer y or n (q to abort).")
    end
end

local function askTags(prompt, default)
    local s = ask(prompt .. (default and " [" .. default .. "]" or " [none]") .. ":")
    if s == nil then return nil end
    if s == "" then s = default or "" end
    return LoopSetup.splitTags(s)
end

function LoopSetup.run(opts)
    opts = opts or {}
    if opts.blurb then
        print(opts.blurb)
        print("")
    end
    local cfg = {}
    cfg.bucketSlot = opts.bucketSlot or 16

    if opts.trash then
        local side = askSide("Trash side (tagged items get dumped here):", {})
        if not side then return nil end
        cfg.trashSide = side
        local tags = askTags("Trash item IDs, comma separated (substring matched)")
        if not tags then return nil end
        cfg.trashTags = tags
    else
        cfg.trashSide = "none"
        cfg.trashTags = {}
    end

    if opts.dumpSide then
        local exclude = nil
        if opts.noFront then exclude = { front = true } end
        local side = askSide("Dump side for non-primary items:", { exclude = exclude })
        if not side then return nil end
        cfg.dumpSide = side
    else
        cfg.dumpSide = "none"
    end

    if opts.fuel then
        local burn = askYesNo("Burn fuel items found while working?", true)
        if burn == nil then return nil end
        cfg.burnFuel = burn
        if burn and opts.fuelTags then
            local tags = askTags("Fuel item IDs, comma separated",
                "minecraft:coal,minecraft:charcoal,minecraft:coal_block,minecraft:lava_bucket")
            if not tags then return nil end
            cfg.fuelTags = tags
        else
            cfg.fuelTags = {}
        end
    else
        cfg.burnFuel = false
        cfg.fuelTags = {}
    end

    if opts.lava then
        -- Side lava is only usable at the start position; never from above.
        local side = askSide("Lava source side at the start position:",
            { exclude = { top = true } })
        if not side then return nil end
        cfg.lavaSide = side
        local under = askYesNo("Also check for lava below while traveling?", true)
        if under == nil then return nil end
        cfg.lavaUnder = under
    else
        cfg.lavaSide = "none"
        cfg.lavaUnder = false
    end

    if opts.fuelChest then
        local side = askSide("Fuel chest side at the start position (for refills):", {})
        if not side then return nil end
        cfg.fuelChestSide = side
    else
        cfg.fuelChestSide = "none"
    end

    return cfg
end

-- Safe no-op config (used when resuming old saves that predate the prompt).
function LoopSetup.defaults()
    return {
        bucketSlot = 16,
        trashSide = "none", trashTags = {},
        dumpSide = "none",
        burnFuel = false, fuelTags = {},
        fuelChestSide = "none",
        lavaSide = "none", lavaUnder = false,
    }
end

-- Turn toward a side and back (for drop/inspect toward named sides).
local function faceSide(side)
    if side == "left" then turtle.turnLeft()
    elseif side == "right" then turtle.turnRight()
    elseif side == "back" then turtle.turnLeft(); turtle.turnLeft() end
end

local function unfaceSide(side)
    if side == "left" then turtle.turnRight()
    elseif side == "right" then turtle.turnLeft()
    elseif side == "back" then turtle.turnRight(); turtle.turnRight() end
end

local SIDE_DROP = {
    front = "drop", back = "drop", left = "drop", right = "drop",
    top = "dropUp", bottom = "dropDown",
}
local SIDE_INSPECT = {
    front = "inspect", back = "inspect", left = "inspect", right = "inspect",
    top = "inspectUp", bottom = "inspectDown",
}

-- Drop items toward a named side. filter(i) selects slots.
-- Returns true if anything moved.
function LoopSetup.dropToward(side, filter)
    if not side or side == "none" then return false end
    local dropFn = SIDE_DROP[side]
    if not dropFn then return false end
    faceSide(side)
    local moved = false
    for i = 1, 16 do
        if filter(i) and turtle.getItemCount(i) > 0 then
            turtle.select(i)
            local before = turtle.getItemCount(i)
            turtle[dropFn]()
            if turtle.getItemCount(i) < before then moved = true end
        end
    end
    turtle.select(1)
    unfaceSide(side)
    return moved
end

local INVENTORY_NAMES = { "chest", "barrel", "shulker", "hopper", "dropper", "dispenser" }

local function nameIsInventory(name)
    if not name then return false end
    for _, n in ipairs(INVENTORY_NAMES) do
        if name:find(n, 1, true) then return true end
    end
    return false
end

-- True if the block on the given turtle-relative side is an inventory.
-- CC:Tweaked: peripheral type check (covers hoppers and modded inventories).
-- dan200 CC: name fallback (inventories are not peripherals there).
-- Never moves items, so a failed detection cannot lose anything.
function LoopSetup.isInventory(side)
    if peripheral.hasType then
        local ok, res = pcall(peripheral.hasType, side, "inventory")
        if ok and res then return true end
    end
    faceSide(side)
    local ok, data = turtle[SIDE_INSPECT[side]]()
    unfaceSide(side)
    return (ok and data and nameIsInventory(data.name)) or false
end

-- First side in SIDE_ORDER (skipping excludeSide) holding an inventory.
function LoopSetup.findInventory(excludeSide)
    for _, side in ipairs(SIDE_ORDER) do
        if side ~= excludeSide then
            if LoopSetup.isInventory(side) then return side end
        end
    end
    return nil
end

return LoopSetup
