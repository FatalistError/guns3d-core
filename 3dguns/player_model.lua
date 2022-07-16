
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
--empty temp_models directory
local model_dynamic_send_queue = {}
local temp_models_path = minetest.get_modpath("3dguns").."/temp_models/"
minetest.rmdir(temp_models_path, true)
minetest.mkdir(temp_models_path)

function guns3d.register_player_model(mesh, def)
    local modpath = minetest.get_modpath(def.modname)
    if modpath then
        local filepath = modlib.minetest.media.paths[mesh]
        if def.filepath and def.modname then
            filepath = modpath..def.filepath
        end
        local file = io.open(filepath, "rb")
        local b3d_table = modlib.b3d.read(file)
        file:close()
        def.offsets = {}
        guns3d.player_model(b3d_table.node, nil, def)
        minetest.safe_file_write(temp_models_path.."guns3d_"..mesh, b3d_table:write_string())
        model_dynamic_send_queue[#model_dynamic_send_queue+1] = mesh
        --modlib compatibility
        modlib.minetest.media.paths["guns3d_"..mesh] = temp_models_path.."guns3d_"..mesh
        if minetest.get_modpath("player_api") then
            --copying is important here, dont wanna modify player_api tables.
            local player_api_def = table.copy(player_api.registered_models[mesh])
            player_api_def.mesh = "guns3d_"..mesh
            player_api_def.animations = player_api_def.animations or def.animations
            player_api.register_model("guns3d_"..mesh, player_api_def)
        end
        --finalize guns3d def.
        guns3d.model_def[mesh] = def
    end
end

local results = " "
local file = io.open(minetest.get_modpath("guns3d_tools").."/models/simple_test.b3d", "rb")
if file ~= nil then
    results = modlib.b3d.read(file)
    file:close()
end
minetest.safe_file_write(temp_models_path.."guns3d_test_file.txt", dump(results))

minetest.after(0,
    function()
        for i, v in pairs(model_dynamic_send_queue) do
            minetest.dynamic_add_media({
                filepath = temp_models_path.."guns3d_"..v,
                ephemeral = false
            }, function(name) print_name() end)
            print(dump(temp_models_path.."guns3d_"..v))
        end
    end,
model_dynamic_send_queue
)
--4th and 5th params to be left nil.
function guns3d.player_model(tbl, parent_tbl, def, total_offset)
    --(global) offset, not local
    local position = vector.multiply(vector.new(tbl.position[1], tbl.position[2], tbl.position[3]), vector.new(tbl.scale[1], tbl.scale[2], tbl.scale[3]))
    if not total_offset then
        total_offset = vector.new()
    else
        total_offset = total_offset + position or vector.new()
    end
    --(just need to make sure it's a bone)
    if tbl.bone then
        for _, name in pairs({"head", "arm_right", "arm_left", "root_bone"}) do
            if tbl.name == def[name] then
                tbl.name = "guns3d_"..name
                def.offsets[name] = position
                --initialize uninitialized bones if applicable
                if name == "arm_right" then
                    tbl.keys = table.copy(tbl.keys[2])
                    parent_tbl.keys = {}
                    parent_tbl.children[#parent_tbl.children+1] = {
                        name = "guns3d_hipfire_bone",
                        keys = {},
                        rotation = modlib.quaternion.from_euler_rotation(vector.new()),
                        bone = {},
                        scale = {1, 1, 1},
                        children = {},
                        position = {0, 0, 0}
                    }
                    def.offsets.global_hipfire_offset = total_offset
                end
                if name == "arm_left" then def.offsets.global_lefarm_offset = total_offset; tbl.keys = table.copy(tbl.keys[2]) end
                if name == "root_bone" then
                    tbl.keys = {}
                    tbl.children[#tbl.children+1] = {
                        name = "guns3d_aiming_bone",
                        keys = {},
                        rotation = modlib.quaternion.from_euler_rotation(vector.new()),
                        bone = {},
                        scale = {1, 1, 1},
                        children = {},
                        position = {0, 0, 0}
                    }
                end
            end
        end
    end
    for i, v in pairs(tbl.children) do
        guns3d.player_model(tbl.children[i], tbl, def, total_offset)
    end
end
function guns3d.get_guns3d_player_model(player)
    local properties = player:get_properties()
    for name, def in pairs(guns3d.model_def) do
        if properties.mesh == nil or name == properties.mesh then
            return name
        end
    end
end
guns3d.register_player_model("character.b3d", {
    modname = "player_api",
    root_bone = "Body",
    arm_left = "Arm_Left",
    arm_right = "Arm_Right",
    head = "Head",
})
guns3d.register_player_model("3d_armor_character.b3d", {
    modname = "3d_armor",
    root_bone = "Body",
    arm_left = "Arm_Left",
    arm_right = "Arm_Right",
    head = "Head",
})
