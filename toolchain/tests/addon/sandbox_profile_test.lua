local root = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local light = import("light_suites", {rootdir = path.join(root, "toolchain", "tests"), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(root, "toolchain", "modules"), anonymous = true})

function main()
    local folder = workspace.fresh("sandbox-profile")
    local profile = path.join(folder, "cache-test.sb")
    light.profile("cache_test", profile)
    local denied = os.execv("/usr/bin/sandbox-exec", {"-f", profile, "/bin/cat", path.join(root, "README.md")},
                            {try = true, stdout = path.join(folder, "denied.log"), stderr = path.join(folder, "denied.log")})
    local allowed = os.execv("/usr/bin/sandbox-exec", {"-f", profile, "/bin/cat", path.join(root, "xmake.lua")},
                             {try = true, stdout = path.join(folder, "allowed.log"), stderr = path.join(folder, "allowed.log")})
    print(string.format("sandbox profile: undeclared %s, declared %s", denied ~= 0 and "blocked" or "allowed", allowed == 0 and "allowed" or "blocked"))
    os.rm(folder)
    if denied == 0 or allowed ~= 0 then
        raise("sandbox profile did not distinguish the declared and the undeclared file")
    end
end
