--models will be indexed by filepath
--once initialized, model is not to change, otherwise this system may not function as intended
local model_data_base = {}
function b3d_tools.initialize_model(filepath)
    local file = io.open(filepath, "rb")
    if file ~= nil then
        local read_file = modlib.b3d.read(file)
        file:close()
        model_data_base[filepath] = b3d_tools.reformat(read_file, true)
        return table.copy(model_data_base[filepath])
    end
end
minetest.register_chatcommand("test_reader", {
    func = function()
        local results = b3d_tools.initialize_model(minetest.get_modpath("3dguns").."/models/m4a1.b3d")
        print(dump(results))
    end
})
minetest.register_chatcommand("test_dir", {
    func = function()
        print(dump(minetest.get_dir_list(minetest.get_modpath("b3d_tools"))))
    end
})
minetest.register_chatcommand("test_reformater", {
    func = function()
        local file = io.open(minetest.get_modpath("guns3d_tools").."/models/simple_test.b3d")
        if file ~= nil then
            local read_file = modlib.b3d.read(file)
            print(dump(b3d_tools.reformat(read_file, true)))
            print("function ran")
            file:close()
        end
    end
})
minetest.register_chatcommand("test_get_keyframe", {
    func = function()
        print(dump(b3d_tools.get_keyframe(minetest.get_modpath("guns3d_tools").."/models/simple_test.b3d", "Bone", 2.5)))
    end
})
--make sure to table.copy before calling unless you want to break pre-existing table.
--This function produces a neatly formated and easily accessible table from the mess that is the b3d output.    
function b3d_tools.reformat(tbl, first_iter, parent)
    local new_tbl = {}
    if first_iter then
        --additional information needs to be perserved, but this is not important currently
        local new_root_tbl = table.copy(tbl.node)
        if tbl.node.children then
            local child_new_tbl = b3d_tools.reformat(tbl.node.children, false, tbl.node.name)
            for i, v in pairs(child_new_tbl) do
                new_tbl[i] = v
            end
        end
        new_root_tbl.parent = ""
        new_root_tbl.children = nil
        --animations will always be same across all nodes.
        if not new_root_tbl.animation then
            new_root_tbl.animation = table.copy(tbl.node.children[1].animation)
        end
        if new_root_tbl.mesh then
            new_root_tbl.mesh = nil
            new_root_tbl.position = {0, 0, 0}
        end
        new_root_tbl.root = true
        new_root_tbl.name = nil
        new_tbl[tbl.node.name] = new_root_tbl
    else
        for _, contents in pairs(tbl) do
            if contents.children then
                local child_new_tbl = b3d_tools.reformat(contents.children, false, contents.name)
                for i, v in pairs(child_new_tbl) do
                    new_tbl[i] = v
                end
            end
            local name = contents.name
            --(only use for debugging)
            --contents.bone = nil
            --contents.keys = nil
            contents.parent = parent
            contents.name = nil
            if contents.mesh then
                contents.mesh = nil
                contents.position = {0, 0, 0}
            end
            contents.children = nil
            new_tbl[name] = contents
        end
    end
    --print(dump(new_tbl))
    return new_tbl
end
--this exists as a shortcut, aswell as future-proofing.
function b3d_tools.model_initialized(filepath)
    if model_data_base[filepath] then return true else return false end
    print(filepath.."    INITIALIZED")
end
function b3d_tools.find_root_reformatted(table)
    for i, v in pairs(table) do
        if v.root then
            return i
        end
    end
end
function b3d_tools.get_keyframe(filepath, node, frame)
    frame = frame + 1
    if not b3d_tools.model_initialized(filepath) then
        --have fun waiting lol, initialize first loser
        b3d_tools.initialize_model(filepath)
    end
    --find closest keys
    local total_frames = model_data_base[filepath][b3d_tools.find_root_reformatted(model_data_base[filepath])].animation.frames
    local closest_key_before = 0
    if (not model_data_base[filepath][node]) or (not model_data_base[filepath][node].keys) or (not model_data_base[filepath][node].keys[1]) then return end
    for i, keyframe in ipairs(model_data_base[filepath][node].keys) do
        if (keyframe.frame <= frame) and (i > closest_key_before) then
            closest_key_before = i
        end 
    end
    local model_frames = model_data_base[filepath][node].keys
    local params = {}
    for i=1,2 do 
        params[i] = {}
        for _, vector_type in pairs({"rotation", "position", "scale"}) do
            if i==2 and model_frames[closest_key_before+1]==nil then return table.copy(params[1]) end
            local additional = 0
            if i==2 then additional = 1 end
            local indexed_table = model_frames[closest_key_before+additional][vector_type]
            local x = indexed_table[1]
            if vector_type == "rotation" then
                params[i][vector_type]=modlib.quaternion.to_euler_rotation_rad(indexed_table)
            else
                params[i][vector_type]=vector.new(indexed_table[1], indexed_table[2], indexed_table[3])
            end
        end
    end
    local interpolation_ratio = (frame-model_frames[closest_key_before].frame)/(model_frames[closest_key_before+1].frame-model_frames[closest_key_before].frame)
    return {
        rotation = modlib.vector.interpolate(params[1].rotation, params[2].rotation, interpolation_ratio),
        position = modlib.vector.interpolate(params[1].position, params[2].position, interpolation_ratio),
        scale = modlib.vector.interpolate(params[1].scale, params[2].scale, interpolation_ratio)
    }
end
function b3d_tools.get_bone_pos_rot(bone, objref, filepath, keyframe) 
    --find the bone's info
    local this_bone_pos
    local this_bone_rot
    if not existing_info then existing_info = {} end
    if objref then
        local properties = objref:get_properties()
        local position_valid = false
        local pos, rot = objref:get_bone_position(bone)
        filepath = modlib.minetest.media.paths[properties.mesh]
        for _, v in pairs({pos.x, pos.y, pos.z, rot.x, rot.y, rot.z}) do 
            --make sure its not empty, otherwise there's no way to be sure.
            if v ~= 0 then position_valid = true print("position valid") end
        end
        if position_valid then
            this_bone_pos = pos   
            this_bone_rot = rot    
        end  
    end
    if not model_data_base[filepath] then
        b3d_tools.initialize_model(filepath)
    end
    if not this_bone_pos then
        local keyframe_results = b3d_tools.get_keyframe(filepath, bone, keyframe)
        --print(dump(keyframe_results))
        if keyframe_results then
            this_bone_pos = vector.multiply(keyframe_results.position, keyframe_results.scale)
            this_bone_rot = keyframe_results.rotation
        else
            this_bone_pos = vector.new()
            this_bone_rot = vector.new()
        end
    end
    if model_data_base[filepath][bone].parent and model_data_base[filepath][bone].parent ~= "" then
        local parent_pos, parent_rot = b3d_tools.get_bone_pos_rot(model_data_base[filepath][bone].parent, objref, filepath, keyframe)
        print(parent_pos)
        this_bone_pos = vector.rotate(this_bone_pos, parent_rot) + parent_pos 
        this_bone_rot = this_bone_rot + parent_rot
    end
    this_bone_pos.x = -this_bone_pos.x
    return vector.new(this_bone_pos), vector.new(this_bone_rot)
end