local here = path.absolute(os.scriptdir())
local revenant = path.directory(path.directory(path.directory(here)))

local function fail(message)
    raise("swift-crypto shared: %s", message)
end

function main(build)
    build = path.absolute(build or path.join(revenant, "build", "swift-crypto-shared"))
    local project = path.join(build, "project")
    os.tryrm(project)
    os.mkdir(build)
    os.cp(here, project)
    local probe = path.join(build, "installdir.txt")
    os.tryrm(probe)
    local log = path.join(build, "configure.log")
    local code = os.execv(os.programfile(), {"f", "-y", "-c"}, {curdir = project, stdin = os.nuldev(), stdout = log, stderr = log, try = true,
                                                               envs = {SWIFT_CRYPTO_ROOT = revenant, SWIFT_CRYPTO_PROBE = probe}})
    if code ~= 0 or not os.isfile(probe) then
        fail("xmake could not install revenant@swift-crypto with shared = true, see " .. log)
    end
    local library = path.join(io.readfile(probe), "lib", "libswiftCrypto.dylib")
    if not os.isfile(library) then
        fail(library .. " is not installed")
    end
    local shared, own = 0, true
    for line in os.iorunv("xcrun", {"otool", "-arch", "armv7", "-L", library}):gmatch("[^\n]+") do
        local name = line:match("^%s+(%S+) %(compatibility version")
        if name and own then
            own = false
        elseif name and path.filename(name):find("^libswift") then
            if not name:find("^/usr/lib/revenant/org%.revenant%.swift%-runtime%-%x+/libswift[%w_]+%.dylib$") then
                fail(path.filename(library) .. " binds " .. name .. " instead of a library of the shared runtime package")
            end
            shared = shared + 1
        end
    end
    if shared == 0 then
        fail(path.filename(library) .. " binds no library of the shared runtime")
    end
    print("swift-crypto shared: %s binds %d libraries of the shared runtime by absolute install name", path.filename(library), shared)
end
