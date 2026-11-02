local function imports(file, module)
    for line in io.readfile(file):gmatch("[^\n]+") do
        if line:match("^%s*import%s+" .. module .. "%f[^%w_]") then
            return true
        end
    end
    return false
end

function failures(opt)
    local root = path.join(opt.modules, "..", "..")
    local found = {}
    local recipe = io.readfile(path.join(root, "packages", "s", "swiftui", "xmake.lua"))
    local swiftui = io.readfile(path.join(root, "frameworks", "SwiftUI", "xmake.lua"))
    local libraries = io.readfile(path.join(root, "frameworks", "Backports", "tools", "library_list.lua"))

    local foundation = false
    for _, file in ipairs(os.files(path.join(root, "frameworks", "SwiftUI", "src", "*.swift"))) do
        foundation = foundation or imports(file, "Foundation")
    end
    local suppressed = recipe:find("REVENANT_BACKPORTS_LIBRARIES", 1, true) ~= nil
    if suppressed and foundation and not recipe:find("revenant@backports", 1, true) then
        table.insert(found, "the swiftui recipe's generated project sets REVENANT_BACKPORTS_LIBRARIES, which drops the revenant@backports requirement every project gets, while the SwiftUI target imports Foundation: attach() refuses the project")
    end

    if not swiftui:match("if has_config%(\"backports_min_ios\"%) then%s+add_deps%(\"MapKitBackports\"%)") then
        table.insert(found, "frameworks/SwiftUI adds MapKitBackports without a check that frameworks/Backports is in the build graph, and the swiftui package's generated project does not include it: unknown target(MapKitBackports)")
    end

    for dependency in swiftui:gmatch("\"([%w_]+Backports)\"") do
        if not libraries:find("name = \"" .. dependency .. "\"", 1, true) then
            table.insert(found, "frameworks/SwiftUI depends on " .. dependency .. ", which frameworks/Backports does not define")
        end
    end
    return found
end
