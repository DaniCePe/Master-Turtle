version = 20261013.1200
-- /lib/allowedBlocks.lua
-- Returns a table with allowed block list and the allowedBlocks() function

local M = {}

-- User additions persist through the CC settings API (no stray data files).
-- pcall-guarded so a missing settings API can never break this lib.
pcall(function()
    settings.define("MasterTurtle.allowedExtra",
        { description = "User-added allowed blocks", type = "table", default = {} })
end)

-- Explicitly allowed blocks (can be extended via Block Manager)
M.allowed = {
    -- Basic stones
    ["minecraft:stone"] = true,
    ["minecraft:cobblestone"] = true,
    ["minecraft:smooth_stone"] = true,
    ["minecraft:stone_bricks"] = true,
    ["biomesoplenty:dried_sand"] = true,

    -- Planks
    ["minecraft:oak_planks"] = true,
    ["minecraft:spruce_planks"] = true,
    ["minecraft:birch_planks"] = true,
    ["minecraft:jungle_planks"] = true,
    ["minecraft:acacia_planks"] = true,
    ["minecraft:dark_oak_planks"] = true,
    ["minecraft:mangrove_planks"] = true,
    ["minecraft:cherry_planks"] = true,

    -- Decorative blocks
    ["minecraft:glass"] = true,
    ["minecraft:dried_kelp_block"] = true,
    ["minecraft:brick_block"] = true,
    ["minecraft:terracotta"] = true,
    ["minecraft:quartz_block"] = true,
    ["minecraft:sandstone"] = true,
    ["minecraft:smooth_sandstone"] = true,
    ["minecraft:cut_sandstone"] = true,
    ["minecraft:wool"] = true,
    ["minecraft:concrete"] = true
}

-- Blocks that are never allowed, whatever the list says
M.rejectPatterns = {
    "pane",
    "stairs",
    "wall",
    "fence",
    "fence_gate",
    "door",
    "trapdoor",
    "pressure_plate",
    "carpet",
    "sign",
    "torch",
    "ladder",
    "scaffolding",
    "slime_block",
    "honey_block",
    "kelp$",
    "root",
    "sand$",
    "gravel$",
    "shard",
    "piece",
    "facade",
    "cover",
    "hollow",
    "dust",
    "powder",
    "frame",
    "speleotem",
    "structure",
    "dye",
    "chest",
    "copycat"
}

-- Session override for the builders' startup offer.
-- When a session table is set (lowercase item name -> true), it IS the
-- list and the static allowlist is skipped. nil restores the static list.
function M.setSession(set)
    M.session = set
end

-- Function to check whether a block is allowed
function M.allowedBlocks(name)
    if not name then return false end

    local id = name:lower()

    -- Session override: the session table replaces the static list.
    if M.session then
        return M.session[id] == true
    end

    -- Explicit allowlist first: the owner's curated list wins outright
    -- (e.g. biomesoplenty:dried_sand is allowed despite ending in "sand").
    if M.allowed[id] then
        return true
    end

    -- Reject patterns guard everything else, including user additions.
    for _, pat in ipairs(M.rejectPatterns) do
        if id:find(pat) then
            return false
        end
    end

    -- User additions from the settings API
    local ok, extra = pcall(function()
        return settings.get("MasterTurtle.allowedExtra")
    end)
    if ok and type(extra) == "table" and extra[id] then
        return true
    end

    return false
end

return M
