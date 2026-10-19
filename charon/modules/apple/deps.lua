function flags(package, names)
    local wanted = names and table.wrap(names) or nil
    local found = {cflags = {}, cxxflags = {}, ldflags = {}}
    local deps = {}
    if wanted then
        for _, name in ipairs(wanted) do
            local dep = package:dep(name)
            if not dep then
                raise("%s names dependency %s, which it does not add_deps()", package:name(), name)
            end
            table.insert(deps, dep)
        end
    else
        for _, dep in ipairs(package:librarydeps()) do
            table.insert(deps, dep)
        end
    end
    for _, dep in ipairs(deps) do
        local info = dep:fetch() or {}
        for _, folder in ipairs(table.join(table.wrap(info.sysincludedirs), table.wrap(info.includedirs))) do
            table.insert(found.cflags, "-isystem" .. folder)
        end
        for _, define in ipairs(table.wrap(info.defines)) do
            table.insert(found.cflags, "-D" .. define)
        end
        table.join2(found.cflags, table.wrap(info.cflags), table.wrap(info.cxflags))
        table.join2(found.cxxflags, table.wrap(info.cxxflags))
        for _, folder in ipairs(table.wrap(info.linkdirs)) do
            table.insert(found.ldflags, "-L" .. folder)
        end
        for _, link in ipairs(table.join(table.wrap(info.links), table.wrap(info.syslinks))) do
            table.insert(found.ldflags, "-l" .. link)
        end
        table.join2(found.ldflags, table.wrap(info.ldflags), table.wrap(info.shflags))
    end
    found.cflags = table.unique(found.cflags)
    found.cxxflags = table.unique(found.cxxflags)
    return found
end
