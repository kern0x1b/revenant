local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "..", "toolchain", "tests", "common"), anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local root = path.absolute(path.join(os.scriptdir(), "..", "..", "..", "..", ".."))
local PROGRAM = "emulatenetworktls"

local function tls_lines(file)
    local kept = {}
    for _, line in ipairs(runs.lines(file)) do
        if line:startswith("tls ") then
            table.insert(kept, line)
        end
    end
    return kept
end

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = os.scriptdir()
    local out = runs.folder("emulate-networktls")
    os.tryrm(out)
    os.mkdir(out)
    for _, name in ipairs({"xmake.lua", "control", "main.swift"}) do
        os.cp(path.join(here, name), path.join(out, name))
    end
    for _, name in ipairs({"toolchain", "packages", "frameworks", "emulator", "recompiler", "addons", "tools"}) do
        os.ln(path.join(root, name), path.join(out, name))
    end
    local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")
    local bytes = io.readfile(identity, {encoding = "binary"})
    local values = {}
    for index = 1, #bytes do
        table.insert(values, tostring(bytes:byte(index)))
    end
    io.writefile(path.join(out, "identity.swift"), string.format("let identityBytes: [UInt8] = [%s]\n", table.concat(values, ",")))

    os.setenv("REVENANT_ROOT", root)
    local function xmake(args, log, opt)
        return os.execv(os.programfile(), args, table.join({curdir = out, stdout = log, stderr = log}, opt or {}))
    end
    xmake({"f", "-c", "-p", "iphoneos", "-a", "armv7", "-y"}, path.join(out, "configure.log"))
    xmake({"build", "-y"}, path.join(out, "build.log"))
    xmake({"emulate", "-d", device, "-r", release, "install"}, path.join(out, "install.log"))

    local run = path.join(out, "run.log")
    local ran = xmake({"emulate", "-d", device, "-r", release, "-n", "host", "-s", "240", "-t", "1500", "run", path.join("/usr/libexec", PROGRAM)},
                      run, {try = true})
    for _, line in ipairs(runs.lines(run)) do
        if line:startswith("reach ") then
            print(line)
        end
    end

    local host = path.join(out, "host")
    os.vrunv("xcrun", {"swiftc", "-O", path.join(backports, "tests", "Network", "tlsserver", "main.swift"), "-o", host})
    os.execv(host, {identity}, {stdout = host .. ".out"})

    local expected, got = tls_lines(host .. ".out"), tls_lines(run)
    assert(#expected > 0, "the host Network TLS program printed nothing")
    assert(ran == 0, "the emulated run exited " .. ran .. ", see " .. run)
    assert(table.concat(expected, "\n") == table.concat(got, "\n"),
           "the emulated Network TLS differs from the host in " .. out .. ": host " .. #expected .. " lines, guest " .. #got)
end
