--models will be indexed by filepath
--once initialized, model is not to change, otherwise this system may not function as intended
local model_data_base = {}
minetest.register_chatcommand("test_reader", {
    func = function()
        local file = io.open(minetest.get_modpath("3dguns").."/models/testing_model.b3d", "rb")
        if file ~= nil then
            local read_file = table.copy(modlib.b3d.read(file))
            print(dump(read_file))
            print("function ran")
            file:close()
        end
    end
})
minetest.register_chatcommand("test_dir", {
    func = function()
        print(dump(minetest.get_dir_list(minetest.get_modpath("b3d_tools"))))
    end
})
minetest.register_chatcommand("test_reformater", {
    func = function()
        local file = io.open(minetest.get_modpath("3dguns").."/models/m4a1.b3d", "rb")
        if file ~= nil then
            local read_file = table.copy(modlib.b3d.read(file))
            print(dump(b3d_tools.reformat(read_file, true)))
            print("function ran")
            file:close()
        end
    end
})
minetest.register_chatcommand("test_get_keyframe", {
    func = function()
        print(dump(b3d_tools.get_keyframe(minetest.get_modpath("3dguns").."/models/m4a1.b3d", "left_aimpoint", 0)))
    end
})
function b3d_tools.initialize_model(filepath)
    if not model_data_base[filepath] then
        local file = io.open(filepath, "rb")
        if file ~= nil then
            local read_file = modlib.b3d.read(file)
            model_data_base[filepath] = read_file
        end
        file:close()
    end
end

function b3d_tools.ordered_rotation(rotation, dir)
    rotation = rotation*math.pi/180
    local has_dir
    if not dir then
        dir = {x=0, y=0, z=1}
    else
        has_dir = true
        --normalize?
    end
    local dir = vector.rotate(dir, {x=0, y=0, z=rotation.z})
    dir = vector.rotate(dir, {x=0, y=rotation.y, z=0})
    dir = vector.rotate(dir, {x=rotation.x, y=0, z=0})
    if has_dir then
        return dir
    else
        return vector.dir_to_rotation(dir)*180/math.pi
    end
end
function b3d_tools.get_anim_info(filepath)
    b3d_tools.initialize_model(filepath)
    --[[local animation = model_data_base[filepath].node.animation
    if not animation then
        animation = model_data_base[filepath].node.children[1].animation
    end]]
    if not animation then
        animation = {
            fps = 0,
            total_frames = 0
        }
    end
    local total_frames = animation.frames
    local fps = animation.fps
    return total_frames, fps
end

local function remap_modlib_bone_list(original_list)
    for i, v in pairs(original_list) do
        if v.bone_name then
            local name = v.bone_name
            v.bone_name = nil
            original_list[name] = v
            local pos = original_list[name].position
            original_list[name].position = vector.new(pos[1], pos[2], pos[3])
            original_list[i] = nil
        end
    end
end
local function local_bone_pos(list, bone)
    if list[bone] then
        if list[bone].parent_bone_name then
            local P_pos, P_rot = local_bone_pos(list, list[bone].parent_bone_name)
        else
            P_pos = vector.new()
            P_rot = {1,0,0,0}
        end
        --print(dump(list[bone].position))
        local pos = vector.rotate(list[bone].position, -vector.new(modlib.quaternion.to_euler_rotation_rad(P_rot))+vector.new(0,0,0*math.pi/180))+P_pos
        local rot = modlib.quaternion.compose(P_rot, list[bone].rotation)
        print(dump(vector.new(modlib.quaternion.to_euler_rotation_rad(rot))*180/math.pi))
        return pos, rot
    end
end
--results should be stored to increase perfomance as this could be a fairly heavy function
function b3d_tools.get_bone_pos_rot(bone, objref, filepath, keyframe)
    if objref then
        local properties = objref:get_properties()
        local position_valid = false
        filepath = modlib.minetest.media.paths[properties.mesh]
    end
    b3d_tools.initialize_model(filepath)
    local anim_list = modlib.b3d.get_animated_bone_properties(model_data_base[filepath], keyframe, true)
    remap_modlib_bone_list(anim_list)
    --print(dump(anim_list))

    local pos, rot = local_bone_pos(anim_list, bone)
    return vector.new(pos), vector.new(modlib.quaternion.to_euler_rotation_rad(rot))
end