b3d_tools = {}
local model_data_base = {}

--models will be indexed by filepath
--once initialized, model is not to change, otherwise this system may not function as intended
function b3d_tools.initialize_model(filepath)
    local file = io.open(filepath)
    if file ~= nil then
        local read_file = modlib.b3d.read(file)
        file:close()
        model_data_base[filepath] = read_file
        
    end
end
minetest.register_chatcommand("test_reader", {
    func = function()
        local file = io.open(minetest.get_modpath("b3d_tools").."/simple_test.b3d")
        if file ~= nil then
            local read_file = modlib.b3d.read(file)
            print(dump(read_file))
            file:close()
        end
    end
})
minetest.register_chatcommand("test_reformater", {
    func = function()
        local file = io.open(minetest.get_modpath("b3d_tools").."/simple_test.b3d")
        if file ~= nil then
            local read_file = modlib.b3d.read(file)
            print(dump(b3d_tools.reformat(read_file, true)))
            print("function ran")
            file:close()
        end
    end
})
--make sure to table.copy before calling unless you want to break pre-existing table.
--This function produces a neatly formated and easily accessible table from the mess that is the b3d output.
function b3d_tools.reformat(tbl, first_iter, parent)
    local new_tbl = {}
    if first_iter then
        local new_root_tbl = table.copy(tbl.node)
        if tbl.node.children then
            local child_new_tbl = b3d_tools.reformat(tbl.node.children, false, tbl.node.name)
            for i, v in pairs(child_new_tbl) do
                new_tbl[i] = v
            end
        end
        new_root_tbl.parent = ""
        new_root_tbl.children = nil
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
            contents.parent = parent
            contents.name = nil
            contents.children = nil
            new_tbl[name] = contents
        end
    end
    --print(dump(new_tbl))
    return new_tbl
end
--this exists as a shortcut, aswell as future-proofing.
function b3d_tools.model_intialized(filepath)
    if model_data_base[filepath] then return true else return false end
end
function b3d_tools.get_keyframe(filepath, bone, frame)
    if not b3d_tools.model_initialized(filepath) then return end
    --local table = 
end