import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

function root(given)
    return path.join(given or os.getenv("XMAKE_GLOBALDIR") or os.getenv("HOME"), ".xmake")
end

function canonical()
    return path.join(os.getenv("HOME"), ".xmake")
end

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

function bring(entry)
    os.mkdir(path.directory(entry.to))
    if os.execv("cp", {"-c", "-R", entry.from, entry.to}, {try = true, stdout = os.nuldev(), stderr = os.nuldev()}) ~= 0 then
        os.tryrm(entry.to)
        os.vrunv("cp", {"-R", entry.from, entry.to})
        return "copied"
    end
    return "cloned"
end
