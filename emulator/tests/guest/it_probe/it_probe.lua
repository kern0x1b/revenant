local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "toolchain", "tests", "common"), anonymous = true})
local here = path.absolute(os.scriptdir())
local root = path.absolute(path.join(here, "..", "..", "..", ".."))
local PROGRAM = "itprobe"

function main(device, release, cores)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local out = runs.folder("emulator-it-probe")
    os.tryrm(out)
    os.mkdir(out)
    for _, name in ipairs({"xmake.lua", "control", "it_probe.c"}) do
        os.cp(path.join(here, name), path.join(out, name))
    end
    for _, name in ipairs({"toolchain", "packages", "frameworks", "emulator", "recompiler", "addons", "tools"}) do
        os.ln(path.join(root, name), path.join(out, name))
    end

    os.setenv("REVENANT_ROOT", root)
    local function xmake(args, log, opt)
        return os.execv(os.programfile(), args, table.join({curdir = out, stdout = log, stderr = log}, opt or {}))
    end
    xmake({"f", "-c", "-p", "iphoneos", "-a", "armv7", "-y"}, path.join(out, "configure.log"))
    xmake({"build", "-y"}, path.join(out, "build.log"))
    xmake({"emulate", "-d", device, "-r", release, "install"}, path.join(out, "install.log"))

    local run = path.join(out, "run.log")
    local argv = {"emulate", "-d", device, "-r", release, "-s", "240", "-t", "1500"}
    if cores then
        table.insert(argv, "--cores=" .. tostring(cores))
    end
    table.join2(argv, {"run", path.join("/usr/libexec", PROGRAM)})
    local ran = xmake(argv, run, {try = true})
    local printed = false
    for _, line in ipairs(runs.lines(run)) do
        if line:startswith("it_probe ") then
            printed = true
            print(line)
        end
    end
    assert(printed, "the emulated IT probe printed nothing, see " .. run)
    assert(ran == 0, "the emulated IT probe exited " .. ran .. ", see " .. run)
end
