
guns3d.register_gun("gun_pack_1:awm", {
    description = "AWM sniper rifle",
    recoil_vel = {look_axial={x=.3, y=.2}, gun_axial={x=.08, y=.05}}, --the velocity that will be added when the gun is fired
    recoil_correction = {look_axial = 2, gun_axial = 60}, --the speed at which the recoil offset is corrected, this isnt actually in degrees- as that'd be impossible based on the system
    max_recoil_correction = 6, --the maximum speed (in degrees) at which the recoil, this needs to be replaced with a table for look and gun axial.
    sway_vel = {look_axial=.06, gun_axial=.05}, --the velocity the gun will drift away from center aim (this doesn't effect non-sway offsets)
    sway_max = {look_axial=.5 , gun_axial=.5}, --the maximum angle that the gun will drift to before changing velocity
    breathing_offset = {look_axial=.01, gun_axial=.04}, --the multiplier for the vertical sine pattern that's offset (this will later be affected by stamina)
    jump_offset = {gun_axial=vector.new(-1, 1, 0), look_axial=vector.new(-1, 1, 0)}, --the offset that the gun will transistion to when jumping/in air
    walking_offset = {gun_axial=vector.new(.2, -.2, 0), look_axial=vector.new(1, 1, 0)}, --the multiplier for figure-8 pattern offset when walking
    deviation_max = .1, --max amount of "deviation" this basically just makes the gun's axial rotation lag behidn the actual look rotation a bit, I dont reccomend putting it too high, its a bit messy.
    ads_zoom_mp = 5, --the amount of zoom
    ads_look_offset = .7, --the horizontal offset of the gun
    ads_time = .4, --the time it takes to ADS
    hip_spread = 1, --the spread while firing at the hip
    ads_spread = .02, --the spread while aiming down sights
    ads_offset = {x=0, y=0, z=2}, --the offset shown when the player is aiming down sights
    offset = {x=-1.5, z=1, y=.5}, -- the offset when in hipfire
    mesh = "awm.b3d", --the mesh to be used
    attachment_mesh = "m4a1_naked.b3d", --unimplemented feature
    texture = "cz527.png",  --the texture? (????)
    firerate = 120, --the RPM of the gun
    fire_modes = {"semi-automatic"}, --the firemodes the gun has
    fire_anim_sync = true,
    burst_fire = 3, --the amount of rounds in a "burst" (aka burst firemode)
    flash_offset = {x=0, y=-.86, z=12.3}, --the location of the muzzle flash and other bullet effects
    reticle = { --this is a system that allows reticles that match the full rotation of the gun
        size = 1, --the size of the entity
        texture = "scope.png", --the texture
        offset = 5, --the offset (not that this can only be on the "z" axis, thus it's a int)
        fade_start_angle = .5, --the gun_axial offset value in which the gun will begin fading in accordance with fade_end_angle
        fade_end_angle = .45 --the gun_axial offset value that the gun will be at when it becomes fully transparent
    },
    reload = {
        type = "magazine",
        {"unloaded", .8, "unload"},
        {"reloaded", 1, "load"},
    },
    ammunitions = {"3dguns:stanag", "3dguns:extended_stanag"}, --the magazines it can take
    pellets = 1, --it's basically just the number of bullets (i.e. for shotguns). It also needs it's own version of spread later.
    chamber_time = 1, --the amount of time to "chamber" the gun after pulling it out, so hotswapping isnt a practical strat
    animation_frames = { --the name and ranges of animations to referenced by various functions and stuff
        unload = {x=2, y=80},
        load = {x=81, y=130},
        rechamber = {x=81, y=130},
        fire = {x=130, y=175, fade_reticle=false}, --"fade reticle" isnt implemented yet.
        fire_mode = {x=2, y=80},
        unloaded = {x=0, y=0, fade_reticle=false},
        loaded = {x=1, y=1, fade_reticle=false}
    },
    arm_animation_frames = { --so... this sucks, but it's required. you need to manually keyframe arm positions
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
    bullet = {
        --bullet override here
    },
    sounds = { --most of these are currently inactive, I havent exactly focused on sound for a bit
        reload = {sound="cz527_fire", distance=40},
        fire = {sound="cz527_fire", distance=40},
        bullet_whizz = {sound="bullet_whizz", distance=1},
        fire_mode = {sound="fire_mode", distance=10}
    }
})