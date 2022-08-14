
--the following is made for easy implementation of compatibility for mods that change the player model

--[[
    NOTE: the locations of bones in models may not translate well
    make sure that the provided location of any given bone's height
    is the height of the bone with the root subtracted.

    requirements for a compatible model:
        A: Head is renamed to Head2
        B: Right_Arm is named Arm_Right2

    make the arm model and name in following format
    mod_name.."arm"..[gun]
    [ADD WHEN IMPLEMENTED]
]]

function guns3d.get_model_def_name(player)
    local properties = player:get_properties()
    local model_name
    local model_def
    if properties.mesh and guns3d.model_def[properties.mesh] then
        model_def = table.copy(guns3d.model_def[properties.mesh])
        model_name = guns3d.model_def[properties.mesh].meshname
    end
    if not model_def or not model_name then
        for i, v in pairs(guns3d.model_def) do
            model_def = table.copy(v)
            model_name = v.meshname
        end
    end
    --make default model def?
    for i, v in pairs(model_def) do
        if type(v)=="table" and v.x and v.y and v.z then
            model_def[i] = vector.new(v)
        end
    end
    for i, v in pairs(model_def.offsets) do
        if type(v)=="table" and v.x and v.y and v.z then
            model_def.offsets[i] = vector.new(v)
        end
    end
    return model_def, model_name
end
function guns3d.register_player_model(name, def)
    guns3d.model_def[name] = def
    if minetest.get_modpath("player_api") then
        player_api.register_model(def.meshname, player_api.registered_models[name])
        print(dump(player_api.registered_models[def.meshname]))
    end
end
--expects guns3d_ prefix
--head, arm and new bones should be prefixed with guns3d_
--two new bones, hipfire_bone, and aiming_bone.
--hipfire should be connected to the same bone that the right arm is connected to
--aiming should be connected to the root bone of the character.
--make sure head and arm bones have rotation 0, aiming bone should be independant of any other bones
guns3d.register_player_model("character.b3d", {
    modname = "player_api",
    meshname = "guns3d_character.b3d",
    offsets = {
        head = vector.new(0,6.3,0),
        arm_right = vector.new(-3.15, 5.5, 0),
        arm_right_global = vector.new(-3.15, 11.55, 0), --can be low precision
        arm_left = vector.new(3.15, 5.5, 0),
        arm_left_global = vector.new(3.15, 11.55, 0),
    }
})
