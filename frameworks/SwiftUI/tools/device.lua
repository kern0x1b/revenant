local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})

local USAGE = [[usage: ./xmakew l frameworks/SwiftUI/tools/device.lua ACTION ..., from a folder whose device.env names the claimed phone
  copy LOCAL REMOTE                 a file to the phone
  fetch REMOTE LOCAL                a file from the phone
  shots [--live | --gesture] SCENARIO...
                                    install the built demo, have it render each scenario (or show it on the screen, or
                                    run its touches) and fetch the pictures
  crash [REPORT]                    symbolicate REPORT, or the demo's latest crash report fetched from the phone]]

local BUNDLE = "space.kern0x1b.swiftui.demo"
local LOG = "/var/tmp/swiftui-demo.log"
local SBLAUNCH = "/private/var/tmp/sblaunch"

local function phone()
    local device = import("@addon.revenant.device", {anonymous = true})
    local settings = device.bind(os.curdir())
    local key = settings.udid ~= "" and settings.udid
    if not key and settings.host ~= "127.0.0.1" then
        key = (settings.host .. "-" .. settings.port):gsub("[^%w%-%.]", "_")
    end
    if not key then
        raise("the phone has no DEVICE_UDID, so whether it is claimed cannot be told: set it in device.env")
    end
    local holder = device.holder_name()
    local lease = device.lease(key)
    if not holder or not lease or lease.holder ~= holder then
        raise("the phone is not claimed by %s: claim it first (workspace skill device-session, xmake device claim) and export REVENANT_DEVICE_HOLDER",
              holder or "anyone (REVENANT_DEVICE_HOLDER is unset)")
    end
    return device, settings
end

local function on_device(device, settings, command)
    return try { function ()
        return device.run(settings, command, {capture = true})
    end }
end

local function wait_for(device, settings, text, tries, pause)
    for _ = 1, tries do
        if on_device(device, settings, "grep -a '" .. text .. "' " .. LOG) then
            return true
        end
        os.sleep(pause)
    end
    return false
end

local function shot(device, settings, file)
    if not on_device(device, settings, "shot") then
        raise("the phone took no screenshot")
    end
    if not device.fetch(settings, "/tmp/screenshot.png", file) then
        raise("the screenshot could not be fetched to %s", file)
    end
end

local function install(device, settings)
    local app = tree.demo()
    if not os.isdir(app) then
        raise("%s does not exist: build it first, ./xmakew build -P . SwiftUIDemo", app)
    end
    local scratch = tree.fresh("device-install")
    local archive = path.join(scratch, "swiftui-demo.tgz")
    os.execv("tar", {"czf", archive, "-C", path.directory(app), path.filename(app)}, {envs = {COPYFILE_DISABLE = "1"}})
    device.copy(settings, archive, "/var/tmp/swiftui-demo.tgz")
    os.tryrm(scratch)
    local name = path.filename(app)
    device.run(settings, "cd /Applications && tar xzf /var/tmp/swiftui-demo.tgz && rm /var/tmp/swiftui-demo.tgz && chmod -R 755 " .. name
               .. " && su mobile -c 'uicache -p /Applications/" .. name .. "'")
end

local function start(device, settings, setup)
    on_device(device, settings, "killall SwiftUIDemo")
    device.run(settings, "sleep 1; rm -rf /var/revenant/show /var/revenant/gesture /var/revenant/snapshots.on /var/revenant/snapshots.png "
               .. "/var/revenant/snapshots.only /var/revenant/swiftui-snapshots " .. LOG .. "; " .. setup
               .. "; " .. SBLAUNCH .. " " .. BUNDLE)
end

local function shots(arguments)
    local mode = "render"
    if arguments[1] == "--live" or arguments[1] == "--gesture" then
        mode = table.remove(arguments, 1):sub(3)
    end
    if #arguments == 0 then
        raise(USAGE)
    end
    local device, settings = phone()
    local out = tree.run("device-shots")
    install(device, settings)
    for _, scenario in ipairs(arguments) do
        if mode == "gesture" then
            start(device, settings, "printf %s " .. scenario .. " > /var/revenant/show; printf %s " .. scenario
                  .. " > /var/revenant/gesture; chmod 666 /var/revenant/show /var/revenant/gesture")
            wait_for(device, settings, "gesture: opened", 60, 1000)
            local open = path.join(out, "gesture-" .. scenario .. "-open.png")
            shot(device, settings, open)
            wait_for(device, settings, "gesture: done", 30, 1000)
            local after = path.join(out, "gesture-" .. scenario .. "-after.png")
            shot(device, settings, after)
            io.write(on_device(device, settings, "grep -a 'gesture\\|swipe\\|backports' " .. LOG) or "")
            on_device(device, settings, "rm -f /var/revenant/show /var/revenant/gesture")
            print("%s (gesture): %s, %s", scenario, open, after)
        elseif mode == "live" then
            start(device, settings, "printf %s " .. scenario .. " > /var/revenant/show; chmod 666 /var/revenant/show")
            os.sleep(8000)
            local file = path.join(out, "live-" .. scenario .. ".png")
            shot(device, settings, file)
            on_device(device, settings, "rm -f /var/revenant/show")
            print("%s (live screen): %s", scenario, file)
        else
            start(device, settings, "touch /var/revenant/snapshots.on /var/revenant/snapshots.png; printf %s " .. scenario
                  .. " > /var/revenant/snapshots.only; chmod 666 /var/revenant/snapshots.*")
            if not wait_for(device, settings, "snapshots done", 40, 3000) then
                print("%s: the app did not finish; ./xmakew l frameworks/SwiftUI/tools/device.lua crash reads its crash report", scenario)
            else
                for _, extension in ipairs({"png", "txt"}) do
                    local file = path.join(out, scenario .. "." .. extension)
                    if not device.fetch(settings, "/var/revenant/swiftui-snapshots/" .. scenario .. "." .. extension, file) then
                        raise("%s.%s was not written on the phone", scenario, extension)
                    end
                end
                print("%s: %s", scenario, path.join(out, scenario .. ".png"))
            end
        end
    end
end

local function crash(arguments)
    local crashes = import("crash", {rootdir = os.scriptdir(), anonymous = true})
    local report = arguments[1]
    if not report then
        local device, settings = phone()
        report = path.join(tree.run("device-crash"), "crash.plist")
        if not device.fetch(settings, "/var/mobile/Library/Logs/CrashReporter/LatestCrash-SwiftUIDemo.plist", report) then
            raise("the phone has no LatestCrash-SwiftUIDemo.plist in /var/mobile/Library/Logs/CrashReporter")
        end
    end
    crashes.symbolicate(report, path.join(tree.demo(), "SwiftUIDemo"))
end

function main(action, ...)
    local arguments = {...}
    if action == "copy" and #arguments == 2 then
        local device, settings = phone()
        device.copy(settings, arguments[1], arguments[2])
    elseif action == "fetch" and #arguments == 2 then
        local device, settings = phone()
        if not device.fetch(settings, arguments[1], arguments[2]) then
            raise("%s could not be fetched", arguments[1])
        end
    elseif action == "shots" then
        shots(arguments)
    elseif action == "crash" then
        crash(arguments)
    else
        raise(USAGE)
    end
end
