
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
    minetest.chat_send_all(dump(ammo_table.bullets).."  "..dump(ammo_table.total_bullets))
    if ammo_table.bullets[ammo_table.loaded_bullet] ~= nil then
        ammo_table.bullets[ammo_table.loaded_bullet]=ammo_table.bullets[ammo_table.loaded_bullet]-1
    end
    ammo_table.total_bullets = ammo_table.total_bullets - 1
    ammo_table.loaded_bullet = guns3d.weighted_randoms(ammo_table.bullets)
    return ammo_table
end
function guns3d.quick_dual_sfx(player, sound_id, sound_file, distance)
    local playername = player:get_player_name()
    local dir, pos = gun_dir_pos(player)
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
function guns3d.end_current_animation(gun, arm, player)
    local t={guns3d.data[playername].attached_gun, guns3d.data[playername].attached_arms}
    local playername = player:get_player_name()
    for i=1,2 do 
        if (i==1 and gun) or (i==2 and arm) then
            t[i]:set_animation({x=0, y=0})
            guns3d.data[playername].animated[i] = false
            guns3d.data[playername].animation_queue[i] = nil
        end
    end
end
function guns3d.start_animation(gun, arm, player)
    local playername = player:get_player_name()
    local t={gun, arm}
    for i=1,2 do 
        if (i==1 and gun) or (i==2 and arm) then
            guns3d.data[playername].animated[i] = false
            guns3d.data[playername].animation_queue[i] = t[i]
        end
    end
end

