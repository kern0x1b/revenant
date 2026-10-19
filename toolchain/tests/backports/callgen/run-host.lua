local revenant = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local workspace = import("workspace", {rootdir = path.join(revenant, "modules"), anonymous = true})
local generator = import("gen-calls", {rootdir = os.scriptdir(), anonymous = true})

local function tail(file, count)
    local lines = (io.readfile(file) or ""):split("\n")
    return table.concat(lines, "\n", math.max(1, #lines - count + 1)) .. "\n"
end

function run(opt)
    opt = opt or {}
    local here = os.scriptdir()
    local registry = opt.registry or path.join(revenant, "packages", "a", "apple-backports", "registry", opt.framework or "Intents")
    local build = opt.build or workspace.fresh("revenant-callgen")
    local out = opt.out or path.join(build, "calls.log")
    os.mkdir(build)
    local sdk = os.iorunv("xcrun", {"--show-sdk-path"}):trim()
    local port_sdk = workspace.sdk()
    if not os.isdir(registry) then
        raise("no such registry: %s", registry)
    end
    print("registry: " .. registry)
    local generated = generator.generate({sdk = port_sdk, registries = {registry}, dump = path.join(build, "ast.json"),
                                          out = path.join(build, "Calls.m"), manifest = path.join(build, "calls.json")})
    print(string.format("%s: %d classes, %d members called", generated.out, generated.classes, generated.members))
    io.flush()
    local log = path.join(build, "build.log")
    local status = os.execv("xcrun", {"clang", "-target", "arm64-apple-macos14.0", "-isysroot", sdk, "-fobjc-arc", "-Wall",
                                      "-Wno-unused-function", "-I" .. here, path.join(here, "harness.m"), path.join(here, "main.m"),
                                      path.join(build, "Calls.m"), "-framework", "Foundation", "-framework", "Intents",
                                      "-o", path.join(build, "calls")}, {stderr = log, try = true})
    if status ~= 0 then
        io.stderr:write(string.format("the call test did not build; %s says why\n", log))
        io.stderr:write(tail(log, 20))
        return {status = 1, build = build}
    end
    local findings = os.execv(path.join(build, "calls"), {"host", out}, {try = true})
    if findings ~= 0 then
        io.stderr:write(string.format("the host run has findings; %s is what it found\n", out))
    end
    print("host digest: " .. out)
    return {status = 0, findings = findings, digest = out, build = build}
end

function main(registry)
    local framework = os.getenv("FRAMEWORK")
    local build = os.getenv("BUILD")
    local out = os.getenv("OUT")
    local result = run({registry = registry, framework = framework ~= "" and framework or nil,
                        build = build ~= "" and build or nil, out = out ~= "" and out or nil})
    if result.status ~= 0 then
        os.exit(result.status)
    end
end
