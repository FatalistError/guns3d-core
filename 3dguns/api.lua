function guns3d.change_fire_mode(active, controls_active, player)
    if active then
        guns3d.data[playername].control_delay = 1
        def = guns3d.get_gun_def(player, player:get_wielded_item())
        if guns3d.data[playername].fire_mode+1 > #def.fire_modes then
            guns3d.data[playername].fire_mode = 1
        else
            guns3d.data[playername].fire_mode = guns3d.data[playername].fire_mode + 1
        end
        minetest.chat_send_all("firemode switched")
    end
end
--NEW AMMO SYSTEM
--deserialize meta:get_string("ammo")
--this contains a table containing all ammo information
--{bullets={bullet_1=29, bullet_2=1}, magazine=magazine, loaded_bullet=bullet_2, total_bullets=30}
--bullet table will be passed to magazine on unload
--magazine table will be used to identify what magazine to unload (ofc)
--loaded_bullet will be future implementations of different bullets
--function 
function guns3d.fire(active, controls_active, player, from_fire_queue)
    --"from_fire_queue" is special parameter to bypass sum shit
    if active then
        local held_stack = player:get_wielded_item()
        local collisions = {}
        local def = guns3d.get_gun_def(player, held_stack)
        local meta = held_stack:get_meta()
        local ammo_table = minetest.deserialize(meta:get_string("ammo"))
        if not guns3d.data[playername].last_controls.LMB and def.firetype == "burst" and not from_fire_queue then
            guns3d.data[playername].fire_queue = def.burst_fire
        end
        minetest.chat_send_all(dump(def.firetype))
        if ((def.firetype ~= "burst" and (def.firetype == "automatic" or (def.firetype ~= "automatic" and not guns3d.data[playername].last_controls.LMB))) or from_fire_queue) and ammo_table.total_bullets > 0 then
            if guns3d.data[playername].rechamber_time <= 0 then
                --this takes ammo, and puts new bullet into next 
                ammo_table = guns3d.dechamber_bullet(player, ammo_table)
                local dir, pos = gun_dir_pos(player)
                for i = 1, def.pellets do
                    --copy it so it only applies to one pellet
                    local dir = table.copy(dir)
                    local spread_rotation = vector.apply(vector.new(), function()
                        local spread = def.hip_spread*math.pi/180
                        if guns3d.data[playername].ads then spread = def.ads_spread*math.pi/180 end
                        local mp = math.random()
                        if mp > .5 then mp = 1 else mp = -1 end
                        local v = (math.random()*spread)*mp
                        return v
                    end)
                    spread_rotation.z = 0 
                    --rotate the dir
                    dir = vector.rotate(dir, spread_rotation)
                    --start the ray
                    guns3d.ray(player, pos, def, 0, dir, true, 0)
                    --yaw multiplier (so it's not only one side)
                end
                local ymp=math.random()
                if ymp > .5 then ymp=1 else ymp=-1 end
                guns3d.data[playername].recoil_offset.x = guns3d.data[playername].recoil_offset.x + def.recoil.x
                guns3d.data[playername].recoil_offset.y = guns3d.data[playername].recoil_offset.y + def.recoil.y*ymp
                guns3d.data[playername].recoil_vel.y=guns3d.data[playername].recoil_vel.y+def.recoil_vel.y*ymp
                guns3d.data[playername].recoil_vel.x=guns3d.data[playername].recoil_vel.x+def.recoil_vel.x
                guns3d.data[playername].rechamber_time = 60 / def.firerate
            end
        elseif ammo_table.total_bullets <= 0 then
            guns3d.data[playername].fire_queue = 0     
        end
        meta:set_string("ammo", minetest.serialize(ammo_table))
        player:set_wielded_item(held_stack)
    end
end
function guns3d.reload(active, controls_active, player)
    --this function was moved out of globalstep so may be a bit fucky
    local playername = player:get_player_name()
    local held_stack = player:get_wielded_item()
    local inv = player:get_inventory()
    local meta = held_stack:get_meta()
    local animation = {}
    local def = guns3d.get_gun_def(player, player:get_wielded_item())
    local ammo_table = minetest.deserialize(meta:get_string("ammo"))
    if guns3d.data[playername].control_delay <= .2 then
        guns3d.data[playername].control_delay = .2
    end
    --minetest.chat_send_all("active:"..dump(active).."  controls:"..dump(controls_active))
    --minetest.chat_send_all("active")
    if not guns3d.data[playername].anim_sounds.reload and controls_active then
        guns3d.data[playername].anim_sounds.reload = true
        if def.ammo_type == "magazine" then
            animation = {{
                def.reload_time,
                table.copy(def.animation_frames.reload)
            }}
            if ammo_table.magazine ~= "" then
                local mag_stack = ItemStack(ammo_table.magazine)
                local mag_meta = mag_stack:get_meta()
                mag_meta:set_string("ammo", minetest.serialize(ammo_table))
                mag_stack:set_wear(max_wear-max_wear*(ammo_table.total_bullets/guns3d.magazines[ammo_table.magazine]))
                inv:add_item("main", mag_stack)
                meta:set_string("ammo", minetest.serialize({bullets={}, magazine="", loaded_bullet="", total_bullets=0}))
                player:set_wielded_item(held_stack)
            end
        end
        guns3d.start_animation(animation, nil, player)
        guns3d.quick_dual_sfx(player, "reload", def.sounds["reload"].sound, def.sounds["reload"].distance)
    end
    if not controls_active and not active then
        --have extra animation for fractional reloading etc
        guns3d.kill_dual_sfx(player, "reload", .1)
        guns3d.end_current_animation(true, false, player)
        guns3d.data[playername].anim_sounds.reload = nil
    end
    if active then
        guns3d.data[playername].control_delay = 1
        guns3d.kill_dual_sfx(player, "reload", .1)
        guns3d.data[playername].anim_sounds.reload = nil
        if def.ammo_type == "magazine" then
            local mag_string
            local stack_index
            local magstack
            local highest_ammo = 0
            local index
            for _, ammunition in pairs(def.ammunitions) do 
                for i = 1, inv:get_size("main") do
                    if inv:get_stack("main", i):get_name() == ammunition then
                        local temp_stack = inv:get_stack("main", i)
                        local temp_ammo_table = temp_stack:get_meta():get_string("ammo")
                        minetest.chat_send_all(dump(temp_ammo_table))
                        if temp_ammo_table == "" then 
                            temp_ammo_table = {bullets={}, magazine="", loaded_bullet="", total_bullets=0}
                            temp_stack:get_meta():set_string("ammo", minetest.serialize({bullets={}, magazine=temp_stack:get_name(), loaded_bullet="", total_bullets=0}))
                            
                        else
                            temp_ammo_table = minetest.deserialize(temp_ammo_table)
                        end
                        --check if mag has higher wear
                        if temp_ammo_table.total_bullets >= highest_ammo then
                            index = i
                            magstack = temp_stack
                            highest_ammo = temp_ammo_table.total_bullets
                        end
                    end
                end
            end
            if magstack == nil then return end
            meta:set_string("ammo", magstack:get_meta():get_string("ammo"))
            inv:set_stack("main", index, "")
            player:set_wielded_item(held_stack)
        end
        if def.ammo_type == "fractional" then 
            if held_stack:get_wear() > 1 then
                local ammo_list = {}
                for _, ammunition in pairs(def.ammunitions) do 
                    if ammo_list[ammunition] == nil then ammo_list[ammunition] = 0 end
                    for i = 1, inv:get_size("main") do
                        if inv:get_stack("main", i):get_name() == ammunition then
                            --this is to account for the possibility that it's already been set
                            --don't wanna loop twice for no reason if there is ammo
                            if meta:get_string("ammo") == "" then
                                meta:set_string("ammo", ammunition)
                                held_stack:set_wear(max_wear)
                            end
                            ammo_list[ammunition] = ammo_list[ammunition] + inv:get_stack("main", i):get_count()
                        end
                    end
                end
                if meta:get_string("ammo") ~= "" then
                    if inv:contains_item("main", meta:get_string("ammo").." 1") then
                        inv:remove_item("main", meta:get_string("ammo").." 1")
                        local new_wear = held_stack:get_wear()-max_wear/def.clip_size
                        if new_wear < 1 then new_wear = 1 end
                        held_stack:set_wear(new_wear)
                        player:set_wielded_item(held_stack)
                    end
                end
            end
            if def.ammo_type == "non_fractional" then
            end
        end
    end
end
function guns3d.register_gun(name, def)
    --probably should optimize this with loops at some point
    if not def.ads_look_offset then def.ads_look_offset = 0 end
    if not def.pellets then def.pellets = 1 end
    if not def.ads_rot_offset then def.ads_rot_offset = vector.new() end
    if not def.sway_timer then def.sway_timer = 0 end
    if not def.sway_angle then def.sway_angle = 0 end
    if not def.bullet then def.bullet = {} end
    if not def.vroffset then def.vroffset = vector.new() end
    if not def.description then def.description = name end
    if not def.recoil_vel then def.recoil_vel=vector.new() else def.recoil_vel.z=0 end
    if not def.recoil_vel_min then def.recoil_vel_min=vector.new() else def.recoil_vel_min.z=0 end
    if not def.recoil_reduction then def.recoil_reduction=vector.new() else def.recoil_reduction.z=0 end
    if not def.hip_spread then def.hip_spread = 0 end
    if not def.ads_spread then def.ads_spread = 0 end

    --NOTE: ads_offset is (as you can see) not modified to fix it's actual intended (i.e x needs to be z)
    --i am not sure why i did this, but i remember having a fairly good reason to
    if not def.ads_offset then def.ads_offset = vector.new() else
        def.ads_offset = vector.divide({x=def.ads_offset.x, y=def.ads_offset.y, z=def.ads_offset.z}, 10)
    end    
    if not def.offset then def.offset = vector.new() else
        def.offset = vector.divide({x=def.offset.z, y=def.offset.y, z=def.offset.x}, 10)
    end      
    if not def.rot_offset then def.rot_offset = vector.new() else
        def.rot_offset = {x=def.rot_offset.x, y=def.rot_offset.z, z=def.rot_offset.y}
    end    
    if not def.vroffset then def.vroffset = vector.new() else
        def.vroffset = {x=def.vroffset.x, y=def.vroffset.z, z=def.vroffset.y}
    end    
    if not def.animation_frames then def.animation_frames = {} end
    if not def.arm_animation_frames then def.arm_animation_frames = {} end
    --register final defs
    def.name = name
    guns3d.guns[name] = def

    --the actual gun tool
    minetest.register_tool(name,{
        description = def.description,
        inventory_image = def.image,
        on_use = function(itemstack, player, pointed_thing)
        end,
        on_drop = function(itemstack, player, pointed_thing)
            --lol, nerd.
            player:set_wielded_item(itemstack)
        end
    })
    --make the unattached and attached gun entities

    --purely visual representation of the gun's pos
    --on its creation .self will IMMEDIATELY have to have a self.parent_player added, failure will cause disfunction
    minetest.register_entity(name.."_visual", {
        initial_properties = {
            visual = "mesh",
            mesh = def.mesh,
            textures = {def.texture},
            glow = 0,
            pointable = false,
            static_save = false,
        },
        on_step = function(self, dtime)
            local name = string.gsub(self.name, "_visual", "")
            local def = guns3d.guns[name]
            local obj = self.object
            if self.parent_player == nil then obj:remove() return end
            local parent = minetest.get_player_by_name(self.parent_player)
            if obj:get_attach() == nil then
                obj:remove()
                return
            elseif name == guns3d.data[parent:get_player_name()].held then
                --obj:set_rotation(guns3d.data[playername].visual_offset.rotation)
                if guns3d.data[playername].ads_location == 1 or guns3d.data[playername].ads_location == 0 then
                    --attach to the correct bone
                    if guns3d.data[playername].ads == false then
                        local normal_pos = def.offset+guns3d.data[playername].visual_offset.regular
                        obj:set_attach(parent, "Arm_Right2", vector.multiply({x=normal_pos.x, y=normal_pos.z, z=-normal_pos.y}, 10), def.rot_offset+guns3d.data[playername].visual_offset.rotation, true)
                    else
                        local normal_pos = def.ads_offset+guns3d.data[playername].visual_offset.regular
                        obj:set_attach(parent, "Eye_Bone", vector.multiply({x=-normal_pos.z, y=normal_pos.y, z=-normal_pos.x}, 10), def.ads_rot_offset+guns3d.data[playername].visual_offset.rotation, true)
                    end
                else
                    --smoooooth ads
                    local normal_pos = guns3d.ads_interpolate(parent, guns3d.data[playername].ads_location)+guns3d.data[playername].visual_offset.regular
                    obj:set_attach(parent, "Eye_Bone", vector.multiply({x=-normal_pos.x, y=normal_pos.y, z=-normal_pos.z}, 1), def.ads_rot_offset, true)
                end
            else 
                obj:remove()
                return
            end
        end
    })
end
--replace in the future
function guns3d.register_magazine(image, description, magazine, ammunitions, size)
    local max_wear = 65535
    guns3d.magazines[magazine] = size
    minetest.register_tool(magazine,{
        description = description,
        inventory_image = image,
        wield_image = image,
        wear_represents = "ammunition",
        on_use = function(itemstack, user, pointed_thing)
            minetest.chat_send_all(dump(itemstack:get_meta():get_string("ammo")))
        end
    })
    --this needs to be fixed to not predict random recipes involving it... but uh, not rn.
    minetest.register_craft_predict(function(itemstack, player, old_craft_grid, craft_inv)
        if craft_inv:contains_item("craft", magazine) and itemstack:get_name()=="" then
            return magazine
        end
    end)

    minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
        minetest.chat_send_all(itemstack:get_name())
        if craft_inv:contains_item("craft", magazine) and craft_inv:contains_item("craftpreview", magazine) then
            local ammo_table = itemstack:get_meta():get_string("ammo")
            local all_items = {}
            local foreign_items = false
            --check what items are there
            for i, stack in pairs(craft_inv:get_list("craft")) do
                local item_name = stack:get_name()
                if item_name ~= "" then
                    local is_foreign = true
                    table.insert(all_items, itemstack)
                    for i, ammo_name in pairs(ammunitions) do
                        if item_name == ammo_name or item_name == magazine then
                            is_foreign = false
                        end
                    end
                    if is_foreign == true then
                        foreign_items = true
                    end
                end
            end
            --basically check if the mag is being crafted or not
            if itemstack:get_name()==magazine and foreign_items then
                if itemstack:get_meta():get_string("ammo") == "" then 
                    ammo_table = {bullets={}, magazine=magazine, loaded_bullet="", total_bullets=0}
                end
                itemstack:set_wear(max_wear-max_wear*(ammo_table.total_bullets/size))
            end
            if craft_inv:get_list("craftpreview")[1]:get_name() == magazine and #all_items == 1 then
                local mag = craft_inv:remove_item("craft", magazine)
                local mag_meta = mag:get_meta()
                local all_items
                if mag_meta:get_string("ammo") == "" then 
                    ammo_table = {bullets={}, magazine=magazine, loaded_bullet="", total_bullets=0}
                else
                    ammo_table = minetest.deserialize(mag_meta:get_string("ammo"))
                end
                for bullet_name, amount in pairs(ammo_table.bullets) do
                    local bullet_stack = ItemStack(bullet_name.." "..amount)
                    if craft_inv:room_for_item("craft", bullet_stack) then
                        craft_inv:add_item("craft", bullet_stack)
                        ammo_table.bullets[bullet_name] = 0
                        ammo_table.total_bullets = ammo_table.total_bullets - amount
                    end
                end
                mag_meta:set_string("ammo", minetest.serialize(ammo_table))
                mag:set_wear(max_wear-max_wear*(ammo_table.total_bullets/size))
                return mag
            end
            --check if its being loaded
            if #all_items > 1 and not foreign_items then
                local mag = craft_inv:remove_item("craft", magazine)
                local mag_meta = mag:get_meta()
                local all_items
                if mag_meta:get_string("ammo") == "" then 
                    ammo_table = {bullets={}, magazine=magazine, loaded_bullet="", total_bullets=0}
                else
                    ammo_table = minetest.deserialize(mag_meta:get_string("ammo"))
                end
                for inv_index, bullet_stack in ipairs(craft_inv:get_list("craft")) do
                    for _, bullet in pairs(ammunitions) do
                        if bullet_stack:get_name() == bullet then
                            if not ammo_table.bullets[bullet] then ammo_table.bullets[bullet] = 0 end
                            if (ammo_table.total_bullets + bullet_stack:get_count())>size then
                                local excess = (ammo_table.total_bullets + bullet_stack:get_count())-size 
                                ammo_table.total_bullets = ammo_table.total_bullets + (bullet_stack:get_count()-excess) 
                                ammo_table.bullets[bullet] = ammo_table.bullets[bullet] + (bullet_stack:get_count()-excess)
                                --remove the specified amount of bullets, dont get confused.
                                bullet_stack:set_count(bullet_stack:get_count()-excess)
                                craft_inv:remove_item("craft", bullet_stack)
                            else
                                ammo_table.bullets[bullet] = ammo_table.bullets[bullet] + bullet_stack:get_count() 
                                ammo_table.total_bullets = ammo_table.total_bullets + bullet_stack:get_count() 
                                craft_inv:remove_item("craft", bullet_stack)
                            end
                        end
                    end
                end
                ammo_table.loaded_bullet=guns3d.weighted_randoms(ammo_table.bullets)
                mag:set_wear(max_wear-max_wear*(ammo_table.total_bullets/size))
                mag:get_meta():set_string("ammo", minetest.serialize(ammo_table))            
                return mag
            end
        end
    end)
