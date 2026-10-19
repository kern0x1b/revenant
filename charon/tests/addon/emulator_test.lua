import("core.base.json")
import("async.runjobs")
import("fixtures")

local CONTROL = "Package: org.example.placed\nName: Placed\nArchitecture: iphoneos-arm\nDescription: files placed through the guest's links\n"

local LOGS = {
    springboard = {
        "[control] ready; use help for commands",
        "[display] frame=1 visible-pixels=11404",
        "[process] spawn-setexec pid=11 parent=1 suspended=0 /usr/libexec/charon-runner argv=\"/usr/libexec/charon-runner\",\"30\",\"/usr/libexec/tool\"",
        "[process] spawn-setexec pid=63 parent=1 suspended=0 /System/Library/CoreServices/SpringBoard.app/SpringBoard argv=\"/System/Library/CoreServices/SpringBoard.app/SpringBoard\"",
        "[process] spawn parent=11 child=68 suspended=0 /usr/libexec/tool argv=\"/usr/libexec/tool\"",
        "[cpu] fatal pid=68 cpu=0 pc=0x2f10 lr=0x2f01 fault=0x0 access=0x1 size=0x4 sp=0x2fffef00 cpsr=0x30",
        "[process] exit pid=68 status=0 signal=11"
    },
    looping = {
        "[control] ready; use help for commands",
        "[process] spawn-setexec pid=23 parent=1 suspended=0 /usr/libexec/backboardd argv=\"/usr/libexec/backboardd\"",
        "[process] exit pid=23 status=0 signal=11",
        "[process] spawn-setexec pid=74 parent=1 suspended=0 /usr/libexec/backboardd argv=\"/usr/libexec/backboardd\"",
        "[process] exit pid=74 status=0 signal=11",
        "[process] spawn-setexec pid=77 parent=1 suspended=0 /usr/libexec/backboardd argv=\"/usr/libexec/backboardd\"",
        "[process] exit pid=77 status=0 signal=11",
        "[process] spawn-setexec pid=64 parent=1 suspended=0 /System/Library/CoreServices/SpringBoard.app/SpringBoard argv=\"/System/Library/CoreServices/SpringBoard.app/SpringBoard\""
    },
    migrating = {
        "[control] ready; use help for commands",
        "[process] spawn-setexec pid=63 parent=1 suspended=0 /System/Library/CoreServices/SpringBoard.app/SpringBoard argv=\"\"",
        "[process] spawn-setexec pid=75 parent=1 suspended=0 /System/Library/PrivateFrameworks/DataMigration.framework/Support/DataMigrator argv=\"\""
    }
}

local function recorded(folder, name, lines, verdict)
    local run = path.join(folder, name)
    os.mkdir(path.join(run, "results"))
    io.writefile(path.join(run, "emulator.log"), table.concat(lines or {}, "\n") .. "\n")
    if verdict then
        json.savefile(path.join(run, "results", "verdict.json"), verdict)
    end
    return run
end

local function verdicts(emulator, folder, found)
    local function judged(name, lines, verdict)
        local run = recorded(folder, name, lines, verdict)
        local state = emulator.scan_file(path.join(run, "emulator.log"), {})
        return emulator.describe(emulator.verdict(state, path.join(run, "results"), {frame = path.join(run, "frame.png")}))
    end
    local test = {path = "/usr/libexec/tool", spawned = 1, spawn_error = 0, timed_out = 0, seconds = 1.5}
    local cases = {
        {"pass", LOGS.springboard, {test = table.join(test, {exit = 0})}, "pass"},
        {"fail", LOGS.springboard, {test = table.join(test, {exit = 3})}, "fail(exit 3)"},
        {"timeout", LOGS.springboard, {test = table.join(test, {timed_out = 1})}, "timeout"},
        {"crash", LOGS.springboard, {test = table.join(test, {signal = 11})}, "crash(signal 11, pc 0x2f10, last frame "},
        {"unspawned", LOGS.springboard, {test = table.join(test, {spawned = 0, spawn_error = 2})}, "fail(spawn error 2)"},
        {"looping", LOGS.looping, nil, "boot-blocked(backboardd)"},
        {"migrating", LOGS.migrating, nil, "boot-blocked(DataMigrator)"},
        {"silent", {}, nil, "boot-blocked(emulator)"}
    }
    for _, case in ipairs(cases) do
        local described = judged(case[1], case[2], case[3])
        if not described:startswith(case[4]) then
            table.insert(found, string.format("a %s run is %s..., the verdict says %s", case[1], case[4], described))
        end
    end
    local state = emulator.scan_file(path.join(recorded(folder, "migrated", table.join(LOGS.migrating, {"[process] exit pid=75 status=0"})), "emulator.log"), {})
    if not state.migrated or not state.springboard then
        table.insert(found, "DataMigrator exiting cleanly after SpringBoard started is the golden image's milestone")
    end
end

-- A Setup.app executable of 32-bit ARM code that stores SetupVersion the way the
-- firmware's own does, [NSNumber numberWithInt:N] under @"SetupVersion", with N
-- the given C expression; a Setup that stores its state under another key is
-- made with that key instead.
local SETUP = [[
@interface NSNumber
+ (id)numberWithInt:(int)value;
@end
@interface NSUserDefaults
+ (id)standardUserDefaults;
- (void)setObject:(id)object forKey:(id)key;
@end
int start(int argc)
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:SETUP_VERSION] forKey:@"SetupVersion"];
    return 0;
}
]]

local function setup_app(folder, ld64, rootfs, version, key)
    local work = path.join(folder, "setup")
    os.mkdir(work)
    io.writefile(path.join(work, "setup.m"), (SETUP:gsub("SetupVersion", key or "SetupVersion")))
    io.writefile(path.join(work, "libSystem.tbd"), fixtures.system_stub(
        "dyld_stub_binder, _objc_msgSend, ___CFConstantStringClassReference, '_OBJC_CLASS_$_NSNumber', '_OBJC_CLASS_$_NSUserDefaults'"))
    local built = fixtures.link(work, ld64, "Setup-" .. path.filename(rootfs), "armv7-apple-ios6.0", "setup.m",
                                {"-w", "-Os", "-Wl,-e,_start", "-DSETUP_VERSION=" .. version})
    os.mkdir(path.join(rootfs, "Applications", "Setup.app"))
    os.cp(built, path.join(rootfs, "Applications", "Setup.app", "Setup"))
end

