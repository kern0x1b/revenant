local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "..", "toolchain", "tests", "common"), anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local root = path.absolute(path.join(os.scriptdir(), "..", "..", "..", "..", ".."))
local PROGRAM = "emulatex509"

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = os.scriptdir()
    local out = runs.folder("emulate-x509")
    os.tryrm(out)
    os.mkdir(out)
    for _, name in ipairs({"xmake.lua", "control", "main.swift"}) do
        os.cp(path.join(here, name), path.join(out, name))
    end
    for _, name in ipairs({"toolchain", "packages", "frameworks", "emulator", "recompiler", "addons", "tools"}) do
        os.ln(path.join(root, name), path.join(out, name))
    end

    local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")
    local pem = path.join(out, "cert.pem")
    local der = path.join(out, "cert.der")
    os.vrunv("openssl", {"pkcs12", "-in", identity, "-clcerts", "-nokeys", "-passin", "pass:revenant", "-out", pem})
    os.vrunv("openssl", {"x509", "-in", pem, "-outform", "der", "-out", der})
    local bytes = io.readfile(der, {encoding = "binary"})
    local values = {}
    for index = 1, #bytes do
        table.insert(values, tostring(bytes:byte(index)))
    end
    io.writefile(path.join(out, "certificate.swift"), string.format("let certificateBytes: [UInt8] = [%s]\n", table.concat(values, ",")))

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
        if line:startswith("x509 ") then
            table.insert(lines, line)
            print(line)
        end
    end
    assert(#lines > 0, "the emulated X.509 probe printed nothing, see " .. run)
    assert(ran == 0, "the emulated X.509 probe exited " .. ran .. ", see " .. run)
end
