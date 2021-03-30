local modn = minetest.get_current_modname()
local modp = minetest.get_modpath(modn)
local register_node = minetest.register_node
euthamia = {}
dofile(modp.."/particle.lua")
local function say(a) local b = type(a); minetest.chat_send_all(b == "string" and a or minetest.serialize(a)) end
euthamia.stages = {1,2,3,4,5,6,7,8}
euthamia.stagetimes = {6,4,2,9,18,14,19}
euthamia.substrate_names = {"nc_terrain:dirt","nc_terrain:dirt_with_grass"}
euthamia.substrates = {["nc_terrain:dirt"] = 2, ["nc_terrain:dirt_with_grass"] = 1}
euthamia.root_radius = 1
euthamia.substrate_score_base = 9
euthamia.seed_sprout_threshold = 4
euthamia.growth_threshold = 100
for n = 1, #euthamia.stages-1 do
    register_node(modn .. ':euthamia'..n, {
        description = 'euthamia tier'..n,
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
        groups = {oddly_breakable_by_hand = 3, euthamia = 6, euthamia_pollen = n == 5 and 1 or 0, flammable = 2, green = 2},
        on_ignite = "nc_fire:ash_lump",
        on_punch = function(pos)
            say(minetest.get_node_light(pos).." ||||| "..nodecore.get_node_light(pos))
            euthamia.check_light(pos)
        end
    })

minetest.register_decoration({
    deco_type = "simple",
    place_on = {"group:soil"},
    sidelen = 8,
        noise_params = {
            offset = -0.016,
            scale = 0.032,
            spread = {x = 20, y = 20, z = 20},
            seed = 34,
            octaves = 3,
            persist = n > 4 and 0.1 or 0.4,
            lacunarity = 2,
            flags = "absvalue"
        },
    biomes = "unknown",
    y_min = -15,
    y_max = 60,
    spawn_by = {"group:soil"},
    num_spawn_by = 8,
    --flags = "all_floors",
    decoration = modn..":euthamia"..n,
    height = 1,
    height_max = 0,
    param2 = 1,
    param2_max = 4,
    place_offset_y = 0,
})
end

minetest.register_craftitem(modn..":seed",{
    description = "Tiny Seed",
    inventory_image = "euthamia_seed.png",
    wield_scale = {x = 0.4, y = 0.4, z = 0.4},
    stack_max = 16,
})
nodecore.register_aism({
    label = "euthamia seed sprout",
    interval = 1,
    chance = 1,
    itemnames = {modn .. ":seed"},
    action = function(stack,data)
        local pos = data.pos
        local substrate_score = euthamia.check_substrate_area(pos)
        local is_sealed = minetest.get_item_group(minetest.get_node(pos).name,"silica") > 0
        if((not is_sealed) and euthamia.check_substrate(pos) and substrate_score)then
            local chance = math.random(10) + substrate_score/euthamia.substrate_score_base
            local name_repl = chance > euthamia.seed_sprout_threshold and modn..":euthamia1" or "air"
            minetest.set_node(pos, {name = name_repl})
            say("I placed "..name_repl)
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
euthamia.substrate_add("nc_fire:ash",-96)



--  --  Plant Behavior functions
euthamia.check_own_vibe = function(pos)
    return minetest.get_item_group(minetest.get_node(pos).name,"euthamia") > 0
end
euthamia.plant_grow = function(pos,lv)
    lv = lv and (lv < #euthamia.stages and lv + 1 or 1)
    minetest.set_node(pos, {name = modn..":euthamia"..lv, param2 = math.random(4)})
end

euthamia.wither = function(pos)
    minetest.remove_node(pos)
end

euthamia.check_light = function(pos)
    local light = nodecore.get_node_light(pos)
    return light > 10
end

euthamia.check_substrate = function(pos) -- Checks node below pos and returns only positive substrate score
    if(pos)then
    local name_below = pos and minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name
    local found = name_below and euthamia.substrates[name_below]
        return found and found > 0 and found
    end
end

euthamia.check_substrate_area = function(pos, r) --  Checks a y-slice underneath pos, returns substrate score(int)
    r = r or euthamia.root_radius
    if(pos and r)then
        local below = {x = pos.x, y = pos.y - 1, z = pos.z}
        --local check_under = euthamia.check_substrate(pos) -- remember should only be done once
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

euthamia.reproduce = function(pos) -- "i reproduced." - pelta 2021
    local stack = ItemStack({name = modn..":seed"})
    local function seed_score()
        local substrate_score = euthamia.check_substrate_area(pos,euthamia.root_radius)
        if(substrate_score)then
            local seed_score = 4
            substrate_score = substrate_score > 0 and substrate_score or 0
            substrate_score = (substrate_score/9)*2
            local fickle_seed_cull = math.random(100-substrate_score) -- variable sets the upper limit for random draw
            fickle_seed_cull = math.random(100) < fickle_seed_cull and -2 or 0  -- true means to cull 2 seeds, otherwise no. (drawing higher means safety from seed cull)
            seed_score = seed_score + fickle_seed_cull
        return seed_score
        end
    end
    nodecore.item_eject(pos, stack, math.random(4), math.random(seed_score()), {x = math.random(0,2)+0.5, y = math.random(0,2)+1, z = math.random(0,2)+0.5})
    euthamia.wither(pos)
end

euthamia.fickle_reaper = function(pos, lv, num)
    return lv < lv and math.random(1000) > num and minetest.set_node(pos,{name = "nc_lode:block_annealed"})--minetest.remove_node(pos) 
end
minetest.register_abm(
{
    label = "Grass Logic",
    -- Descriptive label for profiling purposes (optional).
    -- Definitions with identical labels will be listed as one.

    nodenames = {"group:euthamia"},
    interval = 3.0,
    -- Operation interval in seconds

    chance = 35,
    -- Chance of triggering `action` per-node per-interval is 1.0 / this
    -- value

    catch_up = true,
    action = function(pos, node)
        if(euthamia.check_light(pos) and euthamia.check_substrate(pos))then
            local name = node.name
            local lv = tonumber(string.sub(name,string.find(name,"%d")))
            local gt = euthamia.growth_threshold
            local gf = euthamia.check_substrate_area(pos) -- soil contribution to growth
            local growth_stage_offset = euthamia.stagetimes[lv]
            local chance = math.random(gt)+(growth_stage_offset*(gt/100))+(gf/4)
            if(chance > gt and lv ~= 7)then
                euthamia.fickle_reaper(pos,3,996)
                euthamia.plant_grow(pos,lv)
            elseif(chance > gt and lv == 7 )then
                euthamia.reproduce(pos)
                say("I reproduced")
            end
        else euthamia.wither(pos) end
    end
})

minetest.register_abm(
{
    label = "Sporulating Blossoms",
    nodenames = {"group:euthamia_pollen"},
    interval = 3.0,
    chance = 3,
    catch_up = false,
    action = function(pos, node)
        local wind = {x = math.random(-1,1), y = 0.2, z = math.random(-1,1)}
        local wind_speed = math.random()
        euthamia.spore_distribute(pos,wind,wind_speed)
    end
})

