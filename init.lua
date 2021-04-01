local modn = minetest.get_current_modname()
local modp = minetest.get_modpath(modn)
euthamia = {}
dofile(modp.."/particle.lua")

euthamia.stages = {1,2,3,4,5,6,7} -- plant stages. (should only remain as a table if; NB* color variants? petals?)
euthamia.stagetimes = {6,4,2,2,18,14,19} -- added to chance value per growth stage/level, higher influences faster growth
euthamia.substrates = {["nc_terrain:dirt"] = 2,["nc_terrain:dirt_loose"] = 2, ["nc_terrain:dirt_with_grass"] = 1, ["nc_tree:humus"] = 4,["nc_tree:peat"] = 3,["nc_lode:block_annealed"] = -2, ["nc_fire:coal8"] = -4}
euthamia.substrate_names = {}

for k,_ in pairs(euthamia.substrates) do
    table.insert(euthamia.substrate_names,k) -- named table should always have all entries with scores.
end

euthamia.substrates_mapgen = {"nc_terrain:dirt_with_grass","nc_terrain:dirt"} -- used to specify mapgen decoration placement
euthamia.root_radius = 1 -- base radius offset to x and y axes used in area substrate check (absolute value).
euthamia.substrate_score_base = 9 -- base for amount that summed substrate scores are divided by (evaluates to 1 for 9x9 grass).
euthamia.seed_sprout_threshold = 3 -- a seed must have a final rolled + bolstered survival value higher than this to sprout. Out of 10.
euthamia.growth_threshold = 118 -- similar to above, but not
euthamia.crops = {modn..":fibres"} -- harvestable crop items (NB* petals, seeds, ichor)
euthamia.sounds = {"grass_rustle1","grass_rustle2"}


for n = 1, #euthamia.stages do
    local isyoung = n < 5
    local nodename = modn..":euthamia"..n
    minetest.register_node(nodename, {
        description = "euthamia",
        drawtype = "plantlike",
        waving = 1,
        paramtype = "light",
        paramtype2 = "meshoptions",
        walkable = false,
        floodable = true,
        sunlight_propagates = true,
        tiles = {"euthamia"..n..".png"},
        selection_box = {
            type = "fixed",
            fixed = {
                {-6 / 16, -0.5, -6 / 16, 6 / 16, -3 / 16, 6 / 16},
            },
        },
        groups = {snappy = 1,crumbly = 1, attached_node = 1, flora = 1, euthamia = n, euthamia_pollen = n == 5 and 1 or 0, flammable = 2, green = 2},
        on_ignite = "nc_fire:ash_lump",
        drop = "",
        sounds = nodecore.sounds(euthamia.sounds[isyoung and 1 or 2]),
        after_dig_node = function(pos)
            local fibrecount = isyoung and n or 1
            euthamia.harvest(pos,euthamia.crops[1],fibrecount+math.random(2))
        end
    })

    minetest.register_decoration({
        deco_type = "simple",
        name = "euthamia_mapgen"..n,
        place_on = euthamia.substrates_mapgen,
        sidelen = 16,
        noise_params = n < 5 and
        {
            offset = -0.002,
            scale = n < 2 and 0.038 or 0.042,
            spread = {x = 60, y = 60, z = 60},
            seed = 26,
            octaves = (n == 1) and 3 or 4,
            persist = 0.4,
            lacunarity = 2,
        }
        or
        {
            offset = -0.004,
            scale = 0.016,
            spread = {x = 136, y = 80, z = 145},
            seed = 17,
            octaves = 3,
            persist = 0.66
        },
        biomes = "unknown",
        y_min = -15,
        y_max = 60,
        spawn_by = euthamia.substrates_mapgen,
        num_spawn_by = 7,
        decoration = modn..":euthamia"..n,
        height = 1,
        height_max = 0,
        param2 = 2,
        param2_max = 4,
        place_offset_y = 0,
    })
end

--  --  --  SEED
minetest.register_craftitem(modn..":seed",{
    description = "Tiny Seed",
    inventory_image = "euthamia_seed.png",
    wield_scale = {x = 0.4, y = 0.4, z = 0.4},
    stack_max = 16,
    groups = {euthamia = 1, seedy = 1, flammable = 2, green = 2},
})


