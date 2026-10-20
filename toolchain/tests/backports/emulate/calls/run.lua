local steps = import("steps", {rootdir = path.directory(os.scriptdir()), anonymous = true})
local gencalls = import("gen-calls", {rootdir = path.join(os.scriptdir(), "..", "..", "callgen"), anonymous = true})

local HERE = os.scriptdir()

function run(opt)
    opt = opt or {}
    local root = steps.revenant()
    local workspace = steps.workspace()
    local minimum = opt.minimum or "6.1.3"
    local package = opt.package ~= false
    local work = opt.work or steps.env("WORK") or workspace.run("revenant-calls")
    local generated = path.join(work, "generated")
    os.mkdir(generated)
    os.mkdir(path.join(work, "runs"))
    local registry = opt.registry or steps.env("REGISTRY")
                     or path.join(root, "packages", "frameworks", "apple-backports", "registry", steps.env("FRAMEWORK") or "Intents")
    local result = gencalls.generate({sdk = workspace.sdk(), registries = {registry}, dump = path.join(work, "ast.json"),
                                      out = path.join(generated, "Calls.m"), manifest = path.join(generated, "calls.json")})
    print("%s: %d classes, %d members called", result.out, result.classes, result.members)
    local out = path.join(work, "runs", string.format("calls-%s-%s", minimum, steps.stamp()))
    os.mkdir(out)
    local envs = {CHARCALLS_ROOT = root, CHARCALLS_MINIMUM = minimum, CHARCALLS_GENERATED = generated,
                  CHARCALLS_PACKAGE = package and "1" or "0"}
    steps.required({what = "the call test port", verb = "configure", curdir = HERE, envs = envs,
                    argv = {"f", "-p", "iphoneos", "-a", "armv7", "-y"}, log = path.join(out, "configure.log")})
    steps.required({what = "the call test", verb = "install", curdir = HERE, envs = envs,
                    argv = {"emulate", "-r", minimum, "install"}, log = path.join(out, "install.log")})
    local digest = path.join(out, "calls.log")
    local runlog = path.join(out, "run.log")
    local status = steps.spawn({curdir = HERE, envs = envs, log = runlog,
                                argv = {"emulate", "-r", minimum, "run", "/usr/libexec/revenantcalls", "port", digest}})
    if status ~= 0 then
        io.stderr:write("the port run has findings; ", digest, " is what it found\n")
    end
    steps.spawn({curdir = HERE, envs = envs, argv = {"emulate", "-r", minimum, "log"}, log = path.join(out, "emulate.log")})
    print("port digest: %s", digest)
    print("port run log: %s", runlog)
    return {folder = out, digest = digest, runlog = runlog, status = status, generated = generated}
end

function main(...)
    steps.guard(function (...)
        local given = steps.options({...}, {["--minimum"] = "value", ["--no-package"] = "flag"})
        run({minimum = given.minimum, package = not given["no-package"]})
    end, ...)
end
