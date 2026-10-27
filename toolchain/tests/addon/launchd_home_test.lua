import("fixtures")

local FIRMWARE = {"iPhone4,1", "6.1.3_10B329"}
local JOB = "System/Library/LaunchDaemons/org.revenant.home-probe.plist"
local RESULT = "private/var/mobile/Library/Caches/revenant-home-probe"
local LAUNCHD_CONF = "private/etc/launchd.conf"

local function job_plist()
    return table.concat({
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        '<plist version="1.0">',
        "<dict>",
        "<key>Label</key><string>org.revenant.home-probe</string>",
        "<key>UserName</key><string>mobile</string>",
        "<key>ProgramArguments</key><array>",
        "<string>/bin/sh</string><string>-c</string>",
        "<string>echo \"$HOME\" &gt; /var/mobile/Library/Caches/revenant-home-probe</string>",
        "</array>",
        "<key>RunAtLoad</key><true/>",
        "<key>LaunchOnlyOnce</key><true/>",
        "</dict>",
        "</plist>",
        ""}, "\n")
end

function failures(opt)
    local emulator = import("emulator", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local firmware = path.join(os.getenv("HOME"), ".revenant", "firmware", "rootfs", FIRMWARE[1], FIRMWARE[2])
    if not os.isdir(firmware) then
        table.insert(found, "the iOS 6.1.3 root filesystem is not under ~/.revenant/firmware: ./xmakew firmware --device=iPhone4,1 rootfs 6.1.3")
        return found
    end
    local program = path.join(os.projectdir(), "build", "macosx", "arm64", "release", "emulator")
    if not os.isfile(program) then
        table.insert(found, "the emulator is not built: ./xmakew f -P . -p macosx -a arm64 -y, then ./xmakew build -P . emulator")
        return found
    end
    local rootfs = path.join(folder, "rootfs")
    emulator.clone(firmware, rootfs)
    local job = emulator.guest_path(rootfs, "/" .. JOB)
    os.mkdir(path.directory(job))
    io.writefile(job, job_plist())
    local conf = emulator.guest_path(rootfs, "/" .. LAUNCHD_CONF)
    os.mkdir(path.directory(conf))
    local existing = os.isfile(conf) and io.readfile(conf) or ""
    io.writefile(conf, existing .. "load -w /" .. JOB .. "\n")
    local result = emulator.guest_path(rootfs, "/" .. RESULT)
    local booted = emulator.boot({emulator = program, rootfs = rootfs, identifier = FIRMWARE[1], run = folder,
                                  cache = path.join(folder, "host-cache"), tmpdir = path.join(folder, "tmp"),
                                  network = "isolated", scale = emulator.TIME_SCALE, deadline = 900,
                                  stop = function () return os.isfile(result) end})
    local home = os.isfile(result) and io.readfile(result):trim() or nil
    if home ~= "/var/mobile" then
        table.insert(found, "a UserName=mobile job sees HOME=/var/mobile, read " .. tostring(home) ..
                     "; the boot's folder is kept at " .. folder .. ", its emulator log at " .. tostring(booted.log))
        return found
    end
    os.tryrm(folder)
    return found
end
