local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "toolchain", "tests", "common"), anonymous = true})
local here = path.absolute(os.scriptdir())
local root = path.absolute(path.join(here, "..", "..", "..", ".."))
local PROGRAM = "emulatorconnectdispatch"

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local out = runs.folder("emulator-connect-dispatch")
    os.tryrm(out)
    os.mkdir(out)
    for _, name in ipairs({"xmake.lua", "control"}) do
        os.cp(path.join(here, name), path.join(out, name))
    end
    os.cp(path.join(here, "..", "connect_writable_dispatch.c"), path.join(out, "connect_writable.c"))
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
    local ran = xmake({"emulate", "-d", device, "-r", release, "-n", "loopback", "-s", "240", "-t", "1500", "run", path.join("/usr/libexec", PROGRAM)},
                      run, {try = true})
    local lines = {}
    for _, line in ipairs(runs.lines(run)) do
        if line:startswith("connect_writable ") then
            table.insert(lines, line)
            print(line)
        end
    end
    assert(#lines > 0, "the emulated libdispatch connect probe printed nothing, see " .. run)
    assert(ran == 0, "the emulated libdispatch connect probe exited " .. ran .. ", see " .. run)
end
