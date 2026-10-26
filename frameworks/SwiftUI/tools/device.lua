local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})
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
local SBLAUNCH = "/usr/libexec/revenant-sblaunch"
local SHOT = "/usr/libexec/revenant-shot"
local UNLOCK = "/usr/libexec/revenant-unlock"
local SLIDE = {"0.374", "0.9375", "0.72", "0.9375"}

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
    if not on_device(device, settings, SHOT .. " /tmp/screenshot.png") then
        raise("the phone took no screenshot")
    end
    if not device.fetch(settings, "/tmp/screenshot.png", file) then
        raise("the screenshot could not be fetched to %s", file)
    end
end

local function provision(device, settings, file, remote)
    if not os.isfile(file) then
        raise("%s was not built: it is a target of the SwiftUIDemo component", file)
    end
    local current = (on_device(device, settings, "sha256sum " .. remote .. " | cut -d' ' -f1") or ""):match("%x+")
    if current ~= hash.sha256(file) then
        local staged = "/var/tmp/" .. path.filename(remote)
        device.copy(settings, file, staged)
        device.run(settings, "mv " .. staged .. " " .. remote)
    end
    device.run(settings, "chmod 755 " .. remote)
end

local function guest_stamp()
    local digests = {}
    local shared = path.join(os.projectdir(), "frameworks", "SwiftUI", "examples", "showcase", "device")
    for _, file in ipairs(table.join(os.files(path.join(os.projectdir(), "emulator", "src", "guest", "*")),
                                     os.files(path.join(shared, "hid.*")))) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    table.insert(digests, "daemon=" .. hash.sha256(path.join(os.projectdir(), "toolchain", "rules", "daemon", "xmake.lua")))
    table.insert(digests, "sdk=" .. import("@addon.revenant.workspace", {anonymous = true}).sdk())
    table.sort(digests)
    return hash.strhash128(table.concat(digests, ";"))
end

local function tools(device, settings)
    local out = path.join(os.projectdir(), "build", "iphoneos", "armv7", "release")
    local stamp = path.join(out, "guest-sources")
    local current = guest_stamp()
    local built = os.isfile(stamp) and io.readfile(stamp) == current
        and os.isfile(path.join(out, "revenant-sblaunch")) and os.isfile(path.join(out, "revenant-shot"))
        and os.isfile(path.join(out, "revenant-unlock"))
    if not built then
        os.vrunv(os.programfile(), {"build", "-P", os.projectdir(), "-y", "revenant-sblaunch", "revenant-shot", "revenant-unlock"})
        io.writefile(stamp, current)
    end
    provision(device, settings, path.join(out, "revenant-sblaunch"), SBLAUNCH)
    provision(device, settings, path.join(out, "revenant-shot"), SHOT)
    provision(device, settings, path.join(out, "revenant-unlock"), UNLOCK)
    device.run(settings, "mkdir -p /var/revenant && chmod 777 /var/revenant")
end

local function install(device, settings)
    local app = tree.demo()
    if not os.isdir(app) then
        raise("%s does not exist: build it first, ./xmakew build -P . SwiftUIDemo", app)
    end
    tools(device, settings)
    local scratch = tree.fresh("device-install")
    local archive = path.join(scratch, "swiftui-demo.tgz")
    os.execv("tar", {"czf", archive, "-C", path.directory(app), path.filename(app)}, {envs = {COPYFILE_DISABLE = "1"}})
    device.copy(settings, archive, "/var/tmp/swiftui-demo.tgz")
    os.tryrm(scratch)
    local name = path.filename(app)
    device.run(settings, "cd /Applications && tar xzf /var/tmp/swiftui-demo.tgz && rm /var/tmp/swiftui-demo.tgz && chmod -R 755 " .. name
               .. " && su mobile -c 'uicache -p /Applications/" .. name .. "'")
end

local function unlock(device, settings)
    local state = (on_device(device, settings, UNLOCK .. " status") or ""):match("%a+")
    if state == "unlocked" then
        return
    end
    if state ~= "locked" then
        raise("the screen is %s: revenant-unlock slides only a lock screen without a passcode", state or "not readable")
    end
    device.run(settings, UNLOCK .. " wake; sleep 1; " .. UNLOCK .. " drag " .. table.concat(SLIDE, " "))
    os.sleep(3000)
    if (on_device(device, settings, UNLOCK .. " status") or ""):match("%a+") ~= "unlocked" then
        raise("the screen is still locked after the slide to unlock")
    end