nodecore.register_aism({
    label = "euthamia seed sprout",
    interval = 32,
    chance = 4,
    itemnames = {modn .. ":seed"},
    action = function(stack,data)
        local pos = data.pos
        if(pos)then
            local is_sealed = minetest.get_item_group(minetest.get_node(pos).name,"silica") > 0 -- if in a glass/sand container
            if(not is_sealed)then
                local is_on_substrate = euthamia.check_substrate(pos)
                local substrate_score = euthamia.check_substrate_area(pos) or 0
                local chance = math.random(10) + substrate_score/euthamia.substrate_score_base -- soil contributes here (typically up to a max of 1 in nature for now)
                local name_repl = chance > euthamia.seed_sprout_threshold and is_on_substrate and modn..":euthamia1" or "air"
                minetest.set_node(pos, {name = name_repl})
            end
        end
    end
})

------------------------------- LOGIC
--  --  Core Data Manip functions
euthamia.substrate_add = function(name,value) -- Adds a node as a recognized substrate with a score of value
    if(name)then
        table.insert(euthamia.substrate_names,name)
        euthamia.substrates[name] = value or 0
    end
end
euthamia.substrate_add("nc_fire:ash",4) -- test



--  --  --  --  --  Plant Behavior

--  --  --  SELF
euthamia.check_own_vibe = function(pos) -- Checks for the existence of a euthamia plant at pos.
    return minetest.get_item_group(minetest.get_node(pos).name,"euthamia") > 0
end

euthamia.check = euthamia.check_own_vibe -- same as euthamia.check_own_vibe, second ref.

euthamia.wither = function(pos) -- kills plant at position
    if(pos and euthamia.check(pos))then
        minetest.remove_node(pos)
    end
end

