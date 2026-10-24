local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local PROGRAM = "pin-leak"
local DESCRIPTORS = "512"
local GUEST_FOLDER = "/private/var/tmp/revenant-pin-leak"

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = os.scriptdir()
    local repository = path.absolute(path.join(here, "..", "..", "..", ".."))
    local out = runs.folder("emulate-pin-leak")
    os.tryrm(out)
    os.mkdir(out)
    for _, name in ipairs({"pin-leak.c", "control"}) do
        os.cp(path.join(here, name), path.join(out, name))
    end
    io.writefile(path.join(out, "xmake.lua"), table.concat({
        'set_project("emulatepinleak")',
        'set_version("0.0.1")',
        'add_repositories("revenant ' .. repository .. '")',
        'add_addons("revenant", {sourcedir = "' .. path.join(repository, "toolchain") .. '"})',
        'set_config("apple_minimum", "6.1.3")',
        'includes("@addon/revenant/apple-ios")',
        'includes("@addon/revenant/emulate")',
        'set_allowedplats("iphoneos")',
        'set_allowedarchs("iphoneos|armv7")',
        'set_defaultplat("iphoneos")',
        'set_defaultarchs("iphoneos|armv7")',
        '',
        'target("pin-leak")',
        '    add_rules("@addon/revenant/daemon")',
        '    add_files("pin-leak.c")',
        '    set_values("revenant.version", "1.0")',
        '    set_values("revenant.control", "control")',
        ''}, "\n"))

    local function xmake(args, log, opt)
        return os.execv(os.programfile(), args, table.join({curdir = out, stdout = log, stderr = log}, opt or {}))
    end
    xmake({"f", "-c", "-p", "iphoneos", "-a", "armv7", "-y"}, path.join(out, "configure.log"))
    xmake({"build", "-y"}, path.join(out, "build.log"))
    xmake({"emulate", "-d", device, "-r", release, "install"}, path.join(out, "install.log"))

    local run = path.join(out, "run.log")
    local ran = os.execv("/bin/sh", {"-c", 'ulimit -n "$0"; exec "$@"', DESCRIPTORS, os.programfile(), "emulate", "-d", device,
                                     "-r", release, "-s", "300", "-t", "1500", "run", path.join("/usr/libexec", PROGRAM), GUEST_FOLDER},
                         {curdir = out, stdout = run, stderr = run, try = true})
    for _, line in ipairs(runs.lines(run)) do
        if line:startswith("FAIL") then
            print(line)
        end
    end
    print("the run exited " .. ran .. " with the emulate command under a host descriptor limit of " .. DESCRIPTORS .. ", see " .. run)
    os.exit(ran)
end
