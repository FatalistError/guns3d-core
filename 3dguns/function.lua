
--this file just contains helper functions, i want to fucking die, third rewrite.

--welcome to code block hell
InfAmmoCrtv = false
local max_wear = 65534
--[[function guns3d.compare_table(tbl1, tbl2)
    --this ignores table meta because... fuck you
    tbl1 = table.copy(tbl1)
    tab2 = table.copy(tbl2)
    local result = true
    for i, v in pairs(tbl1) do
        --checks if both of them exist/don't exist
        if ((tbl1[i]==nil) ~= (v==nil)) then result = false break end
        --checks that the types are the same
        if type(tbl2[i]) ~= type(v) then result = false break end
        --checks that if its the table it's the same (bonus points for it calling itself)
        if type(tbl2[i]) == "table" then 
            if not guns3d.compare_table(tbl2[i], v) then result = false break end
        else
            if         
    end
    return result
end]]
local sfx = {}
function guns3d.weighted_randoms(weight_table)
    local weight_table = table.copy(weight_table)
    local new_table = {}
    local ran = math.random()
    local total_weight = 0
    for i, v in pairs(weight_table) do
        total_weight=total_weight+v
        table.insert(new_table, {i, v})
    end
    table.sort(new_table, function(a, b) return a[2] > b[2] end)
    --we now have the total weight and a usable table
    local last_value = 0
    for _, v in ipairs(new_table) do
        if ran < (last_value+v[2])/total_weight then
            return v[1]
        else
            last_value = v[2]
        end
    end
end
function guns3d.dechamber_bullet(player, ammo_table)
    ammo_table = table.copy(ammo_table)
    if ammo_table.bullets[ammo_table.loaded_bullet] ~= nil then
        ammo_table.bullets[ammo_table.loaded_bullet]=ammo_table.bullets[ammo_table.loaded_bullet]-1
    end
    ammo_table.total_bullets = ammo_table.total_bullets - 1
    ammo_table.loaded_bullet = guns3d.weighted_randoms(ammo_table.bullets)
    return ammo_table
end
function guns3d.quick_dual_sfx(player, sound_id, sound_file, distance)
    local playername = player:get_player_name()
    local dir, pos = guns3d.gun_dir_pos(player)
    if not sfx[playername] then sfx[playername] = {} end
    sfx[playername][sound_id]={
        x = minetest.sound_play(sound_file,{
            to_player = playername,
            loop = false,
        }),
        y = minetest.sound_play(sound_file,{
            pos = player:get_pos(),
            max_hear_distance = distance,
            exclude_player = playername,
            loop = false,
        })
    }
end
function guns3d.kill_dual_sfx(player, sound_id, fade)
    local playername = player:get_player_name()
    if sfx[playername][sound_id] then
        --minetest.sound_stop(sfx[playername][sound_id].x)
        minetest.sound_fade(sfx[playername][sound_id].x, 1000, 0)
        minetest.sound_fade(sfx[playername][sound_id].y, 1000, 0)
    end
    sfx[playername][sound_id] = nil
end
function guns3d.end_current_animation(player)
    local playername = player:get_player_name()
    guns3d.data[playername].attached_gun:set_animation({x=0, y=0})
    guns3d.data[playername].animated = false
    guns3d.data[playername].animation_queue = {}
end
function guns3d.start_animation(animation_table, player)
    local playername = player:get_player_name()
    guns3d.data[playername].animated = false
    guns3d.data[playername].animation_queue = animation_table
end
--this function is totally broken, no idea why, rewrote it like 3 times... guess ill make it 4
function guns3d.ads_interpolate(player, percentile)
    return vector.new()
end
--stolen from elk... (see spriteguns [line here]) what the fuck does this even do, anyway it's used fo
function math.clamp(val, lower, upper)
    assert(val and lower and upper, "not very useful error message here")
    if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way (/not my comment you shitters)
    return math.max(lower, math.min(upper, val))