--  --  --  GROWTH
euthamia.plant_grow = function(pos,lv) -- causes plant at pos to be replaced by it's older stage.
    lv = lv and (lv < #euthamia.stages and lv + 1) or 1
    minetest.set_node(pos, {name = modn..":euthamia"..lv, param2 = math.random(4)})
    return lv > 1
end

euthamia.check_growth = function(pos) -- returns the growth level of the plant if present
    local name = pos and minetest.get_node(pos).name
    local digit = name and string.find(name,"%d")
    local lv = digit and tonumber(string.sub(name,digit))
    return lv
end

--  --  --  VITAL REQUIREMENTS (soil, light, nutrition) (NB *add water, deeper nutrition calc)
euthamia.check_light = function(pos) -- returns true if pos is sufficiently lit. Values will be smaller than minetest.get_node_light.
    local light = pos and nodecore.get_node_light(pos)
    return light and light > 10
end

euthamia.check_substrate = function(pos) -- Checks node below pos and returns only positive substrate score
    if(pos)then
        local name_below = pos and minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name
        local found = name_below and euthamia.substrates[name_below]
        return found and found > 0 and found
    end
end

euthamia.check_vitals = function(pos) -- wraps together vital plant functions for full check in one call.
    return pos and euthamia.check_own_vibe(pos) and euthamia.check_light(pos) and euthamia.check_substrate(pos)
end

euthamia.check_substrate_area = function(pos, r) --  Checks a y-slice underneath pos, returns substrate score(int)
    r = r or euthamia.root_radius
    if(pos and r)then
        local below = {x = pos.x, y = pos.y - 1, z = pos.z}
        local function get_area_names()
            local corner1 = {x = below.x + r, y = below.y, z = below.z + r}
            local corner2 = {x = below.x - r, y = below.y, z = below.z - r}
            local area = minetest.find_nodes_in_area(corner1,corner2,euthamia.substrate_names) -- N*(use new [grouped] parameter)
            if(area and #area > 0)then
                for n = 1, #area do
                    area[n] = area[n] and minetest.get_node(area[n]).name or "air"
                end
                return area
            end
        end
        local function sum_substrate_score(names)
            local sum = 0
            if(names and type(names) == "table")then
                for n = 1, #names do
                    local score = names[n] and euthamia.substrates[names[n]] or 0
                    sum = sum + score
                end
            end
            return sum
        end
        local nodes_under = get_area_names()
        local score = sum_substrate_score(nodes_under)
        return score
    end
end

--  --  --  REPRODUCTION

euthamia.reproduce = function(pos) -- "i reproduced." - pelta 2021
    local stack = ItemStack({name = modn..":seed"})
    local function seed_score()
        local substrate_score = euthamia.check_substrate_area(pos,euthamia.root_radius)
        if(substrate_score)then
            local seed_score = 4
            substrate_score = substrate_score > 0 and substrate_score or 0
            substrate_score = (substrate_score/9)*2
            local fickle_seed_cull = math.random(96-substrate_score) -- variable sets the upper limit for random draw
            fickle_seed_cull = math.random(100) < fickle_seed_cull and -2 or 0  -- true means to cull 2 seeds, otherwise no. (drawing higher means safety from seed cull)
            seed_score = seed_score + fickle_seed_cull
            return seed_score
        end
    end
    nodecore.item_eject(pos, stack, math.random(4), math.random(seed_score()), {x = math.random(-2,2)+0.5, y = math.random(2)+2, z = math.random(-2,2)+0.5})
    euthamia.wither(pos)
end

--  --  --  HARVESTING
minetest.register_craftitem(euthamia.crops[1],{
    description = "Grass Bundle",
    inventory_image = "euthamia_fibre_bundle.png",
    stack_max = 16,
    sounds = nodecore.sounds(euthamia.sounds[1]),
    groups = {euthamia_crop = 1, flammable = 2, green = 2, oddly_breakable_by_hand = 1, snappy = 1},
    on_ignite = "nc_fire:ash_lump"
})

euthamia.harvest = function(pos,crop,lv)
    if(pos and crop and lv)then
        nodecore.item_eject(pos,crop,1,math.random(1,lv),{x = math.random(-1,1)+0.5, y = math.random(-1,1)+1, z = math.random(-1,1)+0.5})
    end
end

nodecore.register_craft({
    label = "grind euthamia fibres to peat",
    action = "pummel",
    toolgroups = {crumbly = 3},
    nodes = {
        {
            match = {name = modn..":fibres", count = 8},
            replace = "nc_tree:peat"
        }
    }
})

--  --  -- Active Behaviour
nodecore.register_limited_abm(
    {
        label = "Grass Logic",
        nodenames = {"group:euthamia"},
        interval = 4,
        chance = 35,
        catch_up = true,
        action = function(pos)
            if(euthamia.check_vitals(pos))then
                local lv = euthamia.check_growth(pos)
                local gt = euthamia.growth_threshold
                local gf = euthamia.check_substrate_area(pos) -- soil contribution to growth
                local growth_stage_offset = euthamia.stagetimes[lv] -- stagetimes to contribute slightly so that grassy plants have a lower chance of progressing.
                local chance = math.random(gt)+(growth_stage_offset*(gt/100))+(gf/2) -- Hardcoded values here to be reevaluated.
                if(chance > gt and lv ~= 7)then
                    euthamia.plant_grow(pos,lv)
                elseif(chance > gt)then
                    euthamia.reproduce(pos)
                end
            else euthamia.wither(pos) end
        end
    })


nodecore.register_limited_abm(
    {
        label = "Sporulating Blossoms",
        nodenames = {"group:euthamia_pollen"},
        interval = 5.0,
        chance = 10,
        catch_up = false,
        action = function(pos)
            local wind = {x = math.random(-1,1), y = 0.2, z = math.random(-1,1)} -- random values selected for wind vector to make things a little interesting.
            local wind_speed = math.random()
            euthamia.spore_distribute(pos,wind,wind_speed)
        end
    })


--  --  --  --  --  Compatibility

--[[local function force_place_default_nc_trees() -- without this, nodecore tree decorations and grass decoration fight, trees somehow always lose.
    minetest.after(1, function()
        for k,v in pairs(minetest.registered_decorations)do
            if(v.deco_type == "schematic")then
                v.flags = v.flags..", force_placement"
            end
        end
    end)
end
force_place_default_nc_trees()]]

local function prepare_for_winter() -- convenience conversion of euthamia fibers to nc_nature:plant_fibers
    minetest.after(1,function()
        if(minetest.registered_items["nc_nature:plant_fibers"])then
            minetest.register_alias_force(modn..":fibres","nc_nature:plant_fibers")
        end
    end)
end
prepare_for_winter()