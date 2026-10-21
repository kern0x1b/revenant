function failures(opt)
    local found = {}
    local data = import("data", {rootdir = opt.modules, anonymous = true})
    if not os.isfile(data.licence()) then
        table.insert(found, "the licence of the addon is not at " .. data.licence())
    end
    if not os.isdir(data.src("apple-compat")) then
        table.insert(found, "the addon's sources of apple-compat are not at " .. data.src("apple-compat"))
    end
    if not os.isfile(data.modules("apple", "sdkstubs.lua")) then
        table.insert(found, "the addon's module sdkstubs is not at " .. data.modules("apple", "sdkstubs.lua"))
    end
    return found
end