end
--also stolen from elk, who stole it from some random person then converted from c to lua
--https://forum.unity.com/threads/how-do-i-find-the-closest-point-on-a-line.340058/
function guns3d.nearest_point_on_line(line_start, line_end, point)
    local line = vector.subtract(line_end, line_start)
    local length = vector.length(line)
    line = vector.normalize(line)
    local v = vector.subtract(point, line_start)
    local d = vector.dot(v, line)
    d = math.clamp(d, 0, length);
    return vector.add(line_start, vector.multiply(line, d))
end
function guns3d.gun_dir_pos(player, added_pos, relative_to_player)
    added_pos = vector.new(added_pos)
    local player_properties = player:get_properties()
    local def = guns3d.get_gun_def(player, player:get_wielded_item())
    local model_def = guns3d.model_def[guns3d.data[playername].player_model]
    local playername = player:get_player_name()
    local bone_location = model_def.offsets.global_hipfire_offset/10
    local gun_offset = def.offset/10
    local axis_rotation = def.axis_rotation
    
    if guns3d.data[playername].ads then 
        gun_offset = def.ads_offset/10
        axis_rotation = def.ads_axis_rotation
        if guns3d.data[playername].ads_location == 1 or guns3d.data[playername].ads_location == 0 then
            bone_location = vector.new(0, player_properties.eye_height, 0)
        else
            --ads interpolate would go here.
            bone_location = (vector.new(0, player_properties.eye_height, 0))
        end
    end

    added_pos = vector.rotate(added_pos, axis_rotation*math.pi/180)
    gun_offset = gun_offset+added_pos
    bone_location = vector.new(-bone_location.x, bone_location.y, bone_location.z)

    local player_horizontal = player:get_look_horizontal()
    if relative_to_player then player_horizontal = 0 end
    local player_rotation = vector.new(-player:get_look_vertical(), player_horizontal, 0)

    local wag = guns3d.data[playername].wag_offset*(math.pi/180)
    local recoil = guns3d.data[playername].recoil_offset*(math.pi/180)
    local sway = guns3d.data[playername].sway_offset*(math.pi/180)

    --dir needs to be rotated twice seperately to avoid weirdness
    local dir = vector.new(vector.rotate({x=0, y=0, z=1}, {y=0, x=wag.x+recoil.x+sway.x+player_rotation.x, z=0}))
    dir = vector.rotate(dir, {y=wag.y+recoil.y+sway.y+player_rotation.y, x=0, z=0})

    local local_pos = vector.rotate(bone_location, {x=0, y=player_horizontal, z=0})+vector.rotate(gun_offset, wag+recoil+sway+player_rotation)
    local eye_offset = vector.rotate(player:get_eye_offset()/10, {x=0, y=player_horizontal, z=0})
    --[[local hud = player:hud_add({
        hud_elem_type = "image_waypoint",
        text = "muzzle_flash2.png",
        world_pos =  local_pos+player:get_pos(),
        scale = {x=.6, y=.6},
        alignment = {x=0,y=0},
        offset = {x=0,y=0},
    })
    minetest.add_particle({
        pos = local_pos+player:get_pos(),
        expirationtime = .05,
        texture = "muzzle_flash2.png"
    })
    minetest.after(0, function(hud)
        player:hud_remove(hud) 
    end, hud)]]
    --dir, new_pos
    return dir, local_pos
