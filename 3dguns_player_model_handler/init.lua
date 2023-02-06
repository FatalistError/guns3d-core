minetest.register_globalstep(function(dtime)
    for v, player in pairs(minetest.get_connected_players()) do
        --do stuff
    end
end)