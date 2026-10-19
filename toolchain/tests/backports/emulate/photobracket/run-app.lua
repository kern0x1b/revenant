local steps = import("steps", {rootdir = path.directory(os.scriptdir()), anonymous = true})

local HERE = os.scriptdir()
local DEVICE = {"emulate", "-d", "iPhone4,1", "-r", "6.1.3"}

function verdict(launch, out)
    local probe = steps.text(steps.matching(launch, {"^check ", "^checks: "}))
    local lines_file = path.join(out, "probe.lines")
    io.writefile(lines_file, probe)
    local want, bad
    for _, line in ipairs(steps.lines(probe)) do
        local checks, failed = line:match("^checks: (%d+) failed: (%d+)$")
        if checks then
            want, bad = checks, failed
        end
    end
    local have = steps.count(probe, "^check ")
    local fails = steps.count(probe, "^check .* FAIL")
    if not want or have ~= tonumber(want) then
        raise("FAIL: the probe printed %d check lines but reported %s; see %s", have, want or "no count",
              path.join(out, "launch.log"))
    end
    if tonumber(bad) ~= 0 or fails ~= 0 then
        raise("FAIL: %d of %d checks failed (the failing lines are in %s)\n%s", fails, have, lines_file,
              table.concat(steps.matching(probe, {"FAIL"}), "\n"))
    end
    print("ok  %d of %d checks passed on the 6.1.3 emulator (%s)", have, have, lines_file)
    return {checks = have, lines = lines_file}
end

function run(opt)
    opt = opt or {}
    local out = opt.out or steps.env("PHOTOBRACKET_RUN")
                or steps.workspace().run("v-impl-avf-1", "photobracket-" .. steps.stamp())
    steps.copy(path.join(HERE, "app"), {"xmake.lua", "Info.plist", "control", "main.m"}, out)
    local envs = {CHARPHOTOBRACKET_ROOT = steps.revenant(), CHARPHOTOBRACKET_MINIMUM = "6.1.3"}
    steps.required({what = "the probe", verb = "configure", curdir = out, envs = envs,
                    argv = {"f", "-p", "iphoneos", "-a", "armv7", "-y"}, log = path.join(out, "configure.log")})
    steps.required({what = "the probe", verb = "install", curdir = out, envs = envs,
                    argv = table.join(DEVICE, {"install"}), log = path.join(out, "install.log")})
    local run_status = steps.spawn({curdir = out, envs = envs, log = path.join(out, "launch.log"),
                                    argv = table.join(DEVICE, {"run",
                                                      "/Applications/revenantphotobracketprobe.app/revenantphotobracketprobe"})})
    steps.spawn({curdir = out, envs = envs, argv = table.join(DEVICE, {"log"}), log = path.join(out, "emulate.log")})
    print("run folder: %s (run status %d: the probe's exit status is its failure count)", out, run_status)
    local result = verdict(steps.read(path.join(out, "launch.log")), out)
    result.folder = out
    result.run_status = run_status
    return result
end

function main()
    steps.guard(run)
end
