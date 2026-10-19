local revenant = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local workspace = import("workspace", {rootdir = path.join(revenant, "modules"), anonymous = true})

function run(opt)
    opt = opt or {}
    local build = opt.build or workspace.fresh("revenant-callgen")
    os.mkdir(build)
    local coding = path.join(revenant, "packages", "c", "revenant-coding", "files")
    local log = path.join(build, "build.log")
    local sdk = os.iorunv("xcrun", {"--show-sdk-path"}):trim()
    local status = os.execv("xcrun", {"clang", "-target", "arm64-apple-macos26.0", "-isysroot", sdk, "-fobjc-arc", "-O0", "-Wall",
                                      "-I" .. path.join(revenant, "packages", "a", "apple-backports", "Intents"), "-I" .. coding,
                                      path.join(os.scriptdir(), "ownership-test.m"), path.join(coding, "RevenantCoding.m"),
                                      "-framework", "Foundation", "-framework", "CoreLocation", "-o", path.join(build, "ownership")},
                            {stderr = log, try = true})
    if status ~= 0 then
        io.stderr:write(string.format("the ownership test did not build; %s says why\n", log))
        local lines = io.readfile(log):split("\n")
        io.stderr:write(table.concat(lines, "\n", math.max(1, #lines - 19)) .. "\n")
        return 1
    end
    return os.execv(path.join(build, "ownership"), {}, {try = true})
end

function main()
    local build = os.getenv("BUILD")
    local status = run({build = build ~= "" and build or nil})
    if status ~= 0 then
        os.exit(status == -1 and 1 or status)
    end
end
