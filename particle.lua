local modn = minetest.get_current_modname()
euthamia.spore_distribute = function(pos,dir,mag)
    if(euthamia.check(pos))then
        local dir = dir or {x = 0, y = 0, z = 0}
        local mag = mag or 1
        local bas = {x = 1, y = 1, z = 1}
        minetest.add_particlespawner({
            amount = 16,
            time = 1,
            minpos = {x=pos.x-0.2, y=pos.y, z=pos.z-0.2},
            maxpos = {x=pos.x+0.3, y=pos.y+0.3, z=pos.z+0.3},
            minvel = dir,
            maxvel = vector.multiply(dir,mag/10),
            minacc = {x = 0, y = 0, z = 0},
            maxacc = vector.multiply(bas,mag/10),
            minexptime = 3,
            maxexptime = 6,
            minsize = 0.1,
            maxsize = 0.2,

            collisiondetection = false,
            collision_removal = false,
            vertical = true,
            texture = modn.."_spore.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 4,
                aspect_h = 4,
                length = 0.5},
            {
                type = "sheet_2d",
                frames_w = 1,
                frames_h = 5,
                frame_length = 0.1,
            },
            glow = 12
        })
    end
end