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
end
