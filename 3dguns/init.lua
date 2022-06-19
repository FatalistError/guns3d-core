guns3d = {}
guns3d.guns = {}
guns3d.hud_id = {}
guns3d.player_controls = {}
guns3d.data = {}
guns3d.magazines = {}
guns3d.bullethole_deletion_queue = {}
max_wear = 65534
local mp = minetest.get_modpath("3dguns")
dofile(mp .. "/compatibility.lua")
dofile(mp .. "/function.lua")
dofile(mp .. "/register.lua")
dofile(mp .. "/api.lua")
dofile(mp .. "/default_guns.lua")

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
        guns3d.data[playername].is_holding = false
        for gunname, _ in pairs(guns3d.guns) do
            if held == gunname then
                guns3d.data[playername].is_holding = true
                local controls = player:get_player_control()
                local def = guns3d.get_gun_def(player, player:get_wielded_item())
                if guns3d.data[playername].last_wield_index ~= player:get_wield_index() then
                    guns3d.data[playername].current_anim = "rest"
                    guns3d.data[playername].anim_state = 0
                    guns3d.data[playername].ads_location = 0 
                    guns3d.data[playername].ads = false
                    guns3d.data[playername].fire_mode = 1
                    guns3d.data[playername].control_delay = .4 
                    guns3d.data[playername].fire_queue = 0
                    guns3d.data[playername].sway_vel = vector.new()
                    guns3d.data[playername].sway_offset = vector.new()
                    guns3d.data[playername].sway_timer = def.sway_timer
                    guns3d.data[playername].wag_offset = vector.new()
                    guns3d.data[playername].visual_offset = {rotation=vector.new(), regular=vector.new()}
                    guns3d.data[playername].recoil_vel = vector.new()
                    guns3d.data[playername].recoil_offset = vector.new()
                    guns3d.data[playername].anim_sounds = {}
                    guns3d.data[playername].rechamber_time = def.chamber_time
                    guns3d.data[playername].last_look_vertical = vector.new(player:get_look_vertical(),player:get_look_horizontal(),0)
                    guns3d.data[playername].reload_timer = def.reload_time 
                    guns3d.data[playername].control_data = {}
                    guns3d.data[playername].animation_queue = {{},{}}
                    guns3d.data[playername].animated = {false, false}
                    guns3d.data[playername].last_controls = table.copy(controls)
                    if held_stack:get_meta():get_string("ammo") == "" then
                        minetest.chat_send_all("ammo table init.")
                        local new_ammo_table = {bullets={}, magazine="", loaded_bullet="", total_bullets=0}
                        held_stack:get_meta():set_string("ammo", minetest.serialize(new_ammo_table))
                        player:set_wielded_item(held_stack)
                    else 
                        minetest.chat_send_all(dump(held_stack:get_meta():get_string("ammo")))
                    end
                    
                    if def.controls then
                        for i, v in pairs(def.controls) do
                            guns3d.data[playername].control_data[i] = {false, def.controls[i][4], false}
                        end
                    end
                    --this function also handles offsets for bones
                    local new_model = guns3d.get_new_player_model(player)
                    player_api.set_model(player, new_model)
                    --this is to make it so switching between guns doesn't perma-lock your model
                    if not guns3d.data[playername].original_player_model then
                        guns3d.data[playername].original_player_model = player_properties.mesh
                    end
                    player_properties.mesh = new_model
                end
                local ammo_table = minetest.deserialize(held_stack:get_meta():get_string("ammo"))
                --minetest.chat_send_all(dump(ammo_table))
                guns3d.data[playername].last_wield_index = player:get_wield_index()
                --======================= action detection and anim handling ========================
                
                --======================= DELETE BULLET-HOLES ======================================
                mesh_file = io.open(minetest.get_modpath("3dguns").."/models/"..def.mesh, "rb")
                if mesh_file ~= nil then
                    print("god is dead")
                    print(dump(modlib.b3d.read(mesh_file)))
                    mesh_file:close()
                end
                if guns3d.bullethole_deletion_queue then
                    --probably add a config setting for this, but 80 sounds fair \_(.)_/
                    if #guns3d.bullethole_deletion_queue > 100 then
                        if guns3d.bullethole_deletion_queue[100] ~= nil then
                            guns3d.bullethole_deletion_queue[100]:remove()
                            table.remove(guns3d.bullethole_deletion_queue, 100)
                        end
                    end
                end
                for i, v in pairs(guns3d.data[playername].visual_offset.regular) do 
                    if math.abs(v) < .00001 then 
                        guns3d.data[playername].visual_offset.regular[i]=0
                    end
                end
                --guns3d.data[playername].visual_offset.rotation = guns3d.data[playername].visual_offset.rotation*.9
                guns3d.data[playername].visual_offset.regular = guns3d.data[playername].visual_offset.regular*.9
                --======================= PLAYER MODEL AND DEFAULTS ================================
                guns3d.data[playername].last_held_gun = gunname
                --====================== AIM DOWN SIGHTS ===========================================
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
                --====================== controls =================
                local inv = player:get_inventory()
                local meta = held_stack:get_meta()
                if guns3d.data[playername].control_delay-dtime >= 0 then 
                    guns3d.data[playername].control_delay=guns3d.data[playername].control_delay-dtime
                else
                    guns3d.data[playername].control_delay=0
                end
                local timer = guns3d.data[playername].reload_timer
                if guns3d.data[playername].fire_queue > 0 then 
                    if guns3d.data[playername].rechamber_time <= 0 then
                        guns3d.fire(true, true, player, true)
                        guns3d.data[playername].fire_queue = guns3d.data[playername].fire_queue - 1
                    end
                end
                --minetest.chat_send_all(dump(guns3d.data[playername].control_delay))
                --this is a headache to understand, i'm not even going to bother explaining. 
                --you're smart, you figure it out... I just regret not using strings as indexes
                --I guess I'm just sadistic.
                local excluded_keys = {}
                if def.controls then
                    for i2, i in ipairs(def.control_index_list) do 
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
                        --CTRL_DATA
                        --[1] = was it active last step?
                        --[2] = how much time is left
                        --[3] = were conditions met last step?
                        --minetest.chat_send_all(dump(conditions_met))
                        if ctrl_data[1] then 
                            if not conditions_met then
                                --player isn't pressing button anymore, so reset timer and make conditions false
                                ctrl_data[1] = false
                                ctrl_data[2] = ctrl_def[4]
                            end
                        else
                            if conditions_met then
                                if ctrl_data[2]-dtime <= 0 then
                                    --set to active
                                    ctrl_data[1] = true
                                    --call here if its not set to loop, otherwise it will be called downline
                                    if not ctrl_def[2] then
                                        def.control_callbacks[i](true, true, player)
                                        if ctrl_def[3] then
                                            --if repeat is true prevent it from being active
                                            ctrl_data[1] = false
                                            ctrl_data[2] = ctrl_def[4]
                                        end
                                    end
                                end
                                ctrl_data[2]=ctrl_data[2]-dtime
                            else
                                ctrl_data[2] = ctrl_def[4]
                            end
                        end
                        --minetest.chat_send_all(dump(excluded_keys))
                        if not conditions_met and ctrl_data[3] then
                            --call one last time so anims and sounds can be ended.
                            def.control_callbacks[i](false, false, player)
                        end
                        --only play if it's meant to loop
                        if ctrl_data[1] and ctrl_def[2] then
                            def.control_callbacks[i](ctrl_data[1], conditions_met, player)
                        elseif conditions_met and ((not ctrl_def[2] and not ctrl_data[1]) or ctrl_def[2]) then 
                            def.control_callbacks[i](false, true, player)
                        end
                        if conditions_met then
                            ctrl_data[3] = true
                        else 
                            ctrl_data[3] = false
                        end
                        --minetest.chat_send_all(dump(input_key))
                    end
                end
                if guns3d.data[playername].animation_queue then
                    --[1] is time until end
                    --[2] is animation frames
                    --[3] is conditionary function
                    for i = 1, 2 do
                        if guns3d.data[playername].animation_queue[i] then
                            local reference = attached_obj
                            if i == 2 then reference = arm_obj end
                            local anim_table = guns3d.data[playername].animation_queue[i][1]
                            if anim_table ~= nil then
                                if not guns3d.data[playername].animated[i] then
                                    guns3d.data[playername].animated[i] = true
                                    guns3d.data[playername].anim_flip_flop = not guns3d.data[playername].anim_flip_flop
                                    local extra_frame 
                                    --stupid problems require stupid solutions -Minetest modding 4269
                                    if guns3d.data[playername].anim_flip_flop then extra_frame = 1 else extra_frame = 0 end
                                    local frame_rate = math.abs(anim_table[2].x-anim_table[2].y)/anim_table[1]
                                    --IMPORTANT! remember to have 1 extra frame after each animation! this is so every other animation
                                    --a 1 will be added- this is important because it's the only way to repeat an anim.
                                    reference:set_animation({x=anim_table[2].x, y=anim_table[2].y+extra_frame}, frame_rate, 0, false)
                                end
                                if (anim_table[1]-dtime) >= 0 then
                                    anim_table[1]=anim_table[1]-dtime
                                    --if the condition function returns false it kills the animation
                                    if anim_table[3] and anim_table[3](player, anim_table)==false then
                                        table.remove(guns3d.data[playername].animation_queue[i], 1)
                                        reference:set_animation({x=0, y=0})
                                        guns3d.data[playername].animated[i] = false
                                    end
                                    --otherwise the animation continues running, "but why?" the animations asks, "why is the only purpose of my existence to suffer, and then burn out like some sort of sadistic battery in which you find amusement from, why must you curse me with existence?"
                                else
                                    --otherwise remove the animation
                                    table.remove(guns3d.data[playername].animation_queue[i], 1)
                                    reference:set_animation({x=0, y=0})
                                    guns3d.data[playername].animated[i] = false
                                end       
                            end
                        end
                    end 
                end
                --====rechambering subsection========
                if guns3d.data[playername].rechamber_time > 0 then
                    guns3d.data[playername].rechamber_time = guns3d.data[playername].rechamber_time - dtime
                    if guns3d.data[playername].rechamber_time < 0 then
                        guns3d.data[playername].rechamber_time = 0
                    end
                end
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
                --=================== gun visual entity and attachments ===================
                if attached_obj == nil or attached_obj:get_pos() == nil then
                    attached_obj = minetest.add_entity(player:get_pos(), gunname.."_visual")
                    local self = attached_obj:get_luaentity()
                    self.parent_player = playername
                    attached_obj:set_attach(player, "Arm_Right2", vector.multiply({x=def.offset.x, y=def.offset.z, z=-def.offset.y}, 10), def.rot_offset, true)
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

                --local magazine = held_stack:get_meta():get_string("ammo")
                local bullets = ammo_table.total_bullets
                player:hud_set_flags({wielditem = false}) 
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

                --================= reeeeecoil ============================
                
                for axis, velocity in pairs(guns3d.data[playername].recoil_vel) do 
                    local offset = guns3d.data[playername].recoil_offset[axis]
                    if axis ~= "z" then 
                        if ((player:get_player_control().LMB == true and def.firetype == "automatic") and def.firerate > 350) ~= true or ammo_table.total_bullets == 0 then
                            if offset ~= 0 and velocity == 0 then 
                                if math.abs(offset)-(math.abs(offset)/1.1)*dtime >= 0 and math.abs(offset) > 0.0002 then
                                    --multiplier is to prevent it from going down mid firing/rechamber creating noticably smoother recoil
                                    local multiplier = (((60/def.firerate)-(guns3d.data[playername].rechamber_time*1.5))/(60/def.firerate))
                                    if multiplier < 0 then multiplier = 0 end
                                    guns3d.data[playername].recoil_offset[axis] = offset-((offset*dtime*1/def.recoil_correction)*multiplier)
                                    --this is to prevent velocity from undoing the changes
                                    offset = guns3d.data[playername].recoil_offset[axis]
                                else
                                    guns3d.data[playername].recoil_offset[axis] = 0
                                    --this is to prevent velocity from undoing the changes
                                    offset = guns3d.data[playername].recoil_offset[axis]
                                end
                            end
                        end
                        if velocity ~= 0 then
                            if (math.abs(velocity) - def.recoil_reduction[axis]*dtime) >= 0 then
                                local multiplier = (velocity/math.abs(velocity))*dtime
                                guns3d.data[playername].recoil_vel[axis]=velocity-(def.recoil_reduction[axis]*multiplier)
                            else 
                                guns3d.data[playername].recoil_vel[axis] = 0
                            end
                        end
                        guns3d.data[playername].recoil_offset[axis] = offset+(velocity*dtime)
                    end
                end

                --minetest.chat_send_all(dump(guns3d.data[playername].recoil_vel))
                guns3d.data[playername].recoil_offset = vector.add(guns3d.data[playername].recoil_offset, vector.multiply(guns3d.data[playername].recoil_vel, dtime))
                --make looking up reduce recoil... for obvious reasons (this section also prevents recoil from exceeding 90 degrees, also for obvious reasons)
                local difference_x = (guns3d.data[playername].last_look_vertical.x-player:get_look_vertical())*180/math.pi
                local difference_y = (guns3d.data[playername].last_look_vertical.y-player:get_look_horizontal())*180/math.pi
                local vertical_recoil = guns3d.data[playername].recoil_offset.x
                if difference_x >= 0 then
                    if vertical_recoil - difference_x >= 0 then
                        vertical_recoil = vertical_recoil - difference_x / 2
                    else
                        vertical_recoil = 0 
                    end
                end
                guns3d.data[playername].recoil_offset.x = vertical_recoil 
                --=================== sway/wag ================================
                if time == nil then time = dtime else 
                    time=time+dtime*3
                end
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
                player_vel = math.sqrt((player_vel.x^2)+(player_vel.z^2))
                if player_vel > .5 then
                    local wag_x = math.sin(time*4)*player_vel/4
                    local wag_y = math.sin(time*2)*2*player_vel/4
                    guns3d.data[playername].wag_offset=vector.new(wag_x, wag_y, 0)
                else
                    guns3d.data[playername].wag_offset=vector.divide(guns3d.data[playername].wag_offset, 1.1)
                    if math.abs(guns3d.data[playername].wag_offset.y) < .1 then
                        guns3d.data[playername].wag_offset = vector.new()
                    end
                end
               
                 
                --=================== bones and arms ===================
                --rattle me booones
                --bone stuff
                local wag = guns3d.data[playername].wag_offset
                local sway = guns3d.data[playername].sway_offset
                local recoil = guns3d.data[playername].recoil_offset
                local look_x = player:get_look_vertical()*180/math.pi
                player:set_bone_position("Arm_Right2", guns3d.data[playername].bone_offsets.arm, {x=(look_x+-recoil.x+-sway.x+-wag.x)-90, z=0, y=180+recoil.y+sway.y+wag.y})
                --(.625 is the root bone's height)
                local eye_pos = {x=0, y=(player_properties.eye_height*10-guns3d.data[playername].bone_offsets.root), z=0}
                local eye_rot = vector.add(vector.add(recoil, sway), wag)
                local vertical = player:get_look_vertical()*-(180/math.pi)
                eye_rot.x = eye_rot.x + vertical
                player:set_bone_position("Eye_Bone", eye_pos, eye_rot)
                player:set_bone_position("Head2", guns3d.data[playername].bone_offsets.head, {x=player:get_look_vertical()*-(180/math.pi),z=0,y=0})

                local bone_pos, bone_rot = player:get_bone_position("Arm_Right2")
                local angle = look_x
                --check if arms exist
                if arm_obj == nil or arm_obj:get_pos() == nil then
                    --add arms
                    arm_obj = minetest.add_entity(player:get_pos(),"3dguns:arms")
                    arm_obj:set_attach(player, "", nil, {x=0, y=180, z=0}, false)
                else
                    --disable the arms if adsed because... well i couldn't find a better solution to the arms obscuring the scope
                    arm_obj:set_attach(player, "", nil, {x=0, y=180, z=0}, false)
                    --rotate arms 
                    --this is to make it look half decent in third person while adsing
                    if guns3d.data[playername].ads then angle = (angle*.78) end
                    arm_obj:set_bone_position("Bone", {x=0,y=guns3d.data[playername].bone_offsets.arm.y+guns3d.data[playername].bone_offsets.root,z=0}, {x=0, y=(sway.y*.9)+wag.y+recoil.y, z=-angle+sway.x+recoil.x})
                end
                guns3d.data[playername].last_controls = table.copy(controls)
                guns3d.data[playername].last_look_vertical = {x=player:get_look_vertical(),y=player:get_look_horizontal(),z=0} 
            end
        end
        --================ change model back ==================
        if not guns3d.data[playername].is_holding then
            --*MODIFICATIONS NEEDED FOR 3D ARMOR OR CHARACTER CREATOR COMPAT*
            local def = guns3d.guns[guns3d.data[playername].last_held_gun]
            if player_properties.mesh ~= guns3d.data[playername].original_player_model and guns3d.data[playername].original_player_model then
                player_api.set_model(player, guns3d.data[playername].original_player_model)
                player_properties.mesh = guns3d.data[playername].original_player_model
                guns3d.data[playername].original_player_model = nil
                player:set_properties(player_properties)
            end
            for name, id in pairs(guns3d.hud_id[playername]) do
                player:hud_remove(id)
                guns3d.hud_id[playername][name] = nil 
            end
            player:hud_set_flags({wielditem = true}) 
            --================ disable ADS FOV ====================
            if guns3d.data[playername].ads == true then
                player:set_fov(0, false, def.ads_time/4)
                player:set_eye_offset(vector.new())
                guns3d.data[playername].ads = false
            end
            --================= unset (everything) ====================
            --basically just reset everything.
            guns3d.data[playername] = {is_holding = false, last_wield_index = last_wield_index}
        else
            guns3d.data[playername].attached_arms = arm_obj
            guns3d.data[playername].attached_gun = attached_obj
            guns3d.data[playername].held = held
        end
    end
end
)

