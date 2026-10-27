local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "..", "toolchain", "tests", "common"), anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local root = path.absolute(path.join(os.scriptdir(), "..", "..", "..", "..", ".."))
local PROGRAM = "emulatex509"
local HOSTS = {
    {"www.google.com", "142.251.151.119"},
    {"www.cloudflare.com", "104.16.124.96"},
    {"github.com", "140.82.121.4"},
    {"example.com", "172.66.147.243"},
}

local function bytes_literal(file)
    local bytes = io.readfile(file, {encoding = "binary"})
    local values = {}
    for index = 1, #bytes do
        table.insert(values, tostring(bytes:byte(index)))
    end
    return "[" .. table.concat(values, ",") .. "]"
end

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

    local chains = {}
    local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")
    local pem = path.join(out, "identity.pem")
    os.vrunv("openssl", {"pkcs12", "-in", identity, "-clcerts", "-nokeys", "-passin", "pass:revenant", "-out", pem})
    local identity_der = path.join(out, "identity.der")
    os.vrunv("openssl", {"x509", "-in", pem, "-outform", "der", "-out", identity_der})
    table.insert(chains, "[" .. bytes_literal(identity_der) .. "]")

    for index, host in ipairs(HOSTS) do
        local name, address = host[1], host[2]
        local capture = path.join(out, string.format("chain%d.txt", index))
        os.execv("sh", {"-c", string.format("openssl s_client -connect %s:443 -servername %s -showcerts </dev/null > %s 2>/dev/null", address, name, capture)},
                 {try = true})
        local text = io.readfile(capture)
        local certs = {}
        for block in text:gmatch("%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-.-%-%-%-%-%-END CERTIFICATE%-%-%-%-%-") do
            table.insert(certs, block)
        end
        assert(#certs > 0, "no certificate from " .. name)
        local literals = {}
        for position, block in ipairs(certs) do
            local source = path.join(out, string.format("chain%d-%d.pem", index, position))
            local der = path.join(out, string.format("chain%d-%d.der", index, position))
            io.writefile(source, block .. "\n")
            os.vrunv("openssl", {"x509", "-in", source, "-outform", "der", "-out", der})
            table.insert(literals, bytes_literal(der))
        end
        table.insert(chains, "[" .. table.concat(literals, ",") .. "]")
    end

    io.writefile(path.join(out, "certificate.swift"), string.format("let certificateChains: [[[UInt8]]] = [%s]\n", table.concat(chains, ",")))

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
