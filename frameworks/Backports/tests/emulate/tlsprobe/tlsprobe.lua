local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "..", "toolchain", "tests", "common"), anonymous = true})

local PROGRAM = "emulatetlsprobe"
local NO_GCM = {"0x009c", "0x009d", "0xc02b", "0xc02c", "0xc02f", "0xc030"}

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = os.scriptdir()
    local out = runs.folder("emulate-tlsprobe")
    os.tryrm(out)
    os.mkdir(out)
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
    local ran = xmake({"emulate", "-d", device, "-r", release, "-n", "host", "-s", "240", "-t", "1500", "run", path.join("/usr/libexec", PROGRAM)},
                      run, {try = true})
    local probes = {}
    for _, line in ipairs(runs.lines(run)) do
        if line:startswith("probe:") then
            table.insert(probes, line)
        end
    end
    assert(#probes > 0, "the run printed no probe line: the program did not run, see " .. run)
    assert(ran == 0, "the run exited " .. ran .. ", see " .. run)

    local text = table.concat(probes, "\n")
    assert(text:find("probe: version TLS1.2 set 0 max TLS1.2", 1, true), "the firmware does not stop at TLS 1.2")
    for _, cipher in ipairs(NO_GCM) do
        assert(not text:find("probe: cipher " .. cipher .. " ", 1, true), "the firmware offers the AES-GCM suite " .. cipher)
    end
    for _, line in ipairs(probes) do
        print(line)
    end
end
