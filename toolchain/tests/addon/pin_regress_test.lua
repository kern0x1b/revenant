local function recipe_function(file, calls)
    local captured
    local noop = function() end
    local env = {
        package = noop, set_kind = noop, set_homepage = noop, set_description = noop,
        set_license = noop, add_urls = noop, add_versions = noop, add_patches = noop,
        add_deps = noop, on_test = noop,
        on_install = function(_, fn) captured = fn end,
        ipairs = ipairs, pairs = pairs, table = table, path = path, tostring = tostring,
        os = {
            vrunv = function(_, args, opt)
                table.insert(calls, {args = args, envs = opt and opt.envs})
                return 0
            end,
            cp = noop, vcp = noop, mkdir = noop, isfile = function() return true end,
            isdir = function() return true end, readfile = function() return "" end,
            writefile = noop, programfile = function() return "xmake" end,
            iorunv = function() return "" end, tryrm = noop, curdir = function() return "." end
        },
        io = {writefile = noop, save = noop, readfile = function() return "" end},
        import = function() return {} end,
        addon = {addons = function() return {} end, dirname = function() return "revenant" end}
    }
    assert(loadfile(file, "t", env))()
    return captured
end

local function ldid_flags(root, fetch)
    local file = path.join(root, "packages", "l", "ldid", "xmake.lua")
    local calls = {}
    local on_install = recipe_function(file, calls)
    local dep = {
        fetch = function() return fetch end,
        installdir = function(_, part) return part and ("/dep/" .. part) or "/dep" end,
        get = function(_, key) return ({links = {"plist-2.0"}, defines = {"LIBPLIST_STATIC"}})[key] end
    }
    local mock = {dep = function() return dep end, installdir = function() return "/ldid" end}
    local ok, err = pcall(on_install, mock)
    if not ok then
        return nil, tostring(err)
    end
    return calls[1] and calls[1].envs
end

function failures(opt)
    local found = {}
    local root = path.join(opt.modules, "..", "..")

    local envs, err = ldid_flags(root, nil)
    if not envs then
        table.insert(found, "ldid install fails when a dependency's fetch() returns nil: " .. err)
    else
        if not envs.CPPFLAGS:find("-I/dep/include", 1, true) or not envs.CPPFLAGS:find("-DLIBPLIST_STATIC", 1, true) then
            table.insert(found, "a nil fetch() must still give ldid the dependency's headers and defines: " .. tostring(envs.CPPFLAGS))
        end
        if not envs.LDFLAGS:find("-L/dep/lib", 1, true) or not envs.LDFLAGS:find("-lplist-2.0", 1, true) then
            table.insert(found, "a nil fetch() must still give ldid the dependency's library path and links: " .. tostring(envs.LDFLAGS))
        end
    end

    local fetched = {
        includedirs = {"/fetched/include"}, defines = {"FROM_FETCH"},
        linkdirs = {"/fetched/lib"}, links = {"from-fetch"}
    }
    local from_fetch = ldid_flags(root, fetched)
    if not from_fetch or not from_fetch.CPPFLAGS:find("-I/fetched/include", 1, true) or not from_fetch.LDFLAGS:find("-lfrom-fetch", 1, true) then
        table.insert(found, "ldid must use the fetchinfo when the dependency has one")
    end

    local compat = io.readfile(path.join(root, "packages", "a", "apple-compat", "xmake.lua"))
    if not compat:find("package:builddir()", 1, true) then
        table.insert(found, "apple-compat's generated project must live in the package's own build directory, so parallel installs do not share it")
    end
    if compat:find('path.absolute("compat")', 1, true) then
        table.insert(found, "apple-compat still uses one fixed compat folder for every install")
    end

    local generate = io.readfile(path.join(root, "frameworks", "Backports", "tools", "generate.lua"))
    if not generate:find("./xmakew firmware --arch=armv7 classes ", 1, true) then
        table.insert(found, "a missing class inventory must name the firmware classes command that fills it")
    end

    return found
end