end
function guns3d.arm_dir_rotation(player, left, bone)
    local playername = player:get_player_name()
    --serverside anim tracking
    local rotation = vector.new()
    local length = vector.new()
    local dir = vector.new()
    if guns3d.data[playername].attached_gun then
        local def = guns3d.get_gun_def(player, player:get_wielded_item())
        local model_def = guns3d.model_def[guns3d.data[playername].player_model]
        local anim_table = guns3d.data[playername].animation_queue[1]
        
        local objref = guns3d.data[playername].attached_gun
        local frame = 0
        
        if anim_table then
            frame = anim_table.frames.y-((anim_table.frames.y-anim_table.frames.x)*(anim_table.time/anim_table.length))
        end
        --animation compatibility needed in future (though it may be better to just simulate it this way) 
        local arm_pos = vector.new(model_def.offsets.global_hipfire_offset/10)
        if left then
            arm_pos = vector.new(model_def.offsets.global_lefarm_offset/10)
        end
        arm_pos.x = -arm_pos.x

        local offset
        if def.arm_aiming_bones then
            if left then
                offset, _ = b3d_tools.get_bone_pos_rot(def.arm_aiming_bones.left, objref, nil, frame)/10
            else
                offset, _ = b3d_tools.get_bone_pos_rot(def.arm_aiming_bones.right, objref, nil, frame)/10
            end
        end

        local _, gun_pos = guns3d.gun_dir_pos(player, offset, true)
        dir = vector.direction(arm_pos, gun_pos)
        rotation = vector.dir_to_rotation(dir)*180/math.pi
        length = vector.length(arm_pos, gun_pos)
        print(dump(rotation))
    end
    return dir, rotation, length
end
--for self explanitory, used to aim the arms

--DEPRICATED
--[[function guns3d.handle_animation(player, animation)
    local armref = guns3d.data[playername].attached_arms
    local gunref = guns3d.data[playername].attached_gun
    local gun_name = player:get_wielded_item():get_name()
    --this call is nessecary, because i don't want it to change the muzzle flash entity
    local def = guns3d.get_gun_def(player, player:get_wielded_item())
    guns3d.data[playername].current_anim = animation
    local _, gun_pos = gun_dir_pos(player)
    if animation == "fire" then
        if def.sounds["fire"] ~= nil then
            minetest.sound_play(def.sounds[animation].sound,{
                pos = gun_pos,
                max_hear_distance = def.sounds[animation].distance,
                pitch = 1,
                gain = 1
            })
        end
        if def.sounds["fire_long"] ~= nil then
            --need to know what to start it
            if def.sounds["fire"].distance ~= nil then
                for _, player2 in pairs(minetest.get_connected_players()) do
                    if vector.distance(player:get_pos(), gun_pos) >= def.sounds[animation].distance then
                        minetest.sound_play(def.sounds[animation.."_long"].sound,{
                            pos = pos,
                            max_hear_distance = def.sounds[animation.."_long"].distance,
                            pitch = 1,
                            gain = 1
                        })
                    end
                end
            end
        end
    end
    --check if player is aiming
    if animation == "unloaded" or animation == "resting" then
        local frames = def.arm_animation_frames[animation]
        if animation == "resting" then frames = {x=0, y=0} end
        gunref:set_animation(frames, 1, 0, false)
        return
    end
    if guns3d.data[playername].ads then
        animation = animation.."_ads"
    end
    if gunref ~= nil then
        if guns3d.data[playername].anim_state == 0 then
            guns3d.data[playername].anim_state = 1
        else
            guns3d.data[playername].anim_state = 0
        end

        if def.animation_frames[animation] ~= nil then
            local gun_range = {}
            local fps = 60
            gun_range = def.animation_frames[animation]
            gun_range.y = gun_range.y + guns3d.data[playername].anim_state
            if animation == "reload" or animation == "reload_ads" then 
                fps = math.abs((gun_range.y-gun_range.x)/def.reload_time)
            elseif player:get_wielded_item():get_meta():get_string("ammo") == "" then
                gun_range = def.animation_frames["unloaded"]
            end
            --minetest.chat_send_all(dump(def.animation_frames[animation]))
            gunref:set_animation(gun_range, fps, 0, false)
        end
        if def.arm_animation_frames[animation] then
            local arm_range = {}
            local fps = 60
            arm_range = def.arm_animation_frames[animation]
            if animation == "reload" or animation == "reload_ads" then 
                fps = math.abs((arm_range.y-arm_range.x)/def.reload_time)
            elseif animation == "aim" or animation == "aim_ads" then
                fps = math.abs((arm_range.y-arm_range.x)/def.ads_time)
            end
            armref:set_animation(arm_range, fps, 0, false)
        end
        if animation == "fire" or animation == "fire_ads" then
            if not def.muzzle_flash_entity then def.muzzle_flash_entity = "3dguns:flash_entity" end
            if not def.muzzle_flash_texture then def.muzzle_flash_texture = "muzzle_flash2.png" end
            local flashref = minetest.add_entity(player:get_pos(), def.muzzle_flash_entity)
            local properties = flashref:get_properties()
            properties.visual_size = {x=.2,y=.2,z=.2}
            properties.textures = {def.muzzle_flash_texture}
            if properties.use_texture_alpha then properties.textures[1] = properties.textures[1].."^[opacity:"..tostring(math.random(140, 200)) end
            flashref:set_properties(properties)
            flashref:set_attach(gunref, "", def.flash_offset)
        end
    end
end]]

