import("core.base.task")
import("bundle")
import("macho")
import("signing")
local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})
import("shared_runtime", {alias = "staged"})

local NAME = "org.revenant.backports"
local FOLDER = "/usr/lib/revenant/" .. NAME
local FIELDS = {
    "Package: " .. NAME,
    "Name: Revenant Backports",
    "Architecture: iphoneos-arm",
    "Section: System",
    "Description: the Backports libraries of revenant, the iOS SDK's public APIs that the device's release lacks, in " .. FOLDER .. "; an application that links one of them depends on this package, and only an application that links a library loads it",
}

local written

function name()
    return NAME
end

function folder()
    return FOLDER
end

local RUNTIME = {"libc++.1.dylib", "libc++abi.1.dylib"}

function carried_runtime(package)
    local found = {}
    for _, leaf in ipairs(RUNTIME) do
        local file
        for _, candidate in ipairs(os.files(path.join(package:installdir(), "lib", "*.dylib"))) do
            if not os.islink(candidate) and path.filename(macho.images(macho.read(candidate))[1].identity or candidate) == leaf then
                file = candidate
            end
        end
        if not file then
            raise("the C++ runtime at %s installs no %s, which the Backports package carries", package:installdir(), leaf)
        end
        table.insert(found, {leaf = leaf, file = file})
    end
    return found
end

function libraries(targets, runtime)
    local found, leaves = {}, {}
    for _, target in ipairs(targets) do
        if not os.isfile(target:targetfile()) then
            raise("%s is not built, so the package holding the Backports libraries cannot take it", target:name())
        end
        local leaf = path.filename(target:targetfile())
        found[leaf] = {leaf = leaf, file = target:targetfile()}
        table.insert(leaves, leaf)
    end
    for _, library in ipairs(runtime or {}) do
        if found[library.leaf] then
            raise("the C++ runtime the package carries names %s, which a Backports library already is", library.leaf)
        end
        found[library.leaf] = library
        table.insert(leaves, library.leaf)
    end
    byteorder.sort(leaves)
    local ordered = {}
    for _, leaf in ipairs(leaves) do
        table.insert(ordered, found[leaf])
    end
    return ordered
end

function release(libs, depends)
    local digests = {}
    for _, library in ipairs(libs) do
        table.insert(digests, library.leaf .. "=" .. hash.sha256(library.file))
    end
    table.insert(digests, "depends=" .. table.concat(depends, ","))
    return staged.package_version(hash.strhash128(table.concat(digests, ";")))
end

function needs(files, packages)
    local depends, owners = {}, {}
    for _, file in ipairs(files) do
        for _, reference in ipairs(macho.images(macho.read(file))[1].libraries) do
            if reference:startswith("@") then
                raise("%s names %s by a relative install name, which no package can resolve", path.filename(file), reference)
            end
            if reference:startswith("/usr/lib/revenant/") and not reference:startswith(FOLDER .. "/") then
                local owner
                for _, package in ipairs(packages) do
                    if package.held[reference] then
                        owner = package
                    end
                end
                if not owner then
                    raise("%s names %s, which no package of the platform holds", path.filename(file), reference)
                end
                owners[owner.name] = owner
            end
        end
    end
    for _, label in ipairs(byteorder.keys(owners)) do
        table.insert(depends, string.format("%s (= %s)", label, owners[label].version))
    end
    return depends
end

function stage(libs, root, provided)
    local destination = path.join(root, FOLDER)
    os.mkdir(destination)
    local identities, binaries = {}, {}
    for _, library in ipairs(libs) do
        local copied = path.join(destination, library.leaf)
        os.vcp(library.file, copied)
        identities[copied] = FOLDER .. "/" .. library.leaf
        table.insert(binaries, copied)
    end
    bundle.retarget(binaries, identities, {home = FOLDER .. "/", provided = provided})
    for _, binary in ipairs(binaries) do
        os.vrunv("xcrun", {"strip", "-x", binary})
    end
    return binaries
end

function write(opt)
    local libs = libraries(opt.targets, opt.runtime)
    local root = path.join(opt.workdir, "root")
    os.tryrm(opt.workdir)
    local binaries = stage(libs, root, opt.provided)
    local depends = needs(binaries, opt.packages)
    local version = release(libs, depends)
    for _, binary in ipairs(binaries) do
        signing.sign(opt.ldid, binary)
    end
    local control = path.join(opt.workdir, NAME .. ".control")
    io.writefile(control, table.concat(FIELDS, "\n") .. "\n")
    local deb = debian.write({control = control, version = version, root = root, depends = depends, outputdir = opt.outputdir})
    local leaves = {}
    for _, library in ipairs(libs) do
        table.insert(leaves, library.leaf)
    end
    os.tryrm(opt.workdir)
    return {name = NAME, relation = "=", version = version, deb = deb, depends = depends, libraries = leaves}
end

function ensure(opt)
    if written then
        return written
    end
    local targets = {}
    for _, target in ipairs(opt.targets) do
        task.run("build", {target = target:name()})
        table.insert(targets, target)
    end
    written = write({targets = targets, ldid = opt.ldid, packages = opt.packages, provided = opt.provided, runtime = opt.runtime,
                     workdir = path.join(opt.builddir, "work"), outputdir = opt.builddir})
    return written
end
