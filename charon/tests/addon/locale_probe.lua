-- One process of locale_order_test: runs the cases the byte order decides and prints one line per output, as
-- "case<TAB>value", so the parent can compare the processes byte for byte. Nothing here reads or sets the locale:
-- the parent gives each process its own environment and this file takes whatever collation that is.
function main(modules, root)
    local store = import("store", {rootdir = modules, anonymous = true})
    local macho = import("apple.macho", {rootdir = modules, anonymous = true})
    local debian = import("debian", {rootdir = modules, anonymous = true})
    local emulator = import("emulator", {rootdir = modules, anonymous = true})
    local backports = import("apple.backports", {rootdir = modules, anonymous = true})
    local vt = import("vt-ladder-names", {rootdir = path.join(modules, "..", "tools"), anonymous = true})
    local byteorder = import("byteorder", {rootdir = modules, anonymous = true})

    -- The fixtures are rebuilt in every process from the same text, so what a case reads is the same in each.
    os.tryrm(root)
    local function write(file, text)
        os.mkdir(path.directory(file))
        io.writefile(file, text)
    end
    -- Names that collate differently under C and under en_NZ or en_US: capitals against lower case, and a
    -- capital that sorts after a lower-case letter in one collation and before it in the other.
    local NAMES = {"UIView", "UIVieX", "UIViewA", "UIViewB", "aBc", "Abc", "abc", "AB", "ab", "Zz", "aa", "UIVieW_x"}

    local lines = {}
    local function emit(case, value)
        table.insert(lines, case .. "\t" .. value)
    end
    local function relative(file)
        return path.relative(file, root)
    end

    -- store: the installs of one package, each a folder with a manifest, under digests that differ in case.
    for _, digest in ipairs({"Bb", "bB", "aA", "AA", "ab", "Ab"}) do
        write(path.join(root, "store", "packages", "s", "swift", "6.4.0", digest, "manifest.txt"), digest .. "\n")
    end
    for _, install in ipairs(store.installs(path.join(root, "store"), "swift")) do
        emit("store.installs", relative(install))
    end

    -- macho: the Mach-O files under a root, found by their magic and listed in order.
    for _, name in ipairs(NAMES) do
        write(path.join(root, "macho", name), "\xce\xfa\xed\xfe" .. name)
    end
    for _, file in ipairs(macho.binaries_under(path.join(root, "macho"))) do
        emit("macho.binaries_under", relative(file))
    end

    -- debian: the members of a package tree, in the order the archive lists them.
    for _, name in ipairs(NAMES) do
        write(path.join(root, "tree", "usr", name), name)
    end
    for _, member in ipairs(debian.tree_members(path.join(root, "tree"))) do
        emit("debian.tree_members", member.name)
    end

    -- emulator: the files of a tree, described in path order.
    for _, name in ipairs(NAMES) do
        write(path.join(root, "described", name), "contents of " .. name)
    end
    for _, entry in ipairs(emulator.describe_files(path.join(root, "described"))) do
        emit("emulator.describe_files", entry.path .. " " .. entry.size .. " " .. entry.hash)
    end

    -- backports: the sources a library's folder compiles, in the order the stubs are written.
    for _, name in ipairs(NAMES) do
        write(path.join(root, "library", "Lib", name .. (#name % 2 == 0 and ".m" or ".c")), "")
    end
    for _, file in ipairs(backports.sources(path.join(root, "library"), {folder = "Lib"})) do
        emit("backports.sources", relative(file))
    end

    -- vt-ladder-names: the constant names a names file lists, in the order the ladder is written.
    local names = path.join(root, "names.txt")
    write(names, table.concat(NAMES, "\n") .. "\n")
    for _, name in ipairs(vt.names_from(names)) do
        emit("vt-ladder-names.names_from", name)
    end

    -- sdkstubs: the symbols a newer SDK drops for the 32-bit slices, grouped and listed in the order byteorder gives them.
    local sdkstubs = import("apple.sdkstubs", {rootdir = modules, anonymous = true})
    local older = {exports = {{archs = {"armv7", "armv7s"}, lists = {symbols = NAMES, ["weak-symbols"] = {}, ["thread-local-symbols"] = {}}}}}
    local doc = {exports = {{archs = {"arm64"}, lists = {symbols = {"UIVieX"}, ["weak-symbols"] = {}, ["thread-local-symbols"] = {}}}}}
    for _, group in ipairs(sdkstubs.dropped(older, doc)) do
        emit("sdkstubs.dropped", group.list .. " " .. table.concat(group.archs, ",") .. " " .. table.concat(group.tokens, ","))
    end

    -- registry-one-minimum: the rows an api has, in the order the registry files are read; an api named by two files
    -- of different case lists them in the byte order of the files.
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

    -- byteorder itself: the order of the names, the same in every locale.
    local sorted = table.clone(NAMES)
    byteorder.sort(sorted)
    for _, name in ipairs(sorted) do
        emit("byteorder.sort", name)
    end

    print(table.concat(lines, "\n"))
    os.tryrm(root)
end
