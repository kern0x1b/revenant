function failures(opt)
    local recipes = import("package_recipes", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local root = path.join(opt.modules, "..", "..")

    local function dep(fetch)
        return {
            fetch = function() return fetch end,
            installdir = function(_, part) return part and ("/dep/" .. part) or "/dep" end,
            get = function(_, key) return ({links = {"plist-2.0"}, defines = {"LIBPLIST_STATIC"}})[key] end
        }
    end

    local empty = recipes.dependency_flags(dep(nil))
    if table.concat(empty.includedirs, ",") ~= "/dep/include" or table.concat(empty.defines, ",") ~= "LIBPLIST_STATIC" or
       table.concat(empty.linkdirs, ",") ~= "/dep/lib" or table.concat(empty.links, ",") ~= "plist-2.0" then
        table.insert(found, "a dependency without fetchinfo must give the flags from its install directory and declared metadata")
    end

    local fetched = {
        includedirs = {"/fetched/include"}, defines = {"FROM_FETCH"},
        linkdirs = {"/fetched/lib"}, links = {"from-fetch"}
    }
    local supplied = recipes.dependency_flags(dep(fetched))
    if table.concat(supplied.includedirs, ",") ~= "/fetched/include" or table.concat(supplied.links, ",") ~= "from-fetch" then
        table.insert(found, "a dependency with fetchinfo must give the flags xmake fetched")
    end

    local first = recipes.compat_project({builddir = function() return "build_one" end})
    local second = recipes.compat_project({builddir = function() return "build_two" end})
    if first == second or not first:find("build_one", 1, true) or not second:find("build_two", 1, true) then
        table.insert(found, "two apple-compat installs share one generated project: " .. tostring(first) .. " and " .. tostring(second))
    end

    local message = recipes.missing_inventory_error("6.1.3", "/cache/6.1.3/classes_armv7.json")
    if not message:find("./xmakew firmware --arch=armv7 classes 6.1.3", 1, true) then
        table.insert(found, "a missing class inventory must name the firmware classes command: " .. message)
    end

    local ldid = io.readfile(path.join(root, "packages", "l", "ldid", "xmake.lua"))
    if not ldid:find("dependency_flags(", 1, true) then
        table.insert(found, "ldid must take its dependency flags from the shared helper")
    end
    local compat = io.readfile(path.join(root, "packages", "a", "apple-compat", "xmake.lua"))
    if not compat:find("compat_project(", 1, true) then
        table.insert(found, "apple-compat must take its generated project path from the shared helper")
    end
    local generate = io.readfile(path.join(root, "frameworks", "Backports", "tools", "generate.lua"))
    if not generate:find("missing_inventory_error(", 1, true) then
        table.insert(found, "the generator must take the inventory error from the shared helper")
    end

    return found
end