end

local function start(device, settings, setup)
    unlock(device, settings)
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

local function output_of(program, args)
    return os.iorunv(program, args)
end

local function bisect_right(list, key)
    local lo, hi = 1, #list
    while lo <= hi do
        local mid = (lo + hi) // 2
        if list[mid][1] <= key then
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return lo - 1
end

local function hex_value(s)
    return tonumber(string.gsub(s, "^0x", ""), 16)
end

local function app_base(report)
    local from = 1
    while true do
        local at = string.find(report, "0x", from, true)
        if not at then
            return nil
        end
        local before = at > 1 and string.sub(report, at - 1, at - 1) or ""
        local hex = string.match(report, "^0x[%da-f]+", at)
        if before ~= "" and string.find(before, "%s") and hex then
            local after = at + #hex
            if string.sub(report, after, after + 2) == " - " then
                local line_end = string.find(report, "\n", after, true) or (#report + 1)
                if string.find(string.sub(report, after + 3, line_end - 1), "+SwiftUIDemo", 1, true) then
                    return hex_value(hex)
                end
            end
        end
        from = at + 1
    end
end

local function symbolicate(file, binary)
    if not os.isfile(file) then
        raise("%s: no such report; ./xmakew l frameworks/SwiftUI/tools/device.lua crash fetches the latest from the claimed device", file)
    end
    if not os.isfile(binary) then
        raise("%s: no such binary; build SwiftUIDemo first", binary)
    end
    local report = output_of("plutil", {"-extract", "description", "raw", "-o", "-", file})
    report = string.gsub(report, "\n$", "")

    local exception = string.match(report, "Exception Type:[^\n]*")
    if exception == nil then
        raise("the report has no Exception Type line")
    end
    print(exception)
    local base = app_base(report)
    if base == nil then
        raise("the report has no SwiftUIDemo frame to take the base address from")
    end

    local symbols = {}
    for _, line in ipairs(text.split(output_of("nm", {"-n", binary}), "\n")) do
        local parts = {}
        for word in string.gmatch(line, "%S+") do
            parts[#parts + 1] = word
        end
        if #parts >= 3 then
            local address = tonumber(parts[1], 16)
            if address then
                symbols[#symbols + 1] = {address, parts[3]}
            end
        end
    end

    local frames = {}
    local _, backtrace_start = string.find(report, "Last Exception Backtrace:\n(", 1, true)
    if backtrace_start then
        local close = string.find(report, ")", backtrace_start + 1, true)
        for word in string.gmatch(string.sub(report, backtrace_start + 1, close - 1), "%S+") do
            frames[#frames + 1] = hex_value(word)
        end
    end

    print("exception backtrace, app frames:")
    for i = 1, math.min(#frames, 40) do
        local frame = frames[i]
        if base and frame >= base and frame < base + 0x300000 then
            if #symbols == 0 then
                raise("no symbols in %s; nm printed none", binary)
            end
            local count = bisect_right(symbols, frame - base + 0x4000)
            local index = count > 0 and count or #symbols
            local demangled = text.strip(output_of("xcrun", {"swift-demangle", "--simplified", symbols[index][2]}))
            print("   " .. string.sub(demangled, 1, 140))
        end
    end

    print("crashed thread top:")
    local between = text.split(report, "Thread 0 Crashed:")
    if between[2] == nil then
        raise("the report has no Thread 0 Crashed section")
    end
    local section = text.split(between[2], "Thread 1")[1]
    for _, line in ipairs(text.split(section, "\n")) do
        local number, name = string.match(line, "^(%d+)%s+(%S+)%s+0x[%da-f]+ 0x[%da-f]+ %+ %d+")
        if number and string.find("0123456", number, 1, true) then
            print("   " .. number .. " " .. name)
        end
    end
end

local function crash(arguments)
    local report = arguments[1]
    if not report then
        local device, settings = phone()
        report = path.join(tree.run("device-crash"), "crash.plist")
        if not device.fetch(settings, "/var/mobile/Library/Logs/CrashReporter/LatestCrash-SwiftUIDemo.plist", report) then
            raise("the phone has no LatestCrash-SwiftUIDemo.plist in /var/mobile/Library/Logs/CrashReporter")
        end
    end
    symbolicate(report, path.join(tree.demo(), "SwiftUIDemo"))
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