local function home_step(emulator, folder, opt, found)
    local rootfs = path.join(folder, "home-rootfs")
    os.mkdir(path.join(rootfs, "private", "var", "mobile"))
    setup_app(folder, opt.ld64, rootfs, "3")
    os.mkdir(path.join(rootfs, "private", "var", "root", "Library", "Lockdown"))
    os.ln("private/var", path.join(rootfs, "var"))
    local ark = path.join(rootfs, "private", "var", "root", "Library", "Lockdown", "data_ark.plist")
    os.vrunv("plutil", {"-create", "binary1", ark})
    os.vrunv("plutil", {"-insert", "-DeviceName", "-string", "iPhone", ark})
    emulator.home(rootfs, "10B329")
    local state = try {function () return os.iorunv("plutil", {"-extract", "com\\.apple\\.purplebuddy-SetupState", "raw", ark}):trim() end}
    local stored = try {function () return os.iorunv("plutil", {"-extract", "SetupVersion", "raw",
        path.join(rootfs, "private", "var", "mobile", "Library", "Preferences", "com.apple.purplebuddy.plist")}):trim() end}
    if stored ~= "3" then
        table.insert(found, "the home step writes the SetupVersion the image's own Setup stores, 3, read " .. tostring(stored))
    end
    if state ~= "DONE" then
        table.insert(found, "iOS 6.1 reads the setup state from lockdownd, expected DONE, read " .. tostring(state))
    end
    local kept = try {function () return os.iorunv("plutil", {"-extract", "-DeviceName", "raw", ark}):trim() end}
    if kept ~= "iPhone" then
        table.insert(found, "the home step keeps what lockdownd's store already holds, read -DeviceName " .. tostring(kept))
    end
    -- A firmware's root filesystem has no lockdownd store before its first boot.
    local fresh = path.join(folder, "home-fresh")
    os.mkdir(path.join(fresh, "private", "var", "mobile"))
    os.ln("private/var", path.join(fresh, "var"))
    setup_app(folder, opt.ld64, fresh, "2")
    emulator.home(fresh, "10A403")
    local fresh_plist = path.join(fresh, "private", "var", "mobile", "Library", "Preferences", "com.apple.purplebuddy.plist")
    local written = try {function () return os.iorunv("plutil", {"-extract", "SetupVersion", "raw", fresh_plist}):trim() end}
    if written ~= "2" then
        table.insert(found, "the home step writes the SetupVersion the image's own Setup stores, 2, read " .. tostring(written))
    end
    local older = path.join(folder, "home-older")
    os.mkdir(path.join(older, "private", "var", "mobile"))
    os.ln("private/var", path.join(older, "var"))
    setup_app(folder, opt.ld64, older, "2", "SetupDone")
    emulator.home(older, "9B206")
    local none = try {function () return os.iorunv("plutil", {"-extract", "SetupVersion", "raw",
        path.join(older, "private", "var", "mobile", "Library", "Preferences", "com.apple.purplebuddy.plist")}):trim() end}
    if none then
        table.insert(found, "a release whose Setup has no SetupVersion gets none written, read " .. tostring(none))
    end
    -- A Setup that stores a SetupVersion this cannot read is refused, not left
    -- to run again at every boot.
    local unread = path.join(folder, "home-unread")
    os.mkdir(path.join(unread, "private", "var", "mobile"))
    os.ln("private/var", path.join(unread, "var"))
    setup_app(folder, opt.ld64, unread, "argc")
    local refused = fixtures.refusal(function () emulator.home(unread, "10X000") end)
    if not refused or not refused:find("the SetupVersion of 10X000 is not known", 1, true) then
        table.insert(found, "a SetupVersion Setup stores in a form not read is refused, got " .. tostring(refused))
    end
    local created = path.join(fresh, "private", "var", "root", "Library", "Lockdown", "data_ark.plist")
    state = try {function () return os.iorunv("plutil", {"-extract", "com\\.apple\\.purplebuddy-SetupState", "raw", created}):trim() end}
    local root = try {function () return os.iorunv("xattr", {"-p", "hfsfuse.record.owner_id", created}):trim() end}
    if state ~= "DONE" or root ~= "0" then
        table.insert(found, "an image with no lockdownd store yet gets one, root's, with the setup state DONE, read " ..
                     tostring(state) .. " owned by " .. tostring(root))
    end
    local plist = path.join(rootfs, "private", "var", "mobile", "Library", "Preferences", "com.apple.purplebuddy.plist")
    if not os.isfile(plist) then
        table.insert(found, "the home step writes com.apple.purplebuddy.plist under /private/var/mobile")
        return
    end
    for key, wanted in pairs({SetupDone = "true", SetupFinishedAllSteps = "true", SetupVersion = "3", AssistantPresented = "true"}) do
        local value = try {function () return os.iorunv("plutil", {"-extract", key, "raw", plist}):trim() end}
        if value ~= wanted then
            table.insert(found, string.format("the home step sets %s to %s, read %s", key, wanted, tostring(value)))
        end
    end
    local owner = try {function () return os.iorunv("xattr", {"-p", "hfsfuse.record.owner_id", plist}):trim() end}
    if owner ~= "501" then
        table.insert(found, "the purplebuddy preferences belong to mobile (501), read " .. tostring(owner))
    end
end

local function deb_step(emulator, debian, folder, found)
    local tree = path.join(folder, "deb-tree")
    os.mkdir(path.join(tree, "var", "mobile", "Library"))
    io.writefile(path.join(tree, "var", "mobile", "Library", "note.txt"), "through /var")
    os.mkdir(path.join(tree, "User"))
    io.writefile(path.join(tree, "User", "profile.txt"), "through an absolute link")
    os.mkdir(path.join(tree, "usr", "libexec"))
    io.writefile(path.join(tree, "usr", "libexec", "tool"), "#!/bin/sh\n")
    os.runv("chmod", {"755", path.join(tree, "usr", "libexec", "tool")})
    os.ln("tool", path.join(tree, "usr", "libexec", "alias"))
    local control = path.join(folder, "control")
    io.writefile(control, CONTROL)
    local deb = debian.write({control = control, version = "1.0", root = tree, outputdir = path.join(folder, "debs")})

    local rootfs = path.join(folder, "deb-rootfs")
    os.mkdir(path.join(rootfs, "private", "var", "mobile"))
    os.ln("private/var", path.join(rootfs, "var"))
    os.ln("/private/var/mobile", path.join(rootfs, "User"))
    emulator.install_deb(deb, rootfs)
    local through = path.join(rootfs, "private", "var", "mobile", "Library", "note.txt")
    if not os.isfile(through) or io.readfile(through) ~= "through /var" then
        table.insert(found, "a member under ./var lands in /private/var of the image, through its link")
    end
    local absolute = path.join(rootfs, "private", "var", "mobile", "profile.txt")
    if not os.isfile(absolute) then
        table.insert(found, "a member under an absolute link of the image (/User -> /private/var/mobile) lands inside the image")
    end
    if not os.isexec(path.join(rootfs, "usr", "libexec", "tool")) then
        table.insert(found, "an executable member keeps its mode")
    end
    local alias = path.join(rootfs, "usr", "libexec", "alias")
    if not os.islink(alias) or os.readlink(alias) ~= "tool" then
        table.insert(found, "a symbolic link member stays a link")
    end
    if os.isfile("/private/var/mobile/profile.txt") then
        table.insert(found, "installing a package wrote to the host's /private/var/mobile")
    end

    -- A package whose libraries depend on the release, like the backports, does
    -- its work in the maintainer script dpkg runs with DPKG_ROOT; the image is
    -- that root.
    local scripted = path.join(folder, "scripted")
    os.mkdir(path.join(scripted, "usr", "lib"))
    io.writefile(path.join(scripted, "usr", "lib", "carried.txt"), "carried")
    local scripts = path.join(folder, "scripts")
    os.mkdir(scripts)
    io.writefile(path.join(scripts, "postinst"),
                 '#!/bin/sh\nset -e\n[ "$1" = configure ] || exit 3\n' ..
                 'echo "root ${DPKG_ROOT}" > "${DPKG_ROOT}/usr/lib/configured.txt"\n')
    local script_deb = debian.write({control = control, version = "1.0", root = scripted,
                                     scripts = scripts,
                                     outputdir = path.join(folder, "scripted-debs")})
    emulator.install_deb(script_deb, rootfs)
    local configured = path.join(rootfs, "usr", "lib", "configured.txt")
    if not os.isfile(configured) or not io.readfile(configured):find(rootfs, 1, true) then
        table.insert(found, "the package's postinst runs against the image as its DPKG_ROOT")
    end

    local failing_scripts = path.join(folder, "failing-scripts")
    os.mkdir(failing_scripts)
    io.writefile(path.join(failing_scripts, "postinst"),
                 '#!/bin/sh\necho "no libraries for this release" >&2\nexit 1\n')
    local failing_deb = debian.write({control = control, version = "1.0", root = scripted,
                                      scripts = failing_scripts,
                                      outputdir = path.join(folder, "failing-debs")})
    local script_refusal = fixtures.refusal(function ()
        emulator.install_deb(failing_deb, rootfs)
    end)
    if not script_refusal or not script_refusal:find("no libraries for this release", 1, true) then
        table.insert(found, "a postinst that refuses the image stops the install and says why, said " ..
                            tostring(script_refusal))
    end
    local refused = fixtures.refusal(function ()
        io.writefile(path.join(folder, "not.deb"), "plain text")
        emulator.install_deb(path.join(folder, "not.deb"), rootfs)
    end)
    if not refused or not refused:find("not a Debian package", 1, true) then
        table.insert(found, "a file that is no ar archive must be refused: " .. tostring(refused))
    end
end

