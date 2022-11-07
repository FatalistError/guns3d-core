
--this file just contains helper functions, i want to fucking die, third rewrite.

--welcome to code block hell
InfAmmoCrtv = false
local max_wear = 65534

local sfx = {}
function table.compare(tbl1, tbl2)
    local result = true
    for i, v in pairs(tbl1) do
        if type(tbl1[i]) ~= type(tbl2[i]) then
            result = false
        elseif (type(tbl1[i])=="table" and not table.compare(tbl1[i], tbl2[i])) then
            result = false
        elseif (tbl1[i] ~= tbl2[i]) then
            result = false
        end
    end
    return result
end
--this function is designed for use in the main globalstep, and such uses many pre-existing variables within it to save resources.
function set_gun_rest_animation(player, def, attached_obj)
    local playername = player:get_player_name()
    --minetest.chat_send_all(dump(guns3d.data[playername].animated))
    local ammo_table = minetest.deserialize(player:get_wielded_item():get_meta():get_string("ammo"))
    local current_anim, _, _, _ = attached_obj:get_animation()
    if not guns3d.data[playername].animated and (guns3d.data[playername].rechamber_time > 60/def.firerate) then
        if (ammo_table.magazine == "" and def.reload.type == "magazine") or (ammo_table.total_bullets == 0 and def.reload.type ~= "magazine") then
            attached_obj:set_animation(def.animation_frames.unloaded)
            guns3d.data[playername].current_animation_frame = def.animation_frames.unloaded.x
        else
            attached_obj:set_animation(def.animation_frames.loaded)
            guns3d.data[playername].current_animation_frame = def.animation_frames.unloaded.y
        end
    end
end
local function interpolate(x, y, v)
    local returns
    if type(x) == "table" then
        returns = {}
        for i, v in pairs(x) do
            returns[i] = x[i]+((y[i]-x[i])*v)
        end
    else
        returns = x+((y-x)*v)
    end
    return returns
end
function guns3d.handle_muzzle_fsx(player, def)
    local playername = player:get_player_name()
    if guns3d.data[playername].particle_spawners.muzzle_smoke and guns3d.data[playername].particle_spawners.muzzle_smoke ~= -1 then
        minetest.delete_particlespawner(guns3d.data[playername].particle_spawners.muzzle_smoke, player:get_player_name())
    end
    local dir, offset_pos = guns3d.gun_dir_pos(player, def.flash_offset/10)
    offset_pos=offset_pos+player:get_pos()
    local min = vector.rotate(vector.new(-2, -2, -.3), vector.dir_to_rotation(dir))
    local max = vector.rotate(vector.new(2, 2, .3), vector.dir_to_rotation(dir))
    minetest.add_particlespawner({
        exptime = .09,
        time = .06,
        amount = 15,
        attached = guns3d.data[playername].attached_gun,
        pos = def.flash_offset/10,
        radius = .04,
        glow = 3.5,
        vel = {min=vector.new(-2, -2, -.3), max=vector.new(2, 2, .3), bias=0},
        texpool = {
            {
                name = "smoke2.png",
                alpha_tween = {.25, 0},
                scale = 2,
                blend = "alpha",
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .1,
                },
            },
            {
                name = "smoke2.png",
                alpha_tween = {.25, 0},
                scale = .8,
                blend = "alpha",
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .1,
                },
            },
            {
                name = "smoke2.png^[multiply:#dedede",
                alpha_tween = {.25, 0},
                scale = 2,
                blend = "alpha",
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .1,
                },
            },
            {
                name = "smoke2.png^[multiply:#b0b0b0",
                alpha_tween = {.2, 0},
                scale = 2,
                blend = "alpha",
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .25,
                },
            }
      }
    })
    --muzzle smoke
    guns3d.data[playername].particle_spawners.muzzle_smoke = minetest.add_particlespawner({
        exptime = .3,
        time = 2,
        amount = 50,
        pos = def.flash_offset/10,
        glow = 2,
        vel = {min=vector.new(-.1,.4,.2), max=vector.new(.1,.6,1), bias=0},
        attached = guns3d.data[playername].attached_gun,
        texpool = {
            {
                name = "smoke2.png",
                alpha_tween = {.12, 0},
                scale = 1.4,
                blend = "alpha",
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .35,
                },
            },
            {
                name = "smoke2.png^[multiply:#b0b0b0",
                alpha_tween = {.2, 0},
                scale = 1.4,
                blend = "alpha",
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .35,
                },
            }
    }
    })
