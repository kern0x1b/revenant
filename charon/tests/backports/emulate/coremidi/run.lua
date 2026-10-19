local steps = import("steps", {rootdir = path.directory(os.scriptdir()), anonymous = true})

local HERE = os.scriptdir()

function verdict(opt)
    local launch = opt.launch
    if steps.count(launch, "^roundtrip: PASS") == 0 then
        raise("the round trip did not pass: no 'roundtrip: PASS' line in this run's %s", opt.log)
    end
    if opt.probe and steps.count(launch, "^probe 6.1.3: ") == 0 then
        raise("the probe was asked for (CHARCOREMIDI_PROBE) and this run's %s has none of its lines", opt.log)
    end
    steps.accept_launch(opt.status, launch, "the emulator's report of the budget and the exit")
end

function run(opt)
    opt = opt or {}
    local minimum = opt.minimum or "6.1.3"
    local probe = opt.probe
    if probe == nil then
        probe = steps.env("CHARCOREMIDI_PROBE") ~= nil
    end
    local no_background = opt.no_background
    if no_background == nil then
        no_background = steps.env("CHARCOREMIDI_NO_BACKGROUND") ~= nil
    end
    local seconds = opt.seconds or steps.env("CHARCOREMIDI_SECONDS") or "600"
    local out = opt.build or steps.env("COREMIDI_APP_BUILD")
                or steps.workspace().run("coremidi-app", minimum .. "-" .. steps.stamp())
    steps.copy(path.join(HERE, "app"), {"xmake.lua", "control", "Info.plist"}, out)
    if no_background then
        os.vrunv("plutil", {"-remove", "UIBackgroundModes", path.join(out, "Info.plist")})
    end
    local envs = {CHARCOREMIDI_ROOT = steps.charon(), CHARCOREMIDI_MINIMUM = minimum}
    if probe and not steps.env("CHARCOREMIDI_PROBE") then
        envs.CHARCOREMIDI_PROBE = "1"
    end
    local device = {"emulate", "-d", "iPhone4,1", "-r", minimum}
    steps.required({what = "the application", verb = "configure", curdir = out, envs = envs,
                    argv = {"f", "-p", "iphoneos", "-a", "armv7", "-y"}, log = path.join(out, "configure.log")})
    steps.required({what = "the application", verb = "install", curdir = out, envs = envs,
                    argv = table.join(device, {"install"}), log = path.join(out, "install.log")})
    local launch_argv = table.join(device, probe and {"-s", seconds} or {}, {"launch", "local.charon.backports.coremidiapp"},
                                   probe and {"until-exit"} or {})
    local log = path.join(out, "launch.log")
    local launch_status = steps.spawn({curdir = out, envs = envs, argv = launch_argv, log = log})
    local log_status = steps.spawn({curdir = out, envs = envs, argv = table.join(device, {"log"}),
                                    log = path.join(out, "emulate.log")})
    local launch = steps.read(log)
    io.write(launch)
    print("run folder: %s (launch status %d, log status %d)", out, launch_status, log_status)
    verdict({launch = launch, log = log, probe = probe, status = launch_status})
    return {folder = out, launch_status = launch_status, log_status = log_status}
end

function main(...)
    steps.guard(function (...)
        local given = steps.options({...}, {["--minimum"] = "value"})
        run({minimum = given.minimum})
    end, ...)
end
