local aliases = import("host_alias", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local sources = path.join(backports, "src", "UserNotifications")
local fixtures = path.join(backports, "tests", "UserNotifications")

local function clang(args)
    os.vrunv("xcrun", table.join({"clang", "-fobjc-arc", "-target", "arm64-apple-macos13", "-isysroot", os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()}, args))
end

local function backport_files()
    local files = {}
    for _, name in ipairs({"UNNotificationAction.m", "UNNotificationAttachment.m", "UNNotificationCategory.m", "UNNotificationCategory+HiddenPreviews.m",
                           "UNNotificationContent.m", "UNNotificationRequest.m", "UNNotificationTrigger.m", "RevenantUserNotificationSupport.m"}) do
        table.insert(files, path.join(sources, name))
    end
    return files
end

function main()
    local out = workspace.run("backports-tests", "UserNotifications")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local schedule = path.join(out, "schedule")
    local values = path.join(fixtures, "main.m")
    local constants = aliases.flags(backport_files())
    clang({"-o", host, values, "-framework", "Foundation", "-framework", "UserNotifications"})
    clang(table.join({"-o", backport, values}, backport_files(), constants, {"-framework", "Foundation"}))
    clang(table.join({"-I" .. sources, "-o", schedule, path.join(fixtures, "schedule.m")}, backport_files(), constants, {"-framework", "Foundation"}))
    local attachment = path.join(out, "attachment")
    clang(table.join({"-I" .. sources, "-o", attachment, path.join(fixtures, "attachment.m")}, backport_files(), constants, {"-framework", "Foundation"}))
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    os.execv(schedule, {}, {stdout = schedule .. ".out"})
    os.execv(attachment, {}, {stdout = attachment .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host UserNotifications program printed nothing")
    assert(expected == got, "the backport UserNotifications differs from the host in " .. out)
    assert(io.readfile(schedule .. ".out") == "schedule ok\n", "the trigger-to-date conversion does not match in " .. out)
    assert(io.readfile(attachment .. ".out") == "attachment ok\n", "the attachment checks do not pass in " .. out)
end