function guns3d.get_gun_def(player, itemstack)
    local def = table.copy(guns3d.guns[itemstack:get_name()])
    local modifiers = {}
    for modifier, value in pairs(modifiers) do
        --this will be used in the future to allow modifications of gun stats
        --based on player, global, or otherwise.
    end
    def.firetype = def.fire_modes[guns3d.data[playername].fire_mode]
    local value_table = {}
    local sorting_table = {}
    if def.controls then
        for i, v in pairs(def.controls) do
            sorting_table[i]=#v[1] 
            table.insert(value_table, #v[1])
        end 
        table.sort(value_table, function(a, b) return a > b end)
        for i2, v2 in pairs(sorting_table) do
            local filled = false
            for i, v in pairs(value_table) do 
                if v == v2 and not filled then
                    value_table[i]=i2
                    filled = true
                end
            end
        end
    end
    --minetest.chat_send_all(dump(value_table))
    def.control_index_list = value_table

    if def.ammo_type == "magazine" then
        def.actual_clip_size = guns3d.magazines[itemstack:get_meta():get_string("ammo")]
    else
        def.actual_clip_size = def.clip_size
    end
    return def 
end
--still kinda broken... no idea why, really bothers me, but cant do anything
function guns3d.ads_interpolate(player, percentile)
    local def = guns3d.get_gun_def(player, player:get_wielded_item())
    def.offset = vector.new(def.offset.x, -def.offset.y, def.offset.z)
    if def == nil then return minetest.chat_send_all("nil def or no gun") end
    local playername = player:get_player_name()
    local arm_pos, _ = player:get_bone_position("Arm_Right2")
    arm_pos.x = -arm_pos.x
    arm_pos.y = arm_pos.y - guns3d.data[player:get_player_name()].bone_offsets.root
    local eye_pos, _ = player:get_bone_position("Eye_bone")
    eye_pos.x = -eye_pos.x 

    --relative arm pos
    local recoil = guns3d.data[playername].recoil_offset 
    local sway = guns3d.data[playername].sway_offset
    local rotation = vector.multiply({x=-sway.x+-recoil.x, y=-sway.y+-recoil.y, z=0}, math.pi/180)
    rotation.x = rotation.x + player:get_look_vertical()
    --this is the position of the gun relative to the player (at hip)
    local pos1 = vector.rotate(def.offset*10, rotation)+arm_pos
    pos1 = vector.rotate(pos1-eye_pos, {x=-player:get_look_vertical(),z=0,y=0})
    pos2 = vector.new(def.ads_offset.z,def.ads_offset.y,def.ads_offset.x)*10
    local current_pos = (pos2*percentile)+pos1*(1-percentile)
    return current_pos
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
function gun_dir_pos(player, offset)
    if not offset then offset = vector.new() end
    local def = guns3d.get_gun_def(player, player:get_wielded_item())
    local playername = player:get_player_name()
    local ads = guns3d.data[playername].ads
    local arm_pos, _ = get_exact_arm_position(player, "Arm_Right2")
    
    local current_bone_pos 
    if ads or not (guns3d.data[playername].ads_location == 0 or guns3d.data[playername].ads_location == 1) then 
        current_bone_pos = vector.add({x=0, y=(player:get_properties().eye_height), z=0}, player:get_pos())
    else
        current_bone_pos = arm_pos
    end

    local current_offset
    if guns3d.data[playername].ads_location == 0 or guns3d.data[playername].ads_location == 1 then
        if ads then
            current_offset = {x=def.ads_offset.z,y=def.ads_offset.y,z=def.ads_offset.x}+offset
        else
            current_offset = def.offset+offset
        end
    else
        current_offset = (guns3d.ads_interpolate(player, guns3d.data[playername].ads_location)/10)+offset
    end

    local wag = guns3d.data[playername].wag_offset
    local recoil = guns3d.data[playername].recoil_offset 
    local sway = guns3d.data[playername].sway_offset
    local rotation = vector.dir_to_rotation(player:get_look_dir())
    rotation = vector.add(vector.multiply({x=sway.x+recoil.x+wag.x, y=-sway.y+-recoil.y+-wag.y, z=0}, math.pi/180), rotation)

    local new_dir = vector.rotate({x=0,y=0,z=1}, rotation)
    local new_pos = vector.rotate(current_offset, rotation)
    new_pos = vector.add(current_bone_pos, new_pos)    
    --[[local hud = player:hud_add({
        hud_elem_type = "image_waypoint",
        text = "muzzle_flash2.png",
        world_pos =  new_pos,
        scale = {x=5, y=5},
        alignment = {x=0,y=0},
        offset = {x=0,y=0},
    })
    minetest.after(0, function(hud)
        player:hud_remove(hud) 
    end, hud)]]
    return new_dir, new_pos 
end
--also handles (some) sounds
function guns3d.handle_animation(player, animation)
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
end

--skinny support neededfro
function guns3d.handle_node_hit_fx(dir, node, pointed)
    local reverse_dir = vector.direction(dir, vector.new())
    --bullet collision effects
    minetest.sound_play(minetest.registered_nodes[node.name].sounds.dug,{
        pos = pos,
        gain = 1,
        pitch = 1.1,
        max_hear_distance = 32
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
function guns3d.ray(player, pos, def, dist, dir, new_ray, times_looped)
    --new_ray is basically to keep track of if the function is currently tracking a bullet-
    --which is inside a wall
    --yes, i know. This code is... messy, and hard to understand, and defies logic.
    --however, this was the best way i found
    if new_ray == true then
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
function get_exact_arm_position(player, bone_name)
    local bone_pos, bone_rot = player:get_bone_position(bone_name)
    bone_rot = vector.multiply(bone_rot, math.pi/180)
    bone_pos = vector.divide({x=-bone_pos.x, y=bone_pos.y+guns3d.data[playername].bone_offsets.root, z=bone_pos.z}, 10)
    bone_pos = vector.add(vector.rotate(bone_pos, {x=0, y=player:get_look_horizontal(), z=0}), player:get_pos())
    return bone_pos, bone_rot
end
function get_exact_head_position(player, bone_name)
    --offset is .21
    --y offset is 12.6
    local bone_pos, bone_rot = player:get_bone_position(bone_name)
    bone_rot = vector.multiply(bone_rot, math.pi/180)
    bone_pos = vector.divide({x=bone_pos.x, y=bone_pos.y+-4.2, z=bone_pos.z}, 10)
    bone_pos = vector.add(vector.rotate(bone_pos, {x=-player:get_look_vertical(), y=player:get_look_horizontal(), z=0}), player:get_pos())
    bone_pos = vector.add(bone_pos, {x=0, y=1.36, z=0})
    return bone_pos, bone_rot
end


