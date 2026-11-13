local here = path.absolute(os.scriptdir())
local revenant = path.directory(path.directory(path.directory(here)))

local DYLIBS = {["swift-crypto"] = "libswiftCrypto.dylib", cryptokit = "libswiftCryptoKit.dylib",
                uniformtypeidentifiers = "libswiftUniformTypeIdentifiers.dylib"}
local BINDS_RUNTIME = {["swift-crypto"] = true, uniformtypeidentifiers = true}
local SHARED_NAME = "^/usr/lib/revenant/org%.revenant%.swift%-runtime%-%x+/libswift[%w_]+%.dylib$"

local function fail(message)
    raise("shared packages: %s", message)
end

local function siblings()
    local own = {}
    for _, leaf in pairs(DYLIBS) do
        own[leaf] = true
    end
    return own
end

function main(build)
    build = path.absolute(build or path.join(revenant, "build", "shared-packages"))
    local project = path.join(build, "project")
    os.tryrm(project)
    os.mkdir(build)
    os.cp(here, project)
    local probe = path.join(build, "installdirs.txt")
    os.tryrm(probe)
    local log = path.join(build, "configure.log")
    local code = os.execv(os.programfile(), {"f", "-P", project, "-y", "-c"}, {curdir = project, stdin = os.nuldev(), stdout = log, stderr = log, try = true,
                                                                              envs = {SHARED_PACKAGES_ROOT = revenant, SHARED_PACKAGES_PROBE = probe}})
    if code ~= 0 or not os.isfile(probe) then
        fail("xmake could not install the packages with shared = true, see " .. log)
    end
    local installed = {}
    for line in io.readfile(probe):gmatch("[^\n]+") do
        local name, dir = line:match("^([^=]+)=(.+)$")
        installed[name] = dir
    end
    if not os.isfile(path.join(installed.swiftui, "lib", "libSwiftUI.a")) then
        fail("libSwiftUI.a is not installed")
    end
    local others = siblings()
    for name, leaf in pairs(DYLIBS) do
        local library = path.join(installed[name], "lib", leaf)
        if not os.isfile(library) then
            fail(library .. " is not installed")
        end
        local shared, own = 0, true
        for line in os.iorunv("xcrun", {"otool", "-arch", "armv7", "-L", library}):gmatch("[^\n]+") do
            local bound = line:match("^%s+(%S+) %(compatibility version")
            if bound and own then
                own = false
            elseif bound and path.filename(bound):find("^libswift") and not others[path.filename(bound)] then
                if not bound:find(SHARED_NAME) then
                    fail(leaf .. " binds " .. bound .. " instead of a library of the shared runtime package")
                end
                shared = shared + 1
            end
        end
        if BINDS_RUNTIME[name] and shared == 0 then
            fail(leaf .. " binds no library of the shared runtime")
        end
        print("shared packages: %s binds %d libraries of the shared runtime by absolute install name", leaf, shared)
        local descriptions = os.files(path.join(installed[name], "share", "shared-packages", "*.json"))
        if #descriptions ~= 1 then
            fail(name .. " writes " .. #descriptions .. " shared-packages descriptions instead of one")
        end
        local package = path.basename(descriptions[1])
        local identity = "/usr/lib/revenant/" .. package .. "/" .. leaf
        if not package:find("^org%.revenant%." .. name:gsub("%-", "%%-") .. "%-%x+$") then
            fail(name .. " is staged as " .. package)
        end
        for _, file in ipairs({library, path.join(installed[name], "share", "root", identity)}) do
            local id = os.iorunv("xcrun", {"otool", "-arch", "armv7", "-D", file}):match("([^\n]+)\n*$")
            if id ~= identity then
                fail(file .. " has the install name " .. tostring(id) .. " instead of " .. identity)
            end
        end
        local depends = io.readfile(descriptions[1])
        if not depends:find("org%.revenant%." .. (BINDS_RUNTIME[name] and "swift%-runtime" or "swift%-crypto") .. "%-%x+ %(= ") then
            fail(name .. " does not depend on the package it binds")
        end
        print("shared packages: %s is the package %s, installed under its own absolute install name", leaf, package)
    end
end