local function runner_job(emulator, folder, found)
    local task = emulator.runner_task({"/usr/libexec/tool", "a&b", "<x>", "two words", "'q\"x"}, 45)
    if task ~= "45\0/usr/libexec/tool\0a&b\0<x>\0two words\0'q\"x\0" then
        table.insert(found, "the runner's job holds the deadline and every argument verbatim, each ended by a NUL")
    end
    local launch = emulator.runner_launch()
    if launch ~= "bsexec .. /usr/libexec/charon-runner --job /private/var/charon/job\n" then
        table.insert(found, "launchd.conf starts the runner on its job file, in words launchctl splits on whitespace: " .. launch)
    end
    local job = path.join(folder, "job.plist")
    io.writefile(job, emulator.runner_job())
    if not try {function () os.vrunv("plutil", {"-lint", job}) return true end} then
        table.insert(found, "the runner's LaunchDaemon job is a well-formed property list")
        return
    end
    local listed = os.iorunv("plutil", {"-convert", "json", "-o", "-", job})
    if not listed:find('"--job"', 1, true) or not listed:find("private\\/var\\/charon\\/job", 1, true) then
        table.insert(found, "the runner's plist starts it on its job file: " .. listed)
    end
    for _, case in ipairs({{release = "6.1.3", conf = true}, {release = "3.0", conf = true}, {release = "7.1.2", conf = false}}) do
        local rootfs = path.join(folder, "rootfs-" .. case.release)
        local guest = path.join(folder, "guest")
        os.mkdir(path.join(guest, "usr", "libexec"))
        io.writefile(path.join(guest, "usr", "libexec", "charon-runner"), "")
        os.mkdir(path.join(rootfs, "private", "etc"))
        os.mkdir(path.join(rootfs, "System", "Library", "LaunchDaemons"))
        io.writefile(path.join(rootfs, "private", "etc", "launchd.conf"), "setenv TZ UTC")
        emulator.install_runner(rootfs, guest, {"/bin/true"}, 30, case.release)
        emulator.install_runner(rootfs, guest, {"/bin/true"}, 30, case.release)
        local conf = io.readfile(path.join(rootfs, "private", "etc", "launchd.conf"))
        local plist = os.isfile(path.join(rootfs, "System", "Library", "LaunchDaemons", "org.charon.emulator.runner.plist"))
        local expected = case.conf and "setenv TZ UTC\n" .. emulator.runner_launch() or "setenv TZ UTC"
        if conf ~= expected or plist == case.conf then
            table.insert(found, "iOS " .. case.release .. " starts the runner from " .. (case.conf and "launchd.conf, once, keeping what it held" or "its plist") .. ": " .. conf)
        end
    end
end

local function choice(emulator, found)
    local devices = {
        {identifier = "iPhone1,1", platform = "s5l8900x", firmwares = {{version = "3.1.3", build = "7E18"}}},
        {identifier = "iPhone2,1", platform = "s5l8920x", firmwares = {{version = "6.1.6", build = "10B500"}, {version = "5.0", build = "9A334"}}},
        {identifier = "iPhone3,1", platform = "s5l8930x", firmwares = {{version = "6.0", build = "10A403"}, {version = "7.1.2", build = "11D257"}}},
        {identifier = "iPad3,1", platform = "s5l8945x", firmwares = {{version = "6.0", build = "10A403"}}}
    }
    local emulated = {"iPhone1,1", "iPhone2,1", "iPhone3,1"}
    local chosen = emulator.choose(devices, emulated, {architecture = "armv7", release = "6.0"})
    if chosen.identifier ~= "iPhone2,1" or chosen.version ~= "6.1.6" then
        table.insert(found, string.format("armv7 6.0 goes to the first emulated armv7 device with a release not older, iPhone2,1 6.1.6, got %s %s", chosen.identifier, chosen.version))
    end
    chosen = emulator.choose(devices, emulated, {device = "iphone3,1", architecture = "armv7", release = "6.0"})
    if chosen.identifier ~= "iPhone3,1" or chosen.build ~= "10A403" then
        table.insert(found, "a named device takes its earliest release not older than the wanted one")
    end
    local refused = fixtures.refusal(function () emulator.choose(devices, emulated, {device = "iPad3,1", architecture = "armv7", release = "6.0"}) end)
    if not refused or not refused:find("no profile for iPad3,1", 1, true) then
        table.insert(found, "a device Shade has no profile for must be refused, not replaced by another: " .. tostring(refused))
    end
    refused = fixtures.refusal(function () emulator.choose(devices, emulated, {architecture = "armv7", release = "8.0"}) end)
    if not refused or not refused:find("release 8.0 or later", 1, true) then
        table.insert(found, "a release no emulated device runs must be refused: " .. tostring(refused))
    end
end

local function script(folder, name, body, modules)
    local file = path.join(folder, name .. ".lua")
    io.writefile(file, "function main(root, extra)\n    local emulator = import(\"emulator\", {rootdir = \"" .. path.translate(modules) .. "\", anonymous = true})\n" .. body .. "\nend\n")
    return file
end