end
--rename to "handle_recoil_fsx" for consistency
function guns3d.ordered_rotation(rotation)
    local new_dir = vector.new(0,0,1)
    new_dir = vector.rotate(new_dir, vector.new(rotation.x,0,0))
    new_dir = vector.rotate(new_dir, vector.new(0,rotation.y,0))
    new_dir = vector.rotate(new_dir, vector.new(0,0,rotation.z))
    return vector.dir_to_rotation(new_dir)
end
function guns3d.handle_recoil_effects(player, def)
    local playername = player:get_player_name()
    for _, i in pairs({"x", "y"}) do
        local multiplier = math.random()
        if multiplier > .5 then multiplier = 1 else multiplier = -1 end
        local recoil = guns3d.data[playername].recoil_offset
        local recoil_vel = guns3d.data[playername].recoil_vel
        recoil_vel.gun_axial[i] = recoil_vel.gun_axial[i] + def.recoil_vel.gun_axial[i] * multiplier
        if i=="x" then multiplier = 1 end
        recoil_vel.look_axial[i] = recoil_vel.look_axial[i] + def.recoil_vel.look_axial[i] * multiplier
    end
end
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
    local offset
    if added_pos then
        offset = true
    end
    added_pos = vector.new(added_pos)
    local player_properties = player:get_properties()
    local def = guns3d.get_gun_def(player, player:get_wielded_item())
    local model_def, model_name = guns3d.get_model_def_name(player)
    local playername = player:get_player_name()
    local bone_location = vector.new(model_def.offsets.arm_right_global)/10
    local gun_offset = def.offset/10

    if guns3d.data[playername].ads then
        gun_offset = def.ads_offset/10
        bone_location = vector.new(0, player_properties.eye_height, 0)+player:get_eye_offset()/10
    else
        --minetest is really wacky.
        bone_location = vector.new(-bone_location.x, bone_location.y, bone_location.z)
    end
    gun_offset = gun_offset+added_pos

    local player_horizontal = player:get_look_horizontal()
    if relative_to_player then player_horizontal = 0 end
    local player_rotation = vector.new(guns3d.data[playername].vertical_aim*math.pi/180, player_horizontal, 0)

    --dir needs to be rotated twice seperately to avoid weirdness
    local rotation = guns3d.data[playername].total_rotation
    local dir = vector.new(vector.rotate({x=0, y=0, z=1}, {y=0, x=((rotation.gun_axial.x+rotation.look_axial.x)*math.pi/180)+player_rotation.x, z=0}))
    dir = vector.rotate(dir, {y=((rotation.gun_axial.y+rotation.look_axial.y)*math.pi/180)+player_rotation.y, x=0, z=0})

    local local_pos = vector.rotate(bone_location, {x=0, y=player_horizontal, z=0})+vector.rotate(gun_offset, (rotation.look_axial*math.pi/180)+player_rotation)

    local hud_pos = local_pos+player:get_pos()
    if relative_to_player then
        hud_pos = vector.rotate(local_pos, vector.new(0,player:get_look_horizontal(),0) )+player:get_pos()
    end
    --[[if not false then
        local hud = player:hud_add({
            hud_elem_type = "image_waypoint",
            text = "muzzle_flash2.png",
            world_pos =  hud_pos,
            scale = {x=10, y=10},
            alignment = {x=0,y=0},
            offset = {x=0,y=0},
        })
        minetest.after(0, function(hud)
            player:hud_remove(hud)
        end, hud)
    end]]
    --[[minetest.add_particle({
        pos = hud_pos,
        expirationtime = .05,
        texture = "muzzle_flash2.png"
    })]]

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
        local model_def, _ = guns3d.get_model_def_name(player)

        local objref = guns3d.data[playername].attached_gun
        local frame = 0

        if not objref:get_pos() then
            offset = vector.new()
        end
        frame = guns3d.current_animation_frame
        --animation compatibility needed in future (though it may be better to just simulate it this way)
        local arm_pos = vector.new(model_def.offsets.arm_right_global)/10
        if left then
            arm_pos = vector.new(model_def.offsets.arm_left_global)/10
        end
        arm_pos.x = -arm_pos.x

        if objref:get_pos() then
            if left then
                offset = guns3d.data[playername].arm_animation_offsets.left
            else
                offset = guns3d.data[playername].arm_animation_offsets.right
            end
            offset = vector.new(offset)/10
        end
        local _, gun_pos = guns3d.gun_dir_pos(player, offset, true)
        dir = vector.direction(arm_pos, gun_pos)
        rotation = vector.dir_to_rotation(dir)*180/math.pi
        length = vector.length(arm_pos, gun_pos)
    end
    return dir, rotation, length
