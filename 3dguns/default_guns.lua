guns3d.register_magazine("no2.png", "50R STANAG (5.56x39mm)", "3dguns:extended_stanag", {"default:wood"}, 50)
guns3d.register_magazine("no.png", "30R STANAG (5.56x39mm)", "3dguns:stanag", {"default:wood", "default:acacia_wood"}, 30)
guns3d.register_gun("3dguns:m4a1", {
    description = "m4", --FUCK YOU LUA
    offset = {x=6, z=-1.5, y=2}, --offset of the gun's location relative to arm in hipfire position
    yborder = true, --returns gun to rot_offset (removing vroffset and roffset) when looking above or below a certain angle range 
    recoil_vel = {x=.2, y=.004},--how far the gun goes up per second after firing once
    recoil = {x=.7, y=.25},
    recoil_reduction = {x=200, y=100}, --how fast recoil_vel reduces (if you want smoother recoil, set this so that velocity is not at 0 before rechamber)
    recoil_correction = 1, --how many seconds it takes for recoil to stabilize
    rot_offset = {x=-90, y=90, z=0}, --the rotation offset of the gun that isn't effected by y_border
    ads_offset = {x=5, y=0, z=1}, --offset of the gun while aiming down sights
    ads_rot_offset = {x=0, y=90, z=0}, --ads roffset 
    ads_zoom_mp = 1.4, --isn't actually a multiplier, fov = default_fov / ads_zoom_mp, but functions essentially as a zoom multiplier
    ads_look_offset = 1, --horizontal look offset (useful for making the gun look like it's actually being held up to eye)
    mesh = "m4a1.b3d", --main feature
    texture = "cz527.png", --item texture
    sway_angle = 0, --the radius that the new target angle will be in (add minimum later)
    sway_timer = 3, --how many seconds before the recoil velocity change
    penetration = true, 
    firerate = 850, --rate of fire in rounds per minute (600 would be 10 rounds a second). This same time system is applied to bolt action
    fire_modes = {"burst", "automatic", "semi-automatic"}, --the firing mode NEED TO IMPLEMENT BURST FIRE
    burst_fire = 3,
    flash_offset = {x=5.4, y=-.86, z=0},
    flash_scale = .5,
    range = 200, --range of the ray/bullet. penetrations does NOT account for total range in penetration
    ammo_type = "magazine", --uses fractional reloading otherwise
    ammunitions = {"3dguns:stanag", "3dguns:extended_stanag"}, --what magazines it will take (needs fix)
    reload_time = 1.5, --time it takes to reload in seconds
    ads_time = .45,
    ads_spread = .02,
    hip_spread = 1, 
    controls = {
        --keys, loop, repeat, threshold, override priority
        --if loop is false, it will still call the function after, just with active parameter false.
        --repeat basically just resets the timer etc when the function is activated, loop will not work with this. 
        --(the difference being loop is every step, and repeat at the selected interval)
        --fire = {{"LMB"}, true, false, 0}
        reload = {{"zoom"}, false, false, 2},
        change_fire_mode = {{"zoom", "sneak"}, false, false, 0},
        fire = {{"LMB"}, false, true, 0},
        aim = {{"RMB"}, false, false, 0}
    },
    control_callbacks = { 
        reload = guns3d.reload,
        change_fire_mode = guns3d.change_fire_mode,
        fire = guns3d.fire,
        aim = function(active, controls_active, player)
            if active then
                guns3d.data[player:get_player_name()].ads = not guns3d.data[player:get_player_name()].ads
            end
        end
    },
    chamber_time = 1,
    animation_frames = {
        aim_ads = {x=0, y=0},
        aim = {x=0, y=0},
        reload_ads = {x=1, y=30},
        reload = {x=1, y=30}, --reloading will auto-adjust fps to match reload length
        fire_ads = {x=31, y=40},
        fire = {x=31, y=40},
        fire_mode_1 = {x=41, y=50},
        unloaded = {x=1, y=1},
    },
    arm_animation_frames = {
        aim_ads = {x=0, y=10},
        aim = {x=30, y=35},
        reload_ads = {x=10, y=30},
        fire_ads = {x=10, y=10},
        fire = {x=0, y=0},
        rest_ads = {x=10, y=10},
        rest = {x=0, y=0}
    },
    bullet = { --replace with individual bullet definitions in the future
        mesh = "cz527.obj", --implmentation required
        texture = "cz527.obj",
        range = 1000,
        max_node_pen = 4, --how many nodes deep the it will *augh* penetrate 
        max_pen_deviation = 5, --maximum angle at which the bullet will deviate
        min_pen_deviation = 4, --same thing as above but the minimum
        destroy_nodes = {}, --***UNIMPLEMENTED*** what nodes to destroy on hit and ignore
        pen_nodes = { --the nodes that the bullet will insert themselves into... willingly, secondary value is the multiplier of how thicc it is
                    --I.E. how much it will deduct from max_node_pen
            ["default:wood"] = 1,
            ["default:brick"] = 2,
            ["default:glass"] = 0
        },
    },
    sounds = {
        reload = {sound="cz527_fire", distance=40},
        fire = {sound="cz527_fire", distance=40},
        bullet_whizz = {sound="bullet_whizz", distance=1},
        fire_mode = {sound="fire_mode", distance=10}
    }
})
guns3d.register_gun("3dguns:awm", {
    reticle = {
        offset = {x=0, y=0, z=0},
        bone = "Scope",
        image_size = 80,
        image = "scope.png",
        auto_center = false --only use for root bone (or centered)
    },
    description = "awm", --FUCK YOU LUA
    offset = {x=7, z=-1.2, y=1}, --offset of the gun's location relative to arm in hipfire position
    yborder = true, --returns gun to rot_offset (removing vroffset and roffset) when looking above or below a certain angle range 
    recoil_vel = {x=.2, y=.004},--how far the gun goes up per second after firing once
    recoil = {x=4, y=.25},
    recoil_reduction = {x=200, y=100}, --how fast recoil_vel reduces (if you want smoother recoil, set this so that velocity is not at 0 before rechamber)
    recoil_correction = 1, --how many seconds it takes for recoil to stabilize
    rot_offset = {x=-90, y=90, z=0}, --the rotation offset of the gun that isn't effected by y_border
    ads_offset = {x=7, y=-.812176, z=1}, --offset of the gun while aiming down sights
    ads_rot_offset = {x=0, y=90, z=0}, --ads roffset 
    ads_zoom_mp = 5, --isn't actually a multiplier, fov = default_fov / ads_zoom_mp, but functions essentially as a zoom multiplier
    ads_look_offset = 1, --horizontal look offset (useful for making the gun look like it's actually being held)
    mesh = "awm.b3d", --main feature, ***IMPLEMENTATION NEEDED FOR ANIMATIONS***
    texture = "cz527.png", --item texture
    sway_angle = .3, --the radius that the new target angle will be in (add minimum later)
    sway_timer = 10, --how many seconds before the recoil velocity change
    penetration = true, 
    firerate = 37.5, --rate of fire in rounds per minute (600 would be 10 rounds a second). This same time system is applied to bolt action
    fire_modes = {"semi-automatic"}, --the firing mode NEED TO IMPLEMENT BURST FIRE
    burst_fire = 3,
    flash_offset = {x=8, y=0, z=0},
    flash_scale = .5,
    range = 200, --range of the ray/bullet. penetrations does NOT account for total range in penetration
    clip_size = 1,
    ammo_type = "fractional", --uses fractional reloading otherwise
    ammunitions = {"default:wood"}, --what magazines it will take (needs fix)
    reload_time = .1, --time it takes to reload in seconds
    ads_time = .45,
    ads_spread = .00001,
    hip_spread = .015, 
    chamber_time = 1,
    animation_frames = {
        reload_ads = {x=122, y=183},
        reload = {x=122, y=183}, --reloading will auto-adjust fps to match reload length
        fire_ads = {x=30, y=120},
        fire = {x=30, y=120},
        unloaded = {x=1, y=1},
        fire_mode_1 = {x=1, y=1}
    },
    arm_animation_frames = {
        aim_ads = {x=0, y=10},
        aim = {x=30, y=35},
        reload_ads = {x=10, y=30},
        fire_ads = {x=10, y=10},
        fire = {x=0, y=0},
        rest_ads = {x=10, y=10},
        rest = {x=0, y=0}
    },
    bullet = { --replace with individual bullet definitions in the future
        mesh = "cz527.obj", --implmentation required
        texture = "cz527.obj",
        range = 1000,
        max_node_pen = 4, --how many nodes deep the it will *augh* penetrate 
        max_pen_deviation = 5, --maximum angle at which the bullet will deviate
        min_pen_deviation = 4, --same thing as above but the minimum
        destroy_nodes = {}, --***UNIMPLEMENTED*** what nodes to destroy on hit and ignore
        pen_nodes = { --the nodes that the bullet will insert themselves into... willingly, secondary value is the multiplier of how thicc it is
                    --I.E. how much it will deduct from max_node_pen
            ["default:wood"] = 1,
            ["default:brick"] = 2,
            ["default:glass"] = 0
        },
    },
    sounds = {
        reload = {sound="cz527_fire", distance=40},
        fire = {sound="cz527_fire", distance=40},
        bullet_whizz = {sound="bullet_whizz", distance=1},
        fire_mode = {sound="fire_mode", distance=10}
    }
})