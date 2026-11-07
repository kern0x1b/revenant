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

    local uikit = "\t/System/Library/Frameworks/UIKit.framework/UIKit (compatibility version 1.0.0, current version 9126.2.4, weak)\n"
    local uikit_imports = "(undefined) weak external _OBJC_CLASS_$_UIFeedbackGenerator (from UIKit)\n"
        .. "(undefined) weak external _UIApplicationMissing (from UIKit)\n"
    local uikit_defined = {libUIKitBackports = "00012345 S _OBJC_CLASS_$_UIFeedbackGenerator\n"}
    arguments, notes = host.framework_retargets(uikit, uikit_imports, uikit_defined, {"libUIKitBackports"})
    expect("a framework the backports library does not fully export stays on the device's framework",
        #arguments == 0 and #notes == 1 and notes[1]:find("UIKit stays", 1, true) ~= nil,
        "got " .. table.concat(arguments, " ") .. " notes " .. table.concat(notes, "; "))

    arguments, notes = host.framework_retargets(linked:gsub("UserNotifications", "Other"), weak, defined, {"libUserNotificationsBackports"})
    expect("a framework the executable does not link is left alone", #arguments == 0 and #notes == 0,
        "got " .. table.concat(arguments, " ") .. " notes " .. table.concat(notes, "; "))
end
