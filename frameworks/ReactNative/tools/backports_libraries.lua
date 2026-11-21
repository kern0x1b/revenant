HOST_REQUIRED = {"FoundationBackports", "CoreTextBackports", "UIKitBackports", "UserNotificationsBackports", "CoreGraphicsBackports", "GraphicsBackports", "CoreFoundationBackports", "SystemBackports", "IOSurfaceBackports", "WebKitBackports", "MapKitBackports", "CoreLocationBackports", "SecurityBackports", "CoreMotionBackports", "CoreTelephonyBackports", "AVKitBackports"}

function declared(text)
    local list = text:match('revenant@backports"[^\n]-libraries%s*=%s*"([^"]*)"')
    if not list then
        return nil
    end
    local names = {}
    for name in list:gmatch("[^,%s]+") do
        table.insert(names, name)
    end
    return names
end

function missing(names, required)
    local have = {}
    for _, name in ipairs(names) do
        have[name] = true
    end
    local lacking = {}
    for _, name in ipairs(required or HOST_REQUIRED) do
        if not have[name] then
            table.insert(lacking, name)
        end
    end
    return lacking
end

function check()
    local names = declared(io.readfile(os.projectfile()))
    local manifest = path.join(os.projectdir(), "host.json")
    if not names and os.isfile(manifest) then
        names = import("core.base.json").loadfile(manifest).backports
    end
    if not names then
        raise("the application's xmake.lua names no libraries for its revenant@backports requirement, neither in xmake.lua nor as backports in host.json; the host takes the list from the application and has none of its own")
    end
    local lacking = missing(names)
    if #lacking > 0 then
        raise("the application's Backports libraries lack what the host links: %s", table.concat(lacking, ","))
    end
end
