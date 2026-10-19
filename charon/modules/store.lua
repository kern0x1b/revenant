import("core.base.option")
import("byteorder")

-- A store is where xmake keeps what it installs: the .xmake beside a home, or
-- beside whatever XMAKE_GLOBALDIR names. A session that builds in a store of
-- its own starts empty, and the heavy host packages - the compiler above all -
-- take an hour to build that another store has already spent.
function root(given)
    return path.join(given or os.getenv("XMAKE_GLOBALDIR") or os.getenv("HOME"), ".xmake")
end

-- The store a machine shares: the one beside the home of whoever runs the
-- build, which is where xmake puts what it installs when nothing says
-- otherwise, and so the one that has already built what the others need.
function canonical()
    return path.join(os.getenv("HOME"), ".xmake")
end

-- Every install of a package a store holds: xmake keeps them under
-- packages/<first letter>/<name>/<version>/<digest>, one directory for each
-- set of configs it was built with, and the manifest is what says an install
-- finished rather than an interrupted one leaving its directory behind.
function installs(store, name)
    local found = {}
    for _, folder in ipairs(os.dirs(path.join(store, "packages", name:sub(1, 1):lower(), name, "*", "*"))) do
        if os.isfile(path.join(folder, "manifest.txt")) then
            table.insert(found, folder)
        end
    end
    byteorder.sort(found)
    return found
end

-- What one store can take from another: an install the source holds under a
-- path the target has nothing at. The digest in the path is what xmake looks
-- an install up by, so an install brought over answers for the same configs it
-- answered for where it was built, and one the target already holds is left
-- alone rather than overwritten.
function borrowed(source, target, names)
    local planned = {}
    for _, name in ipairs(names) do
        local held = {}
        for _, folder in ipairs(installs(target, name)) do
            held[path.relative(folder, target)] = true
        end
        for _, folder in ipairs(installs(source, name)) do
            local where = path.relative(folder, source)
            if not held[where] then
                table.insert(planned, {name = name, from = folder, to = path.join(target, where), at = where})
            end
        end
    end
    return planned
end

-- APFS clones a directory without copying its bytes, which is what makes this
-- worth doing at all; a store on a filesystem that cannot clone is copied the
-- ordinary way instead of refused.
function bring(entry)
    os.mkdir(path.directory(entry.to))
    if os.execv("cp", {"-c", "-R", entry.from, entry.to}, {try = true, stdout = os.nuldev(), stderr = os.nuldev()}) ~= 0 then
        os.tryrm(entry.to)
        os.vrunv("cp", {"-R", entry.from, entry.to})
        return "copied"
    end
    return "cloned"
end
