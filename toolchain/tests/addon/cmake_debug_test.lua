function failures(opt)
    local found = {}
    local packages = path.join(opt.modules, "..", "..", "packages")
    local built_with_cmake = 0
    for _, recipe in ipairs(os.files(path.join(packages, "*", "*", "xmake.lua"))) do
        local text = io.readfile(recipe)
        if text:find("apple.cmake", 1, true) then
            built_with_cmake = built_with_cmake + 1
            local name = path.filename(path.directory(recipe))
            if not text:find('if is_mode("debug") then', 1, true) or not text:find('add_configs("debug"', 1, true) then
                table.insert(found, string.format("package %s is built with the cmake module, so its build type follows package:is_debug(), but it does not declare the debug config for the debug mode of the project", name))
            end
        end
    end
    if built_with_cmake == 0 then
        table.insert(found, "no package is built with the cmake module, so the debug mode check has nothing to check")
    end
    return found
end
