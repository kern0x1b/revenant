local steps = import("steps", {rootdir = path.directory(os.scriptdir()), anonymous = true})

local HERE = os.scriptdir()
local DEVICE = {"-d", "iPhone4,1", "-r", "6.1.3"}
local HELD = {" reason = ", "^data%-b ", "^rows: "}

function compare(host_table, launch, out)
    local probe = steps.text(steps.range(launch, "^class superclass = ", "^rows: "))
    io.writefile(path.join(out, "probe.table"), probe)
    local want
    for _, line in ipairs(steps.lines(probe)) do
        want = line:match("^rows: (%d+)$") or want
    end
    local have = steps.count(probe, " = ")
    if not want or have ~= tonumber(want) then
        raise("FAIL: the 6.1.3 table holds %d rows but the probe reported %s; see %s", have, want or "no count",
              path.join(out, "launch.log"))
    end
    local host = steps.text(steps.except(host_table, HELD))
    local device = steps.text(steps.except(probe, HELD))
    io.writefile(path.join(out, "host.cmp"), host)
    io.writefile(path.join(out, "device.cmp"), device)
    local held = steps.count(host_table, " reason = ") + steps.count(host_table, "^data%-b ")
    local compared = steps.count(host, " = ")
    print("6.1.3 %s rows; host %d rows; compared %d, held out %d (reason text and data-b, from the host's table)", want,
          steps.count(host_table, " = "), compared, held)
    local diff = steps.unified(host, device, path.join(out, "host.cmp"), path.join(out, "device.cmp"))
    io.writefile(path.join(out, "diff.log"), diff)
    local differs = steps.count(diff, "^[%-+][^%-+]")
    if differs == 0 then
        print("ok  every compared row: the 6.1.3 table answers what the host answers")
    else
        print("measured: %d line(s) of the compared rows differ from the host's; the 6.1.3 values are in %s", differs,
              path.join(out, "diff.log"))
    end
    return {rows = tonumber(want), compared = compared, held = held, differs = differs, diff = path.join(out, "diff.log")}
end

function run(opt)
    opt = opt or {}
    local workspace = steps.workspace()
    local host = opt.host or steps.env("AVMOVIE5_HOST") or path.join(workspace.run(), "v-avmovie5", "host-rel2")
    local host_table = path.join(host, "build", "host.table")
    if not os.isfile(host_table) then
        raise("the host table is missing (%s): run tests/backports/host/avf-movie4/run.sh first", host_table)
    end
    local out = opt.out or steps.env("AVMOVIE5_APP") or workspace.run("v-avmovie5", "emu-" .. steps.stamp())
    steps.copy(path.join(host, "movies"), {"movie-a.mov", "movie-b.mov", "movie-c.mov"}, path.join(out, "movies"))
    steps.copy(path.join(HERE, "app"), {"xmake.lua", "Info.plist", "control"}, out)
    local envs = {CHARAVMOVIE_ROOT = steps.charon(), CHARAVMOVIE_MINIMUM = "6.1.3"}
    steps.required({what = "the application", verb = "configure", curdir = out, envs = envs,
                    argv = {"f", "-p", "iphoneos", "-a", "armv7", "-y"}, log = path.join(out, "configure.log")})
    steps.required({what = "the application", verb = "install", curdir = out, envs = envs,
                    argv = table.join({"emulate"}, DEVICE, {"install"}), log = path.join(out, "install.log")})
    local launch_status = steps.spawn({curdir = out, envs = envs, log = path.join(out, "launch.log"),
                                       argv = table.join({"emulate"}, DEVICE, {"-s", "240", "launch",
                                                         "local.charon.backports.avmovieprobe", "until-exit"})})
    steps.spawn({curdir = out, envs = envs, argv = table.join({"emulate"}, DEVICE, {"log"}),
                 log = path.join(out, "emulate.log")})
    print("run folder: %s (launch status %d)", out, launch_status)
    local launch = steps.read(path.join(out, "launch.log"))
    steps.accept_launch(launch_status, launch, "the emulator's report of the budget")
    local result = compare(io.readfile(host_table), launch, out)
    result.folder = out
    result.launch_status = launch_status
    return result
end

function main()
    steps.guard(run)
end