end






    --[[minetest.register_tool(magazine,{
        description = description,
        inventory_image = image,
        wield_image = image,
        wear_represents = "ammunition",
        on_use = function(itemstack, user, pointed_thing)
        end
    })
    --future implenetation of multi-ammunition of guns and different ammo stats?
    minetest.register_craft({
        type = "shapeless",
        output = magazine,
        recipe = {magazine, ammunition.." "..size},
    })
    minetest.register_craft({
        type = "shapeless",
        output = magazine.." 1 65535",
        recipe = {magazine}
    })

	minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
		local hasbullet
		local hasmag
		local magid
		local other = false
		for id, stack in pairs (old_craft_grid) do
			if stack:get_name() == ammunition then
				hasbullet = stack:get_count()
			elseif stack:get_name() == magazine then
				hasmag = stack:get_wear()
				magid = id
			elseif stack:get_name() ~= "" then
				other = true
			end
		end
		
		if other then return end
		
		if hasmag and not hasbullet then
			local bullets = math.floor((size+.5) - ((hasmag/max_wear)*size))
			craft_inv:add_item("craft", {name = ammunition, count = bullets})
		end
		
		if hasbullet and hasmag then
			craft_inv:add_item("craft", {name = ammunition})
			local needbullets = math.floor((hasmag/max_wear)*size+.5)
			if needbullets == 0 then
				return
			end
			if hasbullet >= needbullets then
				itemstack:set_wear(1)
				craft_inv:remove_item("craft", {name = ammunition, count = needbullets})
			else
				local wear = hasmag-(hasbullet*(max_wear/size))
				if wear < 1 then wear = 1 end
				itemstack:set_wear(wear)
				craft_inv:remove_item("craft", {name = ammunition, count = hasbullet})
			end
		end
	end)]]
