
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
        visual_size = {x=.1, y=.1, z=0},
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
        if held_stack:get_name()==self.gun_name then
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
                if guns3d.data[playername].ads_location > .9 and guns3d.data[playername].ads then
                    opacity = ((guns3d.data[playername].ads_location-.9)/.1)*255
                else
                    opacity = 0
                end
            end
            properties.visual_size = vector.new(def.reticle.size, def.reticle.size, 0)/10
            if properties.textures[6] ~= def.reticle.texture then
                properties.textures[6] = def.reticle.texture.."^[opacity:"..tostring(opacity)
            end
            --minetest.chat_send_all(dump(def.reticle.texture))
            --I really dont need to set this every step
            --change post-release for perfomance
            obj:set_properties(properties)
        else
            obj:remove()
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
minetest.register_entity("3dguns:arms", {
    initial_properties = {
        visual = "mesh",
        --mesh = "arms.b3d",
        textures = {"character.png"},
        glow = 0,
        pointable = false,
        static_save = false,
    },
    on_step = function(self, dtime)
        local obj = self.object
        local player = obj:get_attach()
        local playername = player:get_player_name()
        if obj:get_attach() ~= nil and not guns3d.data[playername].is_holding then
            self.object:remove()
            return
        end
        local def = guns3d.guns[guns3d.data[playername].last_held_gun]
        local new_textures = obj:get_attach():get_properties().textures
        local properties = obj:get_properties()

        if def.arm_mesh and properties.mesh ~= def.arm_mesh then
            properties.mesh = def.arm_mesh
        else
            properties.mesh = guns3d.data[playername].default_arm_mesh
        end

        if properties.textures ~= new_textures then
            properties.textures = new_textures
        end
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
        minetest.chat_send_all(dump(self.block_pos))
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
minetest.register_entity("3dguns:flash_entity", {
    initial_properties = {
        glow = 100,
        visual = "sprite",
        textures = {"flash.png"}, --assign the same texture as skin on creation
        pointable = false,
        static_save = false,
        use_texture_alpha = true,
    },
    on_step = function(self, dtime)
        if not self.timer then
            self.timer = .1
        else
            self.timer = self.timer - dtime
        end
        local properties = self.object:get_properties()
        if self.timer > .1 then
            properties.visual_size = vector.multiply(properties.visual_size, 1.2)
        else
            properties.visual_size = vector.multiply(properties.visual_size, .8)
        end
        self.object:set_properties(properties)
        if self.timer < 0 then
            self.object:set_detach()
            self.object:remove()
            return
        end
    end
})
minetest.register_on_joinplayer(function(player)
    playername = player:get_player_name()
    guns3d.hud_id[playername] = {}
    guns3d.data[playername] = {}
    guns3d.data[playername].rechamber_time = 0
    guns3d.data[playername].last_held_gun = ""
    guns3d.data[playername].held = player:get_wielded_item():get_name()
    guns3d.data[playername].sway_vel = vector.new()
    guns3d.data[playername].sway_offset = vector.new()
    guns3d.data[playername].recoil_vel = vector.new()
    guns3d.data[playername].recoil_offset = vector.new()
    guns3d.data[playername].ads = false
end)