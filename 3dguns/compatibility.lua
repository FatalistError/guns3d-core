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
guns3d.model_def = {}
for i = 1, 50 do
    if guns3d.model_def[i] == nil then
        guns3d.model_def[i] = {}
    end
end
function guns3d.register_player_model(name, def)
    if def.mod_name == nil or minetest.get_modpath(def.mod_name) then
        guns3d.model_def[def.priority][name] = def
    end
end
function guns3d.get_new_player_model(player)
    --minetest.chat_send_all(dump(guns3d.model_def))
    local properties = player:get_properties()
    for index, table in ipairs(guns3d.model_def) do
        for name, def in pairs(table) do
            if def.mesh_name == nil or def.mesh_name == properties.mesh then
                guns3d.data[player:get_player_name()].bone_offsets = {head=def.head_location, arm=def.arm_location, root=def.root_height}
                guns3d.data[player:get_player_name()].default_arm_mesh = def.arm_mesh
                minetest.chat_send_all(dump(name))
                return name
            end
        end
    end
end
--NOTE! the model must ALREADY be registered by player_api
player_api.register_model("holding_gun_3darmor.b3d", {
    animation_speed = 30,
    mesh = "holding_gun_3darmor.b3d",
    textures = {"character.png"},
    visual_size = {x = 1, y = 1},
    animations = {},
    collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
    stepheight = 0.6,     
    eye_height = 1.47,    
})
guns3d.register_player_model("holding_gun_3darmor.b3d",{
    priority = 1, --10th to be checked, will not be used if something else exists can be up to 50, usually doesnt matter.
    mod_name = "3d_armor", --the name of the mod to check for before adding it, if nil it will be based off of mesh_name
    mesh_name = nil, --the name of the player mesh it is replacing, if nil will be ignored
    arm_location = {x=-3.15, y=5.75, z=0}, 
    root_height = 6.75, 
    arm_mesh = "arms_3darmor.b3d",
    head_location = {x=0, y=6.3, z=0},
})
guns3d.register_player_model("holding_gun.b3d",{
    priority = 3, --10th to be checked, will not be used if something else exists can be up to 50, usually doesnt matter.
    mod_name = nil, --the name of the mod to check for before adding it, if nil it will be based off of mesh_name
    mesh_name = nil, --the name of the player mesh it is replacing, if nil will be ignored
    arm_location = {x=-3.15, y=5.25, z=0}, 
    root_height = 6.3,
    arms_mesh = "arms.b3d",
    head_location = {x=0, y=6.3, z=0},
})