function failures(opt)
    local tools = path.join(path.directory(opt.modules), "..", "frameworks", "ReactNative")
    local export = import("export_bundle", {rootdir = path.join(tools, "tools"), anonymous = true})
    local found = {}
    if not export.wrapper("default"):find('unstable_transformProfile: "default"', 1, true) then
        table.insert(found, "the babel wrapper must select the default transform profile")
    end
    if not export.wrapper("hermes-stable"):find('unstable_transformProfile: "hermes-stable"', 1, true) then
        table.insert(found, "the babel wrapper must select the hermes-stable transform profile for --hermes")
    end
    if not export.wrapper("default"):find('"babel-preset-expo"', 1, true) then
        table.insert(found, "the babel wrapper must change only babel-preset-expo")
    end
    local metro = export.metro_wrapper("cjs")
    if not metro:find('require("./metro.config.original.cjs")', 1, true) then
        table.insert(found, "the metro wrapper must load the original configuration with its extension")
    end
    if not metro:find("inlineRequires: true", 1, true) then
        table.insert(found, "the metro wrapper must turn inline requires on")
    end
    local front = io.readfile(export.prelude())
    for _, name in ipairs({"atob", "btoa"}) do
        if not front or not front:find("g." .. name .. " = function", 1, true) then
            table.insert(found, "the prelude must define " .. name)
        end
    end
    if export.joined("a", "b") ~= "a\nb" then
        table.insert(found, "the prelude must come in front of the bundle")
    end
    return found
end
