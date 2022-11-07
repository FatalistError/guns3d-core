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
minetest.register_on_joinplayer(function(player)
    local playername = player:get_player_name()
    guns3d.hud_id[playername] = {}
    guns3d.data[playername] = {}
    guns3d.data[playername].player_model = player:get_properties().mesh
    print(dump(guns3d.data[playername].player_model))
end)
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
        local data_table_init
        local holding_gun
        local id
        for gunname, _ in pairs(guns3d.guns) do
            if held == gunname then
                holding_gun = true
                local player_properties = player:get_properties()
                local gun_obj = guns3d.data[playername].attached_gun
                local reticle_obj = guns3d.data[playername].attached_reticle
                local meta = held_stack:get_meta()
                local ammo_table = minetest.deserialize(meta:get_string("ammo"))
                local player_controls = player:get_player_control()
                local def = guns3d.get_gun_def(player, player:get_wielded_item())
                local model_def, model_name = guns3d.get_model_def_name(player)
                id = meta:get_string("id")
                --this will break if a gun is placed into hand!
                --YOUR RAM IS MINE MORTAL
                if guns3d.data[playername].last_gun_id ~= id then
                    --timers go brrr
                    if gun_obj then
                        gun_obj:remove()
                        gun_obj = nil
                    end
                    guns3d.data[playername] = {}
                    guns3d.data[playername].last_gun_id = id
                    guns3d.data[playername].current_anim = "rest"
                    guns3d.data[playername].anim_state = 0
                    guns3d.data[playername].ads_location = 0
                    guns3d.data[playername].ads = false
                    guns3d.data[playername].fire_mode = 1
                    guns3d.data[playername].control_delay = .4
                    guns3d.data[playername].fire_queue = 0
                    guns3d.data[playername].time_since_last_fire = 0
                    guns3d.data[playername].walking_tick = 0
                    guns3d.data[playername].breathing_tick = 0

                    --offsets
                    guns3d.data[playername].recoil_offset = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].recoil_vel = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].sway_vel = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].sway_offset = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].breathing_offset = {gun_axial=1, look_axial=1}
                    guns3d.data[playername].jump_offset = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].walking_offset = {gun_axial=vector.new(), look_axial=vector.new()}
                    guns3d.data[playername].deviation_offset = vector.new()
                    guns3d.data[playername].total_rotation = {gun_axial=vector.new(), look_axial=vector.new()}
                    --guns3d.data[playername].reticle_fade_in = 1

                    --look stuff
                    guns3d.data[playername].vertical_aim = player:get_look_vertical()
                    guns3d.data[playername].last_look = vector.new(player:get_look_vertical()*180/math.pi, player:get_look_horizontal()*180/math.pi, 0)
                    --replaace with "rechamber" with existing control delay timer.
                    guns3d.data[playername].reload_locked = false
                    guns3d.data[playername].rechamber_time = def.ready_time
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
                    end

                    if (ammo_table.magazine ~= "" or def.ammo_type ~= "magazine") and ammo_table.total_bullets > 0 then
                        if def.animation_frames.ready then
                            local animation = {{
                                time = def.ready_time,
                                frames = table.copy(def.animation_frames.ready)
                            }}
                            guns3d.start_animation(animation, player)
                        end
                    end

                    if minetest.get_modpath("player_api") then
                        player_api.set_model(player, model_name)
                    end

                    if id == "" then
                        id = tostring(math.random())
                        meta:set_string("id", id)
                    end

                    player:set_wielded_item(held_stack)
                    player_properties.mesh = model_name
                end
                --account for model changes here by checking every step if its different
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
                local sway = guns3d.data[playername].sway_offset
                local sway_vel = guns3d.data[playername].sway_vel
                local recoil = guns3d.data[playername].recoil_offset
                local recoil_vel = guns3d.data[playername].recoil_vel
                local walking_offset = guns3d.data[playername].walking_offset
                local jump_offset = guns3d.data[playername].jump_offset
                local breathing = guns3d.data[playername].breathing_offset
                local deviation = guns3d.data[playername].deviation_offset
                --=============== movement detection stuff ====================
                local is_touching_ground = false
                local is_in_fluid = false
                local ray = minetest.raycast(player:get_pos()+vector.new(0, player_properties.eye_height, 0), player:get_pos()-vector.new(0,.1,0), true, true)

                for pointed_thing in ray do
                    if pointed_thing.type == "object" then
                        if pointed_thing.ref ~= player and pointed_thing.ref:get_properties().physical == true then
                            is_touching_ground = true
                        end
                    end
                    if pointed_thing.type == "node" then
                        is_touching_ground = true
                    end
                end
                if not guns3d.data[playername].was_touching_ground then
                    if is_touching_ground then
                        guns3d.data[playername].was_touching_ground = true
                    else
                        guns3d.data[playername].was_touching_ground = false
                    end
                end
                local velocity = player:get_velocity()
                local is_walking = false
                if vector.length(vector.new(velocity.x, 0, velocity.z)) > .1 then
                    is_walking = true
                end
                --bad practice to use a name like this in a large enviornment.
                ray = nil
                --=================== THE GUN =======================
                local gun_added = false
                if gun_obj and gun_obj:get_pos() == nil then
                    gun_obj = nil
                end
                if not gun_obj then
                    gun_obj = minetest.add_entity(player:get_pos(), gunname.."_visual")
                    local self = gun_obj:get_luaentity()
                    self.parent_player = playername
                    gun_obj:set_attach(player, "guns3d_hipfire_bone", def.offset, nil, true)
                    guns3d.data[playername].attached_gun = gun_obj
                    gun_added = true
                end
                if not reticle_obj and def.reticle then
                    reticle_obj = minetest.add_entity(player:get_pos(), def.reticle_obj)
                    local self = reticle_obj:get_luaentity()
                    self.parent_player = playername
                    self.gun_name = held
                    reticle_obj:set_attach(player, "guns3d_reticle_bone", {x=def.ads_look_offset,y=0,z=def.offset.z+def.reticle.offset}, nil, true)
                    guns3d.data[playername].attached_reticle = reticle_obj
                end
                --======================== ANIMATIONS ==========================
                if guns3d.data[playername].animation_queue then
                    local anim_table = guns3d.data[playername].animation_queue[1]
                    if anim_table ~= nil and (not gun_added) then
                        if not guns3d.data[playername].animated then
                            guns3d.data[playername].animated = true
                            anim_table.length = anim_table.time
                            --this is needed because minetest is a fucking dogshit engine.
                            guns3d.data[playername].anim_flip_flop = not guns3d.data[playername].anim_flip_flop
                            local extra_frame
                            if guns3d.data[playername].anim_flip_flop then extra_frame = 1 else extra_frame = 0 end
                            local frame_rate = math.abs(anim_table.frames.y-anim_table.frames.x)/anim_table.time
                            gun_obj:set_animation({x=anim_table.frames.x, y=anim_table.frames.y+extra_frame}, frame_rate, 0, false)
                        end
                        if (anim_table.time-dtime) >= 0 then
                            anim_table.time=anim_table.time-dtime
                            --if the condition function returns false it kills the animation
                            if anim_table.func and anim_table.func(player, anim_table)==false then
                                table.remove(guns3d.data[playername].animation_queue, 1)
                                set_gun_rest_animation(player, def, gun_obj)
                                guns3d.data[playername].animated = false
                            end
                        else
                            --otherwise end the animation
                            table.remove(guns3d.data[playername].animation_queue, 1)
                            set_gun_rest_animation(player, def, gun_obj)
                            guns3d.data[playername].animated = false
                        end
                    end
                end
                local anim_table = guns3d.data[playername].animation_queue[1]
                if anim_table and not gun_added then
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
                local current_anim, _, _, _ = gun_obj:get_animation()
                if not guns3d.data[playername].animated then
                    if ammo_table.magazine == "" and def.reload.type == "magazine" then
                        gun_obj:set_animation(def.animation_frames.unloaded)
                        guns3d.data[playername].current_animation_frame = def.animation_frames.unloaded.x
                    else
                        gun_obj:set_animation(def.animation_frames.loaded)
                        guns3d.data[playername].current_animation_frame = def.animation_frames.unloaded.y
                    end
                end

                --====================================================== controls ===========================================================================
                --this is just built in ADS stuff
                --guns3d.arm_dir_rotation(player)
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
                --important that this is called after the controls and not before, as the state can have changed, which will cause undesirable results.
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
                set_gun_rest_animation(player, def, gun_obj)
                --============================================================== HUD =====================================================================
                --update this to only send changes when there's a change
                --reload bar
                local timer = guns3d.data[playername].control_data.reload.timer
                player:hud_set_flags({wielditem = false, crosshair = false})
                --[[if timer < def.reload_time and timer >= 0 and not guns3d.data[playername].reload_locked then
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
                --this will break everything with non-magazine guns... oh boy, this wont be fun.
                local inv = player:get_inventory()
                local inv_bullets = 0
                for _, ammunition in pairs(def.ammunitions) do
                    local clip_size = def.clip_size or guns3d.magazines[ammunition]
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

                --================= innaccurcies ============================
                guns3d.data[playername].breathing_tick = guns3d.data[playername].breathing_tick + dtime
                --this is mainly for future implementation of stamina
                --else i'd go with constant variables.
                --note that this assumes breathing is always 1
                local breathing_info = {pause=1.4, rate=4.2}
                --(rate) 4.2 seconds = 1 breath (yes this is realistic, stfu)
                local combined_ratio = 1+breathing_info.pause
                local x = ((guns3d.data[playername].breathing_tick/(breathing_info.rate/combined_ratio)) % combined_ratio)-.5
                if x > 1.5 then
                    x = 1.5
                end
                print(x)
                local breathing_value = (math.sin(x*math.pi)+1)/2
                for _, axis in pairs({"look_axial", "gun_axial"}) do
                    --breathing
                    --4.28 is about the average human resting breaths per minute, I plan on swapping it out for a variable that will be calculated
                    --based on stamina and speed.
                    breathing[axis] = breathing_value*def.breathing_offset[axis]
                    --sway
                    local ran
                    ran = vector.apply(vector.new(), function(i,v)
                        if i ~= "x" then
                            return (math.random()-.5)*2
                        end
                    end)
                    ran.z = 0
                    sway_vel[axis] = vector.normalize(sway_vel[axis]+(ran*dtime))*def.sway_vel[axis]
                    sway[axis]=sway[axis]+(sway_vel[axis]*dtime)
                    if vector.length(sway[axis]) > def.sway_max[axis] then
                        sway[axis]=vector.normalize(sway[axis])*def.sway_max[axis]
                        sway_vel[axis] = vector.new()
                    end

                    --recoil stuff sorta needs to be done like this
                    for _, i in pairs({"x", "y"}) do
                        if is_walking then
                            local time = guns3d.data[playername].walking_tick
                            local multiplier = 1
                            if i == "x" then
                                multiplier = 2
                            end
                            walking_offset[axis][i] = math.sin((time/1.6)*math.pi*multiplier)*def.walking_offset[axis][i]
                        else
                            local OGval = walking_offset[axis][i]
                            if math.abs(walking_offset[axis][i]) > .05 then
                                local multiplier = (walking_offset[axis][i]/math.abs(walking_offset[axis][i]))
                                walking_offset[axis][i] = walking_offset[axis][i]-(dtime*2*multiplier)
                            else
                                walking_offset[axis][i] = 0
                            end
                            if math.abs(walking_offset[axis][i]) > math.abs(OGval) then
                                walking_offset[axis][i] = 0
                            end
                        end
                        --jumping/in air stuff
                        local jump_offset = jump_offset[axis][i]
                        local added_jump_offset = def.jump_offset[axis][i]*dtime*math.abs(velocity.y)
                        local OGjump_offset = jump_offset
                        local multiplier = (jump_offset/math.abs(jump_offset))*-1
                        if is_touching_ground and guns3d.data[playername].was_touching_ground then
                            if math.abs(jump_offset) > 0.001 then
                                jump_offset=jump_offset-(jump_offset*12*dtime)
                                if math.abs(jump_offset) > math.abs(jump_offset) then
                                    jump_offset = 0
                                end
                            else
                                --jump_offset = 0
                            end
                            if jump_offset > OGjump_offset then
                                jump_offset = 0
                            end
                        end
                        if velocity.y > .1 then
                            guns3d.data[playername].control_delay = .1
                            if math.abs(jump_offset+added_jump_offset)<=math.abs(def.jump_offset[axis][i]) then
                                jump_offset = jump_offset + added_jump_offset
                            else
                                jump_offset = def.jump_offset[axis][i]
                            end
                        end
                        --recoil
                        local recoil = recoil[axis][i]
                        local OGrecoil_vel = recoil_vel[axis][i]
                        local recoil_vel = recoil_vel[axis][i]
                        recoil = recoil + recoil_vel
                        if math.abs(recoil_vel) > 0.001 then
                            recoil_vel = recoil_vel * (recoil_vel/(recoil_vel/(def.recoil_reduction*2))*dtime)
                        else
                            recoil_vel = 0
                        end
                        local OGrecoil = recoil
                        if math.abs(recoil) > 0.001 then
                            local correction_multiplier = guns3d.data[playername].time_since_last_fire*def.recoil_correction[axis]
                            local correction_factor = recoil*correction_multiplier
                            if correction_factor > def.max_recoil_correction then
                                correction_factor = def.max_recoil_correction*(math.abs(def.max_recoil_correction)/def.max_recoil_correction)
                            end
                            recoil=recoil-correction_factor*dtime
                            if math.abs(recoil) > math.abs(OGrecoil) then
                                recoil = 0
                            end
                        end
                        guns3d.data[playername].recoil_offset[axis][i] = recoil
                        guns3d.data[playername].recoil_vel[axis][i] = recoil_vel
                        guns3d.data[playername].jump_offset[axis][i] = jump_offset
                        --this is hacky, it just checks if it's NaN since NaN isnt equivelant to itself
                        if sway[axis][i] ~= sway[axis][i] then
                            sway[axis] = vector.new()
                        end
                    end
                end
                if is_walking then
                    local velocity = table.copy(velocity)
                    velocity.y = 0
                    velocity = vector.length(velocity)
                    if velocity > 6 then
                        velocity = 6
                    end
                    guns3d.data[playername].walking_tick = guns3d.data[playername].walking_tick + (dtime*velocity)
                else
                    guns3d.data[playername].walking_tick = 0
                end
                guns3d.data[playername].time_since_last_fire=guns3d.data[playername].time_since_last_fire+dtime
                --sway = vector.add(sway, vector.multiply(sway_vel, dtime))
                --gun wag based on player velocity
                --=================== aim interpolation and other stuff ==========
                local look_rotation = vector.new(player:get_look_vertical(), player:get_look_horizontal(), 0)*180/math.pi
                local constant = .8
                local next_vert_aim = ((guns3d.data[playername].vertical_aim+look_rotation.x)/(1+((constant*10)*dtime)))-look_rotation.x
                if math.abs(look_rotation.x-next_vert_aim) > .005 then
                    guns3d.data[playername].vertical_aim = next_vert_aim
                else
                    guns3d.data[playername].vertical_aim = look_rotation.x
                end
                --make sure it doesnt go above or below a certain point
                if math.abs(guns3d.data[playername].vertical_aim) > 85 then
                    local control_int = (guns3d.data[playername].vertical_aim/math.abs(guns3d.data[playername].vertical_aim))
                    guns3d.data[playername].vertical_aim = 85*control_int
                end
                local vertical_aim = guns3d.data[playername].vertical_aim
                --I love how fucked up minetest's look rotation is.
                local difference = guns3d.data[playername].last_look-look_rotation
                difference.y = ((difference.y + 180) % 360) - 180
                difference.x = -difference.x*5
                deviation = deviation+(difference/100)
                --deviation.x = -deviation.x
                for i, v in pairs(deviation) do
                    local ctrl_int = v/math.abs(v)
                    if math.abs(v) > def.deviation_max then
                        deviation[i] = def.deviation_max*ctrl_int
                    else
                        if math.abs(v) < .05 and not v==0 then
                            deviation[i] = 0
                        else
                            if math.abs(v)-(2*dtime*(math.abs(v)/def.deviation_max)) > 0 then
                                deviation[i] = v-(1*dtime*ctrl_int*(math.abs(v)/def.deviation_max))
                            else
                                deviation[i] = 0
                            end
                        end
                    end
                end
                guns3d.data[playername].deviation_offset = deviation
                --set total rotation
                guns3d.data[playername].last_look = look_rotation
                guns3d.data[playername].total_rotation = {
                    gun_axial = deviation+sway.gun_axial+recoil.gun_axial+jump_offset.gun_axial+walking_offset.gun_axial+vector.new(breathing.gun_axial,0,0),
                    look_axial = sway.look_axial+recoil.look_axial+jump_offset.look_axial+walking_offset.look_axial+vector.new(breathing.look_axial,0,0)
                }

                --=================== bones and arms ===================
                local eye_offset_z = 0
                local real_eye_offset = player:get_eye_offset()
                if guns3d.data[playername].vertical_aim < -55 and guns3d.data[playername].ads then
                    eye_offset_z = 2.5 * (55-math.abs(guns3d.data[playername].vertical_aim))/-35
                end
                local difference = (eye_offset_z-real_eye_offset.z)
                if math.abs(difference) > 1*dtime then
                    eye_offset_z = real_eye_offset.z+(math.abs(difference*5)*dtime*(math.abs(difference)/difference))
                end
                player:set_eye_offset(vector.new(def.ads_look_offset*guns3d.data[playername].ads_location, 0, eye_offset_z), {x=5, z=0, y=2})
                local look_rotation = guns3d.data[playername].total_rotation.look_axial
                local total_rotation = guns3d.data[playername].total_rotation.look_axial+guns3d.data[playername].total_rotation.gun_axial
                local eye_pos = vector.new(0, player_properties.eye_height*10, eye_offset_z)
                --these have to be flipped 180 for offsets to work, despite the fact that it should actually be backwards... I'm not sure how minetest's rotation works anymore
                player:set_bone_position("guns3d_hipfire_bone", model_def.offsets.arm_right, vector.new(-(look_rotation.x+(vertical_aim*.75)), 180-look_rotation.y, 0))
                player:set_bone_position("guns3d_aiming_bone", eye_pos, vector.new(vertical_aim+look_rotation.x, 180-look_rotation.y, 0))
                player:set_bone_position("guns3d_reticle_bone", eye_pos, vector.new(vertical_aim+total_rotation.x, 180-total_rotation.y, 0))
                player:set_bone_position("guns3d_head", model_def.offsets.head, {x=vertical_aim,z=0,y=0})
                --aim arms at user defined bones.
                local left_dir, left_rot, left_length = guns3d.arm_dir_rotation(player, true)
                left_rot.x=-left_rot.x
                local right_dir, right_rot, right_length = guns3d.arm_dir_rotation(player)
                right_rot.x=-right_rot.x
                player:set_bone_position("guns3d_arm_right", model_def.offsets.arm_right, vector.new(90,0,0)-right_rot)
                player:set_bone_position("guns3d_arm_left", model_def.offsets.arm_left, vector.new(90,0,0)-left_rot)
                guns3d.data[playername].last_controls = table.copy(player_controls)
                guns3d.data[playername].attached_gun = gun_obj
                guns3d.data[playername].attached_reticle = reticle_obj
            end
        end
        --check if a gun is not being held anymore, or has been switched
        last_wield = player:get_wield_index()
        --because after this id will be nil
        if not holding_gun then
            local player_properties = player:get_properties()
            if guns3d.data[playername].last_gun_id ~= id then
                local def = guns3d.guns[guns3d.data[playername].last_held_gun]
                if player_properties.mesh ~= guns3d.data[playername].player_model and guns3d.data[playername].player_model then
                    if minetest.get_modpath("player_api") then
                        player_api.set_model(player, guns3d.data[playername].player_model)
                    end
                    player_properties.mesh = guns3d.data[playername].player_model
                    player:set_properties(player_properties)
                end
                for name, hud_id in pairs(guns3d.hud_id[playername]) do
                    player:hud_remove(hud_id)
                    guns3d.hud_id[playername][name] = nil
                end
                player:hud_set_flags({wielditem = true})
                --reset FOV
                if guns3d.data[playername].ads == true then
                    player:set_fov(0, false, def.ads_time/4)
                    player:set_eye_offset(vector.new())
                    guns3d.data[playername].ads = false
                end
            end
            guns3d.data[playername].player_model = player_properties.mesh
            --================= unset (everything) ====================
            guns3d.data[playername] = {}
        end
        guns3d.data[playername].held = held
        guns3d.data[playername].last_gun_id = id
    end
end
)
--dev stuff
