
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
        elseif not type(tbl1[i])=="table" and (tbl1[i] ~= tbl2[i]) then
            result = false
        end
    end
    for i, v in pairs(tbl2) do
        if type(tbl1[i]) ~= type(tbl2[i]) then
            result = false
        elseif (type(tbl1[i])=="table" and not table.compare(tbl1[i], tbl2[i])) then
            result = false
        elseif not type(tbl1[i])=="table" and (tbl1[i] ~= tbl2[i]) then
            result = false
        end
    end
    return result
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
function guns3d.handle_recoil_effects(player, def)
    for _, i in pairs({"x", "y"}) do
        local multiplier = math.random()
        if multiplier > .5 then multiplier = 1 else multiplier = -1 end
        local recoil = guns3d.data[playername].recoil_offset
        local recoil_vel = guns3d.data[playername].recoil_vel
        recoil_vel.gun_axial[i] = recoil_vel.gun_axial[i] + def.axial_recoil_vel[i] * multiplier
        if i=="x" then multiplier = 1 end
        recoil_vel.look_axial[i] = recoil_vel.look_axial[i] + def.recoil_vel[i] * multiplier
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
        axis_rotation = def.ads_axis_rotation
        gun_offset = def.ads_offset/10
        if guns3d.data[playername].ads_location == 1 or guns3d.data[playername].ads_location == 0 then
            bone_location = vector.new(0, player_properties.eye_height, 0)
        else
            --ads interpolate would go here.
            bone_location = (vector.new(0, player_properties.eye_height, 0))
        end
    end
    gun_offset = gun_offset+added_pos
    bone_location = vector.new(-bone_location.x, bone_location.y, bone_location.z)

    local player_horizontal = player:get_look_horizontal()
    if relative_to_player then player_horizontal = 0 end
    local player_rotation = vector.new(-player:get_look_vertical()+(def.vertical_rotation_offset*math.pi/180), player_horizontal, 0)
    if math.abs(player_rotation.x*180/math.pi) > 78 then
        player_rotation.x = player_rotation.x-((player_rotation.x/math.abs(player_rotation.x)*(math.abs(player_rotation.x)-(78*math.pi/180))))
    end

    --dir needs to be rotated twice seperately to avoid weirdness
    local rotation = guns3d.data[playername].total_rotation
    local dir = vector.new(vector.rotate({x=0, y=0, z=1}, {y=0, x=((rotation.gun_axial.x+rotation.look_axial.x)*math.pi/180)+player_rotation.x, z=0}))
    dir = vector.rotate(dir, {y=((rotation.gun_axial.y+rotation.look_axial.y)*math.pi/180)+player_rotation.y, x=0, z=0})

    local local_pos = vector.rotate(bone_location, {x=0, y=player_horizontal, z=0})+vector.rotate(gun_offset, (rotation.look_axial*math.pi/180)+player_rotation)
    local eye_offset = vector.rotate(player:get_eye_offset()/10, {x=0, y=player_horizontal, z=0})

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
        local anim_table = guns3d.data[playername].animation_queue[1]

        local objref = guns3d.data[playername].attached_gun
        local frame = 0

        if not objref:get_pos() then
            offset = vector.new()
        end
        if anim_table then
            frame = anim_table.frames.y-((anim_table.frames.y-anim_table.frames.x)*(anim_table.time/anim_table.length))
        end
        --animation compatibility needed in future (though it may be better to just simulate it this way)
        local arm_pos = vector.new(model_def.offsets.arm_right_global)/10
        if left then
            arm_pos = vector.new(model_def.offsets.arm_left_global)/10
        end
        arm_pos.x = -arm_pos.x

        if def.arm_aiming_bones and objref:get_pos() then
            if left then
                offset = vector.new()
            else
                offset = vector.new()
            end
        end
        local _, gun_pos = guns3d.gun_dir_pos(player, offset, true)
        dir = vector.direction(arm_pos, gun_pos)
        rotation = vector.dir_to_rotation(dir)*180/math.pi
        length = vector.length(arm_pos, gun_pos)
    end
    return dir, rotation, length
end

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

function guns3d.ray(player, pos, dir, not_first_iter, bullet_info, def)
    if not bullet_info then
        def = guns3d.get_gun_def(player, player:get_wielded_item())
        bullet_info = {history={}, range_left=def.bullet.range}
        --no point in calling this over several iterations.
    end
    local ray
    if bullet_info.state == "transverse" then
        ray = minetest.raycast(pos, pos+(bullet_info.range_left*dir), true, true)
    else
        ray = minetest.raycast(pos, pos+(dir*.5), true, true)
    end
    local last_hit_info = {}
    if bullet_info.history[#bullet_info.history] then
        last_hit_info = bullet_info.history[#bullet_info.history]
    end
    local new_dir = dir
    for _, i in pairs({"x", "y", "z"}) do
        local random_num
        if (math.random() > .5) then random_num = 1 else random_num = -1 end
        local new_v = vector.new()
        new_v[i] = math.random(def.bullet.min_pen_deviation, def.bullet.max_pen_deviation)*random_num
         new_dir = vector.rotate(new_dir, new_v*math.pi/180)
    end
    local pointed
    for pointed in ray do
        if pointed.type == "object" then
            --for now it just ignores objects, damage has not yet been implemented.
        end
        local node
        if pointed.type == "node" then
            if bullet_info.state ~= "transverse" then
                pointed = pointed
                break
            end
        end
    end
    if bullet_info.state == "transverse" then
        if length > .5 then
            length = .5
        end
        new_dir = vector.new(interpolate(dir, new_dir, length/.5))
    end
    if bullet_info.state == "free" then
    end
    if not not_first_iter then
        for i, v in pairs(bullet_info.history) do
            local pos = v.pos
            local hud = player:hud_add({
                hud_elem_type = "image_waypoint",
                text = "muzzle_flash2.png",
                world_pos =  pos,
                scale = {x=.6, y=.6},
                alignment = {x=0,y=0},
                offset = {x=0,y=0},
            })
            minetest.after(20, function(hud)
                player:hud_remove(hud)
            end, hud)
        end
    end
end