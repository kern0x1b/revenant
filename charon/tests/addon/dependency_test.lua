-- A recipe takes the dependency built for its own platform, not whichever of the same name the name-keyed map holds.
function failures(opt)
    local dependency = import("apple.dependency", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local function fake(name, plat, arch, deps)
        local instance = {name = function () return name end, plat = function () return plat end, arch = function () return arch end}
        instance.orderdeps = function () return deps or {} end
        return instance
    end
    local target, host = fake("openssl", "iphoneos", "armv7"), fake("openssl", "macosx", "arm64")
    local package = fake("tdlib", "iphoneos", "armv7", {target, host, fake("ldid", "macosx", "arm64")})
    -- the name-keyed lookup the graph does answers the later one, the host's
    package.dep = function (_, name) return host end
    if dependency.target_dependency(package, "openssl") ~= target then
        table.insert(found, "the openssl built for the package's own platform and architecture must be the one taken, not the host's that the name-keyed map holds")
    end
    -- and whichever comes first in the walk
    local reversed = fake("tdlib", "iphoneos", "armv7", {host, target})
    reversed.dep = package.dep
    if dependency.target_dependency(reversed, "openssl") ~= target then
        table.insert(found, "the walk's order does not decide which build is taken")
    end
    local tool = fake("ldid", "macosx", "arm64", {host, fake("libplist", "macosx", "arm64")})
    tool.dep = function (_, name) return host end
    if dependency.target_dependency(tool, "openssl") ~= host then
        table.insert(found, "a host package takes the host's build of what it depends on")
    end
    local lone = fake("other", "iphoneos", "armv7", {fake("zlib", "iphoneos", "armv7")})
    local marker = {}
    lone.dep = function (_, name) return marker end
    if dependency.target_dependency(lone, "missing") ~= marker then
        table.insert(found, "a dependency the walk does not find is the one the package's own lookup answers")
    end
    return found
end
