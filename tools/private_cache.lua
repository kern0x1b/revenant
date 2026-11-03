local EXCLUDED = {"devices", "emulator-slots", "scratch", "sizes"}
local MARKER = ".private-cache"

local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

local function absolute(folder)
    return path.normalize(path.absolute(folder))
end

local function resolved(folder)
    return os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
end

local function roots_of(source)
    local roots = {absolute(source)}
    local real = resolved(source)
    if real ~= roots[1] then
        table.insert(roots, real)
    end
    return roots
end

local function under(file, root)
    return file == root or file:startswith(root .. "/")
end

local function points_into(target, roots)
    for _, root in ipairs(roots) do
        if under(target, root) then
            return true
        end
    end
    return false
end

local function retarget(target, roots, folder)
    for _, root in ipairs(roots) do
        if under(target, root) then
            return folder .. target:sub(#root + 1)
        end
    end
end

local function replace(text, old, new)
    local parts, position = {}, 1
    while true do
        local first, last = text:find(old, position, true)
        if not first then
            break
        end
        table.insert(parts, text:sub(position, first - 1))
        table.insert(parts, new)
        position = last + 1
    end
    table.insert(parts, text:sub(position))
    return table.concat(parts)
end

local function lines(output)
    local found = {}
    for line in output:gmatch("[^\n]+") do
        table.insert(found, line)
    end
    return found
end

local function links(folder)
    return lines(os.iorunv("find", {folder, "-type", "l"}))
end

local function cmake_caches(folder)
    return lines(os.iorunv("find", {folder, "-type", "f", "(", "-name", "CMakeCache.txt", "-o", "-name", "manifest.txt", "-o", "-name", "references.txt",
                                   "-o", "-name", "*.pc", "-o", "-name", "cmake_install.cmake", ")"}))
end

local function target_of(link)
    return os.iorunv("readlink", {link}):trim()
end

local function is_empty(folder)
    return os.iorunv("ls", {"-A", folder}):trim() == ""
end

local function remove_tree(folder)
    if not (os.exists(folder) or os.islink(folder)) then
        return
    end
    os.vrunv("find", {"-P", folder, "-type", "d", "!", "-perm", "-u+w", "-exec", "chmod", "u+w", "{}", "+"})
    os.vrunv("rm", {"-rf", "--", folder})
end

local function write_text(file, text)
    os.vrunv("chmod", {"u+w", file})
    io.writefile(file, text)
end

function clone(source, folder)
    source = absolute(source)
    folder = absolute(folder)
    if not os.isdir(source) then
        raise("%s is not a folder, so there is no cache to clone", source)
    end
    local roots = roots_of(source)
    for _, root in ipairs(roots) do
        if under(folder, root) then
            raise("%s is inside the cache %s, and the private cache must not be written into it", folder, root)
        end
        if under(root, folder) then
            raise("%s holds the cache %s, so it cannot be the private cache", folder, root)
        end
    end
    if os.isdir(folder) and not is_empty(folder) then
        raise("%s exists and is not empty, so it is not a new private cache", folder)
    end
    os.mkdir(folder)
    if os.iorunv("stat", {"-f", "%d", source}):trim() ~= os.iorunv("stat", {"-f", "%d", folder}):trim() then
        remove_tree(folder)
        raise("%s is on another volume than %s, and only an APFS clone of the cache is small enough", folder, source)
    end
    local failure
    local copied = try {
        function ()
            os.vrunv("cp", {"-c", "-R", "-p", source .. "/.", folder})
            return true
        end,
        catch {
            function (errors)
                failure = errors
            end
        }
    }
    if not copied then
        remove_tree(folder)
        raise("cloning %s failed: %s", source, failure or "cp reported an error")
    end
    for _, name in ipairs(EXCLUDED) do
        remove_tree(path.join(folder, name))
    end

    local rewritten, dangling, stale = 0, 0, 0
    for _, link in ipairs(links(folder)) do
        local old = target_of(link)
        local new = retarget(old, roots, folder)
        if new then
            os.vrunv("ln", {"-sfn", new, link})
            rewritten = rewritten + 1
            if not (os.isfile(new) or os.isdir(new)) then
                if os.isfile(old) or os.isdir(old) then
                    dangling = dangling + 1
                else
                    stale = stale + 1
                end
            end
        end
    end

    local cmake = 0
    for _, file in ipairs(cmake_caches(folder)) do
        local text = io.readfile(file)
        local changed = text
        for _, root in ipairs(roots) do
            changed = replace(changed, root, folder)
        end
        if changed ~= text then
            write_text(file, changed)
            cmake = cmake + 1
        end
    end

    local leftover
    for _, link in ipairs(links(folder)) do
        if points_into(target_of(link), roots) then
            leftover = link
            break
        end
    end
    for _, file in ipairs(cmake_caches(folder)) do
        for _, root in ipairs(roots) do
            if not leftover and io.readfile(file):find(root, 1, true) then
                leftover = file
            end
        end
    end
    if leftover then
        remove_tree(folder)
        raise("%s still names the cache %s after the rewrite, so the clone was removed", leftover, roots[1])
    end

    io.writefile(path.join(folder, MARKER), "source " .. roots[1] .. "\n")
    return {folder = folder, source = roots[1], links = rewritten, dangling = dangling, stale = stale, cmake = cmake}
end

function repair(folder)
    folder = absolute(folder)
    local marker = path.join(folder, MARKER)
    if not os.isfile(marker) then
        raise("%s is not a private cache made by tools/private_cache.lua (it has no %s), so it is kept", folder, MARKER)
    end
    local source = io.readfile(marker):match("^source (.-)\n")
    if not source then
        raise("%s does not name its source cache", marker)
    end
    local roots = roots_of(source)
    local count = 0
    for _, file in ipairs(cmake_caches(folder)) do
        local text = io.readfile(file)
        local changed = text
        for _, root in ipairs(roots) do
            changed = replace(changed, root, folder)
        end
        if changed ~= text then
            write_text(file, changed)
            count = count + 1
        end
    end
    return count
end

function remove(folder)
    folder = absolute(folder)
    local checkout = absolute(cache().checkout())
    if under(checkout, folder) then
        raise("%s holds the checkout %s, so it is not removed", folder, checkout)
    end
    if not os.isfile(path.join(folder, MARKER)) then
        raise("%s is not a private cache made by tools/private_cache.lua (it has no %s), so it is kept", folder, MARKER)
    end
    remove_tree(folder)
    return folder
end

local function test_suite()
    local count = 0
    local function check(condition, message)
        count = count + 1
        assert(condition, "private cache test: " .. message)
    end
    local function refused(action)
        local done = try {
            function ()
                action()
                return true
            end,
            catch {
                function () end
            }
        }
        return not done
    end

    local base = os.iorunv("mktemp", {"-d"}):trim()
    local source = path.join(base, "source")
    local folder = path.join(base, "private")
    local store = path.join(source, "xmake-global", ".xmake", "packages", "a", "alpha", "1.0")
    local install = path.join(store, "install")
    os.mkdir(path.join(install, "lib"))
    io.writefile(path.join(install, "lib", "libx.dylib"), "library")
    os.vrunv("ln", {"-s", install, path.join(store, "dir-link")})
    os.vrunv("ln", {"-s", path.join(install, "lib", "libx.dylib"), path.join(store, "file-link")})
    os.vrunv("ln", {"-s", path.join("install", "lib", "libx.dylib"), path.join(store, "relative-link")})
    os.vrunv("ln", {"-s", "/usr/bin/env", path.join(store, "outside-link")})
    os.vrunv("ln", {"-s", path.join(source, "devices", "held"), path.join(store, "held-link")})
    os.vrunv("ln", {"-s", path.join(source, "gone"), path.join(store, "stale-link")})
    local build = path.join(source, "xmake-global", ".xmake", "cache", "build")
    os.mkdir(build)
    io.writefile(path.join(build, "CMakeCache.txt"), "CMAKE_CACHEFILE_DIR:INTERNAL=" .. build .. "\n")
    io.writefile(path.join(store, "manifest.txt"), "installdir = \"" .. install .. "\"\n")
    os.mkdir(path.join(install, "lib", "pkgconfig"))
    io.writefile(path.join(install, "lib", "pkgconfig", "alpha.pc"), "Libs: -L" .. path.join(install, "lib") .. "\n")
    io.writefile(path.join(source, "note.txt"), "kept " .. source .. "\n")
    local sealed = path.join(store, "sealed")
    os.mkdir(sealed)
    io.writefile(path.join(sealed, "data"), "sealed")
    os.vrunv("chmod", {"555", sealed})
    os.mkdir(path.join(source, "devices"))
    io.writefile(path.join(source, "devices", "held"), "run")

    local result = clone(source, folder)
    check(result.links == 4, "four absolute links into the source are rewritten, got " .. result.links)
    check(result.dangling == 1, "the link into the excluded folder dangles in the clone only, got " .. result.dangling)
    check(result.stale == 1, "the link to a path the source never had is stale, got " .. result.stale)
    check(result.cmake == 3, "CMakeCache.txt, the package manifest and the pkg-config file are rewritten, got " .. result.cmake)

    local cloned_store = path.join(absolute(folder), "xmake-global", ".xmake", "packages", "a", "alpha", "1.0")
    for _, link in ipairs(links(folder)) do
        check(not points_into(target_of(link), roots_of(source)), link .. " still points into the source cache")
    end
    check(target_of(path.join(cloned_store, "dir-link")) == path.join(absolute(folder), "xmake-global", ".xmake", "packages", "a", "alpha", "1.0", "install"),
          "a directory link points into the clone")
    check(io.readfile(path.join(cloned_store, "file-link")) == "library", "a file link reads the clone's library")
    check(target_of(path.join(cloned_store, "relative-link")) == path.join("install", "lib", "libx.dylib"), "a relative link is kept")
    check(target_of(path.join(cloned_store, "outside-link")) == "/usr/bin/env", "a link outside the cache is kept")
    local cloned_cmake = path.join(absolute(folder), "xmake-global", ".xmake", "cache", "build", "CMakeCache.txt")
    check(not io.readfile(cloned_cmake):find(source, 1, true), "CMakeCache.txt names no source path")
    check(io.readfile(cloned_cmake):find(absolute(folder), 1, true) ~= nil, "CMakeCache.txt names the clone")
    check(not io.readfile(path.join(cloned_store, "manifest.txt")):find(source, 1, true), "the package manifest names no source path")
    check(io.readfile(path.join(cloned_store, "manifest.txt")):find(absolute(folder), 1, true) ~= nil, "the package manifest names the clone")
    check(not io.readfile(path.join(cloned_store, "install", "lib", "pkgconfig", "alpha.pc")):find(source, 1, true), "the pkg-config file names no source path")
    check(io.readfile(path.join(absolute(folder), "note.txt")):find(source, 1, true) ~= nil, "a text file that is not a CMake cache is copied unchanged")
    check(not os.isdir(path.join(folder, "devices")), "an excluded folder is left out of the clone")
    check(io.readfile(path.join(cloned_store, "sealed", "data")) == "sealed", "a read-only folder is cloned")

    check(target_of(path.join(store, "dir-link")) == install, "the source's directory link still points into the source")
    check(io.readfile(path.join(build, "CMakeCache.txt")):find(source, 1, true) ~= nil, "the source's CMakeCache.txt is unchanged")
    check(os.isfile(path.join(source, "devices", "held")), "the source keeps its excluded folders")
    check(io.readfile(path.join(install, "lib", "libx.dylib")) == "library", "the source's library is unchanged")

    check(refused(function () clone(source, path.join(source, "inside")) end), "a clone inside the source is refused")
    check(refused(function () clone(source, source) end), "a clone onto the source is refused")
    check(refused(function () clone(source, folder) end), "a clone onto a non-empty folder is refused")
    check(refused(function () clone(path.join(source, "xmake-global"), base) end), "a clone into a folder that holds the source is refused")

    check(refused(function () remove(source) end), "the source is not removed")
    check(refused(function () remove(base) end), "a folder without the marker is not removed")
    os.vrunv("ln", {"-s", install, path.join(folder, "escape-link")})
    io.writefile(path.join(cloned_store, "manifest.txt"), "installdir = \"" .. install .. "\"\n")
    check(repair(folder) == 1, "repair rewrites a manifest that still names the source")
    check(not io.readfile(path.join(cloned_store, "manifest.txt")):find(source, 1, true), "the repaired manifest names no source path")
    remove(folder)
    check(not os.isdir(folder), "the private cache is removed")
    check(os.isfile(path.join(install, "lib", "libx.dylib")), "removing a clone that links into the source leaves the source's library in place")
    check(os.isdir(source), "removing a clone leaves the source in place")

    remove_tree(base)
    print("private cache: %d tests passed", count)
end

function main(...)
    local args = {...}
    local command, folder, source = "clone", nil, nil
    local index = 1
    while index <= #args do
        local arg = args[index]
        if arg == "test" then
            command = "test"
        elseif arg == "--remove" then
            command = "remove"
        elseif arg == "--repair" then
            command = "repair"
        elseif arg == "--from" then
            index = index + 1
            source = args[index]
            if not source then
                raise("--from names the cache to clone, and no folder follows it")
            end
        else
            folder = arg
        end
        index = index + 1
    end

    if command == "test" then
        test_suite()
    elseif command == "repair" then
        if not folder then
            raise("usage: ./xmakew l -P . tools/private_cache.lua --repair <folder>")
        end
        print("repaired %d files of %s", repair(folder), folder)
    elseif command == "remove" then
        if not folder then
            raise("usage: ./xmakew l -P . tools/private_cache.lua --remove <folder>")
        end
        print("removed %s", remove(folder))
    else
        if not folder then
            raise("usage: ./xmakew l -P . tools/private_cache.lua <folder> [--from <cache>]")
        end
        source = source or path.join(cache().checkout(), ".cache")
        local result = clone(source, folder)
        print("cloned   %s", result.source)
        print("folder   %s", result.folder)
        print("links    %d rewritten: %d dangling only in the clone (into folders it leaves out), %d already dangling in the source", result.links, result.dangling, result.stale)
        print("cmake    %d CMakeCache.txt rewritten", result.cmake)
        print("")
        print("REVENANT_CACHE=%s", result.folder)
    end
end
