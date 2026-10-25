local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local BUNDLE = "org.revenant.emulatefontapp"

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = path.absolute(os.scriptdir())
    local out = runs.folder("emulate-fontapp")
    os.mkdir(out)
    -- The baseline case's emulator root already holds iPhone4,1 10B329's golden image. A root of its own starts that image's
    -- first-boot build, which the load refused and left as a 0-byte build.lock, so this case runs on the baseline's root.
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
    -- -t covers the whole boot. -s is the launcher's wait for SpringBoard's server port, in guest seconds. Under load
    -- 100 SpringBoard checked in 570-800 host seconds after boot; before that the launcher never calls SpringBoard, so
    -- its -1 is its initial value, not a refusal (emulatefontapp-62c8ce43).
    local ran = xmake({"emulate", "-d", device, "-r", release, "-s", "1500", "-t", "3600", "launch", BUNDLE, "until-exit"}, log, {try = true})
    -- `until-exit` makes the command fail on any app exit, status 0 included (toolchain/plugins/emulate/main.lua), so the
    -- log decides, not the command's result.
    print("the launch command returned " .. tostring(ran))
    local text = io.readfile(log)
    for line in text:gmatch("[^\n]+") do
        if line:find("FONT-APP", 1, true) then
            print(line)
        end
    end
    if not text:find("FONT-APP-DONE", 1, true) then
        print("the app did not finish its font call; the log is " .. log)
        os.exit(1)
    end
    print("FONT-APP started and got its system font on " .. device .. " iOS " .. release)
    os.exit(0)
end
