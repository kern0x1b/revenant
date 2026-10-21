local here = path.directory(path.absolute(os.scriptdir()))
local toolchain = path.directory(path.directory(path.directory(here)))
local revenant = path.directory(toolchain)

import("workspace", {rootdir = path.join(toolchain, "modules")})

local function lines_of(file)
    local lines = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    return lines
end

local function head(file, count)
    local lines = lines_of(file)
    for i = 1, math.min(count, #lines) do
        print(lines[i])
    end
end

local function tail(file, count)
    local lines = lines_of(file)
    for i = math.max(1, #lines - count + 1), #lines do
        print(lines[i])
    end
end

local function xmake(project, argv, log)
    return os.execv(os.programfile(), argv, {curdir = project, stdin = os.nuldev(), stdout = log, stderr = log, try = true,
                                             envs = {SWIFTUI_ROOT = revenant}})
end

local function consume(build)
    local project = path.join(build, "project")
    if not os.isdir(path.join(project, ".xmake")) then
        os.tryrm(project)
        os.cp(here, project)
        print("consumer: configured a project in " .. project)
    else
        print("consumer: resuming the configured project in " .. project)
    end
    local kept = path.join(build, "stopped-run-locks")
    for _, lock in ipairs(table.join({path.join(project, "xmake-addons.lock")}, os.files(path.join(project, ".xmake", "*", "*", "project.lock")))) do
        if os.isfile(lock) then
            os.mkdir(kept)
            local moved = path.join(kept, os.date("%Y%m%d-%H%M%S") .. "-" .. path.filename(lock))
            os.mv(lock, moved)
            print("consumer: the lock of a stopped run is kept aside, not waited on: " .. moved)
        end
    end

    local configure = path.join(build, "configure.log")
    if xmake(project, {"f", "-y", "-c"}, configure) ~= 0 then
        tail(configure, 40)
        raise("consumer: xmake could not configure the project, see " .. configure)
    end
    local compile = path.join(build, "build.log")
    if xmake(project, {"-y"}, compile) ~= 0 then
        tail(compile, 40)
        raise("consumer: xmake could not build the project, see " .. compile)
    end

    local binary = os.files(path.join(project, "build", "**", "consumer"))[1]
    if not binary then
        print("consumer: the build produced no binary")
        tail(compile, 40)
        raise("consumer: the build produced no binary")
    end

    local store = os.getenv("XMAKE_GLOBALDIR") or path.join(os.getenv("HOME"), ".xmake")
    local library = os.files(path.join(store, "packages", "*", "swiftui", "**", "libRevenantSwiftUI.a"))[1]
    if not library then
        raise("consumer: revenant@swiftui installed no libRevenantSwiftUI.a under " .. store)
    end
    local module = path.join(path.directory(path.directory(library)), "lib", "swift", "iphoneos", "SwiftUI.swiftmodule")
    if not os.isfile(path.join(module, "armv7-apple-ios.swiftmodule")) then
        raise("consumer: no armv7 module in " .. module)
    end
    local interface = path.join(module, "SwiftUI.swiftinterface")
    if not os.isfile(interface) then
        raise("consumer: no interface in " .. module)
    end

    if not os.iorunv("nm", {"-gU", binary}):find("$s7SwiftUI", 1, true) then
        raise("consumer: the binary carries nothing of the SwiftUI module")
    end
    if not io.readfile(interface):find("public struct VStack", 1, true) then
        raise("consumer: the interface names no VStack")
    end

    print("consumer: the resolution said")
    head(configure, 20)
    print("consumer: built against the module, linked the library, read the interface")
    print("  library:  " .. library)
    print("  module:   " .. module)
    print("  binary:   " .. binary)
end

function main()
    local build = os.getenv("SWIFTUI_BUILD") or workspace.run("swiftui-consumer")
    os.mkdir(build)
    local lock = path.join(build, "run.lock")
    if os.isdir(lock) then
        raise("consumer: another run of this test is in %s (its lock is %s, from %s)", build, lock,
              os.date("%c", os.mtime(lock)))
    end
    os.mkdir(lock)
    print("consumer: one run at a time, this one holds " .. lock)
    local failure
    try {
        function ()
            consume(build)
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    os.tryrm(lock)
    if failure then
        raise(failure)
    end
end