--skinny support neededfro
function guns3d.handle_node_hit_fx(dir, node, pointed)
    local reverse_dir = vector.direction(dir, vector.new())
    --bullet collision effects
    minetest.sound_play(minetest.registered_nodes[node.name].sounds.dug,{
        pos = pos,
        gain = 1,
        pitch = 1.1,
        max_hear_distance = 1
    })
    local max_particle_vel = vector.rotate(reverse_dir*10, {x=.15, y=.15, z=0})
    local min_particle_vel = vector.rotate(reverse_dir*10, {x=-.15, y=-.15, z=0})
    minetest.add_particlespawner({
        pos = pos,
        texture = minetest.registered_nodes[node.name].tiles[1],
        amount = 20,
        maxpos = pointed.intersection_point+reverse_dir/20,
        minpos = pointed.intersection_point+reverse_dir/20,
        minvel = max_particle_vel,
        maxvel = min_particle_vel,
        minacc = {x=0, y=-8, z=0},
        maxacc = {x=0, y=-8, z=0},
        time = .1,
        maxexptime = .3,
        minexptime = .12,
        minsize = .5,
        maxsize = .8
    })
    local obj = minetest.add_entity(pointed.intersection_point+reverse_dir*(.001+(.001*math.random())), "3dguns:bullet_hole")
    table.insert(guns3d.bullethole_deletion_queue, 1, obj)
    obj:get_luaentity().block_texture = minetest.registered_nodes[node.name].tiles[1]
    obj:set_rotation(vector.dir_to_rotation(vector.direction(pointed.under, pointed.above)))
    return false
end
function guns3d.tracer(player, start_pos, end_pos, def)
    playername = player:get_player_name()
    local offset = def.flash_offset
    local dir = vector.direction(start_pos, end_pos)
    local obj = minetest.add_entity(start_pos, "3dguns:tracer")
    local self = obj:get_luaentity()
    self.end_position = end_pos
    self.start_position = start_pos+dir
    obj:set_rotation(vector.dir_to_rotation(dir))
    obj:set_velocity(dir*800)
