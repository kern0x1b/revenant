local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

local HEADER = table.concat({
    "@interface Image : NSObject",
    "- (id)transformed:(int)value NS_AVAILABLE(10_10, 8_0);",
    "- (id)unmarked:(int)value NS_AVAILABLE(10_10, 6_0);",
    "- (id)iosOnly:(int)value NS_AVAILABLE_IOS(7_1);",
    "- (id)macOnly:(int)value NS_AVAILABLE(10_10, NA);",
    "- (id)modern:(int)value API_AVAILABLE(macos(10.10), ios(8.0));",
    "- (id)absent:(int)value NS_AVAILABLE(10_10, 8_0);",
    "@property (nonatomic, readonly) int count NS_AVAILABLE(NA, 7_0);",
    "@end",
    "",
}, "\n")

local RELEASED = {Image = {instance = {"transformed:", "unmarked:", "iosOnly:", "macOnly:", "modern:", "count"}}}

function failures()
    local found = {}
    local set = lowered.device_members_in(HEADER, RELEASED, {})
    local members = set.classes.Image or {}
    for _, key in ipairs({"-transformed:", "-iosOnly:", "-modern:", "-count"}) do
        if not members[key] then
            table.insert(found, "a member the release implements and an availability macro of the old form or the new one marks later than iOS 6.0 must be a device member: " .. key)
        end
    end
    for _, key in ipairs({"-unmarked:", "-macOnly:", "-absent:"}) do
        if members[key] then
            table.insert(found, "a member that is not marked later than iOS 6.0, or that the release does not implement, must not be a device member: " .. key)
        end
    end
    return found
end
