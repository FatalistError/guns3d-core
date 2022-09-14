guns3d.register_magazine("no2.png", "50R STANAG (5.56x39mm)", "3dguns:extended_stanag", {"default:wood", "default:acacia_wood"}, 50)
guns3d.register_magazine("no.png", "30R STANAG (5.56x39mm)", "3dguns:stanag", {"default:wood", "default:acacia_wood"}, 30)

guns3d.register_gun("3dguns:m4a1", {
    description = "m4",
    offset = {x=-1.6, z=4, y=1.5},
    root_offset = {x=0, y=0, z=0},
    ads_offset = {x=.7, y=0, z=4.67},
    vertical_rotation_offset = 0,
    recoil_vel = {x=.2, y=.2},
    axial_recoil_vel = {x=.06, y=.06},
    --recoil = {x=.7, y=.25},
    recoil_correction = {look_axial = 2, gun_axial = 40},
    max_recoil_correction = 6,
    ads_zoom_mp = 1.5,
    ads_look_offset = .7,
    mesh = "m4a1.b3d",
    texture = "cz527.png",
    sway_angle = 0,
    sway_timer = 3,
    penetration = true,
    firerate = 850,
    fire_modes = {"burst", "automatic", "semi-automatic"},
    burst_fire = 3,
    flash_offset = {x=0, y=-.86, z=5.8},
    flash_scale = .5,
    range = 200,
    reload = {
        type = "magazine",
        {"unloaded", .8, "unload"},
        {"reloaded", 1, "load"},
    },
    ammunitions = {"3dguns:stanag", "3dguns:extended_stanag"},
    reload_time = 1,
    ads_time = .45,
    ads_spread = .02,
    hip_spread = 1,
    pellets = 1,
    chamber_time = 1,
    animation_frames = {
        unload = {x=2, y=34},
        load = {x=34, y=75},
        rechamber = {x=100, y=115},
        fire = {x=75, y=82},
        fire_mode = {x=82, y=98},
        unloaded = {x=0, y=0},
        loaded = {x=1, y=1}
    },
    arm_animation_frames = {
        --IN ORDER!!!
        {frame=-1, right=vector.new(0,-2.5,-.7), left=vector.new(0,-0.9, 1.8)},
        {frame=0, right=vector.new(0,-2.5,-.7), left=vector.new(0,-0.9, 1.8)},
        {frame=16, right=vector.new(0,-2.5,-.7), left=vector.new(0,-0.9, 1.8)},
        {frame=20, right=vector.new(0,-2.5,-.7), left=vector.new(-3,-2.7, -1.2)},
        {frame=30, right=vector.new(0,-2.5,-.7), left=vector.new(0,-0.9, 1.8)},
        {frame=40, right=vector.new(0,-2.5,-.7), left=vector.new(-3,-2.7, -1.2)},
        {frame=60, right=vector.new(0,-2.5,-.7), left=vector.new(0,-0.9, 1.8)},
        {frame=100, right=vector.new(0,-2.5,-.7), left=vector.new(-1,-1.4, 0.6)},
        {frame=115, right=vector.new(0,-2.5,-.7), left=vector.new(0,-0.9, 1.8)}
    },
    --[[arm_aim_positions = {
        right=vector.new(0,-2.5,-.7), left=vector.new(0,-0.9, 1.8)
    },]]
    bullet = {
        --bullet override here
    },
    sounds = {
        reload = {sound="cz527_fire", distance=40},
        fire = {sound="cz527_fire", distance=40},
        bullet_whizz = {sound="bullet_whizz", distance=1},
        fire_mode = {sound="fire_mode", distance=10}
    }
})
--[[guns3d.register_gun("3dguns:awm", {
    reticle = {
        offset = {x=0, y=0, z=0},
        bone = "Scope",
        image_size = 80,
        image = "scope.png",
        auto_center = false --only use for root bone (or centered)
    },
    description = "awm", --FUCK YOU LUA
    offset = {x=-1.4, y=1, z=6}, --offset of the gun's location relative to arm in hipfire position
    yborder = true, --returns gun to rot_offset (removing vroffset and roffset) when looking above or below a certain angle range
    recoil_vel = {x=.2, y=.004},--how far the gun goes up per second after firing once
    recoil = {x=4, y=.25},
    recoil_reduction = {x=200, y=100}, --how fast recoil_vel reduces (if you want smoother recoil, set this so that velocity is not at 0 before rechamber)
    recoil_correction = 1, --how many seconds it takes for recoil to stabilize
    axis_rotation = {x=0, y=-90, z=0},
    ads_axis_rotation = {x=0, y=-90, z=0},
    ads_offset = {x=1, y=-.812176, z=7}, --offset of the gun while aiming down sights
    ads_zoom_mp = 8, --isn't actually a multiplier, fov = default_fov / ads_zoom_mp, but functions essentially as a zoom multiplier
    ads_look_offset = 1, --horizontal look offset (useful for making the gun look like it's actually being held)
    mesh = "awm.b3d", --main feature, ***IMPLEMENTATION NEEDED FOR ANIMATIONS***
    texture = "cz527.png", --item texture
    sway_angle = 0, --the radius that the new target angle will be in (add minimum later)
    sway_timer = 10, --how many seconds before the recoil velocity change
    penetration = true,
    firerate = 37.5, --rate of fire in rounds per minute (600 would be 10 rounds a second). This same time system is applied to bolt action
    fire_modes = {"semi-automatic"}, --the firing mode NEED TO IMPLEMENT BURST FIRE
    burst_fire = 3,
    flash_offset = {x=8, y=0, z=0},
    flash_scale = .5,
    range = 200, --range of the ray/bullet. penetrations does NOT account for total range in penetration
    clip_size = 1,
    ammo_type = "fractional",
    ammunitions = {"default:wood"}, --what magazines it will take (needs fix)
    reload_time = 2,
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
})]]