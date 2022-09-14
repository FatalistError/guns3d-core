guns3d = {}
guns3d.guns = {}
guns3d.model_def = {} --(player model)
guns3d.bullets = {}
guns3d.hud_id = {}
guns3d.data = {}
guns3d.magazines = {}
guns3d.bullethole_deletion_queue = {}
guns3d.last_dtime = 0
max_wear = 65534
local mp = minetest.get_modpath("3dguns")
dofile(mp .. "/player_model.lua")
dofile(mp .. "/block_values.lua")
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
    guns3d.last_dtime = dtime
    player_list = minetest.get_connected_players()
    --yes you do need two variables to track wether the gun is held
    --I want to kill myself.
    for _, player in pairs(player_list) do
        local playername = player:get_player_name()
        local held_stack = player:get_wielded_item()
        local held = held_stack:get_name()
        guns3d.data[playername].is_holding = false
        for gunname, _ in pairs(guns3d.guns) do
            if held == gunname then
                guns3d.data[playername].is_holding = true
                local player_properties = player:get_properties()
                local arm_obj = guns3d.data[playername].attached_arms
                local attached_obj = guns3d.data[playername].attached_gun
                local ammo_table = minetest.deserialize(held_stack:get_meta():get_string("ammo"))
                local meta = held_stack:get_meta()
                local player_controls = player:get_player_control()
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

                    guns3d.data[playername].wag_offset = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].recoil_offset = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].recoil_vel = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].sway_offset = vector.new()
                    guns3d.data[playername].vertical_aim = player:get_look_vertical()
                    guns3d.data[playername].total_rotation = {gun_axial=vector.new(), look_axial=vector.new()}

                    --replaace with "rechamber" with existing control delay timer.
                    guns3d.data[playername].reload_locked = false
                    guns3d.data[playername].rechamber_time = def.chamber_time
                    guns3d.data[playername].control_data = {}
                    guns3d.data[playername].last_controls = table.copy(player_controls)

                    --these need to be set in meta
                    guns3d.data[playername].particle_spawners = {}
                    guns3d.data[playername].anim_sounds = {}
                    guns3d.data[playername].animation_queue = {}
                    guns3d.data[playername].animated = false
                    guns3d.data[playername].current_animation_frame = 0
                    guns3d.data[playername].arm_animation_offsets = {left=vector.new(), right=vector.new()}

                    for i, v in pairs(def.controls) do
                        guns3d.data[playername].control_data[i] = {
                            active = false,
                            timer = def.controls[i].timer,
                            conditions_met = false
                        }
                    end
                    if meta:get_string("ammo") == "" then
                        ammo_table = {bullets={}, magazine="", loaded_bullet="", total_bullets=0}
                        meta:set_string("ammo", minetest.serialize(ammo_table))
                        meta:set_int("state", 1)
                        player:set_wielded_item(held_stack)
                    end
                    if (ammo_table.magazine ~= "" or def.ammo_type ~= "magazine") and ammo_table.total_bullets > 0 then
                        local animation = {{
                            time = def.chamber_time,
                            frames = table.copy(def.animation_frames.rechamber)
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
                --=================== THE GUN =======================
                if not attached_obj then
                    attached_obj = minetest.add_entity(player:get_pos(), gunname.."_visual")
                    local self = attached_obj:get_luaentity()
                    self.parent_player = playername
                    attached_obj:set_attach(player, "guns3d_hipfire_bone", vector.multiply({x=def.offset.x, y=def.offset.z, z=-def.offset.y}, 10), def.rot_offset, true)
                    guns3d.data[playername].attached_gun = attached_obj
                    if def.reticle ~= nil then
                        local reticle_obj = minetest.add_entity(player:get_pos(), "3dguns:reticle")
                        local modifier = vector.new(); if def.reticle.auto_center == true then modifier = {x=0, y=-def.ads_offset.y*10, z=0} end
                        reticle_obj:set_attach(attached_obj, def.reticle.bone, vector.add(def.reticle.offset, {x=0,z=0,y=0}), {x=90,y=0, z=0}, true)
                        local self = reticle_obj:get_luaentity()
                        self.image = def.reticle.image
                        self.image_size = def.reticle.image_size/100
                    end
                end
                --======================== ANIMATIONS ==========================
                if guns3d.data[playername].animation_queue then
                    local anim_table = guns3d.data[playername].animation_queue[1]
                    print(dump())
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
                                set_gun_rest_animation(player, def, attached_obj)
                                guns3d.data[playername].animated = false
                            end
                        else
                            --otherwise end the animation
                            table.remove(guns3d.data[playername].animation_queue, 1)
                            set_gun_rest_animation(player, def, attached_obj)
                            guns3d.data[playername].animated = false
                        end
                    end
                end
                local anim_table = guns3d.data[playername].animation_queue[1]
                if anim_table then
                    guns3d.data[playername].current_animation_frame = anim_table.frames.y-(anim_table.frames.y-anim_table.frames.x)*anim_table.time/anim_table.length
                end
                if guns3d.data[playername].current_animation_frame and def.arm_animation_frames then
                    local current_frame = guns3d.data[playername].current_animation_frame
                    local index_above_frame = 2
                    for i, v in pairs(def.arm_animation_frames) do
                        if v.frame > current_frame then
                            index_above_frame = i
                            break
                        end
                    end
                    local pos = {left=vector.new(), right=vector.new()}
                    for i, v in pairs({"left", "right"}) do
                        local frame1 = def.arm_animation_frames[index_above_frame-1]
                        local frame2 = def.arm_animation_frames[index_above_frame]
                        local ratio = (frame1.frame-current_frame)/(frame1.frame-frame2.frame)
                        guns3d.data[playername].arm_animation_offsets[v] = vector.new(frame1[v])+((vector.new(frame2[v])-vector.new(frame1[v]))*ratio)
                    end
                    --print(dump(guns3d.data[playername].arm_animation_offsets))
                end
                local current_anim, _, _, _ = attached_obj:get_animation()
                if not guns3d.data[playername].animated then
                    if ammo_table.magazine == "" and def.reload.type == "magazine" then
                        attached_obj:set_animation(def.animation_frames.unloaded)
                        guns3d.data[playername].current_animation_frame = def.animation_frames.unloaded.x
                    else
                        attached_obj:set_animation(def.animation_frames.loaded)
                        guns3d.data[playername].current_animation_frame = def.animation_frames.unloaded.y
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
                if def.controls.reload then
                    local controls_active = false
                    for _, v in pairs(def.controls.reload.keys) do
                        if player_controls[v] then
                            controls_active = true
                        end
                    end
                    if not controls_active then
                        guns3d.data[playername].reload_locked = false
                    end
                end
                --needs to be ran after
                --this is the main control processing part of the function
                local inv = player:get_inventory()
                local meta = held_stack:get_meta()
                local controls_locked = false
                --"control_index_list" is basically a heirarchy of what should be checked first
                --this is to prevent something like {"z"} overiding {"z", "shift"} if {"z", "shift"} are active.
                print(dump(guns3d.data[playername].control_delay))
                for _, i in ipairs(def.control_index_list) do
                    local ctrl_def = def.controls[i]
                    local ctrl_data = guns3d.data[playername].control_data[i]
                    if ((not controls_locked or ctrl_def.ignore_other_cntrls) and ((guns3d.data[playername].control_delay <= 0) or ctrl_def.ignore_lock)) then
                        local conditions_met = true
                        local is_active = false
                        for _, input_key in pairs(ctrl_def.keys) do
                            if not player_controls[input_key] then
                                conditions_met = false
                            end
                        end
                        if conditions_met then
                            ctrl_data.timer = ctrl_data.timer - dtime
                        else
                            ctrl_data.timer = ctrl_def.timer
                        end
                        if ctrl_data.active and ctrl_def.loop and ctrl_data.timer <= 0 then
                            ctrl_data.timer = ctrl_def.timer
                        end
                        if ctrl_data.timer <= 0 and conditions_met then
                            is_active = true
                        end
                        --if it doesn't loop, then it must
                        if (conditions_met and ((not ctrl_def.loop and not ctrl_data.active) or ctrl_def.loop)) or (not is_active and ctrl_data.active) or (((not is_active) and (not conditions_met)) and ctrl_data.conditions_met) then
                            --minetest.chat_send_all("called")
                            local returns = def.control_callbacks[i](is_active, conditions_met, (conditions_met and not ctrl_data.conditions_met), player, def)
                            --this is sort of a hack, but it really shouldn't get in the way, it's so the "first call" variable can be true for loops
                            if conditions_met and is_active then
                                conditions_met = false
                            end
                            controls_locked = true
                            if returns then
                                ctrl_data.timer = returns.timer
                            end
                            --other returns maybe idk
                        end
                        --this makes sure if it's a loop it wasnt active last step
                        ctrl_data.active = is_active
                        ctrl_data.conditions_met = conditions_met
                        --make sure no additional controls are called
                        if conditions_met and not ctrl_def.ignore_other_cntrls then
                            controls_locked = true
                        end
                    else
                        if ctrl_data.conditions_met then
                            def.control_callbacks[i](false, false, false, player, def)
                        end
                        ctrl_data.active = false
                        ctrl_data.conditions_met = false
                    end
                end
                --important that this is called after the controls and not before, as the state can have changed, which will cause undesirable results.
                set_gun_rest_animation(player, def, attached_obj)
                --================= HUD ===================================
                --update this to only send changes when there's a change
                --reload bar
                local timer = guns3d.data[playername].control_data.reload.timer
                player:hud_set_flags({wielditem = false, crosshair = false})
                --[[if timer < def.reload_time and timer <= def.reload_time and timer >= 0 then
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
                end]]
                --count number of bullets in the gun and in the inventory
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
                            end
                        end
                    end
                end
                local bullets = ammo_table.total_bullets
                if guns3d.hud_id[playername].fore_count == nil then
                    guns3d.hud_id[playername].fore_count = player:hud_add({
                        type = "text",
                        position = {x=.84, y=.88},
                        alignment = {x=-1, y=0},
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
                if guns3d.hud_id[playername].back_count == nil then
                    guns3d.hud_id[playername].back_count = player:hud_add({
                        hud_elem_type = "text",
                        position = {x=.85, y=.88},
                        scale = {x=1000, y=10},
                        alignment = {x=1, y=0},
                        size = {x=4},
                        name = "bullet_counter_back",
                        number = 0xFFFFFF,
                        z_index = 200,
                        text = " / "..tostring(inv_bullets)
                    })
                else
                    player:hud_change(guns3d.hud_id[playername].back_count, "text", " / "..tostring(inv_bullets))
                end
                --bullet indiciator
                if ammo_table.loaded_bullet and ammo_table.loaded_bullet ~= "" then
                    local image = minetest.registered_items[ammo_table.loaded_bullet].inventory_image
                    if minetest.registered_nodes[ammo_table.loaded_bullet] then
                        image = minetest.registered_nodes[ammo_table.loaded_bullet].tiles[1]
                    end
                    if guns3d.hud_id[playername].loaded_bullet_img == nil then
                        guns3d.hud_id[playername].loaded_bullet_img = player:hud_add({
                            hud_elem_type = "image",
                            position = {x=.72, y=.88},
                            scale = {x=3, y=3},
                            name = "loaded_ammunition_image",
                            z_index = 200,
                            text = image
                        })
                    else
                        player:hud_change(guns3d.hud_id[playername].loaded_bullet_img, "text", image)
                    end
                    if guns3d.hud_id[playername].loaded_bullet_acr == nil then
                        guns3d.hud_id[playername].loaded_bullet_acr = player:hud_add({
                            hud_elem_type = "text",
                            position = {x=.72, y=.97},
                            size = {x=2},
                            alignment = {x=0, y=0},
                            name = "loaded_ammunition_acronym",
                            number = 0xFFFFFF,
                            z_index = 200,
                            text = def.bullet.acronym
                        })
                        player:hud_change(guns3d.hud_id[playername].loaded_bullet_acr, "text", def.bullet.acronym)
                    end
                else
                    if guns3d.hud_id[playername].loaded_bullet_img then
                        player:hud_change(guns3d.hud_id[playername].loaded_bullet_img, "text", "")
                    end
                    if guns3d.hud_id[playername].loaded_bullet_acr then
                        player:hud_change(guns3d.hud_id[playername].loaded_bullet_acr, "text", "")
                    end
                end
                --firemode indicator
                if def.firetype then
                    if guns3d.hud_id[playername].firemode == nil then
                        guns3d.hud_id[playername].firemode = player:hud_add({
                            hud_elem_type = "text",
                            position = {x=.76, y=.97},
                            size = {x=2},
                            alignment = {x=1, y=0},
                            name = "firemode_indicator",
                            number = 0xFFFFFF,
                            z_index = 200,
                            text = def.firetype
                        })
                    else
                        player:hud_change(guns3d.hud_id[playername].firemode, "text", def.firetype)
                    end
                end

                --================= Recoil, sway, and the like ============================
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
                            local correction_multiplier = guns3d.data[playername].time_since_last_fire*def.recoil_correction[axis]
                            local correction_factor = recoil*correction_multiplier
                            if correction_factor > def.max_recoil_correction then
                                correction_factor = def.max_recoil_correction*(math.abs(def.max_recoil_correction)/def.max_recoil_correction)
                            end
                            --have to use "control int" bc negative squareroots cause NAN
                            local control_int = (recoil/math.abs(recoil))
                            recoil=recoil-correction_factor*dtime
                            --[[if i=="x" and axis=="look_axial" then
                                print(dump(recoil*correction_multiplier))
                            end]]
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
                --=================== aim interpolation/delay ==========
                local wag = guns3d.data[playername].wag_offset
                local sway = guns3d.data[playername].sway_offset
                local recoil = guns3d.data[playername].recoil_offset
                local look_rotation = vector.new(-player:get_look_vertical(), -player:get_look_horizontal(), 0)*180/math.pi
                local constant = 1
                local next_vert_aim = ((guns3d.data[playername].vertical_aim-look_rotation.x)/(1+((constant*10)*dtime)))+look_rotation.x
                if math.abs(look_rotation.x-next_vert_aim) > .01 then
                    guns3d.data[playername].vertical_aim = next_vert_aim
                else
                    guns3d.data[playername].vertical_aim = look_rotation.x
                end
                --print(dump2(attached_obj)
                if math.abs(guns3d.data[playername].vertical_aim) > 76 then
                    local control_int = (guns3d.data[playername].vertical_aim/math.abs(guns3d.data[playername].vertical_aim))
                    guns3d.data[playername].vertical_aim = 76*control_int
                end
                local vertical_aim = guns3d.data[playername].vertical_aim
                guns3d.data[playername].total_rotation = {gun_axial=(wag.gun_axial+recoil.gun_axial), look_axial=sway+wag.look_axial+recoil.look_axial}
                --=================== bones and arms ===================
                --rattle me booones
                --bone stuff

                --sway will eventually have to be look_axial
                local total_rotation = guns3d.data[playername].total_rotation.look_axial
                local eye_pos = vector.new(0, player_properties.eye_height*10, 0)

                --these have to be flopped 180 for offsets to work, despite the fact that it should actually be backwards... I'm not sure how minetest's rot works anymore
                player:set_bone_position("guns3d_hipfire_bone", model_def.offsets.arm_right, vector.new(-(total_rotation.x+(vertical_aim*.75)), 180-total_rotation.y, 0))
                player:set_bone_position("guns3d_aiming_bone", eye_pos, vector.new(vertical_aim+total_rotation.x, 180-total_rotation.y, 0))
                player:set_bone_position("guns3d_head", model_def.offsets.head, {x=vertical_aim,z=0,y=0})
                --aim arms at user defined bones.
                local left_dir, left_rot, left_length = guns3d.arm_dir_rotation(player, true)
                left_rot.x=-left_rot.x
                local right_dir, right_rot, right_length = guns3d.arm_dir_rotation(player)
                right_rot.x=-right_rot.x
                player:set_bone_position("guns3d_arm_right", model_def.offsets.arm_right, vector.new(90,0,0)-right_rot)
                player:set_bone_position("guns3d_arm_left", model_def.offsets.arm_left, vector.new(90,0,0)-left_rot)
                guns3d.data[playername].last_controls = table.copy(player_controls)
                guns3d.data[playername].attached_gun = attached_obj
                --set total rotation
            end
        end
        --check if a gun is not being held anymore, or has been switched
        if not guns3d.data[playername].is_holding or guns3d.data[playername].last_wield_index ~= player:get_wield_index() then
            local player_properties = player:get_properties()
            local def = guns3d.guns[guns3d.data[playername].last_held_gun]
            if player_properties.mesh ~= guns3d.data[playername].player_model and guns3d.data[playername].player_model then
                if minetest.get_modpath("player_api") then
                    player_api.set_model(player, guns3d.data[playername].player_model)
                end
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
            guns3d.data[playername].held = held
        end
    end
end
)
--dev stuff
