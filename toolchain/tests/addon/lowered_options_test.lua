local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

local HEADER = "UNUserNotificationCenter.h"
local DIRECTORY = path.join("System", "Library", "Frameworks", "UserNotifications.framework", "Headers")
local DIRECT_ENUM = "typedef enum __attribute__((flag_enum, enum_extensibility(open))) UNNotificationPresentationOptions : NSUInteger UNNotificationPresentationOptions;\nenum UNNotificationPresentationOptions : NSUInteger {"
local OPTIONS_TYPEDEF = "typedef NS_OPTIONS(NSUInteger, UNNotificationPresentationOptions)"
local CAST_NONE = "= (UNNotificationPresentationOptions)0;"
local BANNER = "    UNNotificationPresentationOptionBanner API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0)) = (1 << 4),\n"

local function declares_directly(text, where, found)
    if not text:find(DIRECT_ENUM, 1, true) then
        table.insert(found, where .. " does not declare UNNotificationPresentationOptions as a direct enum with flag_enum, so the protocol block imports as Int")
    end
    if text:find(OPTIONS_TYPEDEF, 1, true) then
        table.insert(found, where .. " still declares UNNotificationPresentationOptions with NS_OPTIONS, whose swift-unavailable typedef makes the block import as Int")
    end
    if not text:find(CAST_NONE, 1, true) then
        table.insert(found, where .. " declares UNNotificationPresentationOptionNone without the cast to the enum, which C++ rejects from int")
    end
end

function failures(arguments)
    local found = {}
    local sdk_text = io.readfile(path.join(arguments.sdk, DIRECTORY, HEADER))

    local applied = lowered.member_header_text(sdk_text, HEADER)
    declares_directly(applied, "the record applied to the iPhoneOS SDK header", found)

    local start, stop = sdk_text:find(BANNER, 1, true)
    if not start then
        table.insert(found, "the iPhoneOS SDK header no longer has the Banner line this test changes, so the loud-failure check cannot run")
    else
        local changed = sdk_text:sub(1, start - 1) .. sdk_text:sub(stop + 1)
        local stopped
        try {
            function () lowered.member_header_text(changed, HEADER) end,
            catch {
                function (err) stopped = tostring(err) end
            }
        }
        if not stopped then
            table.insert(found, "a changed UNNotificationPresentationOptions block is passed through unlowered instead of stopping the generator")
        elseif not stopped:find("UNNotificationPresentationOptions", 1, true) then
            table.insert(found, "a changed UNNotificationPresentationOptions block stops the generator without naming the declaration: " .. stopped)
        end
    end

    local output = workspace.run("lowered-options")
    os.rm(output)
    os.mkdir(output)
    local vfs = lowered.overlay(arguments.sdk, path.join(output, "overlay"))
    local external = io.readfile(vfs):match('"name": "' .. HEADER .. '", "type": "file", "external%-contents": "([^"]+)"')
    if not external then
        table.insert(found, "the overlay maps no " .. HEADER .. " for UserNotifications")
    else
        declares_directly(io.readfile(external), "the lowered " .. HEADER, found)
    end
    return found
end
