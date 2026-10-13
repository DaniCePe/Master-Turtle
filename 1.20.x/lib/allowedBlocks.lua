version = 20261013.0300
-- /lib/allowedBlocks.lua
-- Returns a table with allowed block list and the allowedBlocks() function

local M = {}

-- Explicitly allowed blocks (can be extended)
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

-- Function to detect allowed blocks
function M.allowedBlocks(name)
    if not name then return false end

    local id = name:lower()

    ----------------------------------------------------------------
    -- BLOCK REJECTION
    ----------------------------------------------------------------
    local rejectPatterns = {
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

    for _, pat in ipairs(rejectPatterns) do
        if id:find(pat) then
            return false
        end
    end

    ----------------------------------------------------------------
    -- EXPLICIT ALLOWLIST
    ----------------------------------------------------------------
    if M.allowed[id] then
        return true
    end

    ----------------------------------------------------------------
    -- AUTO-DETECTION FOR FULL BLOCK TYPES
    ----------------------------------------------------------------

    -- Saplings / propagules (requested)
    if id:find("sapling") then return true end
    if id:find("propagule") then return true end

    -- Planks
    if id:find("planks") then return true end

    -- Logs & stems
    if id:find("log") or id:find("stem") then return true end

    -- Leaves
    if id:find("leaves") then return true end

    -- Slabs
    if id:find("slab") then return true end

    -- Buttons
    if id:find("button") then return true end

    -- Stone & stone-like
    if (id:find("stone") and not id:find("redstone")) or
       id:find("granite") or id:find("andesite") or id:find("diorite") or
       id:find("tuff") or id:find("deepslate") or
       id:find("basalt") or id:find("blackstone") then
        return true
    end

    -- Glass
    if id:find("glass") then return true end

    -- Full kelp blocks
    if id:find("kelp") and id:find("block") then return true end

    -- Bricks & variants
    if id:find("brick") then return true end

    -- Terracotta & variants
    if id:find("terracotta") then return true end

    -- Sandstone variants
    if id:find("sandstone") then return true end

    -- Wool
    if id:find("wool") then return true end

    -- Concrete
    if id:find("concrete") then return true end

    -- Quartz
    if id:find("quartz") then return true end

    -- Dirt & grass
    if id:find("dirt") or id:find("grass") then return true end

    return false
end

return M
