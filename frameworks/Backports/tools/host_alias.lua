function defined(files)
    local names, seen = {}, {}
    for _, file in ipairs(files) do
        for name in io.readfile(file):gmatch("BACKPORT_IMPL%(([%w_]+)%)") do
            if not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    table.sort(names)
    return names
end

function flags(files)
    local list = {}
    for _, name in ipairs(defined(files)) do
        table.insert(list, "-Wl,-alias,___revenant_fb_" .. name .. ",_" .. name)
    end
    return list
end

function swift_flags(files)
    local list = {}
    for _, flag in ipairs(flags(files)) do
        table.insert(list, "-Xclang-linker")
        table.insert(list, flag)
    end
    return list
end
