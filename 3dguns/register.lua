
player_api.register_model("holding_gun.b3d", {
    animation_speed = 60,
    mesh = "holding_gun.b3d",
    textures = {"character.png"},
    visual_size = {x = 1, y = 1},
    animations = {},
    collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
    stepheight = 0.6,
    eye_height = 1.47,
})
--probably should just make this a sprite
minetest.register_entity("3dguns:generic_reticle", {
    initial_properties = {
        visual = "cube",
        visual_size = {x=0, y=0, z=0},
        textures = {"invisible.png", "invisible.png", "invisible.png", "invisible.png", "invisible.png", "invisible.png"},
        glow = 255,
        pointable = false,
        static_save = false,
        use_texture_alpha = true
    },
    on_step = function(self, dtime)
        local playername = self.parent_player
        local player = minetest.get_player_by_name(playername)
        local obj = self.object
        local properties = obj:get_properties()
        local held_stack = player:get_wielded_item()
        if held_stack:get_name()==self.gun_name and guns3d.data[playername].attached_gun then
            local def = guns3d.get_gun_def(player, held_stack)
            local opacity = 255
            local deviation = math.sqrt(math.abs(guns3d.data[playername].total_rotation.gun_axial.x^2)+math.abs(guns3d.data[playername].total_rotation.gun_axial.y^2))
            if (def.reticle.fade_start_angle and deviation >= def.reticle.fade_start_angle) then
                local start_ang = def.reticle.fade_start_angle
                local end_ang = def.reticle.fade_end_angle
                if guns3d.data[playername].ads_location == 1 then
                    opacity = 255-((deviation-start_ang)/(end_ang-start_ang))*255
                end
            end
            if guns3d.data[playername].ads_location ~= 1 then
                if guns3d.data[playername].ads_location > .8 and guns3d.data[playername].ads then
                    opacity = ((guns3d.data[playername].ads_location-.8)/.1)*255
                else
                    opacity = 0
                end
            end
            if self.opacity_lock == nil then
                self.opacity_lock = false
            end
            if self.opacity_lock then
                opacity = 0
            end
            --I really dont need to set this every step
            --change post-release for perfomance
            properties.textures[6] = def.reticle.texture
            if (guns3d.data[playername].current_animation_frame ~= def.animation_frames.loaded.x) and (guns3d.data[playername].current_animation_frame ~= def.animation_frames.unloaded.x) then
                --ok: so
                --if you have a reticle bone, it attaches during non-firing animations, if you want it to attach during firing animations then use fire_attach = true
                --if you do not have a reticle bone, during non-firing animations it simply becomes invisible
                local firing = ((guns3d.data[playername].current_animation_frame > def.animation_frames.fire.x) and (guns3d.data[playername].current_animation_frame < def.animation_frames.fire.y))
                if def.reticle.bone then
                    if (firing and def.reticle.fire_attach) or not firing then
                        if properties.visual_size.x <= def.reticle.attached_size/10+.08 and properties.visual_size.x >= def.reticle.attached_size/10-.08 then
                            obj:set_attach(guns3d.data[playername].attached_gun, def.reticle.bone, nil, nil, true)
                            self.opacity_lock = false
                        else
                            self.opacity_lock = true
                            opacity = 0
                        end
                        properties.visual_size = vector.new(def.reticle.attached_size, def.reticle.attached_size, 0)/10
                    end
                elseif not firing then
                    self.opacity_lock = true
                    opacity = 0
                end
            else
                if properties.visual_size.x <= def.reticle.size/10+.08 and properties.visual_size.x >= def.reticle.size/10-.08 then
                    obj:set_attach(player, "guns3d_reticle_bone", {x=def.ads_look_offset,y=0,z=def.offset.z+def.reticle.offset}, nil, true)
                    self.opacity_lock = false
                else
                    self.opacity_lock = true
                    opacity = 0
                end
                properties.visual_size = vector.new(def.reticle.size, def.reticle.size, 0)/10
            end
            properties.textures[6] = def.reticle.texture.."^[opacity:"..tostring(opacity)
            obj:set_properties(properties)
        else
            obj:remove()
            guns3d.data[playername].attached_reticle = nil
        end
    end
})
minetest.register_entity("3dguns:tracer", {
    initial_properties = {
        visual = "cube",
        visual_size = {x=.04, y=.04, z=15},
        textures = {"white.png", "white.png", "white.png", "white.png", "white.png", "white.png"},
        glow = 14,
        pointable = false,
        static_save = false
    },
    on_step = function(self, dtime)
        local obj = self.object
        if self.end_position == nil then obj:remove() return end
        local distance = vector.distance(self.end_position, obj:get_pos())
        local properties = obj:get_properties()
        if distance <= 23 then
            properties.visual_size.z = ((distance/15))*15
            obj:set_velocity(obj:get_velocity()*1.005)
        end
        if vector.distance(obj:get_pos(), self.start_position) > vector.distance(self.end_position, self.start_position)+.5 then obj:remove() return end
        obj:set_properties(properties)
    end
})

minetest.register_entity("3dguns:bullet_hole", {
    initial_properties = {
        visual = "cube",
        visual_size = {x=.15, y=.15, z=0},
        pointable = false,
        static_save = false,
        use_texture_alpha = true,
        textures = {"invisible.png", "invisible.png", "invisible.png", "invisible.png", "bullet_hole_1.png", "invisible.png"}
    },
    on_step = function(self, dtime)
        if not self.timer then
            self.timer = 120
        else
            self.timer = self.timer - dtime
        end
        if not self.block_name then
            self.block_name = minetest.get_node(self.block_pos).name
        elseif self.block_name ~= minetest.get_node(self.block_pos).name then
            self.object:set_detach()
            self.object:remove()
            return
        end
        local properties = self.object:get_properties()
        local timer = (self.timer-160)/40
        if timer > 0 then
            --png_image = 'bullet_hole_1.png^(bullet_hole_2.png^[opacity:160")'
            properties.textures[5] = 'bullet_hole_1.png^(bullet_hole_2.png^[opacity:129)'
        end
        self.object:set_properties(properties)
        if self.timer < 0 then
            self.object:set_detach()
            self.object:remove()
            return
        end
    end
})