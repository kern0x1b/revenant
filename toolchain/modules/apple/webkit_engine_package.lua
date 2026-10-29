import("bundle")
import("macho")
import("signing")
local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})
import("shared_runtime", {alias = "staged"})

local NAME = "org.revenant.webkit-engine"
local FOLDER = "/usr/lib/revenant/webkit-engine"
local FRAMEWORKS = {"JavaScriptCore", "WebCore", "WebKitLegacy"}
local FIELDS = {
    "Package: " .. NAME,
    "Name: Revenant WebKit Engine",
    "Architecture: iphoneos-arm",
    "Section: System",
    "Description: the modern WebKit engine of revenant, JavaScriptCore, WebCore and WebKitLegacy with every class renamed Rev, in " .. FOLDER .. "; the WKWebView backport loads it from there when a page is shown, and an application that links the backport depends on this package",
}

local written

function name()
    return NAME
end

function folder()
    return FOLDER
end

-- The prefixed variant's frameworks, as the engine recipe copies them into its deb folder: one
-- directory per framework, holding the binary and its resources.
function frameworks(installdir)
    local found = {}
    for _, framework in ipairs(FRAMEWORKS) do
        local dir = path.join(installdir, framework .. ".framework")
        if not os.isfile(path.join(dir, framework)) then
            raise("the webkit-engine package holds no %s.framework under %s: install its prefixed variant", framework, installdir)
        end
        table.insert(found, {name = framework, dir = dir})
    end
    return found
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
    local shared = {}
    for _, label in ipairs(byteorder.keys(owners)) do
        table.insert(depends, string.format("%s (= %s)", label, owners[label].version))
        table.insert(shared, owners[label])
    end
    return depends, shared
end

-- Copies each framework into the package's folder and names it by that folder: the frameworks
-- find one another there, and the C++ runtime is the shared package's file, named where it is
-- installed. The engine recipe's deb folder is a copy that nothing has changed yet, so this works
-- from it on every run.
function stage(found, root, provided)
    local destination = path.join(root, FOLDER)
    os.mkdir(destination)
    local identities, binaries = {}, {}
    for _, framework in ipairs(found) do
        local copied = path.join(destination, framework.name .. ".framework")
        os.vcp(framework.dir, destination .. "/")
        local binary = path.join(copied, framework.name)
        identities[binary] = FOLDER .. "/" .. framework.name .. ".framework/" .. framework.name
        table.insert(binaries, binary)
    end
    bundle.retarget(binaries, identities, {home = FOLDER .. "/", provided = provided})
    for _, binary in ipairs(binaries) do
        os.vrunv("xcrun", {"strip", "-S", "-x", binary})
    end
    return binaries
end

function write(opt)
    local root = path.join(opt.workdir, "root")
    os.tryrm(opt.workdir)
    local binaries = stage(frameworks(opt.installdir), root, opt.provided)
    local depends, shared = needs(binaries, opt.packages)
    local digests = {}
    for _, binary in ipairs(binaries) do
        table.insert(digests, path.basename(path.directory(binary)) .. "=" .. hash.sha256(binary))
    end
    table.insert(digests, "depends=" .. table.concat(depends, ","))
    local version = staged.package_version(hash.strhash128(table.concat(digests, ";")))
    for _, binary in ipairs(binaries) do
        signing.sign(opt.ldid, binary)
    end
    local control = path.join(opt.workdir, NAME .. ".control")
    io.writefile(control, table.concat(FIELDS, "\n") .. "\n")
    local deb = debian.write({control = control, version = version, root = root, depends = depends, outputdir = opt.outputdir})
    os.tryrm(opt.workdir)
    return {name = NAME, relation = "=", version = version, deb = deb, depends = depends, shared = shared}
end

-- The package is written once per run: the backports package names it as a dependency, and the
-- packaging step carries the written file beside the others.
function ensure(opt)
    if written then
        return written
    end
    written = write(opt)
    return written
end