end
--REWRITE NEEDED 
function guns3d.ray(player, pos, def, dist, dir, new_ray, times_looped)
    --new_ray is basically to keep track of if the function is currently tracking a bullet-
    --which is inside a wall
    --yes, i know. This code is... messy, and hard to understand, and defies logic.
    --however, this was the best way i found
    if new_ray then
        if def.sounds.bullet_whizz ~= nil then
            for _, player2 in pairs(minetest.get_connected_players()) do
                if player2 ~= player then
                    local pos1 = vector.add(player2:get_pos(), {x=0, y=player2:get_properties().eye_height, z=0})
                    local pos2 = guns3d.nearest_point_on_line(pos, vector.multiply(dir, def.range), pos1)
                    local distance = vector.distance(pos1, pos2)
                    if distance < def.sounds.bullet_whizz.distance then
                        minetest.sound_play(def.sounds.bullet_whizz.sound, {
                            to_player = player2:get_player_name(),
                            gain = 1,
                            pitch = 1
                        })
                    end
                end
            end
        end
        local ray = minetest.raycast(pos, vector.add(vector.multiply(dir, def.range), pos))
        local first_node
        for pointed in ray do
            if pointed.type == "node" then
                --this prevents it from colliding with itself and creating a stack overflow
                if vector.distance(pos, pointed.intersection_point) > .1 then
                    local next_node = minetest.get_node(pointed.under)
                    if not first_node then
                        first_node = pointed.intersection_point
                        guns3d.tracer(player, pos, first_node, def)
                        guns3d.handle_node_hit_fx(dir, next_node, pointed)
                    end
                    for name, pen_value in pairs(def.bullet.pen_nodes) do
                        if next_node.name == name then
                            --[[player:hud_add({
                                hud_elem_type = "image_waypoint",
                                text = "entering_wall.png",
                                world_pos = pointed.intersection_point,
                                scale = {x=5, y=5},
                                alignment = {x=0,y=0},
                                offset = {x=0,y=0},
                            })]]
                            guns3d.ray(player, pointed.intersection_point, def, dist, dir, false, times_looped+1)
                            return
                        end
                    end
                end
            elseif pointed.type == "object" then
                --damage the punch the player/object (if pointable)
            end
        end
        if not first_node then 
            guns3d.tracer(player, pos, vector.add(vector.multiply(dir, def.range), pos), def)
        end
    else
        --not worth doing a for loop when its gonna be the same amount of lines added
        local mp1 = math.random(0, 20) if mp1 > 10 then mp1 = -1 else mp1 = 1 end
        local x1 = math.random(def.bullet.max_pen_deviation*10, def.bullet.min_pen_deviation*10)/10*mp1
        local mp2 = math.random(0, 20) if mp2 > 10 then mp2 = -1 else mp2 = 1 end
        local y1 = math.random(def.bullet.max_pen_deviation*10, def.bullet.min_pen_deviation*10)/10*mp2
        local new_rot = {x=x1, y=y1, z=0}
        local new_dir = vector.rotate(dir, vector.multiply(new_rot, math.pi/180))
        
        --check one block ahead to see if the wall ends
        local target_node = minetest.get_node(vector.add(pos, new_dir))
        for name, pen_value in pairs(def.bullet.pen_nodes) do
            --if well doesn't end, then continue calling the function until A: max penetration is hit, or B: wall ends
            if target_node.name ~= "air" then
                if target_node.name == name then
                    guns3d.ray(player, vector.add(pos, new_dir), def, dist+1, new_dir, false, times_looped+1)
                    --[[player:hud_add({
                        hud_elem_type = "image_waypoint",
                        text = "gun_mrkr.png",
                        world_pos = vector.add(pos, new_dir),
                        scale = {x=5, y=5},
                        alignment = {x=0,y=0},
                        offset = {x=0,y=0},
                    })]]
                end
            else
                --when wall ends, find the exact intersection point, so the distance can be found, and the bullethole can be placed precisely
                --and of course, start a new ray from that location
                if target_node.name == "air" then
                    local ray = minetest.raycast(vector.add(pos, new_dir), pos, false, true)
                    local pointed = ray:next()
                    local intersect = pointed.intersection_point
                    local end_node = minetest.get_node(pointed.under)
                    if end_node.name == name then
                        local new_dist = dist + vector.distance(pos, intersect)
                        guns3d.ray(player, intersect, def, new_dist, dir, true, times_looped+1)
                        guns3d.handle_node_hit_fx(vector.direction(new_dir, vector.new()), end_node, pointed)
                        --[[player:hud_add({
                            hud_elem_type = "image_waypoint",
                            text = "exiting_wall.png",
                            world_pos = intersect,
                            scale = {x=5, y=5},
                            alignment = {x=0,y=0},
                            offset = {x=0,y=0},
                        })]]
                    end
                end
            end
        end
    end
end