end

function guns3d.handle_node_hit_fx(normal, dir, pos, pointed)
    local node = minetest.get_node(dir+normal/100)
    local reverse_dir = vector.direction(dir, vector.new())
    --[[minetest.sound_play(minetest.registered_nodes[node.name].sounds.dug,{
        pos = pos,
        gain = 1,
        pitch = 1.1,
        max_hear_distance = 1
    })]]

    local obj = minetest.add_entity(pos+(normal*(.001+.001*math.random())), "3dguns:bullet_hole")
    minetest.add_particlespawner({

    })
    table.insert(guns3d.bullethole_deletion_queue, 1, obj)
    obj:get_luaentity().block_pos = pos-(normal/1000)
    obj:set_rotation(vector.dir_to_rotation(normal))
    return false
end
function guns3d.tracer(player, start_pos, end_pos, def)
    local playername = player:get_player_name()
    local offset = def.flash_offset
    local dir = vector.direction(start_pos, end_pos)
    local obj = minetest.add_entity(start_pos, "3dguns:tracer")
    local self = obj:get_luaentity()
    self.end_position = end_pos
    self.start_position = start_pos+dir
    obj:set_rotation(vector.dir_to_rotation(dir))
    obj:set_velocity(dir*800)
end

--this is a complicated task, I've re-written it multiple times,
--I've come to the conclusion that ultimately this will not be clean or pretty.
function guns3d.ray(player, pos, dir, def, bullet_info)
    local playername = player:get_player_name()
    local is_first_iter = false
    local constant = .7
    local normal
    --initialize if first ray
    if not bullet_info then
        is_first_iter = true
        bullet_info = {
            history = {},
            state = "free",
            last_pos = pos,
            last_node = "",
            last_normal = vector.new(),
            end_direction = dir,
            range_left = def.bullet.range,
            penetration_left = def.bullet.penetration_RHA
            --last_pointed
        }
    end
    table.insert(bullet_info.history, {start_pos=pos, state=bullet_info.state, normal=bullet_info.last_normal, end_direction = bullet_info.end_direction})
    --set ray end
    local pos2 = pos+(dir*bullet_info.range_left)
    local block_ends_early = false
    --check if the block ends earlier then the check
    if bullet_info.state == "transverse" then
        local pointed
        --its import
        local ray = minetest.raycast(pos+dir, pos, false, false)
        for p in ray do
            --line gore
            if p.type == "node" and (table.compare(p.under, bullet_info.last_pointed.under) or not minetest.registered_nodes[minetest.get_node(bullet_info.last_pointed.under).name].node_box) then
                pointed = p
                break
            end
        end
        --maybe remove check for pointed
        if pointed and vector.distance(pointed.intersection_point, pos) < constant then
            pos2 = pointed.intersection_point
            block_ends_early = true
            normal = pointed.intersection_normal
            bullet_info.end_direction = vector.direction(dir, vector.new())
        else
            pos2 = pos+(dir*constant)
        end
    end
    --main raycast
    local ray = minetest.raycast(pos, pos2, true, true)
    local pointed
    local next_ray_pos = pos2
    for p in ray do
        if vector.distance(p.intersection_point, bullet_info.last_pos) > 0.0005 and vector.distance(p.intersection_point, bullet_info.last_pos) < bullet_info.range_left then
            local distance = vector.distance(pos, p.intersection_point)
            if p.type == "node" and guns3d.node_properties[minetest.get_node(p.under).name].behavior ~= "ignore" then
                local next_penetration_val = bullet_info.penetration_left-(distance*guns3d.node_properties[minetest.get_node(p.under).name].rha*1000)
                if bullet_info.state ~= "transverse" then
                    pointed = p
                    --print(dump(p))
                    bullet_info.state = "transverse"
                    next_ray_pos = p.intersection_point
                else
                    pointed = p
                    if minetest.get_node(p.under).name ~= bullet_info.last_node and next_penetration_val > 0 and guns3d.node_properties[minetest.get_node(p.under).name].behavior ~= "ignore"  then
                        next_ray_pos = p.intersection_point
                    end
                end
                break
            end
            if p.type == "object" and p.ref ~= player then
                local next_penetration_val = bullet_info.penetration_left-def.bullet.penetration_dropoff_RHA*distance
                if bullet_info.state == "transverse" then
                    mext_penetration_val = bullet_info.penetration_left-(distance*guns3d.node_properties[minetest.get_node(bullet_info.last_pointed.under).name].rha*1000)
                end
                if bullet_info.penetration_left > 0 then
                    if (bullet_info.state == "transverse" and next_penetration_val > 0) or (bullet_info.state == "free" and bullet_info.penetration_left-def.bullet.penetration_dropoff_RHA*distance > 0) then
                        local penetration_val = next_penetration_val
                        if bullet_info.state == "free" then
                            bullet_info.penetration_left = next_penetration_val
                            penetration_val = bullet_info.penetration_left
                        end
                        local damage = math.floor((def.bullet.damage*(next_penetration_val/def.bullet.penetration_RHA))+1)
                        p.ref:punch(player, 10000000, {damage_groups = {fleshy = damage}}, dir)
                        if p.ref:is_player() then
                            minetest.chat_send_all(dump(damage))
                        end
                    end
                end
            end
        end
    end
    local distance = vector.distance(pos, next_ray_pos)
    local new_dir = dir
    local node_properties

    if pointed then
        node_properties = guns3d.node_properties[minetest.get_node(pointed.under).name]
    end

    local penetration_loss = def.bullet.penetration_dropoff_RHA
    if bullet_info.history[#bullet_info.history].state == "transverse" and pointed then
        local rotation = vector.apply(vector.new(), function(a)
            a=a+(((math.random()-.5)*2)*node_properties.random_deviation*def.bullet.penetration_deviation*distance)
            return a
        end)
        new_dir = vector.rotate(new_dir, rotation*math.pi/180)
        penetration_loss = node_properties.rha*1000
    end

    if not normal then
        if pointed then
            normal = pointed.intersection_normal
        else
            normal = vector.new()
        end
    end
    if not bullet_info.end_direction then
        bullet_info.end_direction = new_dir
    end
    if block_ends_early or not pointed then
        bullet_info.state = "free"
    end
    bullet_info.penetration_left=bullet_info.penetration_left-(penetration_loss*distance)
    bullet_info.range_left = bullet_info.range_left-distance
    bullet_info.last_pointed = pointed
    bullet_info.last_normal = normal
    bullet_info.last_pos = pos


    if pointed then
        bullet_info.last_node = minetest.get_node(pointed.under).name
    end

    if bullet_info.range_left > 0.001 and bullet_info.penetration_left > 0 then
        guns3d.ray(player, next_ray_pos, new_dir, def, bullet_info)
    end
    if is_first_iter then
        print(dump(bullet_info.history))
        for i, val in pairs(bullet_info.history) do
            if not table.compare(val.normal, vector.new()) then
                guns3d.handle_node_hit_fx(val.normal, val.end_direction, val.start_pos)
            end
        end
    end
end