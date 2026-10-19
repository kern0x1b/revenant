local steps = import("steps", {rootdir = path.directory(os.scriptdir()), anonymous = true})

local HERE = os.scriptdir()
local NEEDED = {
    "bare browse: did not search",
    "present: YES",
    "delegate: did dismiss",
    "completion 1: userDidSelect NO, error Error Domain=NSNetServicesErrorDomain Code=-72004",
    "finished: 1 completion(s)"
}
local FORBIDDEN = {"deadline:"}

function verdict(launch, log, minimum)
    local failed = false
    for _, line in ipairs(NEEDED) do
        if not string.find(launch, line, 1, true) then
            io.stderr:write("MISSING in this run's output: ", line, "\n")
            failed = true
        end
    end
    for _, line in ipairs(FORBIDDEN) do
        if string.find(launch, line, 1, true) then
            io.stderr:write("UNEXPECTED in this run's output: ", line, "\n")
            failed = true
        end
    end
    if failed then
        raise("the picker did not behave as the run expects; see %s", log)
    end
    print("uikitprinter-app %s: presented, dismissed with userDidSelect NO on the guest's browse failure (bare browse fails too)",
          minimum)
end

function run(opt)
    opt = opt or {}
    local minimum = opt.minimum or "6.1.3"
    local out = opt.out or steps.env("UIKITPRINTER_APP_BUILD")
                or steps.workspace().run("uikitprinter-app", minimum .. "-" .. steps.stamp())
    steps.copy(path.join(HERE, "app"), {"xmake.lua", "control", "Info.plist"}, out)
    local envs = {CHARUIKITPRINTER_ROOT = steps.revenant(), CHARUIKITPRINTER_MINIMUM = minimum}
    local device = {"emulate", "-d", "iPhone4,1", "-r", minimum}
    steps.required({what = "the application", verb = "configure", curdir = out, envs = envs,
                    argv = {"f", "-p", "iphoneos", "-a", "armv7", "-y"}, log = path.join(out, "configure.log")})
    steps.required({what = "the application", verb = "install", curdir = out, envs = envs,
                    argv = table.join(device, {"install"}), log = path.join(out, "install.log")})
    local log = path.join(out, "launch.log")
    local launch_status = steps.spawn({curdir = out, envs = envs, log = log,
                                       argv = table.join(device, {"-s", "120", "launch",
                                                         "local.revenant.backports.uikitprinterapp", "until-exit"})})
    steps.spawn({curdir = out, envs = envs, argv = table.join(device, {"log"}), log = path.join(out, "emulate.log")})
    local launch = steps.read(log)
    io.write(launch)
    print("run folder: %s (launch status %d)", out, launch_status)
    verdict(launch, log, minimum)
    return {folder = out, launch_status = launch_status}
end

function main(...)
    steps.guard(function (...)
        local given = steps.options({...}, {["--minimum"] = "value"})
        run({minimum = given.minimum})
    end, ...)
end
