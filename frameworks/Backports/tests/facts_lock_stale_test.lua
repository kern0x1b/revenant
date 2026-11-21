local tools = path.join(os.scriptdir(), "..", "tools")
local generate = import("generate", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local exclusive = import("@addon.revenant.exclusive", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function fixture(folder)
    local header = path.join(folder, "System", "Library", "Frameworks", "Fixture.framework", "Headers", "Fixture.h")
    os.mkdir(path.directory(header))
    io.writefile(path.join(folder, "SDKSettings.json"), '{"Version": "99.9"}')
    io.writefile(header, "__attribute__((objc_root_class)) @interface FixtureRoot\n- (void)hello;\n@end\n")
    return folder
end

function main()
    local base = workspace.fresh("facts-lock-stale-test")
    local sdk = fixture(path.join(base, "sdk"))
    local version = sdkfiles.sdk_version(sdk)
    local logs = path.join(base, "logs")
    local root = sdkfiles.shared_root()
    local key = sdkfiles.cache_key(sdk)

    local held = path.join(root, "held-by-live")
    local free = path.join(root, "free-to-go")
    os.mkdir(held)
    os.mkdir(free)
    os.execv("/usr/bin/touch", {"-t", "200101010000", held})
    os.execv("/usr/bin/touch", {"-t", "200101010000", free})

    local heldlock = io.openlock(path.join(root, "held-by-live.lock"))
    assert(heldlock:trylock(), "could not take the stale key's lock")

    generate.ready(sdk, version, logs, {})

    assert(os.isdir(held), "the stale folder of a key a live process holds was deleted")
    assert(not os.isdir(free), "the stale folder of an unheld key was kept")
    assert(exclusive.held(path.join(root, "held-by-live.lock")), "the held key is not reported as held")

    heldlock:unlock()
    heldlock:close()
    os.tryrm(path.join(root, "held-by-live.lock"))
    os.tryrm(path.join(root, "free-to-go.lock"))
    os.tryrm(held)
    os.tryrm(path.join(root, key))
    os.tryrm(path.join(root, key .. ".lock"))
    os.tryrm(base)
    print("FACTS_LOCK_STALE_TEST passed")
end
