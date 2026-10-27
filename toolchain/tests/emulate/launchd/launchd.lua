local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local PROGRAM = "emulatelaunchd"

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = path.absolute(os.scriptdir())
    local out = runs.folder("emulate-launchd")
    os.tryrm(out)
    os.mkdir(out)
    os.setenv("REVENANT_EMULATOR_ROOT", path.join(out, "emulator"))
    os.setenv("REVENANT_REPO", path.absolute(path.join(here, "..", "..", "..", "..")))
    for _, name in ipairs({"xmake.lua", "control", "main.c"}) do
        os.cp(path.join(here, name), path.join(out, name))
    end

    local function xmake(args, log, opt)
        return os.execv(os.programfile(), args, table.join({curdir = out, stdout = log, stderr = log}, opt or {}))
    end
    xmake({"f", "-c", "-p", "iphoneos", "-a", "armv7", "-y"}, path.join(out, "configure.log"))
    xmake({"build", "-y"}, path.join(out, "build.log"))
    xmake({"emulate", "-d", device, "-r", release, "install"}, path.join(out, "install.log"))

    local run = path.join(out, "run.log")
    local ran = xmake({"emulate", "-d", device, "-r", release, "-s", "240", "-t", "1500", "run", path.join("/usr/libexec", PROGRAM)},
                      run, {try = true})
    local probes = {}
    for _, line in ipairs(runs.lines(run)) do
        if line:startswith("probe:") then
            table.insert(probes, line)
        end
    end
    for _, line in ipairs(probes) do
        print(line)
    end
    if #probes == 0 then
        print("the run printed no probe line: the program did not run, see " .. run)
    end
    print("the run itself exited " .. ran)
    os.exit(ran)
end
