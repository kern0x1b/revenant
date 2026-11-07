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

    local system = macho({dylib_command(0x0C, "/usr/lib/libSystem.B.dylib", 65536, 65536)})
    expect("a load command to a system library is left alone",
        #host.version_fixes(system, library) == 0 and refusal(function () host.check_load_versions("RNHost", system, library) end) == nil,
        "the system library's load command was changed or refused")
end
