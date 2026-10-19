local steps = import("steps", {rootdir = path.directory(os.scriptdir()), anonymous = true})

local HERE = os.scriptdir()
local DEVICE = {"emulate", "-d", "iPhone4,1", "-r", "6.1.3"}

function verdict(launch, out)
    local measured = steps.text(steps.matching(launch, {"^info ", "^measure done"}))
    local lines_file = path.join(out, "measure.lines")
    io.writefile(lines_file, measured)
    if steps.count(measured, "^measure done") == 0 then
        raise("FAIL: no 'measure done' line; see %s", path.join(out, "launch.log"))
    end
    local count = steps.count(measured, "^info ")
    print("ok  %d measurement lines (%s)", count, lines_file)
    return {measurements = count, lines = lines_file}
end

function run(opt)
    opt = opt or {}
    local out = opt.out or steps.env("RELEASEMEASURE_RUN")
                or steps.workspace().run("v-impl-avf-1", "releasemeasure-" .. steps.stamp())
    steps.copy(path.join(HERE, "app"), {"xmake.lua", "Info.plist", "control", "main.m"}, out)
    local envs = {CHARPHOTOBRACKET_ROOT = steps.charon(), CHARPHOTOBRACKET_MINIMUM = "6.1.3"}
    steps.required({what = "the measurement", verb = "configure", curdir = out, envs = envs,
                    argv = {"f", "-p", "iphoneos", "-a", "armv7", "-y"}, log = path.join(out, "configure.log")})
    steps.required({what = "the measurement", verb = "install", curdir = out, envs = envs,
                    argv = table.join(DEVICE, {"install"}), log = path.join(out, "install.log")})
    local run_status = steps.spawn({curdir = out, envs = envs, log = path.join(out, "launch.log"),
                                    argv = table.join(DEVICE, {"run", "/Applications/charonreleasemeasure.app/charonreleasemeasure"})})
    steps.spawn({curdir = out, envs = envs, argv = table.join(DEVICE, {"log"}), log = path.join(out, "emulate.log")})
    print("run folder: %s (run status %d)", out, run_status)
    local result = verdict(steps.read(path.join(out, "launch.log")), out)
    result.folder = out
    result.run_status = run_status
    return result
end

function main()
    steps.guard(run)
end
