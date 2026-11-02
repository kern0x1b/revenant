function failures(opt)
    local root = path.join(opt.modules, "..", "..")
    local found = {}
    local recipe = io.readfile(path.join(root, "packages", "s", "swiftui", "xmake.lua"))
    local swiftui = io.readfile(path.join(root, "frameworks", "SwiftUI", "xmake.lua"))
    local libraries = io.readfile(path.join(root, "frameworks", "Backports", "tools", "library_list.lua"))

    if not recipe:find("path.join(root, \"frameworks\", \"Backports\")", 1, true) then
        table.insert(found, "the swiftui recipe's generated project does not include frameworks/Backports, so MapKitBackports cannot resolve")
    end

    local _, direct = recipe:gsub("envs = backports", "")
    local _, joined = recipe:gsub("table%.join%(backports", "")
    if direct + joined < 3 then
        table.insert(found, "the swiftui recipe sets REVENANT_BACKPORTS_LIBRARIES on " .. (direct + joined) .. " of 3 xmake calls (configure, build, install)")
    end

    for dependency in swiftui:gmatch("\"([%w_]+Backports)\"") do
        if not libraries:find("name = \"" .. dependency .. "\"", 1, true) then
            table.insert(found, "frameworks/SwiftUI depends on " .. dependency .. ", which frameworks/Backports does not define")
        end
    end
    return found
end
