local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local TOOLS = path.join(ROOT, "frameworks", "ReactNative", "tools")
local ENTITLEMENTS = path.join(TOOLS, "data", "rnhost.entitlements")

local host = import("host_install", {rootdir = TOOLS, anonymous = true})

local function expect(name, condition, detail)
    if not condition then
        raise("%s: %s", name, detail)
    end
    print(name .. ": passes")
end

local function refusal(check)
    local message
    try { check, catch { function (errors) message = tostring(errors) end } }
    return message
end

local function word(value)
    return string.char(value % 256, math.floor(value / 256) % 256, math.floor(value / 65536) % 256, math.floor(value / 16777216) % 256)
end

local function dylib_command(command, name, current, compatibility)
    local text = name .. "\0"
    while #text % 4 ~= 0 do
        text = text .. "\0"
    end
    return word(command) .. word(24 + #text) .. word(24) .. word(2) .. word(current) .. word(compatibility) .. text
end

local function macho(commands)
    local body = table.concat(commands)
    return word(0xFEEDFACE) .. word(12) .. word(9) .. word(6) .. word(#commands) .. word(#body) .. word(0) .. body
end

function main()
    local value = os.iorunv("plutil", {"-extract", "aps-environment", "raw", "-o", "-", ENTITLEMENTS}):trim()
    expect("the host entitlements declare aps-environment", value == "development", "aps-environment is " .. value)

    local first = host.signing_arguments(ENTITLEMENTS, 1, "RNHost")
    expect("the executable is signed with the entitlements", first[1] == "-S" .. ENTITLEMENTS and first[2] == "RNHost" and #first == 2,
        "got " .. table.concat(first, " "))

    local other = host.signing_arguments(ENTITLEMENTS, 2, "libUIKitBackports.dylib")
    expect("a framework is signed without entitlements", other[1] == "-S" and other[2] == "libUIKitBackports.dylib" and #other == 2,
        "got " .. table.concat(other, " "))

    local sdk = "/System/Library/Frameworks/UserNotifications.framework/UserNotifications"
    local linked = "\t" .. sdk .. " (compatibility version 1.0.0, current version 1.0.0, weak)\n"
    local weak = "                 (undefined) weak external _UNNotificationDefaultActionIdentifier (from UserNotifications)\n"
    local defined = {libUserNotificationsBackports = "0001cc6c D _UNNotificationDefaultActionIdentifier\n"}
    local arguments, notes = host.framework_retargets(linked, weak, defined, {"libUserNotificationsBackports"})
    expect("a weak import the backports library covers is retargeted to it",
        #arguments == 3 and arguments[1] == "-change" and arguments[2] == sdk and arguments[3] == "@executable_path/Frameworks/libUserNotificationsBackports.dylib" and #notes == 0,
        "got " .. table.concat(arguments, " ") .. " notes " .. table.concat(notes, "; "))

    local partial = weak .. "(undefined) weak external _UNMissingSymbol (from UserNotifications)\n"
    arguments, notes = host.framework_retargets(linked, partial, defined, {"libUserNotificationsBackports"})
    expect("a framework the backports library does not fully export stays on the device's framework",
        #arguments == 0 and #notes == 1 and notes[1]:find("UserNotifications stays", 1, true) ~= nil,
        "got " .. table.concat(arguments, " ") .. " notes " .. table.concat(notes, "; "))

    local cg = "\t/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics (compatibility version 64.0.0, current version 1965.2.3, weak)\n"
    local cg_imports = "(undefined) weak external _CGContextDrawImage (from CoreGraphics)\n"
    local cg_defined = {libCoreGraphicsBackports = "00012345 T _CGContextDrawImage\n"}
    arguments, notes = host.framework_retargets(cg, cg_imports, cg_defined, {"libCoreGraphicsBackports"})
    expect("a framework the release has stays on the device's framework even when the library exports all of it",
        #arguments == 0 and #notes == 0, "got " .. table.concat(arguments, " ") .. " notes " .. table.concat(notes, "; "))

    arguments, notes = host.framework_retargets(linked:gsub("UserNotifications", "Other"), weak, defined, {"libUserNotificationsBackports"})
    expect("a framework the executable does not link is left alone", #arguments == 0 and #notes == 0,
        "got " .. table.concat(arguments, " ") .. " notes " .. table.concat(notes, "; "))

    local listing = "RNHost-probe_2026-11-07-170000_iPhone.crash\nRNHost-other_2026-11-07.crash\nRNHost-probe_2026-11-06.plist\n"
        .. "RNHost-probe2_2026-11-05.crash\nnotes.txt\n\n  RNHost-probe_2026-11-08.ips  \n"
    local reports = host.crash_reports(listing, "RNHost-probe")
    expect("diagnostics takes the crash reports of its own executable only, in name order",
        table.concat(reports, ",") == "RNHost-probe_2026-11-06.plist,RNHost-probe_2026-11-07-170000_iPhone.crash,RNHost-probe_2026-11-08.ips",
        "got " .. table.concat(reports, ","))
    expect("a listing without crash reports gives none", #host.crash_reports("", "RNHost-probe") == 0, "got a report")

    local plist = path.join(os.tmpdir(), "host-install-test-" .. os.getpid() .. ".plist")
    io.writefile(plist, '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>\n'
        .. '<key>CFBundleShortVersionString</key>\n<string>0.1.0</string>\n<key>CFBundleVersion</key>\n<string>42</string>\n</dict></plist>\n')
    local short = host.plist_value(plist, "CFBundleShortVersionString")
    local build = host.plist_value(plist, "CFBundleVersion")
    local absent = host.plist_value(plist, "CFBundleIdentifier")
    os.rm(plist)
    expect("diagnostics reads a key of a plist, and a missing key gives nothing", short == "0.1.0" and build == "42" and absent == nil,
        "got " .. tostring(short) .. " " .. tostring(build) .. " " .. tostring(absent))

    local repeated = host.duplicate_install_names(linked .. linked)
    expect("a library loaded by two load commands is found", #repeated == 1 and repeated[1] == sdk,
        "got " .. table.concat(repeated, ", "))
    expect("a library loaded once is not reported", #host.duplicate_install_names(linked) == 0,
        "got " .. table.concat(host.duplicate_install_names(linked), ", "))

    local refused = refusal(function () host.check_install_names("RNHost", linked) end)
    expect("a single load command passes the stage check", refused == nil, "the check refused one load command: " .. tostring(refused))
    refused = refusal(function () host.check_install_names("RNHost", linked .. linked) end)
    expect("two load commands for one library fail the stage with the library named",
        refused ~= nil and refused:find("RNHost has two load commands for " .. sdk, 1, true) ~= nil,
        "message " .. tostring(refused))

    local bundled = "@executable_path/Frameworks/libUserNotificationsBackports.dylib"
    local executable = macho({dylib_command(0x80000018, bundled, 65536, 65536)})
    local library = {[bundled] = {current = 0, compatibility = 0}}
    local fixes = host.version_fixes(executable, library)
    local synced = host.apply_version_fixes(executable, fixes)
    local record = host.dylib_records(synced)[1]
    expect("a load command takes the versions of the bundled library it points to",
        #fixes == 2 and record.name == bundled and record.compatibility == 0 and record.current == 0,
        "got " .. #fixes .. " fixes, compatibility " .. tostring(record.compatibility) .. ", current " .. tostring(record.current))
    expect("a load command with the library's versions passes the version check",
        refusal(function () host.check_load_versions("RNHost", synced, library) end) == nil,
        "the check refused it: " .. tostring(refusal(function () host.check_load_versions("RNHost", synced, library) end)))

    local above = {[bundled] = {current = 65536, compatibility = 131072}}
    local raised = host.apply_version_fixes(executable, host.version_fixes(executable, above))
    local message = refusal(function () host.check_load_versions("RNHost", raised, above) end)
    expect("a bundled library whose compatibility version is above its current version fails the stage with both named",
        message ~= nil and message:find("RNHost loads " .. bundled, 1, true) ~= nil and message:find("2.0.0", 1, true) ~= nil and message:find("1.0.0", 1, true) ~= nil,
        "message " .. tostring(message))

    local uikit = "@executable_path/Frameworks/libUIKitBackports.dylib"
    local installed = "/usr/lib/revenant/org.revenant.backports/libUIKitBackports.dylib"
    local bundled_uikit = {[uikit] = {current = 0, compatibility = 0}}
    for _, name in ipairs({installed, uikit}) do
        local overlay = macho({dylib_command(0x0C, name, 65536, 65536)})
        local dependent = refusal(function () host.check_dependent_versions("libswiftUniformTypeIdentifiers.dylib", overlay, bundled_uikit) end)
        expect("a Swift library that needs a newer Backports library than the bundled one fails the stage with both named (" .. name:sub(1, 5) .. ")",
            dependent ~= nil and dependent:find("libswiftUniformTypeIdentifiers.dylib requires libUIKitBackports.dylib", 1, true) ~= nil
                and dependent:find("1.0.0", 1, true) ~= nil and dependent:find("0.0.0", 1, true) ~= nil,
            "message " .. tostring(dependent))
    end
    local satisfied = macho({dylib_command(0x0C, installed, 0, 0)})
    expect("a Swift library whose requirement the bundled Backports library meets passes",
        refusal(function () host.check_dependent_versions("libswiftCore.dylib", satisfied, bundled_uikit) end) == nil,
        "the check refused a satisfied requirement")
    local elsewhere = macho({dylib_command(0x0C, "/usr/lib/libSystem.B.dylib", 65536, 65536)})
    expect("a Swift library that loads no Backports library is left alone",
        refusal(function () host.check_dependent_versions("libswiftCore.dylib", elsewhere, bundled_uikit) end) == nil,
        "the check refused a library that loads none")

    local system = macho({dylib_command(0x0C, "/usr/lib/libSystem.B.dylib", 65536, 65536)})
    expect("a load command to a system library is left alone",
        #host.version_fixes(system, library) == 0 and refusal(function () host.check_load_versions("RNHost", system, library) end) == nil,
        "the system library's load command was changed or refused")

    expect("diagnostics removes the screenshot it took from the phone",
        host.screenshot_removal(host.screenshot_remote("worklets-probe")) == "rm -f /tmp/diagnostics-worklets-probe.png",
        "got " .. host.screenshot_removal(host.screenshot_remote("worklets-probe")))
    expect("diagnostics removes nothing but its own screenshot",
        refusal(function () host.screenshot_removal("/tmp/screenshot.png") end) ~= nil
            and refusal(function () host.screenshot_removal("/tmp/diagnostics-../../var/x.png") end) ~= nil,
        "a path outside the diagnostics screenshots was accepted")

    local base = os.iorunv("mktemp", {"-d"}):trim()
    local names = {"libFoundationBackports", "libCoreTextBackports", "libUIKitBackports", "libUserNotificationsBackports", "libCoreGraphicsBackports",
                   "libGraphicsBackports", "libCoreFoundationBackports", "libSystemBackports", "libIOSurfaceBackports", "libWebKitBackports", "libMapKitBackports",
                   "libCoreLocationBackports", "libSecurityBackports", "libContactsBackports", "libLocalAuthenticationBackports", "libTLSBackports"}
    local partial = path.join(base, "partial")
    os.mkdir(partial)
    for _, name in ipairs(names) do
        if name ~= "libSecurityBackports" and name ~= "libTLSBackports" then
            io.writefile(path.join(partial, name .. ".dylib"), "")
        end
    end
    expect("a folder's Backports libraries are read as they are", #host.backports_libraries(partial) == 14,
        "got " .. #host.backports_libraries(partial))

    local otool = "\t/usr/lib/revenant/org.revenant.backports/libMapKitBackports.dylib (compatibility version 1.0.0, current version 1.0.0)\n"
        .. "\t/usr/lib/revenant/org.revenant.backports/libTLSBackports.dylib (compatibility version 1.0.0, current version 1.0.0)\n"
        .. "\t/System/Library/Frameworks/UIKit.framework/UIKit (compatibility version 1.0.0, current version 1.0.0)\n"
    local lacking = host.missing_backports(otool, {"libMapKitBackports"})
    expect("stage names each Backports library the host loads and the folder lacks",
        #lacking == 1 and lacking[1] == "libTLSBackports", "got " .. table.concat(lacking, ", "))
    expect("a host whose Backports libraries the folder carries lacks none",
        #host.missing_backports(otool, {"libMapKitBackports", "libTLSBackports"}) == 0, "a library was named")

    local layout = path.join("share", "root", "usr", "lib", "revenant", "org.revenant.backports")
    local store = path.join(base, "store")
    local older, newer = path.join(base, "generation-a"), path.join(base, "generation-b")
    local key, other = "a800f513dca84e78a72a5c1eb2da98e9", "d50b2a6f3c1e4b7a9d8e0f123456789a"
    os.mkdir(path.join(older, layout))
    os.mkdir(path.join(newer, layout))
    for _, name in ipairs(names) do
        io.writefile(path.join(older, layout, name .. ".dylib"), "")
    end
    io.writefile(path.join(newer, layout, "libFoundationBackports.dylib"), "")
    os.mkdir(store)
    os.vrunv("ln", {"-s", older, path.join(store, key)})
    os.vrunv("ln", {"-s", newer, path.join(store, other)})
    os.vrunv("touch", {"-t", "203001010000", newer})
    expect("a store generation is named by its key, not by the newest modification",
        host.backports_generation(store, key) == path.join(store, key, layout)
            and #host.backports_libraries(host.backports_generation(store, key)) == 16,
        "got " .. host.backports_generation(store, key))
    expect("the generation of another key is read on its own, with the libraries it carries",
        #host.backports_libraries(host.backports_generation(store, other)) == 1,
        "got " .. #host.backports_libraries(host.backports_generation(store, other)))
    expect("a key that no generation has is refused",
        refusal(function () host.backports_generation(store, "0123456789abcdef0123456789abcdef") end) ~= nil,
        "a missing key was accepted")
    expect("a key that is not hexadecimal is refused, so no path leaves the store",
        refusal(function () host.backports_generation(store, "../generation-a") end) ~= nil,
        "a path outside the store was accepted")
    os.vrunv("rm", {"-rf", base})

    do
        local base = os.tmpfile() .. "-packages"
        os.mkdir(base)
        local json = import("core.base.json")
        json.savefile(path.join(base, "org.revenant.backports.json"), {name = "org.revenant.backports", version = "0.8.18+9772f8d3"})
        json.savefile(path.join(base, "org.revenant.swift-runtime-8e5fdec8.json"), {name = "org.revenant.swift-runtime-8e5fdec8", version = "0.8.18+8e5fdec8"})
        local listing = table.concat({
            "RNHost:",
            "\t/usr/lib/revenant/org.revenant.swift-runtime-8e5fdec8/libswiftCore.dylib (compatibility version 0.0.0, current version 0.0.0)",
            "\t/usr/lib/revenant/org.revenant.backports/libUIKitBackports.dylib (compatibility version 1.0.0, current version 1.0.0)",
            "\t/usr/lib/revenant/org.revenant.backports/libFoundationBackports.dylib (compatibility version 1.0.0, current version 1.0.0)",
            "\t/System/Library/Frameworks/UIKit.framework/UIKit (compatibility version 1.0.0, current version 1.0.0)",
            ""}, "\n")
        local packages = host.shared_packages(listing, {base})
        expect("a shared stage lists each package folder the host loads once, with the version of its description",
            #packages == 2 and packages[1].name == "org.revenant.backports" and packages[1].version == "0.8.18+9772f8d3"
            and packages[2].name == "org.revenant.swift-runtime-8e5fdec8" and packages[2].version == "0.8.18+8e5fdec8",
            "the package list is " .. #packages .. " entries long or has other names or versions")
        local message = refusal(function () host.shared_packages(listing, {path.join(base, "none")}) end)
        expect("a package without a description is refused by name", message ~= nil and message:find("org.revenant.backports", 1, true) ~= nil,
            "a package with no description was accepted or the refusal does not name it")
        expect("the phone's versions that match raise no problem", #host.version_mismatches(packages,
            {["org.revenant.backports"] = "0.8.18+9772f8d3", ["org.revenant.swift-runtime-8e5fdec8"] = "0.8.18+8e5fdec8"}) == 0, "a matching version was reported")
        local problems = host.version_mismatches(packages, {["org.revenant.backports"] = "0.8.18+2396e86d"})
        expect("another version and a missing package are each reported by name", #problems == 2 and problems[1]:find("0.8.18+2396e86d", 1, true) ~= nil
            and problems[2]:find("swift-runtime-8e5fdec8", 1, true) ~= nil and problems[2]:find("not installed", 1, true) ~= nil,
            "the problems are " .. table.concat(problems, " | "))
        os.vrunv("rm", {"-rf", base})
    end
end
