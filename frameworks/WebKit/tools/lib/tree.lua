local common = import("@addon.revenant.member", {anonymous = true})
local paths = common.paths(os.scriptdir())
member = paths.member
revenant = paths.revenant
arguments = common.arguments

function modules(name)
    return import(name, {rootdir = member("src", "modules"), anonymous = true})
end

function where(name)
    local found = os.iorunv(os.programfile(), {"where", "-P", revenant(), name}, {curdir = revenant()}):trim()
    local last
    for line in found:gmatch("[^\n]+") do
        last = line:trim()
    end
    if not last or not os.isdir(last) then
        raise("xmake where %s answered %s, which is not a folder; configure for iphoneos and install the packages first", name, found)
    end
    return last
end

function engine_source(given)
    if given then
        return path.absolute(given)
    end
    return path.join(where("webkit"), "src")
end

function patches()
    return revenant("packages", "w", "webkit", "patches")
end

function recipe()
    return revenant("packages", "w", "webkit", "xmake.lua")
end
