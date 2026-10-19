import("bundle")
import("signing")
import("dyld")
import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

local ADDON = path.join(os.scriptdir(), "..", "..", "addons", "c", "charon", "xmake.lua")

-- A runtime that programs share instead of carrying: its libraries live in /usr/lib/charon/<package> under absolute
-- install names, and a package of its own holds them. The package and its folder are named after the build (see charon@swift-runtime),
-- and a program depends on exactly that one: by default the libraries are built without library evolution, so two builds do not
-- answer for each other, and with the library_evolution config, which is a build of its own, the mark still names it.

-- The packages of the shared runtime: the C++ runtime, the Swift libraries, and the ones that pull UIKit in. Each is named
-- after the build it holds, and each names the ones it needs by exact version.
function package_name(kind, buildhash)
    return "org.charon." .. kind .. "-" .. buildhash:sub(1, 8)
end

-- The version of such a package: the Charon release the recipe belongs to, and the build.
function package_version(buildhash)
    local released
    for version in io.readfile(ADDON):gmatch('add_versions%("v(%d[%d%.]*)"') do
        if not released or dyld.compare_versions(version, released) > 0 then
            released = version
        end
    end
    return assert(released, "the addon recipe names no Charon release") .. "+" .. buildhash:sub(1, 8)
end

function folder_of(name)
    return "/usr/lib/charon/" .. name
end

-- The libraries an image names to the loader that nothing of it is bound to, by the file name the image lists them under:
-- ld64 keeps a dylib that is named on its command line (or by an overlay's own autolink entry that something used) whether
-- or not any symbol resolves to it, and the loader then opens it, and the ones it names in turn, for nothing. What the
-- image names is read from `otool -L` (the first line it lists is the image's own install name) and what each undefined
-- symbol is bound to from `nm -m`, which says "(from <library>)" for a two-level namespace; both give a library by its
-- file name up to the first dot, so that is how the two are matched.
function unbound_dependencies(image, architecture)
    local function stem(name)
        return path.filename(name):match("^[^.]+")
    end
    local bound = {}
    for line in os.iorunv("xcrun", {"nm", "-arch", architecture, "-m", image}):gmatch("[^\n]+") do
        local from = line:match("%(undefined%).*%(from ([^)]+)%)")
        if from then
            bound[from] = true
        end
    end
    local unbound, own = {}, true
    for line in os.iorunv("xcrun", {"otool", "-arch", architecture, "-L", image}):gmatch("[^\n]+") do
        local name = line:match("^%s+(%S+) %(compatibility version")
        if name and own then
            own = false
        elseif name and not bound[stem(name)] then
            table.insert(unbound, path.filename(name))
        end
    end
    byteorder.sort(unbound)
    return unbound
end

-- Gives the libraries of one or more packages their absolute names, and leaves each package's tree and what a Debian package
-- of it needs to be written from. The libraries are not signed here: signing needs ldid, a tool of the host whose own
-- dependencies (openssl, libplist) reach every package that depends on a package that has it, and the wrong openssl - the
-- host's - reached the C++ packages that link openssl. The program that depends on these packages signs them when it writes
-- their Debian packages (deb below).
--   opt.packages: each {name, version, title, description, depends, libraries, extra}: the package, the packages it needs as
--     Debian writes them, the libraries it holds, and {source, leaf} for the ones that come from elsewhere (libc++)
--   opt.root: where the packages' trees are built, and stay, since a program links against the libraries in them
--   opt.metadata: the folder that holds a file of what each package is, named after it
--   opt.strip: the strip arguments
function stage(opt)
    os.tryrm(opt.root)
    os.tryrm(opt.metadata)
    os.mkdir(opt.metadata)
    local held = {}
    for _, described in ipairs(opt.packages) do
        local folder = folder_of(described.name)
        local destination = path.join(opt.root, folder)
        os.mkdir(destination)
        local entry = {described = described, folder = folder, destination = destination, identities = {}, binaries = {}, leaves = {}}
        local function place(source, leaf)
            local target = path.join(destination, leaf)
            os.vcp(source, target)
            entry.identities[target] = folder .. "/" .. leaf
            entry.leaves[leaf] = folder .. "/" .. leaf
            table.insert(entry.binaries, target)
        end
        for _, library in ipairs(described.libraries) do
            place(library, path.filename(library))
        end
        for _, library in ipairs(described.extra or {}) do
            place(library.source, library.leaf)
        end
        table.insert(held, entry)
    end
    -- Every reference the libraries make to one another is by absolute name afterwards, into their own package or into
    -- another of these, and retarget refuses a library that still says @rpath.
    for _, entry in ipairs(held) do
        local others = {}
        for _, other in ipairs(held) do
            if other ~= entry then
                for leaf, identity in pairs(other.leaves) do
                    others[leaf] = identity
                end
            end
        end
        bundle.retarget(entry.binaries, entry.identities, {home = entry.folder .. "/", provided = others})
        for _, library in ipairs(entry.binaries) do
            os.vrunv("xcrun", table.join({"strip"}, opt.strip, {library}))
        end
        json.savefile(path.join(opt.metadata, entry.described.name .. ".json"),
                      {name = entry.described.name, version = entry.described.version, title = entry.described.title,
                       description = entry.described.description, depends = entry.described.depends or {}, folder = entry.folder})
    end
end

-- What stage left of a package: {name, version, title, description, depends, folder}.
function metadata(folder, name)
    local file = path.join(folder, name .. ".json")
    if not os.isfile(file) then
        raise("there is no %s, and the package %s was staged there", file, name)
    end
    return json.loadfile(file)
end

-- The Debian package of one staged package: its own folder of the tree, every library in it signed with the program's ldid,
-- and the control file stage described it with. root is the tree stage built; ldid is the program's own.
function deb(described, root, ldid, workdir, outputdir)
    local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
    os.tryrm(workdir)
    local tree = path.join(workdir, "tree")
    os.mkdir(path.directory(path.join(tree, described.folder)))
    -- The package holds its own folder and nothing of the others'.
    os.vcp(path.join(root, described.folder), path.directory(path.join(tree, described.folder)) .. "/")
    for _, library in ipairs(os.files(path.join(tree, described.folder, "*.dylib"))) do
        signing.sign(ldid, library)
    end
    local control = path.join(workdir, described.name .. ".control")
    io.writefile(control, table.concat({
        "Package: " .. described.name,
        "Name: " .. described.title,
        "Architecture: iphoneos-arm",
        "Section: System",
        "Description: " .. described.description .. " in " .. described.folder .. "; the runtime is named after the build that holds it (by default without library evolution) and cannot be replaced by another build"
    }, "\n") .. "\n")
    local written = debian.write({control = control, version = described.version, root = tree, depends = described.depends, outputdir = outputdir})
    os.tryrm(workdir)
    return written
end
