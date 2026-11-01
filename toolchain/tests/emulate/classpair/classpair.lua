local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local PROGRAM = "emulateclasspair"
local EXPECTED = {"makeCast", "makeNoCast", "makeBitCast", "makeRegisteredCast", "makeLikeExpo"}

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = path.absolute(os.scriptdir())
    local out = runs.folder("emulate-classpair")
    os.tryrm(out)
    os.mkdir(out)
    os.setenv("REVENANT_EMULATOR_ROOT", path.join(out, "emulator"))
    os.setenv("REVENANT_REPO", path.absolute(path.join(here, "..", "..", "..", "..")))
    for _, name in ipairs({"xmake.lua", "control", "main.swift"}) do
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
    local seen = {}
    local failures = {}
    local finished = false
    for _, line in ipairs(runs.lines(run)) do
        if line:startswith("classpair:") then
            print(line)
            local label, verdict = line:match("^classpair: (%S+) (%S+)")
            if label == "done" then
                finished = true
            elseif verdict == "OK" then
                seen[label] = true
            else
                table.insert(failures, line)
            end
        end
    end
    for _, label in ipairs(EXPECTED) do
        if not seen[label] then
            table.insert(failures, "classpair: " .. label .. " did not print OK, see " .. run)
        end
    end
    if not finished then
        table.insert(failures, "classpair: the program did not reach its last line, see " .. run)
    end
    if ran ~= 0 then
        table.insert(failures, "the run itself exited " .. ran)
    end
    for _, line in ipairs(failures) do
        print(line)
    end
    os.exit(#failures == 0 and 0 or 1)
end
