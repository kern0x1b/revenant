local function load_recipe(file, calls, overrides)
    local captured
    local noop = function() end
    local env = {
        package = noop, set_kind = noop, set_homepage = noop, set_description = noop,
        set_license = noop, set_policy = noop, set_configs = noop, add_configs = noop,
        add_urls = noop, add_versions = noop, add_patches = noop, add_deps = noop,
        includes = noop, on_load = noop, on_test = noop,
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
            iorunv = function() return "" end, tryrm = noop, curdir = function() return "." end,
            scriptdir = function() return "/recipe" end
        },
        io = {
            writefile = function(p, text) table.insert(calls, {path = p, text = text}) end,
            save = noop, readfile = function() return "" end
        },
        import = function()
            return {src = function() return "/src/apple-compat" end, licence = function() return "/licence" end}
        end,
        addon = {addons = function() return {revenant = {version = "1.0"}} end, dirname = function() return "revenant" end}
    }
    for name, value in pairs(overrides or {}) do
        env[name] = value
    end
    assert(loadfile(file, "t", env))()
    return captured
end

local function ldid_envs(root, fetch)
    local calls = {}
    local on_install = load_recipe(path.join(root, "packages", "l", "ldid", "xmake.lua"), calls)
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

local function compat_project(root, builddir)
    local calls = {}
    local on_install = load_recipe(path.join(root, "packages", "a", "apple-compat", "xmake.lua"), calls)
    local mock = {
        toolchains = function() return {{load = function() end, config = function() return "6.0" end}} end,
        config = function() return "26.2" end,
        arch = function() return "armv7" end,
        installdir = function() return "/install" end,
        scriptdir = function() return "/recipe" end,
        builddir = function() return builddir end,
        data = function() return {} end
    }
    on_install(mock)
    for _, call in ipairs(calls) do
        if call.path and call.path:sub(-9) == "xmake.lua" then
            return call.path
        end
    end
end

local function inventory_error(root)
    local source = io.readfile(path.join(root, "frameworks", "Backports", "tools", "generate.lua"))
    local message
    local noop = function() end
    local env = setmetatable({}, {__index = _ENV})
    env.import = function(name)
        if name:find("dyld", 1, true) then
            return {root = function() return "/cache" end}
        end
        if name:find("library_list", 1, true) then
            return {backports_libraries = function() return {} end}
        end
        return setmetatable({}, {__index = function() return function() return "" end end})
    end
    env.os = {scriptdir = function() return "/tools" end, isfile = function() return false end}
    env.raise = function(text, ...)
        message = string.format(text, ...)
        error("raised")
    end
    local chunk = assert(load(source .. "\nreturn {device_class_inventory = device_class_inventory}", "generate", "t", env))
    pcall(chunk().device_class_inventory)
    return message
end

function failures(opt)
    local found = {}
    local root = path.join(opt.modules, "..", "..")

    local envs, err = ldid_envs(root, nil)
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
    local from_fetch = ldid_envs(root, fetched)
    if not from_fetch or not from_fetch.CPPFLAGS:find("-I/fetched/include", 1, true) or not from_fetch.LDFLAGS:find("-lfrom-fetch", 1, true) then
        table.insert(found, "ldid must use the fetchinfo when the dependency has one")
    end

    local first = compat_project(root, "build_one")
    local second = compat_project(root, "build_two")
    if not first or not second then
        table.insert(found, "apple-compat did not generate a project for two installs")
    elseif first == second or not first:find("build_one", 1, true) or not second:find("build_two", 1, true) then
        table.insert(found, "two apple-compat installs share one generated project: " .. tostring(first) .. " and " .. tostring(second))
    end

    local message = inventory_error(root)
    if not message or not message:find("./xmakew firmware --arch=armv7 classes ", 1, true) then
        table.insert(found, "a missing class inventory must name the firmware classes command: " .. tostring(message))
    end

    return found
end
