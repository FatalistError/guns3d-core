guns3d.node_properties = {}
--{["default:gravel"] = {rha=2, random_deviation=1, behavior="normal"}, . . . }
--behavior types:
--normal, bullets hit and penetrate
--breaks, bullets break it but still applies RHA/randomness values (etc)
--ignore, bullets pass through

--unimplemented

--liquid, bullets hit and penetrate, but effects are different
--damage, bullets hit and penetrate, but replace with "replace = _"

--mmRHA of wood .05 (mostly arbitrary)
--each block is 1000mm
--{choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1}

--this is really the best way I could think of to do this
--in a perfect world you could perfectly balance each node, but a aproximation will have to do
--luckily its still an option, if you're insane.
minetest.register_on_mods_loaded(function()
    for i, v in pairs(minetest.registered_nodes) do
        local groups = v.groups
        local mmRHA = 1
        local random_deviation = 1
        local behavior_type = "normal"
        if groups.wood then
            mmRHA = mmRHA*groups.wood*.5
            random_deviation = random_deviation/groups.wood
        end
        if groups.oddly_breakable_by_hand then
            mmRHA = mmRHA / groups.oddly_breakable_by_hand
        end
        if groups.choppy then
            mmRHA = mmRHA*(1+(groups.choppy*.2))
        end
        if groups.flora or groups.grass then
            mmRHA = 0
            random_deviation = 0
            behavior_type = "ignore"
        end
        if groups.leaves then
            mmRHA = .0001
            random_deviation = .005
        end
        if groups.stone then
            mmRHA = groups.stone
            random_deviation = .5
        end
        if groups.cracky then
            mmRHA = mmRHA*groups.cracky
            random_deviation = random_deviation*(groups.cracky*.5)
        end
        if groups.crumbly then
            mmRHA = mmRHA/groups.crumbly
        end
        if groups.soil then
            mmRHA = mmRHA*(groups.soil*2)
        end
        if groups.sand then
            mmRHA = mmRHA*(groups.sand*2)
        end
        if groups.liquid then
            --behavior type here
            mmRHA = .5
            random_deviation = .1
        end
        guns3d.node_properties[i] = {rha=mmRHA, random_deviation=random_deviation, behavior=behavior_type}
        print(i.." = "..dump(guns3d.node_properties[i]))
    end
end)
function manually_assign_block_values(table)
    for i, v in pairs(table) do
        assigned_values[i]=v
    end
end