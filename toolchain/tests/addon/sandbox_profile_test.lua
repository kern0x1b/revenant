local root = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local light = import("light_suites", {rootdir = path.join(root, "toolchain", "tests"), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(root, "toolchain", "modules"), anonymous = true})

function failures(opt)
    local found = {}
    local folder = workspace.fresh("sandbox-profile")
    local profile = path.join(folder, "cache-test.sb")
    light.profile("cache_test", profile)
    local text = io.readfile(profile)
    if not text:find("(deny file-read*", 1, true) then
        table.insert(found, "the profile has no deny rule for the checkout")
    end
    if os.getenv("REVENANT_SUITE_SANDBOX") == "1" then
        os.rm(folder)
        return found
    end
    local denied = os.execv("/usr/bin/sandbox-exec", {"-f", profile, "/bin/cat", path.join(root, "README.md")},
                            {try = true, stdout = path.join(folder, "denied.log"), stderr = path.join(folder, "denied.log")})
    local allowed = os.execv("/usr/bin/sandbox-exec", {"-f", profile, "/bin/cat", path.join(root, "xmake.lua")},
                             {try = true, stdout = path.join(folder, "allowed.log"), stderr = path.join(folder, "allowed.log")})
    if denied == 0 then
        table.insert(found, "a child process read a file the declaration does not list")
    end
    if allowed ~= 0 then
        table.insert(found, "a child process could not read a declared file")
    end
    os.rm(folder)
    return found
end
