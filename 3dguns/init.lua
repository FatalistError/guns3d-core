guns3d = {}
guns3d.guns = {}
guns3d.model_def = {} --(player model)
guns3d.bullets = {}
guns3d.hud_id = {}
guns3d.data = {}
guns3d.magazines = {}
guns3d.bullethole_deletion_queue = {}
max_wear = 65534
local mp = minetest.get_modpath("3dguns")
dofile(mp .. "/player_model.lua")
dofile(mp .. "/function.lua")
dofile(mp .. "/register.lua")
dofile(mp .. "/api.lua")
dofile(mp .. "/guns.lua")

--[[
***WARNING***
This code may contain graphic content: such as workarounds that make no sense and create paradoxal loops,
bad APIs, repetive unoptimized bullshit, and code that doesnt follow any readable style or guidelines.
read at your own risk.
]]

--]penetration = bool
--bullet.pen_nodes = {node=ngtv_velocity, etc, etc}
--bullet.max_node_pen = number, how many blocks can penetrate
--bullet.pen_deviation = number, in degrees to randomly rotate after penetration
----=============== GLOBALSTEP ======================
minetest.register_globalstep(function(dtime)
    --minetest.chat_send_all(dump(dtime))
    --[[local t2=math.random()*1000*150
    local t = minetest.get_us_time()+t2
    dtime=dtime+(t2/1000000)
    minetest.chat_send_all(dump(dtime))
    while (minetest.get_us_time()<t)do end]]
    player_list = minetest.get_connected_players()
    --yes you do need two variables to track wether the gun is held
    --I want to kill myself.
    for _, player in pairs(player_list) do
        local player_properties = player:get_properties()
        local playername = player:get_player_name()
        local held_stack = player:get_wielded_item()
        local held = held_stack:get_name()
        local arm_obj = guns3d.data[playername].attached_arms
        local attached_obj = guns3d.data[playername].attached_gun
        local ammo_table = minetest.deserialize(held_stack:get_meta():get_string("ammo"))
        guns3d.data[playername].is_holding = false
        for gunname, _ in pairs(guns3d.guns) do
            if held == gunname then
                guns3d.data[playername].is_holding = true
                local controls = player:get_player_control()
                local def = guns3d.get_gun_def(player, player:get_wielded_item())
                local model_def, model_name = guns3d.get_model_def_name(player)
                --this will break if a gun is placed into hand!
                if guns3d.data[playername].last_wield_index ~= player:get_wield_index() then
                    guns3d.data[playername].current_anim = "rest"
                    guns3d.data[playername].anim_state = 0
                    guns3d.data[playername].ads_location = 0
                    guns3d.data[playername].ads = false
                    guns3d.data[playername].fire_mode = 1
                    guns3d.data[playername].control_delay = .4
                    guns3d.data[playername].fire_queue = 0
                    guns3d.data[playername].time_since_last_fire = 0

                    --timers and stuff
                    guns3d.data[playername].sway_timer = def.sway_timer
                    guns3d.data[playername].sway_vel = vector.new()

                    --VISIBLE offsets
                    guns3d.data[playername].wag_offset = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].recoil_offset = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].recoil_vel = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].sway_offset = vector.new()
                    guns3d.data[playername].total_rotation = {gun_axial=vector.new(), look_axial=vector.new()}
                    --this is for a later date
                    guns3d.data[playername].anim_sounds = {}
                    guns3d.data[playername].rechamber_time = def.chamber_time
                    guns3d.data[playername].last_look_vertical = vector.new(player:get_look_vertical(),player:get_look_horizontal(),0)
                    guns3d.data[playername].reload_timer = def.reload_time
                    guns3d.data[playername].control_data = {}
                    guns3d.data[playername].animation_queue = {}
                    guns3d.data[playername].animated = {false, false}
                    guns3d.data[playername].last_controls = table.copy(controls)
                    for i, v in pairs(def.controls) do
                        guns3d.data[playername].control_data[i] = {active = false, timer = def.controls[i][4], conditions_met = false}
                    end
                    if held_stack:get_meta():get_string("ammo") == "" then
                        ammo_table = {bullets={}, magazine="", loaded_bullet="", total_bullets=0}
                        held_stack:get_meta():set_string("ammo", minetest.serialize(ammo_table))
                        player:set_wielded_item(held_stack)
                    end
                    if (ammo_table.magazine ~= "" or def.ammo_type ~= "magazine") and ammo_table.total_bullets > 0 then
                        local animation = {{
                            time = def.chamber_time,
                            frames = table.copy(def.animation_frames.reload)
                        }}
                        guns3d.start_animation(animation, player)
                    end
                    --some model stuff
                    guns3d.data[playername].player_model = player:get_properties().mesh
                    if minetest.get_modpath("player_api") then
                        player_api.set_model(player, model_name)
                    end
                    player_properties.mesh = model_name
                end
                --account for model changes here by checking every step if its different
                guns3d.data[playername].last_wield_index = player:get_wield_index()
                guns3d.data[playername].last_held_gun = gunname
                --delete bullet holes
                if guns3d.bullethole_deletion_queue then
                    --probably add a config setting for this, but 80 for now
                    if #guns3d.bullethole_deletion_queue > 100 then
                        if guns3d.bullethole_deletion_queue[100] ~= nil then
                            guns3d.bullethole_deletion_queue[100]:remove()
                            table.remove(guns3d.bullethole_deletion_queue, 100)
                        end
                    end
                end
                --====================== controls =================
                --this is just built in ADS stuff
                guns3d.arm_dir_rotation(player)
                player:set_eye_offset({x=def.ads_look_offset*guns3d.data[playername].ads_location, z=0, y=0})
                if guns3d.data[playername].ads == true then
                    player:set_fov(1/def.ads_zoom_mp, true, .5)
                    if guns3d.data[playername].ads_location+dtime <= 1 then
                        guns3d.data[playername].ads_location=guns3d.data[playername].ads_location+dtime/def.ads_time
                    else
                        guns3d.data[playername].ads_location = 1
                    end
                else
                    player:set_fov(0, false, .30)
                    player:set_eye_offset({x=0, z=0, y=0})
                    if guns3d.data[playername].ads_location+dtime/(-def.ads_time/2.5) >= 0 then
                        guns3d.data[playername].ads_location=guns3d.data[playername].ads_location+dtime/(-def.ads_time/2.5)
                    else
                        guns3d.data[playername].ads_location = 0
                    end
                end
                --"control delay" which is just used to prevent actions for X amount of time
                if guns3d.data[playername].control_delay-dtime >= 0 then
                    guns3d.data[playername].control_delay=guns3d.data[playername].control_delay-dtime
                else
                    guns3d.data[playername].control_delay=0
                end
                --burst fire go pew pew pew
                if guns3d.data[playername].fire_queue > 0 then
                    if guns3d.data[playername].rechamber_time <= 0 then
                        guns3d.fire(player, def)
                        guns3d.data[playername].fire_queue = guns3d.data[playername].fire_queue - 1
                    end
                end
                --rechambering
                if guns3d.data[playername].rechamber_time > 0 then
                    guns3d.data[playername].rechamber_time = guns3d.data[playername].rechamber_time - dtime
                    if guns3d.data[playername].rechamber_time < 0 then
                        guns3d.data[playername].rechamber_time = 0
                    end
                end
                --this is a utter mess.
                --this is the main control processing part of the function
                local inv = player:get_inventory()
                local meta = held_stack:get_meta()
                local timer = guns3d.data[playername].reload_timer
                local excluded_keys = {}
                if def.controls then
                    for _, i in ipairs(def.control_index_list) do
                        local ctrl_def = def.controls[i]
                        local ctrl_data = guns3d.data[playername].control_data[i]
                        local conditions_met = true
                        for _, input_key in pairs(ctrl_def[1]) do
                            if (not controls[input_key]) or (excluded_keys[input_key]==true and not ctrl_def[5]) then
                                conditions_met = false
                            end
                        end
                        if conditions_met then
                            for _, input_key in pairs(ctrl_def[1]) do
                                excluded_keys[input_key] = true
                            end
                        end
                        if ctrl_data.active then
                            if not conditions_met then
                                --player isn't pressing button anymore, so reset timer and make conditions false
                                ctrl_data.active = false
                                ctrl_data.timer = ctrl_def[4]
                            end
                        else
                            if conditions_met then
                                if ctrl_data.timer-dtime <= 0 then
                                    --set to active
                                    ctrl_data.active = true
                                    --call here if its not set to loop, otherwise it will be called downline
                                    if not ctrl_def[2] then
                                        def.control_callbacks[i](true, true, player)
                                        if ctrl_def[3] then
                                            --if repeat is true prevent it from being active
                                            ctrl_data.active = false
                                            ctrl_data.timer = ctrl_def[4]
                                        end
                                    end
                                end
                                ctrl_data.timer=ctrl_data.timer-dtime
                            else
                                ctrl_data.timer = ctrl_def[4]
                            end
                        end
                        --minetest.chat_send_all(dump(excluded_keys))
                        if not conditions_met and ctrl_data.conditions_met then
                            --call one last time so anims and sounds can be ended.
                            def.control_callbacks[i](false, false, player)
                        end
                        --only play if it's meant to loop
                        if ctrl_data.active and ctrl_def[2] then
                            def.control_callbacks[i](ctrl_data.active, conditions_met, player)
                        elseif conditions_met and ((not ctrl_def[2] and not ctrl_data.active) or ctrl_def[2]) then
                            def.control_callbacks[i](false, true, player)
                        end
                        if conditions_met then
                            ctrl_data.conditions_met = true
                        else
                            ctrl_data.conditions_met = false
                        end
                        --minetest.chat_send_all(dump(input_key))
                    end
                end
                --paricle effects
                --=================== THE GUN =======================
                if attached_obj == nil or attached_obj:get_pos() == nil then
                    attached_obj = minetest.add_entity(player:get_pos(), gunname.."_visual")
                    local self = attached_obj:get_luaentity()
                    self.parent_player = playername
                    attached_obj:set_attach(player, "guns3d_hipfire_bone", vector.multiply({x=def.offset.x, y=def.offset.z, z=-def.offset.y}, 10), def.rot_offset, true)
                    if def.reticle ~= nil then
                        local reticle_obj = minetest.add_entity(player:get_pos(), "3dguns:reticle")
                        local modifier = vector.new(); if def.reticle.auto_center == true then modifier = {x=0, y=-def.ads_offset.y*10, z=0} end
                        reticle_obj:set_attach(attached_obj, def.reticle.bone, vector.add(def.reticle.offset, {x=0,z=0,y=0}), {x=90,y=0, z=0}, true)
                        local self = reticle_obj:get_luaentity()
                        self.image = def.reticle.image
                        self.image_size = def.reticle.image_size/100
                    end
                end
                --================= HUD ===================================
                local timer = guns3d.data[playername].reload_timer
                if timer < def.reload_time then
                    if guns3d.hud_id[playername].reload_bar == nil then
                        guns3d.hud_id[playername].reload_bar = player:hud_add({
                            hud_elem_type = "statbar",
                            text = "reload_bar.png",
                            text2 = "reload_bar_empty.png",
                            item = 34,
                            number = 1,
                            position = {x=.43, y=.8},
                            name = "reload_bar",
                            size = 0,
                        })
                    else
                        player:hud_change(guns3d.hud_id[playername].reload_bar, "number", 34-(34*(timer/def.reload_time)))
                    end
                elseif guns3d.hud_id[playername].reload_bar ~= nil then
                    player:hud_remove(guns3d.hud_id[playername].reload_bar)
                    guns3d.hud_id[playername].reload_bar = nil
                end
                local bullets = ammo_table.total_bullets
                player:hud_set_flags({wielditem = false, crosshair = false})
                if guns3d.hud_id[playername].fore_count == nil then
                    guns3d.hud_id[playername].fore_count = player:hud_add({
                        type = "text",
                        position = {x=.78, y=.93},
                        scale = {x=10, z=10},
                        size = {x=7},
                        number = 0xFFFFFF,
                        name = "bullet_counter",
                        z_index = 200,
                        text = tostring(bullets)
                    })
                else
                    player:hud_change(guns3d.hud_id[playername].fore_count, "text", bullets)
                end
                local inv = player:get_inventory()
                local inv_bullets = 0
                for _, ammunition in pairs(def.ammunitions) do
                    local clip_size = guns3d.magazines[ammunition]
                    for index = 1, inv:get_size("main") do
                        local stack = inv:get_stack("main", index)
                        if stack:get_name() == ammunition then
                            --this is to account for non-magazine guns
                            if clip_size == nil then clip_size = stack:get_count() end
                            if stack:get_meta():get_string("ammo") ~= "" then
                                inv_bullets = inv_bullets + minetest.deserialize(stack:get_meta():get_string("ammo")).total_bullets
                            else
                                stack:get_meta():set_string("ammo", minetest.serialize({bullets={}, magazine=stack:get_name(), loaded_bullet="", total_bullets=0}))
                            end
                        end
                    end
                end
                if guns3d.hud_id[playername].back_count == nil then
                    guns3d.hud_id[playername].back_count = player:hud_add({
                        hud_elem_type = "text",
                        position = {x=.87, y=.93},
                        scale = {x=1000, y=10},
                        size = {x=4},
                        name = "bullet_counter_back",
                        number = 0xFFFFFF,
                        z_index = 200,
                        text = " / "..tostring(inv_bullets)
                    })
                else
                    player:hud_change(guns3d.hud_id[playername].back_count, "text", " / "..tostring(inv_bullets))
                end
                --======================== ANIMATIONS ==========================
                if guns3d.data[playername].animation_queue then
                    local anim_table = guns3d.data[playername].animation_queue[1]
                    if anim_table ~= nil then
                        if not guns3d.data[playername].animated then
                            guns3d.data[playername].animated = true
                            anim_table.length = anim_table.time
                            --this is needed because minetest is a fucking dogshit engine.
                            guns3d.data[playername].anim_flip_flop = not guns3d.data[playername].anim_flip_flop
                            local extra_frame
                            if guns3d.data[playername].anim_flip_flop then extra_frame = 1 else extra_frame = 0 end
                            local frame_rate = math.abs(anim_table.frames.y-anim_table.frames.x)/anim_table.time
                            attached_obj:set_animation({x=anim_table.frames.x, y=anim_table.frames.y+extra_frame}, frame_rate, 0, false)
                        end
                        if (anim_table.time-dtime) >= 0 then
                            anim_table.time=anim_table.time-dtime
                            --if the condition function returns false it kills the animation
                            if anim_table.func and anim_table.func(player, anim_table)==false then
                                table.remove(guns3d.data[playername].animation_queue, 1)
                                attached_obj:set_animation({x=0, y=0})
                                guns3d.data[playername].animated = false
                            end
                            --otherwise the animation continues running, "but why?" the animations asks, "why is the only purpose of my existence to suffer, and then burn out like some sort of sadistic battery in which you find amusement from, why must you curse me with existence?"
                        else
                            --otherwise end the animation
                            table.remove(guns3d.data[playername].animation_queue, 1)
                            attached_obj:set_animation({x=0, y=0})
                            guns3d.data[playername].animated = false
                        end
                    end
                end
                local current_anim, _, _, _ = attached_obj:get_animation()
                if (current_anim.x == 0 and current_anim.y == 0) and (ammo_table.magazine ~= "" and def.ammo_type == "magazine") then
                    attached_obj:set_animation({x=1, y=1})
                end
                if (current_anim.x == 1 and current_anim.y == 1) and not (ammo_table.magazine ~= "" and def.ammo_type == "magazine") then
                    attached_obj:set_animation({x=0, y=0})
                end
                --================= Recoil, sway, and the like ============================
                print(dump(guns3d.data[playername].time_since_last_fire))
                for _, axis in pairs({"look_axial", "gun_axial"}) do
                    for _, i in pairs({"x", "y"}) do
                        local recoil = guns3d.data[playername].recoil_offset[axis][i]
                        local recoil_vel = guns3d.data[playername].recoil_vel[axis][i]
                        --order matters here.
                        --apply velocity
                        recoil = recoil + recoil_vel
                        if math.abs(recoil_vel) > 0.00001 then
                            recoil_vel = recoil_vel * (recoil_vel/(recoil_vel/(def.recoil_reduction*2))*dtime)
                        else
                            recoil_vel = 0
                        end
                        --correct recoil
                        if math.abs(recoil) > 0.00001 then
                            local correction_factor = math.sqrt(guns3d.data[playername].time_since_last_fire)*def.recoil_correction[axis]
                            recoil=recoil-(recoil*correction_factor)*dtime
                            if i=="x" then
                                --print(correction_factor)
                            end
                        end
                        guns3d.data[playername].recoil_offset[axis][i] = recoil
                        guns3d.data[playername].recoil_vel[axis][i] = recoil_vel
                    end
                end
                guns3d.data[playername].time_since_last_fire = guns3d.data[playername].time_since_last_fire + dtime
                if def.sway_angle ~= 0 then
                    guns3d.data[playername].sway_timer = guns3d.data[playername].sway_timer + dtime
                    if guns3d.data[playername].sway_timer >= def.sway_timer then
                        local old_pos = guns3d.data[playername].sway_offset
                        local new_pos = vector.new()
                        new_pos.x = math.random(def.sway_angle*100, -def.sway_angle*100)
                        new_pos.y = math.random(def.sway_angle*100, -def.sway_angle*100)
                        new_pos = vector.divide(new_pos, 100)
                        local distance = vector.subtract(new_pos, old_pos)
                        local new_velocity = vector.divide(distance, def.sway_timer)
                        guns3d.data[playername].sway_vel = new_velocity
                        guns3d.data[playername].sway_timer = 0
                    end
                end
                guns3d.data[playername].sway_offset = vector.add(guns3d.data[playername].sway_offset, vector.multiply(guns3d.data[playername].sway_vel, dtime))
                --gun wag based on player velocity
                local player_vel = player:get_velocity()
                if time == nil then time = dtime else
                    time=time+dtime*3
                end
                player_vel = math.sqrt((player_vel.x^2)+(player_vel.z^2))
                for _, axis in pairs({"look_axial", "gun_axial"}) do
                    if player_vel > .5 then
                        local multiplier = 1
                        if axis == "gun_axial" then
                            multiplier = -.2
                        end
                        local wag_x = (math.sin(time*6)*player_vel/4)*multiplier
                        local wag_y = (math.sin(time*3)*2*player_vel/4)*multiplier
                        guns3d.data[playername].wag_offset[axis]=vector.new(wag_x, wag_y, 0)
                    else
                        for i, v in pairs(guns3d.data[playername].wag_offset[axis]) do
                            if v > .08 then
                                v = v/8
                            else
                                v = 0
                            end
                            guns3d.data[playername].wag_offset[axis][i] = v
                        end
                    end
                end
                --=================== bones and arms ===================
                --rattle me booones
                --bone stuff
                local wag = guns3d.data[playername].wag_offset
                local sway = guns3d.data[playername].sway_offset
                local recoil = guns3d.data[playername].recoil_offset
                local total_rotation = recoil.look_axial+wag.look_axial+sway
                guns3d.data[playername].total_rotation = {gun_axial=(wag.gun_axial+recoil.gun_axial), look_axial=total_rotation}
                --(.625 is the root bone's height)
                local eye_pos = vector.new(0, player_properties.eye_height*10, 0)
                local look_vertical = (player:get_look_vertical()*180/math.pi)-def.vertical_rotation_offset
                if math.abs(look_vertical) > 78 then
                    look_vertical = look_vertical-((look_vertical/math.abs(look_vertical)*(math.abs(look_vertical)-78)))
                end
                --these have to be flopped 180 for offsets to work, despite the fact that it should actually be backwards... I'm not sure how minetest's rot works anymore
                player:set_bone_position("guns3d_hipfire_bone", model_def.offsets.arm_right, vector.new(look_vertical, 180, 0)-total_rotation)
                player:set_bone_position("guns3d_aiming_bone", eye_pos, vector.new(-look_vertical, 180, 0)+vector.new(total_rotation.x, -total_rotation.y, total_rotation.z))
                player:set_bone_position("guns3d_head", model_def.offsets.head, {x=-look_vertical,z=0,y=0})
                --aim arms at user defined bones.
                local left_dir, left_rot, left_length = guns3d.arm_dir_rotation(player, true)
                left_rot.x=-left_rot.x
                local right_dir, right_rot, right_length = guns3d.arm_dir_rotation(player)
                right_rot.x=-right_rot.x
                player:set_bone_position("guns3d_arm_right", model_def.offsets.arm_right, vector.new(90,0,0)-right_rot)
                player:set_bone_position("guns3d_arm_left", model_def.offsets.arm_left, vector.new(90,0,0)-left_rot)
                guns3d.data[playername].last_controls = table.copy(controls)
                guns3d.data[playername].last_look_vertical = {x=player:get_look_vertical(),y=player:get_look_horizontal(),z=0}

                --set total rotation
            end
        end
        --check if a gun is not being held anymore, or has been switched
        if not guns3d.data[playername].is_holding or guns3d.data[playername].last_wield_index ~= player:get_wield_index() then
            local def = guns3d.guns[guns3d.data[playername].last_held_gun]
            if player_properties.mesh ~= guns3d.data[playername].player_model and guns3d.data[playername].player_model then
                if minetest.get_modpath("player_api") then
                    player_api.set_model(player, guns3d.data[playername].player_model)
                end
                print(dump(guns3d.data[playername].player_model))
                player_properties.mesh = guns3d.data[playername].player_model
                guns3d.data[playername].player_model = nil
                player:set_properties(player_properties)
            end
            for name, id in pairs(guns3d.hud_id[playername]) do
                player:hud_remove(id)
                guns3d.hud_id[playername][name] = nil
            end
            player:hud_set_flags({wielditem = true})
            --reset FOV
            if guns3d.data[playername].ads == true then
                player:set_fov(0, false, def.ads_time/4)
                player:set_eye_offset(vector.new())
                guns3d.data[playername].ads = false
            end
            --================= unset (everything) ====================
            --basically just reset everything.
            guns3d.data[playername] = {is_holding = false}
        else
            guns3d.data[playername].attached_arms = arm_obj
            guns3d.data[playername].attached_gun = attached_obj
            guns3d.data[playername].held = held
        end
    end
end
)
--dev stuff
