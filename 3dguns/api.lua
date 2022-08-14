


function guns3d.fire(player, def)
    --do not call if it's semi, it will be called by on_use instead.
    local held_stack = player:get_wielded_item()
    local meta = held_stack:get_meta()
    local ammo_table = minetest.deserialize(meta:get_string("ammo"))
    if ammo_table.total_bullets > 0 then
        if guns3d.data[playername].rechamber_time <= 0 then
            --this takes ammo, and puts new bullet into next

            if not minetest.check_player_privs(player, {creative=true}) then
                ammo_table = guns3d.dechamber_bullet(player, ammo_table)
            end
            local dir, pos = guns3d.gun_dir_pos(player)
            pos = pos+player:get_pos()
            --pellets (for shotguns and whatnot)
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
                dir = vector.rotate(dir, spread_rotation)
                guns3d.ray(player, pos, dir)
            end
            --rechambering
            if def.rechamber_time then
                --guns3d.data[playername].rechamber_time =
            else
                guns3d.data[playername].rechamber_time = 60/def.firerate
                --this needs to be mentioned in the API
                guns3d.data[playername].time_since_last_fire = 0
            end
            --recoil (needs redo)
            guns3d.handle_recoil_effects(player, def)
            --animataion
            if def.animation_frames.fire then
                local anim_time = (def.animation_frames.fire.y-def.animation_frames.fire.x)/def.fire_anim_fps
                guns3d.start_animation({{time = anim_time, frames = table.copy(def.animation_frames.fire)}}, player)
            end
            --muzzle flash
            local flashref = minetest.add_entity(player:get_pos(), def.flash_entity)
            local properties = flashref:get_properties()
            properties.visual_size = {x=.2,y=.2,z=.2}
            properties.textures = {def.flash_texture}
            if properties.use_texture_alpha then properties.textures[1] = properties.textures[1].."^[opacity:"..tostring(math.random(140, 200)) end
            flashref:set_properties(properties)
            flashref:set_attach(guns3d.data[playername].attached_gun, "", vector.rotate(def.flash_offset, def.axis_rotation*math.pi/180))
        end
    elseif ammo_table.total_bullets <= 0 then
        guns3d.data[playername].fire_queue = 0
    end
    meta:set_string("ammo", minetest.serialize(ammo_table))
    player:set_wielded_item(held_stack)
end

function guns3d.pull_trigger(active, controls_active, player)
    local def = guns3d.get_gun_def(player, player:get_wielded_item())
    if active then
        if not (guns3d.data[playername].last_controls.LMB) and def.firetype == "burst" then
            guns3d.data[playername].fire_queue = def.burst_fire
        end
        if (not guns3d.data[playername].last_controls.LMB or not player:get_player_control().LMB) and def.firetype == "semi-automatic" then
            guns3d.fire(player, def)
        end
        if def.firetype == "automatic" then
            guns3d.fire(player, def)
        end
        --ADD API FOR DIFFERENT FIRETYPES HERE
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
                time = def.reload_time,
                frames = table.copy(def.animation_frames.reload)
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
        guns3d.start_animation(animation, player)
        guns3d.quick_dual_sfx(player, "reload", def.sounds["reload"].sound, def.sounds["reload"].distance)
    end
    if not controls_active and not active then
        --have extra animation for fractional reloading etc
        guns3d.kill_dual_sfx(player, "reload", .1)
        guns3d.end_current_animation(player)
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
            guns3d.data[playername].attached_gun:set_animation({x=1, y=10})
            player:set_wielded_item(held_stack)
        end
        --[[if def.ammo_type == "fractional" then
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
        end]]
    end
end
function guns3d.aim_down_sights(active, controls_active, player)
    --make option for holding down in future
    if active then
        guns3d.data[player:get_player_name()].ads = not guns3d.data[player:get_player_name()].ads
    end
end
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

