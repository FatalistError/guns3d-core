guns3d.register_magazine("no2.png", "50R STANAG (5.56x39mm)", "3dguns:extended_stanag", {"default:wood", "default:acacia_wood"}, 50)
guns3d.register_magazine("no.png", "30R STANAG (5.56x39mm)", "3dguns:stanag", {"default:wood", "default:acacia_wood"}, 30)

guns3d.register_gun("3dguns:m4a1", {
    description = "m4",
    offset = {x=-1.6, z=4, y=1.5},
    recoil_vel = {look_axial={x=.2, y=.2}, gun_axial={x=.03, y=.03}},
    recoil_correction = {look_axial = 2, gun_axial = 12},
    sway_vel = {look_axial=.1, gun_axial=.1},
    sway_max = {look_axial=.2, gun_axial=.05},
    breathing_offset = {look_axial=.1, gun_axial=0}, --(in degrees)
    jump_offset = {gun_axial=vector.new(-1, 1, 0), look_axial=vector.new(-1, 1, 0)},
    walking_offset = {gun_axial=vector.new(.2, -.2, 0), look_axial=vector.new(1, 1, 0)},
    deviation_max = .1,
    max_recoil_correction = 6,
    ads_zoom_mp = 1.5,
    ads_look_offset = .7,
    ads_time = .4,
    ads_spread = .02,
    ads_offset = {x=0, y=0, z=4.67},
    mesh = "m4a1.b3d",
    attachment_mesh = "m4a1_naked.b3d",
    texture = "cz527.png",
    firerate = 850,
    fire_modes = {"burst", "automatic", "semi-automatic"},
    burst_fire = 3,
    flash_offset = {x=0, y=-.86, z=5.8},
    range = 200,
    --[[reticle = {
        size = .22,
        texture = "gun_mrkr.png",
        offset = 0,
        fade_start_angle = .2,
        fade_end_angle = .45
    },]]
    reload = {
        type = "magazine",
        {"unloaded", .8, "unload"},
        {"reloaded", 1, "load"},
    },
    ammunitions = {"3dguns:stanag", "3dguns:extended_stanag"},
    reload_time = 1,

    hip_spread = 1,
    pellets = 1,
    chamber_time = 1,
    animation_frames = {
        unload = {x=2, y=34},
        load = {x=34, y=75},
        rechamber = {x=100, y=115},
        fire = {x=75, y=82, fade_reticle=false},
        fire_mode = {x=82, y=98},
        unloaded = {x=0, y=0, fade_reticle=false},
        loaded = {x=1, y=1, fade_reticle=false}
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