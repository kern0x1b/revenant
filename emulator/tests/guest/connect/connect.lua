local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "toolchain", "tests", "common"), anonymous = true})
local here = path.absolute(os.scriptdir())
local root = path.absolute(path.join(here, "..", "..", "..", ".."))
local PROBES = {
    connect_writable = {program = "emulatorconnect", source = "connect_writable.c", prefix = "connect_writable ", network = "loopback"},
    connect_kevent64 = {program = "emulatorconnect64", source = "connect_kevent64.c", prefix = "connect_kevent64 ", network = "loopback"},
    connect_external = {program = "emulatorconnectext", source = "connect_external.c", prefix = "connect_external ", network = "host"},
    connect_backport = {program = "emulatorconnectbackport", source = "main.swift", prefix = "connect_backport ", network = "host", here = true},
}

function main(device, release, probe)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    probe = probe or "connect_writable"
    local chosen = assert(PROBES[probe], "no probe named " .. probe)
    local out = runs.folder("emulator-" .. probe)
    os.tryrm(out)
    os.mkdir(out)
    for _, name in ipairs({"xmake.lua", "control", "control64", "controlext", "controlbackport"}) do
        os.cp(path.join(here, name), path.join(out, name))
    end
    for _, entry in pairs(PROBES) do
        os.cp(path.join(here, entry.here and "" or "..", entry.source), path.join(out, entry.source))
    end
    for _, name in ipairs({"toolchain", "packages", "frameworks", "emulator", "recompiler", "addons", "tools"}) do
        os.ln(path.join(root, name), path.join(out, name))
    end

    os.setenv("REVENANT_ROOT", root)
    local function xmake(args, log, opt)
        return os.execv(os.programfile(), args, table.join({curdir = out, stdout = log, stderr = log}, opt or {}))
    end
    xmake({"f", "-c", "-p", "iphoneos", "-a", "armv7", "-y"}, path.join(out, "configure.log"))
    xmake({"build", "-y", chosen.program}, path.join(out, "build.log"))
    xmake({"emulate", "-d", device, "-r", release, "install"}, path.join(out, "install.log"))

    local run = path.join(out, "run.log")
    local ran = xmake({"emulate", "-d", device, "-r", release, "-n", chosen.network, "-s", "240", "-t", "1500", "run", path.join("/usr/libexec", chosen.program)},
                      run, {try = true})
    local lines = {}
    for _, line in ipairs(runs.lines(run)) do
        if line:startswith(chosen.prefix) then
            table.insert(lines, line)
            print(line)
        end
    end
    assert(#lines > 0, "the emulated " .. probe .. " probe printed nothing, see " .. run)
    assert(ran == 0, "the emulated " .. probe .. " probe exited " .. ran .. ", see " .. run)
end
