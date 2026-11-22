function failures(opt)
    local requirements = import("apple.requirements", {rootdir = opt.modules, anonymous = true})
    local root = path.join(opt.modules, "..", "..")
    local found = {}
    for _, case in ipairs({
        {"", nil, true, "a whole configuration"},
        {"", "", true, "a whole configuration with an empty selection"},
        {nil, nil, true, "a configuration with no component"},
        {"emulator", nil, true, "the emulator component"},
        {"ReactNative", nil, true, "the React Native component, whose host takes the package"},
        {"SwiftUI", "MapKitBackports", false, "the SwiftUI package project with a library selection"},
        {"", "UIKitBackports", false, "a selection of libraries"},
        {"Backports", nil, false, "the Backports component, which builds the libraries itself"},
        {"Backports", "", false, "the Backports component with an empty selection"},
    }) do
        local required = requirements.backports_package_required(case[1], case[2])
        if required ~= case[3] then
            table.insert(found, string.format("%s: the backports package is %s, expected %s", case[4],
                                              required and "required" or "not required", case[3] and "required" or "not required"))
        end
    end
    local include = io.readfile(path.join(root, "toolchain", "includes", "apple-ios", "xmake.lua"))
    if not include:find("backports_package_required(get_config(\"component\"), os.getenv(\"REVENANT_BACKPORTS_LIBRARIES\"))", 1, true) then
        table.insert(found, "the apple-ios include does not decide the backports requirement through backports_package_required with the component and the selection")
    end
    if not include:find("modules\", \"apple\", \"requirements.lua\"", 1, true) then
        table.insert(found, "the apple-ios include does not include apple/requirements.lua, which defines backports_package_required")
    end
    local backports_project = io.readfile(path.join(root, "frameworks", "Backports", "xmake.lua"))
    if backports_project:find("add_packages(\"backports\"", 1, true) or backports_project:find("target:pkg(\"backports\")", 1, true) then
        table.insert(found, "frameworks/Backports/xmake.lua uses the backports package, which a --component=Backports configuration no longer requires")
    end
    return found
end
