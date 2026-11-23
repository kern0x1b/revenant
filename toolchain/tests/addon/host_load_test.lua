import("fixtures")

local LISTING = [[
import("core.project.config")
import("core.project.project")

function main()
    config.load()
    local names = {}
    for name, _ in pairs(project.targets()) do
        table.insert(names, name)
    end
    table.sort(names)
    print("TARGETS " .. #names)
end
]]

local FOREIGN = [[
{
    __toolchains_iphoneos_armv7 = {
        "xcode"
    },
    apple_minimum = "6.0",
    apple_sdk = "",
    arch = "armv7",
    builddir = "build",
    ccache = true,
    component = "Combine",
    host = "macosx",
    kind = "static",
    mode = "release",
    ndk_stdcxx = true,
    plat = "iphoneos",
    tests = "host",
    xcode = "/Applications/Xcode.app"
}
]]

local function load(root, folder, curdir, envs)
    local listing = path.join(folder, "listing.lua")
    local log = path.join(folder, "load.log")
    io.writefile(listing, LISTING)
    local status = os.execv(os.programfile(), {"l", "-P", root, listing},
        {try = true, stdout = log, stderr = log, curdir = curdir, envs = envs})
    local text = io.readfile(log) or ""
    if status ~= 0 then
        return "the project must load all of its targets on a host with no iPhoneOS SDK, but xmake l exited with " .. tostring(status) .. ": " .. text
    elseif not text:find("TARGETS %d+") then
        return "the listing printed no target count, so the project did not load its targets: " .. text
    end
end

function failures(opt)
    local found = {}
    local repository = path.absolute(path.join(os.scriptdir(), "../../.."))
    local root = fixtures.scratch()

    local own = path.join(root, "own")
    os.mkdir(own)
    local problem = load(repository, own, own, {XMAKE_CONFIGDIR = path.join(own, "config")})
    if problem then
        table.insert(found, problem)
    end

    local foreign = path.join(root, "foreign")
    os.mkdir(foreign)
    local copy = path.join(foreign, "checkout")
    local copied = os.execv("rsync", {"-a", "--exclude", ".git", "--exclude", ".cache", "--exclude", "build", "--exclude", ".claude",
        "--exclude", ".xmake", repository .. "/", copy .. "/"},
        {try = true, stdout = path.join(foreign, "copy.log"), stderr = path.join(foreign, "copy.log")})
    if copied ~= 0 then
        table.insert(found, "the checkout with a foreign configuration could not be copied: " .. (io.readfile(path.join(foreign, "copy.log")) or ""))
        os.tryrm(root)
        return found
    end
    local configdir = path.join(copy, ".xmake", "macosx", "arm64")
    os.mkdir(configdir)
    io.writefile(path.join(configdir, "xmake.conf"), FOREIGN)

    local isolated = path.join(foreign, "isolated")
    os.mkdir(isolated)
    problem = load(copy, isolated, copy, {XMAKE_CONFIGDIR = path.join(isolated, "config")})
    if problem then
        table.insert(found, "with a foreign iPhoneOS configuration in the checkout being loaded: " .. problem)
    end

    local shared = path.join(foreign, "shared")
    os.mkdir(shared)
    if not load(copy, shared, copy, nil) then
        table.insert(found, "a foreign iPhoneOS configuration in the checkout being loaded must break the load when that checkout's own configuration is used, or the check of the isolated load proves nothing")
    end

    os.tryrm(root)
    return found
end
