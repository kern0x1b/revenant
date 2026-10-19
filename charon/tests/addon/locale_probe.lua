function main(modules, root)
    local store = import("store", {rootdir = modules, anonymous = true})
    local macho = import("apple.macho", {rootdir = modules, anonymous = true})
    local debian = import("debian", {rootdir = modules, anonymous = true})
    local emulator = import("emulator", {rootdir = modules, anonymous = true})
    local backports = import("apple.backports", {rootdir = modules, anonymous = true})
    local vt = import("vt-ladder-names", {rootdir = path.join(modules, "..", "tools"), anonymous = true})
    local byteorder = import("byteorder", {rootdir = modules, anonymous = true})

    os.tryrm(root)
    local function write(file, text)
        os.mkdir(path.directory(file))
        io.writefile(file, text)
    end
    local NAMES = {"UIView", "UIVieX", "UIViewA", "UIViewB", "aBc", "Abc", "abc", "AB", "ab", "Zz", "aa", "UIVieW_x"}

    local lines = {}
    local function emit(case, value)
        table.insert(lines, case .. "\t" .. value)
    end
    local function relative(file)
        return path.relative(file, root)
    end

    for _, digest in ipairs({"Bb", "bB", "aA", "AA", "ab", "Ab"}) do
        write(path.join(root, "store", "packages", "s", "swift", "6.4.0", digest, "manifest.txt"), digest .. "\n")
    end
    for _, install in ipairs(store.installs(path.join(root, "store"), "swift")) do
        emit("store.installs", relative(install))
    end

    for _, name in ipairs(NAMES) do
        write(path.join(root, "macho", name), "\xce\xfa\xed\xfe" .. name)
    end
    for _, file in ipairs(macho.binaries_under(path.join(root, "macho"))) do
        emit("macho.binaries_under", relative(file))
    end

    for _, name in ipairs(NAMES) do
        write(path.join(root, "tree", "usr", name), name)
    end
    for _, member in ipairs(debian.tree_members(path.join(root, "tree"))) do
        emit("debian.tree_members", member.name)
    end

    for _, name in ipairs(NAMES) do
        write(path.join(root, "described", name), "contents of " .. name)
    end
    for _, entry in ipairs(emulator.describe_files(path.join(root, "described"))) do
        emit("emulator.describe_files", entry.path .. " " .. entry.size .. " " .. entry.hash)
    end

    for _, name in ipairs(NAMES) do
        write(path.join(root, "library", "Lib", name .. (#name % 2 == 0 and ".m" or ".c")), "")
    end
    for _, file in ipairs(backports.sources(path.join(root, "library"), {folder = "Lib"})) do
        emit("backports.sources", relative(file))
    end

    local names = path.join(root, "names.txt")
    write(names, table.concat(NAMES, "\n") .. "\n")
    for _, name in ipairs(vt.names_from(names)) do
        emit("vt-ladder-names.names_from", name)
    end

    local sdkstubs = import("apple.sdkstubs", {rootdir = modules, anonymous = true})
    local older = {exports = {{archs = {"armv7", "armv7s"}, lists = {symbols = NAMES, ["weak-symbols"] = {}, ["thread-local-symbols"] = {}}}}}
    local doc = {exports = {{archs = {"arm64"}, lists = {symbols = {"UIVieX"}, ["weak-symbols"] = {}, ["thread-local-symbols"] = {}}}}}
    for _, group in ipairs(sdkstubs.dropped(older, doc)) do
        emit("sdkstubs.dropped", group.list .. " " .. table.concat(group.archs, ",") .. " " .. table.concat(group.tokens, ","))
    end

    local registry = import("registry-one-minimum", {rootdir = path.join(modules, "..", "tools"), anonymous = true})
    local gate = path.join(root, "gate")
    for _, name in ipairs({"UIView", "UIVieX", "aBc"}) do
        write(path.join(gate, "registry", name .. ".json"), '{"entries": [{"api": "UIView"}, {"api": "' .. name .. '"}]}')
    end
    write(path.join(gate, "registry", "Sub", "Ab.json"), '{"entries": [{"api": "UIView"}]}')
    local rows = registry.rows_of(gate, nil)
    local apis = table.keys(rows)
    byteorder.sort(apis)
    for _, api in ipairs(apis) do
        local files = {}
        for _, row in ipairs(rows[api]) do
            table.insert(files, relative(row.registry))
        end
        emit("registry-one-minimum.rows_of", api .. " " .. table.concat(files, ","))
    end

    local sorted = table.clone(NAMES)
    byteorder.sort(sorted)
    for _, name in ipairs(sorted) do
        emit("byteorder.sort", name)
    end

    print(table.concat(lines, "\n"))
    os.tryrm(root)
end
