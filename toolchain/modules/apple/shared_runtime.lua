import("bundle")
import("signing")
import("dyld")
import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

local ADDON = path.join(os.scriptdir(), "..", "..", "..", "addons", "r", "revenant", "xmake.lua")

function package_name(kind, buildhash)
    return "org.revenant." .. kind .. "-" .. buildhash:sub(1, 8)
end

function package_version(buildhash)
    local released
    for version in io.readfile(ADDON):gmatch('add_versions%("v(%d[%d%.]*)"') do
        if not released or dyld.compare_versions(version, released) > 0 then
            released = version
        end
    end
    return assert(released, "the addon recipe names no Revenant release") .. "+" .. buildhash:sub(1, 8)
end

function folder_of(name)
    return "/usr/lib/revenant/" .. name
end

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

function metadata(folder, name)
    local file = path.join(folder, name .. ".json")
    if not os.isfile(file) then
        raise("there is no %s, and the package %s was staged there", file, name)
    end
    return json.loadfile(file)
end

function deb(described, root, ldid, workdir, outputdir)
    local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
    os.tryrm(workdir)
    local tree = path.join(workdir, "tree")
    os.mkdir(path.directory(path.join(tree, described.folder)))
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