local function spawned(files, arguments)
    runjobs("emulator-concurrency", function (index)
        local log = files[index] .. "." .. index .. ".log"
        os.execv(os.programfile(), table.join({"l", files[index]}, arguments[index]), {stdout = log, stderr = log, try = true})
    end, {total = #files, comax = #files})
end

local function load_step(emulator, found)
    for _, case in ipairs({{20.0, 12, true}, {3.0, 12, false}, {12.0, 12, false}, {nil, 12, false}, {5.0, nil, false}}) do
        if emulator.crowded(case[1], case[2]) ~= case[3] then
            table.insert(found, string.format("a load of %s on %s cores is %scrowded",
                                              tostring(case[1]), tostring(case[2]), case[3] and "" or "not "))
        end
    end
    local load = emulator.machine_load()
    if load ~= nil and (type(load) ~= "number" or load < 0) then
        table.insert(found, "the machine's load reads as a number or as nothing, read " .. tostring(load))
    end
    -- A build the queue already started carries its slot, and a build inside it
    -- must not wait for a second one.
    local marker = emulator.build_slot_name()
    if emulator.holds_build_slot({}) or not emulator.holds_build_slot({[marker] = "2"}) or
       emulator.holds_build_slot({[marker] = ""}) then
        table.insert(found, "a build carries its slot to the builds it starts, and only then")
    end
    if emulator.build_capacity() < 2 then
        table.insert(found, "a machine runs at least two builds at once, said " .. tostring(emulator.build_capacity()))
    end
    -- A slot is a share of the machine: what runs in it is told how much of it
    -- to take, and only when it is an xmake that would otherwise take all of it.
    if emulator.build_jobs(12, 3) ~= 4 or emulator.build_jobs(2, 3) ~= 1 or emulator.build_jobs(12, 0) ~= 12 then
        table.insert(found, string.format("three slots on twelve cores are four jobs each, said %d, %d and %d",
                                          emulator.build_jobs(12, 3), emulator.build_jobs(2, 3), emulator.build_jobs(12, 0)))
    end
    for _, case in ipairs({{{"xmake", {}}, "-j 4"},
                           {{"xmake", {"test", "suite/default"}}, "test suite/default -j 4"},
                           {{"xmake", {"build", "--", "-v"}}, "build -j 4 -- -v"},
                           {{"xmake", {"run", "port"}}, "run port"},
                           {{"xmake", {"f", "-y"}}, "f -y"},
                           {{"xmake", {"build", "-j8"}}, "build -j8"},
                           {{"/bin/sh", {"-c", "xmake"}}, "-c xmake"}}) do
        local given = table.concat(emulator.queued_arguments(case[1][1], case[1][2], 4), " ")
        if given ~= case[2] then
            table.insert(found, string.format("%s %s runs in a slot as %s, not %s", case[1][1], table.concat(case[1][2], " "), case[2], given))
        end
    end
    -- Patience of zero is how a test takes a slot without waiting for a quiet
    -- machine; it must still hand out the slot.
    local slot = emulator.acquire({folder = path.join(os.tmpdir(), "charon-slot-test-" .. os.getpid()), count = 1, patience = 0})
    if not slot then
        table.insert(found, "a run with no patience still takes a slot")
    else
        emulator.release(slot)
    end
end

local function concurrency(folder, modules, found)
    local root = path.join(folder, "emulator-root")
    local firmware = path.join(folder, "firmware-rootfs")
    os.mkdir(path.join(firmware, "System", "Library", "CoreServices"))
    io.writefile(path.join(firmware, "System", "Library", "CoreServices", "SystemVersion.plist"), "firmware")
    os.mkdir(path.join(firmware, "private", "var", "mobile"))
    local golden = script(folder, "golden", [[
    local rootfs = emulator.golden({root = root, identifier = "iPhone3,1", version = "6.0", build = "10A403", shade_hash = "fixture", deadline = 30,
                                    firmware = extra, boot = function (opt)
        io.writefile(path.join(root, "boot-" .. os.getpid()), "booted")
        os.sleep(3000)
        return {reason = "reached", seconds = 3, state = {}, log = "none"}
    end})
    io.writefile(path.join(root, "result-" .. os.getpid()), rootfs)]], modules)
    os.mkdir(root)
    spawned({golden, golden}, {{root, firmware}, {root, firmware}})
    local boots = os.files(path.join(root, "boot-*"))
    local results = os.files(path.join(root, "result-*"))
    if #boots ~= 1 then
        table.insert(found, string.format("two processes preparing one golden image boot it once, booted %d times", #boots))
    end
    if #results ~= 2 then
        table.insert(found, "both processes preparing one golden image get it")
    else
        local first, second = io.readfile(results[1]), io.readfile(results[2])
        if first ~= second or not os.isfile(path.join(first, "System", "Library", "CoreServices", "SystemVersion.plist")) then
            table.insert(found, "both processes get the same complete golden image, got " .. first .. " and " .. second)
        end
    end
    if #os.dirs(path.join(root, "golden.noindex", "*.partial-*")) > 0 then
        table.insert(found, "a finished golden image leaves no partial folder behind")
    end

    local slots = path.join(folder, "slots")
    local holders = path.join(folder, "holders")
    os.mkdir(path.join(holders, "active"))
    local slot = script(folder, "slot", [[
    local taken = emulator.acquire({folder = root, count = 2})
    local marker = path.join(extra, "active", tostring(os.getpid()))
    io.writefile(marker, tostring(taken.index))
    io.writefile(path.join(extra, os.getpid() .. ".peak"), tostring(#os.files(path.join(extra, "active", "*"))))
    os.sleep(1500)
    os.rm(marker)
    emulator.release(taken)]], modules)
    spawned({slot, slot, slot, slot, slot}, {{slots, holders}, {slots, holders}, {slots, holders}, {slots, holders}, {slots, holders}})
    local peaks = os.files(path.join(holders, "*.peak"))
    if #peaks ~= 5 then
        table.insert(found, string.format("five processes waiting for two slots all get one, %d did", #peaks))
    end
    for _, peak in ipairs(peaks) do
        local holding = tonumber(io.readfile(peak))
        if holding > 2 then
            table.insert(found, string.format("two slots were held by %d processes at once", holding))
        end
    end
end

local function timing_and_reports(emulator, folder, found)
    local run = recorded(folder, "timed", LOGS.springboard,
                         {test = {path = "/usr/libexec/tool", spawned = 1, spawn_error = 0, timed_out = 0,
                                  seconds = 1.5, exit = 0}})
    local result = emulator.verdict(emulator.scan_file(path.join(run, "emulator.log"), {}),
                                    path.join(run, "results"), {scale = 10, host_seconds = 18.25})
    if result.guest_seconds ~= 1.5 or result.host_seconds ~= 18.25 or result.scale ~= 10 then
        table.insert(found, string.format("a verdict carries both clocks and the scale, read %s guest, %s host, scale %s",
                                          tostring(result.guest_seconds), tostring(result.host_seconds), tostring(result.scale)))
    end

    local rootfs = path.join(folder, "report-rootfs")
    local reports = path.join(rootfs, "private", "var", "logs", "CrashReporter")
    os.mkdir(reports)
    os.ln("private/var", path.join(rootfs, "var"))
    local description = table.concat({"Incident Identifier: 0", "Hardware Model:      iPhone4,1",
                                      "Exception Code:      0xbe18d1ee",
                                      "Reason:              mediaserverd: RPCTimeout message received to terminate [0] with reason 'InitializeSystemSoundPorts'"}, "\n")
    local report = path.join(reports, "SpringBoard-2026-09-17-131741.plist")
    io.writefile(report, "")
    os.vrunv("plutil", {"-create", "binary1", report})
    os.vrunv("plutil", {"-replace", "description", "-string", description, report})
    local collected = emulator.reports(rootfs)
    if #collected ~= 1 or collected[1].process ~= "SpringBoard" or
       not (collected[1].reason or ""):startswith("mediaserverd: RPCTimeout") then
        table.insert(found, "the guest's own report names the process and the reason it died")
        return
    end
    local unanswered = table.join(LOGS.looping, {
        "[mach] stalled pid=23 thread=1 request=118 reply-port=73216 object=477440 receive-owner=23 guest-seconds=45",
        "[mach] stalled pid=23 thread=4 request=404 reply-port=73217 object=477441 receive-owner=23 guest-seconds=12"})
    local blocked = emulator.verdict(emulator.scan_file(path.join(recorded(folder, "blocked", unanswered), "emulator.log"), {}),
                                     path.join(folder, "blocked", "results"), {reports = collected})
    local described = emulator.describe(blocked)
    if not described:find("mediaserverd: RPCTimeout", 1, true) then
        table.insert(found, "a blocked boot names the guest's own reason, said " .. described)
    end
    for _, case in ipairs({{"strict", 10, true}, {"strict", 1, false}, {"scaled", 10, false}, {nil, 10, false}}) do
        local refused = emulator.timing_refusal(case[1], case[2]) ~= nil
        if refused ~= case[3] then
            table.insert(found, string.format("a %s port at scale %d is %srefused",
                                              tostring(case[1]), case[2], case[3] and "" or "not "))
        end
    end
    -- A request the emulator never answers is a hole in the HLE, and a blocked
    -- boot says so instead of reading as a slow guest.
    if not blocked.gap or blocked.gap.request ~= 118 or blocked.gap.seconds ~= 45 or
       blocked.gap.process ~= "backboardd" or not described:find("reply to request 118", 1, true) then
        table.insert(found, "a blocked boot names the reply the guest waited for, said " .. described)
    end
end

-- The queue's plugin runs in xmake's sandbox, where a call the sandbox does not
-- hold is a crash on the way in and no command runs at all. Nothing catches
-- that but running it, so the test installs the repository as an addon in a
-- store of its own, with a Charon home of its own for the slots, and asks the
-- queue for a command that succeeds and one that fails.
local function queue_step(emulator, folder, opt, found)
    local work = path.join(folder, "queue")
    local envs = {XMAKE_GLOBALDIR = path.join(work, "store"), CHARON_HOME = path.join(work, "home")}
    os.mkdir(work)
    -- The install must land in the store named by XMAKE_GLOBALDIR and nowhere else: on xmake 3.1.1 an addon
    -- installed into the machine's own store becomes the active one for every project on it
    -- (charon/AGENTS.md, the trap the coordinator reserves). Measured 2026-09-28 around this step: the listing
    -- of ~/.xmake/addons and addons.conf are byte for byte what they were, and no addons.conf.bak-* appears.
    local shared = path.join(os.getenv("HOME"), ".xmake", "addons")
    local before = os.exists(shared) and os.files(shared) or {}
    os.iorunv("xmake", {"addon", "--install", "-y", path.absolute(path.join(opt.modules, ".."))}, {curdir = work, envs = envs})
    if os.isdir(shared) then
        for _, name in ipairs(os.files(shared)) do
            if not table.contains(before, name) then
                table.insert(found, "emulator_test's own xmake addon --install added " .. name .. " to the machine's own ~/.xmake/addons, and on xmake 3.1.1 that makes it the active addon for every project")
            end
        end
    end
    -- where it landed: the private store is the whole point, so where the install went is the measurement
    local landed = os.files(path.join(work, "store"))
    if #landed == 0 and not os.isdir(path.join(work, "store")) then
        table.insert(found, "emulator_test's xmake addon --install left no store of its own under " .. work .. ", so where it installed is not what XMAKE_GLOBALDIR says")
    end
    -- A queue that already holds a slot passes it down and runs the command
    -- itself, and both ways have to answer with the status of what they ran.
    for _, held in ipairs({"", "1"}) do
        for _, case in ipairs({{"/usr/bin/true", 0}, {"/usr/bin/false", 1}}) do
            local code = os.execv("xmake", {"queue", "--", case[1]},
                                  {curdir = work, try = true,
                                   envs = table.join(envs, {[emulator.build_slot_name()] = held}),
                                   stdout = path.join(work, "queue.log"), stderr = path.join(work, "queue.log")})
            if code ~= case[2] then
                table.insert(found, string.format("the queue ends with the status of what it ran%s: %s answered %s, not %d, and said %s",
                                                  held == "" and "" or ", slot held", case[1], tostring(code), case[2],
                                                  (io.readfile(path.join(work, "queue.log")) or ""):trim()))
            end
        end
    end
end

-- An address in a backtrace is named by the image the guest says it loaded and
-- by the nearest symbol of the images the rootfs holds as files; what only the
-- shared cache holds is named by image and offset, and what no image covers
-- stays the number it is.
local function naming_step(emulator, found)
    local images = {{address = 0x4000, install = "/usr/libexec/port"}, {address = 0x33141000, install = "/usr/lib/libobjc.A.dylib"}}
    local symbols = {["/usr/libexec/port"] = {{address = 0x0, name = "_start"}, {address = 0x120, name = "_main"}}}
    for _, case in ipairs({{0x4124, "port`_main + 0x4"}, {0x4000, "port`_start + 0x0"},
                           {0x3314dfe8, "libobjc.A.dylib + 0xcfe8"}, {0x100, "0x00000100"}}) do
        local named = emulator.named_address(case[1], images, symbols)
        if named ~= case[2] then
            table.insert(found, string.format("0x%x is %s, not %s", case[1], case[2], named))
        end
    end
end

local function runner_source(opt, found)
    local source = io.readfile(path.join(opt.modules, "..", "packages", "e", "emulator-guest", "src", "charon-runner.c"))
    if source:find("CFPropertyListCreateWithStream", 1, true) then
        table.insert(found, "the runner reads SystemVersion.plist with a function iOS 3 does not have: CFPropertyListCreateWithStream arrived in 4.0, CFPropertyListCreateFromStream is there from 2.0")
    end
    -- The runner is started from launchd.conf, which launchctl reads before it loads the LaunchDaemons: a
    -- test begun at once finds none of them (com.apple.cvmsServ among them). tests/emulate/launchd is the
    -- measurement on a real guest; this is the shape of the cause. The test is spawned only after launchd
    -- has registered the Mach services the firmware's plists declare, and a service a plist hides until its
    -- daemon checks in is not one of them.
    local wait_call = source:find("wait_for_daemons(deadline", 1, true)
    local spawn_call = source:find("posix_spawn(&child", 1, true)
    if not wait_call or not spawn_call or wait_call > spawn_call then
        table.insert(found, "the runner starts the test only after launchd has registered the daemons' services")
    end
    local lookup = source:find("bootstrap_look_up(bootstrap_port", 1, true)
    if not source:find('"/System/Library/LaunchDaemons"', 1, true) or not source:find('CFSTR("MachServices")', 1, true) or not lookup then
        table.insert(found, "the runner asks launchd for the Mach services the LaunchDaemons plists declare")
    end
    if not source:find('"HideUntilCheckIn"', 1, true) then
        table.insert(found, "the runner does not wait for a service its daemon registers only when it checks in")
    end
end

-- The check every copy an install makes ends with: a program that was not copied is a program the
-- image does not hold, and an install that says it installed one is worse than one that failed. A source
-- that is not there stands in for a copy that did not happen, because the copy itself cannot be made to
-- fail here; what is under test is that the result is checked rather than assumed.
local function copy_step(opt, found)
    local platform = import("apple.platform", {rootdir = opt.modules, anonymous = true})
    local folder = fixtures.scratch()
    io.writefile(path.join(folder, "there"), "program\n")
    if not platform.copy_program(path.join(folder, "there"), path.join(folder, "usr", "libexec", "there"), "probe") then
        table.insert(found, "a program that was copied is not reported as a failure")
    end
    if not os.isfile(path.join(folder, "usr", "libexec", "there")) then
        table.insert(found, "a copied program is where it was asked for")
    end
    if not fixtures.refusal(function ()
        platform.copy_program(path.join(folder, "not-built"), path.join(folder, "usr", "libexec", "not-built"), "probe")
    end) then
        table.insert(found, "a program that was not built must fail the install, not install nothing")
    end
    -- A file that is not a Mach-O has no LC_UUID, and says so rather than guessing: the UUID is read
    -- out of a Mach-O by otool, and the two-builds refusal is measured on real binaries rather than here,
    -- because a stand-in would only test the stand-in.
    io.writefile(path.join(folder, "not-a-macho"), "built\n")
    if platform.macho_uuid(path.join(folder, "not-a-macho")) ~= nil then
        table.insert(found, "a file that is not a Mach-O has no LC_UUID")
    end
    if platform.macho_uuid(path.join(folder, "nowhere")) ~= nil then
        table.insert(found, "a file that is not there has no LC_UUID")
    end
    os.tryrm(folder)
end

-- A root filesystem holds read-only directories - the dyld cache ships as one - and a directory needs
-- execute as well as write for the entries in it to be unlinked, so remove() has to grant both. And an
-- image nothing has used for the age, an owner nothing has used for the age, and the root filesystem a
-- killed run left inside an image that is otherwise wanted all go at the start of the next xmake emulate.
local function prune_step(emulator, folder, found)
    local base = path.join(folder, "images.noindex")
    local function image(owner, name)
        local here = path.join(base, owner, name)
        io.writefile(path.join(here, "image.json"), "{}")
        return here
    end
    -- stale means what used() reads: the folder and every direct child, so ageing only the folder left the
    -- image.json written when the image was built looking like a use, and the image stayed
    local function stale(what)
        local when = os.date("%Y%m%d%H%M", os.time() - 48 * 3600)
        if os.isdir(what) or os.isfile(what) then
            os.execv("touch", {"-t", when, what}, {try = true, stdout = os.nul, stderr = os.nul})
        end
        if os.isdir(what) then
            for _, child in ipairs(os.files(path.join(what, "*"))) do
                os.execv("touch", {"-t", when, child}, {try = true, stdout = os.nul, stderr = os.nul})
            end
        end
    end
    -- a read-only directory holding a file, as the root filesystem holds the dyld cache
    local readonly = path.join(folder, "readonly", "System", "Library", "Caches", "com.apple.dyld")
    io.writefile(path.join(readonly, "dyld_shared_cache_armv7"), "cache")
    -- the file first: a directory at 444 cannot be entered to have its contents changed
    os.execv("chmod", {"444", path.join(readonly, "dyld_shared_cache_armv7")}, {try = true, stdout = os.nul, stderr = os.nul})
    os.execv("chmod", {"444", path.directory(readonly)}, {try = true, stdout = os.nul, stderr = os.nul})
    local refused = try {function () emulator.remove(path.join(folder, "readonly")) return true end,
                         catch {function (errors) return false, errors end}}
    if not refused then
        table.insert(found, "a root filesystem holding a read-only directory cannot be removed: " .. tostring(refused))
    end
    if os.isdir(path.join(folder, "readonly")) then
        table.insert(found, "the read-only directory is still there after remove()")
    end

    -- wanted: the image itself is recent, and only the run a killed run left inside it is not
    local fresh = image("owner-fresh", "iPhone3,1_7A")
    local used = image("owner-used", "iPhone3,1_7A")
    local leftover = path.join(used, "run")
    io.writefile(path.join(leftover, "rootfs", "placeholder"), "x")
    stale(leftover)
    stale(path.join(leftover, "rootfs"))
    -- abandoned: neither the image nor the owner that holds it has been touched
    local abandoned = image("owner-unused", "iPhone3,1_7A")
    stale(abandoned)
    stale(path.join(base, "owner-unused"))
    -- held: an xmake emulate is using it, whatever its age
    local held = image("owner-held", "iPhone3,1_7A")
    stale(held)
    stale(path.join(base, "owner-held"))
    local lock = io.openlock(held .. ".lock")
    lock:lock()
    local removed = emulator.prune({root = folder, hours = 24})
    lock:unlock()
    lock:close()
    local gone = {}
    for _, entry in ipairs(removed) do
        gone[entry:sub(#base + 2)] = true
    end
    if not gone["owner-used/run"] and os.isdir(leftover) then
        table.insert(found, "the root filesystem a killed run left inside an image that is still wanted is pruned, not kept: " .. table.concat(removed, " "))
    end
    if os.isdir(path.join(base, "owner-unused")) and not gone["owner-unused"] then
        table.insert(found, "an owner that holds nothing after the prune goes with it, and it is still there: " .. table.concat(removed, " "))
    end
    if (not gone["owner-unused/iPhone3,1_7A"] and not gone["owner-unused"]) or os.isdir(abandoned) then
        table.insert(found, "an image nothing has booted for the age is pruned with the owner that holds nothing else, not kept: " .. table.concat(removed, " "))
    end
    if not os.isdir(fresh) then
        table.insert(found, "an image used within the age is kept")
    end
    if not os.isdir(used) then
        table.insert(found, "an image whose run was pruned is kept: only the run goes")
    end
    if not os.isdir(held) or not os.isdir(path.join(base, "owner-held")) then
        table.insert(found, "an image another xmake emulate holds the lock of is kept whatever its age")
    end
    -- a fresh tree is left alone entirely, which is what every normal run sees
    local only = path.join(folder, "only")
    io.writefile(path.join(only, "owner", "iPhone3,1_7A", "image.json"), "{}")
    if #emulator.prune({root = only}) ~= 0 or not os.isdir(path.join(only, "owner", "iPhone3,1_7A")) then
        table.insert(found, "a prune of images all used within the age removes nothing")
    end
end


-- An owner has no lock a running emulate takes: the run holds its image's lock, so a prune that asked for
-- the owner's judged nothing and removed the images inside a live run's image. An image a live process holds
-- is kept, and an owner is only removed when it holds nothing.
-- A lock held by another process, which is the situation the prune's bug is about: this process opens the
-- same file and its own openlock interacts with the holder differently. The child says "held" in a file when
-- it has the lock, and the caller waits for that word.
local function wait_for_the_lock(lock, word)
    local script = path.join(path.directory(word), "holder.py")
    io.writefile(script, string.format([[import fcntl, sys, time
f = open(sys.argv[1], "a")
fcntl.flock(f, fcntl.LOCK_EX)
open(sys.argv[2], "w").write("held")
time.sleep(60)
]], path.absolute(lock), path.absolute(word)))
    os.execv("python3", {script, lock, word}, {try = true, stdout = os.nul, stderr = os.nul, detach = true})
    for attempt = 1, 60 do
        if os.isfile(word) and io.readfile(word):find("held", 1, true) then
            return true
        end
        os.sleep(100)
    end
    return false
end

local function held_image_step(emulator, folder, found)
    -- o1: an owner aged 48h, an image aged 48h, and the image's lock held by *another process* - the case the
    -- review measured red on the old code and green on this one, cross-process because a lock this process
    -- took is not the situation the bug is about.
    local base = path.join(folder, "images.noindex")
    local owner = path.join(base, "o1")
    local image = path.join(owner, "iPhone3,1_1")
    os.mkdir(base)
    os.mkdir(owner)
    os.mkdir(image)
    local when = os.date("%Y%m%d%H%M", os.time() - 48 * 3600)
    for _, what in ipairs({image, owner}) do
        os.execv("touch", {"-t", when, what}, {try = true, stdout = os.nul, stderr = os.nul})
    end
    local held = wait_for_the_lock(image .. ".lock", folder .. "/held.txt")
    -- the lock is aged with the owner and the image, as one pass after the holder says "held": the holder's
    -- open(lock, "a") created it inside the owner, and a fresh lock reads as a use of the owner
    for _, what in ipairs({image, owner, image .. ".lock"}) do
        os.execv("touch", {"-t", when, what}, {try = true, stdout = os.nul, stderr = os.nul})
    end
    if not held then
        table.insert(found, "the holder process did not take the image's lock")
    end
    local removed = emulator.prune({root = folder, hours = 24})
    if os.isdir(image) then
        -- kept, which is the point
    else
        table.insert(found, string.format("o1: an image a live xmake emulate holds must survive the prune, and it was removed: %s (owner mtime=%s used=%s unlocks=%s)",
                                          table.concat(removed, " "), os.mtime(owner),
                                          tostring(emulator.used(owner, 24)), tostring(emulator.unlocks(owner))))
    end
    -- a lock beside an *owner* is the prune's: the run's real lock is the image's, which the holder made
    local visited = path.join(base, "o3")
    os.mkdir(visited)
    os.mkdir(path.join(visited, "iPhone3,1_1"))
    for _, what in ipairs({path.join(visited, "iPhone3,1_1"), visited}) do
        os.execv("touch", {"-t", when, what}, {try = true, stdout = os.nul, stderr = os.nul})
    end
    emulator.prune({root = folder, hours = 24})
    for _, entry in ipairs(os.files(path.join(base, "*.lock"))) do
        if entry:find("o3") then
            table.insert(found, "the prune left a lock beside an owner it visited: " .. path.filename(entry))
        end
    end
    -- o2, the control: the owner is fresh, so nothing is pruned whatever the lock says
    local owner2 = path.join(base, "o2")
    local image2 = path.join(owner2, "iPhone3,1_1")
    os.mkdir(owner2)
    os.mkdir(image2)
    for _, what in ipairs({image2}) do
        os.execv("touch", {"-t", when, what}, {try = true, stdout = os.nul, stderr = os.nul})
    end
    wait_for_the_lock(image2 .. ".lock", folder .. "/held2.txt")
    os.execv("touch", {"-t", when, image2 .. ".lock"}, {try = true, stdout = os.nul, stderr = os.nul})
    local removed2 = emulator.prune({root = folder, hours = 24})
    if #removed2 > 0 then
        table.insert(found, "o2: a fresh owner with a held image must be left alone, and the prune removed: " .. table.concat(removed2, " "))
    end
    os.tryrm(folder)
end

local INFO = [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Probe</string>
%s
</dict></plist>
]]

local function registration_step(emulator, debian, folder, found)
    local tree = path.join(folder, "app-tree")
    os.mkdir(path.join(tree, "Applications", "Probe.app"))
    io.writefile(path.join(tree, "Applications", "Probe.app", "Info.plist"), INFO:format("<key>CFBundleIdentifier</key><string>org.example.probe</string>"))
    local control = path.join(folder, "app-control")
    io.writefile(control, (CONTROL:gsub("org.example.placed", "org.example.probe")))
    local deb = debian.write({control = control, version = "1.0", root = tree, outputdir = path.join(folder, "app-debs")})
    local rootfs = path.join(folder, "app-rootfs")
    local cache = path.join(rootfs, "private", "var", "mobile", "Library", "Caches", "com.apple.mobile.installation.plist")
    os.mkdir(path.directory(cache))
    os.ln("private/var", path.join(rootfs, "var"))
    os.vrunv("plutil", {"-create", "binary1", cache})
    local placed = emulator.install_deb(deb, rootfs)
    if #placed ~= 1 or placed[1] ~= "Applications/Probe.app" then
        table.insert(found, "installing a package names the application bundles it placed, said " .. table.concat(placed, ", "))
        return
    end
    if emulator.register_application(rootfs, placed[1]) ~= "org.example.probe" then
        table.insert(found, "registering an application answers its bundle identifier")
    end
    if os.isfile(cache) then
        table.insert(found, "registering an application removes MobileInstallation's cache, which it rebuilds from /Applications at boot")
    end
    local bare = path.join(folder, "bare-rootfs")
    os.mkdir(path.join(bare, "Applications", "Probe.app"))
    os.cp(path.join(tree, "Applications", "Probe.app", "Info.plist"), path.join(bare, "Applications", "Probe.app") .. "/")
    if emulator.register_application(bare, "Applications/Probe.app") ~= "org.example.probe" then
        table.insert(found, "an image with no MobileInstallation cache yet registers an application too")
    end
    io.writefile(path.join(bare, "Applications", "Probe.app", "Info.plist"), INFO:format(""))
    local refused = fixtures.refusal(function () emulator.register_application(bare, "Applications/Probe.app") end) or ""
    if not refused:find("CFBundleIdentifier", 1, true) then
        table.insert(found, "an application with no bundle identifier must be refused, said " .. refused)
    end
    os.rm(path.join(bare, "Applications", "Probe.app", "Info.plist"))
    refused = fixtures.refusal(function () emulator.register_application(bare, "Applications/Probe.app") end) or ""
    if not refused:find("has no Info.plist", 1, true) then
        table.insert(found, "a bundle with no Info.plist must be refused as such, said " .. refused)
    end
end

local function launch_step(emulator, folder, found)
    local steps = emulator.parse_steps({"tap", "160", "260", "home", "drag", "1", "2", "3", "4", "until-exit"})
    if table.concat(steps, ";") ~= "tap 160 260;home;drag 1 2 3 4;until-exit" then
        table.insert(found, "launch's steps are read as tap X Y, home, drag X1 Y1 X2 Y2 and until-exit, read " .. table.concat(steps, ";"))
    end
    for _, words in ipairs({{"tap", "1"}, {"swipe", "1", "2"}, {"tap", "x", "2"}}) do
        if not fixtures.refusal(function () emulator.parse_steps(words) end) then
            table.insert(found, "a step that is not tap X Y, drag X1 Y1 X2 Y2, home or until-exit must be refused: " .. table.concat(words, " "))
        end
    end
    local command = table.concat(emulator.launch_command("org.example.probe", 90), " ")
    if command ~= "/usr/libexec/charon-sblaunch --wait 90 --stdout /private/var/charon/app.stdout --stderr /private/var/charon/app.stderr org.example.probe" then
        table.insert(found, "launch has charon-sblaunch wait and keep the application's output beside the verdict: " .. command)
    end
    local scanned = {}
    for _, line in ipairs({"[control] snapshot=/run/app-0.png frame=12", "[transition] input-complete id=3 kind=gesture completed-ns=1",
                           "[transition] settle id=4 sequence=90 started-ns=2", "[transition] internal-stable id=4 sequence=90 content-revision=7",
                           "[process] spawn-setexec pid=90 parent=1 suspended=0 /Applications/Probe.app/Probe argv=\"\""}) do
        emulator.scan(scanned, line)
    end
    if not (scanned.snapshots or {})["/run/app-0.png"] or scanned.transition ~= 4 or not (scanned.stable or {})[4]
       or (scanned.programs or {})["90"] ~= "/Applications/Probe.app/Probe" then
        table.insert(found, "the log is read for the snapshots taken, the transitions started and settled, and the path of each program started")
    end

    local results = path.join(folder, "launch-results")
    local function driven()
        os.tryrm(results)
        os.mkdir(results)
        local sent = {}
        local driver = emulator.launch_driver({results = results, run = "/run", application = "/Applications/Probe.app",
                                               steps = {"tap 160 260"}})
        return driver, sent, function (state)
            return driver.stop(state, function (command) table.insert(sent, command) end)
        end
    end
    do
        local _, sent, tick = driven()
        local state = {}
        tick(state)
        io.writefile(path.join(results, "test.stdout"), "charon-sblaunch: 21.5 s: SpringBoard refused with 3 (device locked), screen=passcode\n")
        tick(state)
        state.ready = true
        tick(state)
        if #sent ~= 0 then
            table.insert(found, "a screen locked with a passcode is not unlocked, sent " .. table.concat(sent, ";"))
        end
    end
    local driver, sent, tick = driven()
    local state = {}
    tick(state)
    io.writefile(path.join(results, "test.stdout"), "charon-sblaunch: 0.0 s: waiting for SpringBoard\ncharon-sblaunch: 21.5 s: SpringBoard refused with 3 (device locked), screen=locked\n")
    tick(state)
    state.ready = true
    tick(state)
    tick(state)
    state.transition = 1
    tick(state)
    if table.concat(sent, ";") ~= "unlock" then
        table.insert(found, "a locked screen is unlocked once while the unlock has not settled, sent " .. table.concat(sent, ";"))
    end
    state.stable = {[1] = true}
    tick(state)
    if #sent ~= 2 or sent[2] ~= "unlock" then
        table.insert(found, "a screen still locked after its unlock settled is unlocked again, sent " .. table.concat(sent, ";"))
    end
    state.transition, state.stable[2] = 2, true
    json.savefile(path.join(results, "verdict.json"), {test = {spawned = 1, exit = 0}})
    tick(state)
    if sent[3] ~= "settle" then
        table.insert(found, "once the application is frontmost the emulator is asked to settle, sent " .. tostring(sent[3]))
    end
    state.programs = {["90"] = "/Applications/Probe.app/Probe"}
    tick(state)
    if #sent ~= 3 then
        table.insert(found, "no snapshot is taken before the settle has started, sent " .. table.concat(sent, ";"))
    end
    state.transition = 3
    tick(state)
    if #sent ~= 3 then
        table.insert(found, "no snapshot is taken before the screen has settled, sent " .. table.concat(sent, ";"))
    end
    state.stable[3] = true
    tick(state)
    if sent[4] ~= "snapshot /run/app-0.png" then
        table.insert(found, "a settled screen is snapshot into the run, sent " .. tostring(sent[4]))
    end
    tick(state)
    state.snapshots = {["/run/app-0.png"] = true}
    tick(state)
    if sent[5] ~= "tap 160 260" then
        table.insert(found, "a step is taken once the snapshot before it is written, sent " .. tostring(sent[5]))
    end
    tick(state)
    state.transition = 4
    tick(state)
    if sent[6] ~= "settle" or #sent ~= 6 then
        table.insert(found, "the emulator is asked to settle once the step's input is complete, sent " .. table.concat(sent, ";"))
    end
    state.transition, state.stable[5] = 5, true
    tick(state)
    state.snapshots["/run/app-1.png"] = true
    local done = tick(state)
    if sent[7] ~= "snapshot /run/app-1.png" or not done or #driver.shots ~= 2 or driver.failure or driver.application.pid ~= "90" then
        table.insert(found, string.format("after its last step and snapshot the launch is done with two shots, sent %s, done %s",
                                          table.concat(sent, ";"), tostring(done)))
    end

    driver, sent, tick = driven()
    json.savefile(path.join(results, "verdict.json"), {test = {spawned = 1, exit = 4}})
    if not tick({ready = true}) or driver.failure ~= "refused" then
        table.insert(found, "a launch charon-sblaunch could not finish ends the run as refused")
    end
    driver, sent, tick = driven()
    json.savefile(path.join(results, "verdict.json"), {test = {spawned = 1, exit = 0}})
    state = {ready = true}
    tick(state)
    state.programs, state.exits = {["90"] = "/Applications/Probe.app/Probe"}, {["90"] = {status = 0, signal = 11}}
    if not tick(state) or driver.failure ~= "exited" or driver.exit.signal ~= 11 then
        table.insert(found, "an application that dies ends the run with its signal")
    end

    -- until-exit holds the guest instead of asking the emulator for anything, and lets go on the
    -- application's own end or on the run's budget, whichever comes first, saying which. The verdict
    -- is the one the real runner writes when charon-sblaunch returns, which is at launch, as soon as
    -- the application is frontmost. Measured on an iPhone4,1 6.1.3 run of a probe application that lives
    -- for 20 guest seconds (`launch ... until-exit -s 60`): the runner's verdict file read
    -- {"machine":"iPhone4,1","system":"6.1.3 (10B329)","uikit":1,"UIApplication":1,"runner_seconds":17.924,
    --  "test":{"path":"/usr/libexec/charon-sblaunch","spawned":1,"spawn_error":0,"timed_out":0,"output":1,
    --  "seconds":17.843,"exit":0}}
    -- while the application was at its second second of twenty, and the driver, which took the file for the
    -- end of the budget, quit the guest 222 host seconds into the run with the application still running.
    -- The file's existence says the application was launched, and nothing about the application's end.
    local SCALE, BUDGET = 10, 240
    local now = 0
    local function held(steps)
        os.tryrm(results)
        os.mkdir(results)
        now = 0
        local sent, driver = {}, emulator.launch_driver({results = results, run = "/run",
                                                           application = "/Applications/Probe.app", steps = steps,
                                                           seconds = BUDGET, scale = SCALE, clock = function () return now end})
        local function tick(state)
            return driver.stop(state, function (command) table.insert(sent, command) end)
        end
        json.savefile(path.join(results, "verdict.json"),
                      {machine = "iPhone4,1", system = "6.1.3 (10B329)", uikit = 1, UIApplication = 1, runner_seconds = 17.924,
                       test = {path = "/usr/libexec/charon-sblaunch", spawned = 1, spawn_error = 0, timed_out = 0, output = 1,
                               seconds = 17.843, exit = 0}})
        local state = {ready = true, programs = {["90"] = "/Applications/Probe.app/Probe"}}
        tick(state)
        state.transition = 1
        tick(state)
        state.stable = {[1] = true}
        tick(state)
        tick(state)
        state.snapshots = {["/run/app-0.png"] = true}
        tick(state)
        return driver, sent, tick, state
    end
    local driver, sent, tick, state = held({"until-exit"})
    if #sent ~= 2 or sent[2] ~= "snapshot /run/app-0.png" then
        table.insert(found, "the snapshot before until-exit is taken as any other, sent " .. table.concat(sent, ";"))
    end
    now = (BUDGET * SCALE - 1) * 1000
    if tick(state) or driver.held or #sent ~= 2 then
        table.insert(found, "a verdict written at launch does not end the hold while the application runs and the budget is not spent, held "
                            .. tostring(driver.held) .. ", sent " .. table.concat(sent, ";"))
    end
    state.exits = {["90"] = {status = 0, signal = 0}}
    if tick(state) or driver.failure then
        table.insert(found, "an application that ends while until-exit holds is not a failure, " .. tostring(driver.failure))
    end
    if driver.held ~= "exited" or sent[3] ~= "settle" then
        table.insert(found, "until-exit settles once the application has ended, held " .. tostring(driver.held) .. ", sent " .. table.concat(sent, ";"))
    end
    -- The run goes on after the application's end: the exit stays in the log, so every later tick sees it, and it
    -- is the hold's own end, not the application's death, however far the settle and the last snapshot have got
    -- (measured: the first fixed run held the probe for its 20 guest seconds and then failed it as "ended with
    -- status 0" at the tick after the settle).
    state.transition = 2
    tick(state)
    state.stable[2] = true
    local after = tick(state)
    state.snapshots["/run/app-1.png"] = true
    after = tick(state)
    if not after or driver.failure or #driver.shots ~= 2 or sent[4] ~= "snapshot /run/app-1.png" then
        table.insert(found, string.format("after the hold the frame is taken and the run is done, not failed, done %s, failure %s, shots %d, sent %s",
                                          tostring(after), tostring(driver.failure), #driver.shots, table.concat(sent, ";")))
    end
    driver, sent, tick, state = held({"until-exit"})
    now = BUDGET * SCALE * 1000
    tick(state)
    if driver.held ~= "deadline" or sent[3] ~= "settle" then
        table.insert(found, "until-exit settles when the budget, -s guest seconds at the time scale from the application being frontmost, is spent and says so, held "
                            .. tostring(driver.held) .. ", sent " .. table.concat(sent, ";"))
    end
    driver, sent, tick, state = held({"until-exit"})
    now = BUDGET * SCALE * 1000
    state.exits = {["90"] = {status = 0, signal = 0}}
    tick(state)
    if driver.held ~= "exited" then
        table.insert(found, "an application that ended is what the hold reports even when the budget is spent too, held " .. tostring(driver.held))
    end
    local refused = fixtures.refusal(function ()
        emulator.launch_driver({results = results, run = "/run", application = "/Applications/Probe.app", steps = {"until-exit"}})
    end)
    if not refused or not refused:find("the run gave no seconds", 1, true) then
        table.insert(found, "until-exit has no budget to hold for unless the run gives its seconds: " .. tostring(refused))
    end
    driver, sent, tick, state = held({})
    if tick(state) ~= true then
        table.insert(found, "a launch with no step after the first snapshot is done")
    end
end

-- A run's program output: the three states told apart, because silence reads as a program that
-- printed nothing when it is a program whose output was lost. A run folder, a capture flag and what
-- the two files hold, which is all the function looks at.
local function output_step(emulator, folder, found)
    local function run(stdout, output)
        os.tryrm(folder)
        os.mkdir(path.join(folder, "results"))
        if stdout then
            io.writefile(path.join(folder, "results", "test.stdout"), stdout)
        end
        local said = emulator.report_output(folder, output)
        return said
    end
    if not run("hello from the guest\n", 1) then
        table.insert(found, "a run whose program wrote to stdout prints it and says so")
    end
    if run("", 1) then
        table.insert(found, "a program that wrote nothing is not reported as having written something")
    end
    if run("hello from the guest\n", 0) then
        table.insert(found, "a verdict that says the output was not captured keeps the file's text off the host, whatever it holds")
    end
end

-- What an install put in: every file, its size and its whole hash, which is what the caller prints
-- and what a band holds against the build. The size is the part two installs can be compared on, a
-- signature being not reproducible.
local function files_step(emulator, folder, found)
    os.tryrm(folder)
    os.mkdir(path.join(folder, "usr", "libexec"))
    io.writefile(path.join(folder, "usr", "libexec", "probe"), "probe\n")
    io.writefile(path.join(folder, "usr", "libexec", "other"), "a longer payload\n")
    local described = emulator.describe_files(folder)
    if #described ~= 2 then
        table.insert(found, "an install describes every file it put in, described " .. #described)
    else
        if described[1].path ~= "usr/libexec/other" or described[2].path ~= "usr/libexec/probe" then
            table.insert(found, "the files an install describes are named in order, " .. described[1].path .. " then " .. described[2].path)
        end
        if described[1].size ~= 17 or described[2].size ~= 6 then
            table.insert(found, "an install describes each file with the size it has, " .. described[1].size .. " and " .. described[2].size)
        end
        if #described[1].hash ~= 64 or described[1].hash == described[2].hash then
            table.insert(found, "an install describes each file with its own whole hash, " .. described[1].hash)
        end
    end
    os.tryrm(folder)
end

function failures(opt)
    local emulator = import("emulator", {rootdir = opt.modules, anonymous = true})
    local debian = import("debian", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    verdicts(emulator, folder, found)
    home_step(emulator, folder, opt, found)
    deb_step(emulator, debian, folder, found)
    runner_job(emulator, folder, found)
    registration_step(emulator, debian, folder, found)
    launch_step(emulator, folder, found)
    runner_source(opt, found)
    timing_and_reports(emulator, folder, found)
    load_step(emulator, found)
    choice(emulator, found)
    concurrency(folder, opt.modules, found)
    queue_step(emulator, folder, opt, found)
    naming_step(emulator, found)
    copy_step(opt, found)
    prune_step(emulator, folder, found)
    held_image_step(emulator, fixtures.scratch(), found)
    output_step(emulator, folder, found)
    files_step(emulator, folder, found)
    os.tryrm(folder)
    return found
end
