local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local BUNDLE = "org.revenant.emulatefontapp"

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = path.absolute(os.scriptdir())
    local out = runs.folder("emulate-fontapp")
    os.mkdir(out)
    os.setenv("REVENANT_EMULATOR_ROOT", path.join(runs.folder("emulate-baseline"), "emulator"))

    local function xmake(args, log, opt)
        local command = {args[1], "-P", here}
        for index = 2, #args do
            table.insert(command, args[index])
        end
        return os.execv(os.programfile(), command, table.join({curdir = here, stdout = log, stderr = log}, opt or {}))
    end
    xmake({"f", "-p", "iphoneos", "-a", "armv7", "-y"}, path.join(out, "configure.log"))
    xmake({"emulate", "-d", device, "-r", release, "install"}, path.join(out, "install.log"))

    local log = path.join(out, "launch.log")
    local ran = xmake({"emulate", "-d", device, "-r", release, "-s", "1500", "-t", "3600", "launch", BUNDLE, "until-exit"}, log, {try = true})
    local text = io.readfile(log)
    for line in text:gmatch("[^\n]+") do
        if line:find("FONT-APP", 1, true) then
            print(line)
        end
    end
    if ran ~= 0 or not text:find("FONT-APP-DONE", 1, true) then
        print("the app did not finish its font call with status 0 (the launch returned " .. tostring(ran) .. "); the log is " .. log)
        os.exit(1)
    end
    print("FONT-APP started and got its system font on " .. device .. " iOS " .. release)
    os.exit(0)
end