local default_gun_def = {
    description = "NO DESCRIPTION",

    recoil_vel = {x=0, y=0},
    axial_recoil_vel = {x=0, y=0},
    recoil = {x=0, y=0},
    recoil_correction = 1,
    recoil_reduction = 1,

    offset = vector.new(),
    ads_offset = vector.new(),
    bone_offset = vector.new(),
    flash_offset = vector.new(),

    vertical_rotation_offset = -6,

    ads_zoom_mp = 1,
    ads_look_offset = 1,
    sway_angle = 0,
    sway_timer = 0,
    flash_scale = .0,

    ads_time = 0,
    ads_spread = 0,
    hip_spread = 0,

    flash_entity = "3dguns:flash_entity",
    flash_texture = "muzzle_flash2.png",
    flash_offset = vector.new(),

    firerate = 0,
    burst_fire = 0,
    chamber_time = 0,
    reload_time = 0,
    range = 0,
    pellets = 1,

    penetration = false,
    fire_modes = {"semi-automatic"},
    controls = {
        reload = {{"zoom"}, false, false, 2},
        change_fire_mode = {{"zoom", "sneak"}, false, false, 0},
        fire = {{"LMB"}, false, true, 0},
        aim = {{"RMB"}, false, false, 0}
    },
    control_callbacks = {
        reload = guns3d.reload,
        change_fire_mode = guns3d.change_fire_mode,
        fire = guns3d.pull_trigger,
        aim = guns3d.aim_down_sights
    },
    fire_anim_fps = 60,
}
local default_bullet_def = {
    texture = "cz527.obj",
    range = 1000,
    max_node_pen = 0,
    max_pen_deviation = 0,
    min_pen_deviation = 0,
    destroy_nodes = {},
    penetratable_nodes = {
        ["default:wood"] = 1,
        ["stairs:slab_wood"] = 1,
        ["default:brick"] = 1,
        ["default:glass"] = 1
    },
}
function guns3d.register_gun(name, def)
    --sanitize definition
    print("\n GUNS3d: beginning definition registration checks for gun: "..name.."\n")
    for index, value in pairs(default_gun_def) do
        local initialized
        if not def[index] then
            def[index] = value
            initialized = true
        end
        if initialized then
            print("     "..index.." = ".. tostring(value))
        end
    end
    print("\n registration checks \"".. name.. "\" end \n")
    if def.screen_offset then
    end
    --get animation info (this may cause increased startup time/lag)

    def.name = name
    guns3d.guns[name] = def
    minetest.register_tool(name,{
        description = def.description,
        inventory_image = def.image,
        on_use = function(itemstack, player)
            --why
        end,
        on_drop = function(itemstack, player, pointed_thing)
            player:set_wielded_item(itemstack)
        end
    })
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
        --this all really could be on regular globalstep (excluding the self-deletion)
        --probably should do that sometime.
        on_step = function(self, dtime)
            local name = string.gsub(self.name, "_visual", "")
            local def = guns3d.guns[name]
            local obj = self.object
            if self.parent_player == nil then obj:remove() return end
            local parent = minetest.get_player_by_name(self.parent_player)
            if obj:get_attach() == nil or name ~= guns3d.data[parent:get_player_name()].held then
                obj:remove()
                return
            elseif name == guns3d.data[parent:get_player_name()].held then
                --obj:set_rotation(guns3d.data[playername].visual_offset.rotation)
                local axial_rot = guns3d.data[playername].total_rotation.gun_axial
                --axial_recoil = guns3d.ordered_rotation(axial_recoil)
                if guns3d.data[playername].ads_location == 1 or guns3d.data[playername].ads_location == 0 then
                    --attach to the correct bone
                    if guns3d.data[playername].ads == false then
                        local normal_pos = def.offset
                        -- vector.multiply({x=normal_pos.x, y=normal_pos.z, z=-normal_pos.y}, 10)
                        obj:set_attach(parent, "guns3d_hipfire_bone", normal_pos, -axial_rot, true)
                    else
                        local normal_pos = def.ads_offset
                        obj:set_attach(parent, "guns3d_aiming_bone", normal_pos, -axial_rot, true)
                    end
                else
                    --smoooooth ads
                    local normal_pos = guns3d.ads_interpolate(parent, guns3d.data[playername].ads_location)
                end
            end

            --print(dump(pos))
        end
    })
end

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
--gun def
function guns3d.register_bullet(name, def)
    --sanitize definition
    print("\n GUNS3d: beginning definition registration checks for bullet: "..name.."\n")
    for index, value in pairs(default_bullet_def) do
        local initialized
        if not def[index] then
            def[index] = value
            initialized = true
        end
        if initialized then
            print("     "..index.." = ".. tostring(value))
        end
    end
    print("\n registration checks \"".. name.. "\" end \n")
    guns3d.bullets[name] = def
end
function guns3d.get_gun_def(player, itemstack, name)
    local def
    local ammo_table
    if itemstack then
        def = table.copy(guns3d.guns[itemstack:get_name()])
        ammo_table = minetest.deserialize(itemstack:get_meta():get_string("ammo"))
    else
        --incase itemstack is not viable
        def = table.copy(guns3d.guns[name])
    end
    local modifiers = {}
    for i, v in pairs(def) do
        if type(def[i]) == "table" then
            if def[i].z and def[i].y and def[i].x then
                def[i] = vector.new(def[i].x, def[i].y, def[i].z)
            end
        end
    end
    if ammo_table and ammo_table.total_bullets >= 1 then
        for i, v in pairs(default_bullet_def) do
            local gun_value = def.bullet[i]
            local current_value = v
            if def.bullet[i] then
                if guns3d.bullets[ammo_table.loaded_bullet] then
                    current_value = guns3d.bullets[ammo_table.loaded_bullet][i]
                end
                if gun_value[1] == "+" then
                    def.bullet[i]=current_value+gun_value[2]
                elseif gun_value[1] == "*" then
                    def.bullet[i]=current_value*gun_default[2]
                elseif gun_value[1] == "override" then
                    def.bullet[i]=gun_value[2]
                end
            else
                def.bullet[i] = default_bullet_def[i]
            end
        end
    else
        def.bullet = default_bullet_def
    end
    --[[for modifier, value in pairs(modifiers) do
        --this will be used in the future to allow modifications of gun stats
        --based on player, global, or otherwise.
    end]]
    def.firetype = def.fire_modes[guns3d.data[playername].fire_mode]
    local value_table = {}
    local sorting_table = {}
    --this is some weird sorting to prevent controls from being mis-detected... tl:dr, keep it or replace it, it's needed.
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

    --
    if def.ammo_type == "magazine" then
        def.actual_clip_size = guns3d.magazines[itemstack:get_meta():get_string("ammo")]
    else
        def.actual_clip_size = def.clip_size
    end
    return def
end




--==================== DEFAULT CONTROLS ========================




