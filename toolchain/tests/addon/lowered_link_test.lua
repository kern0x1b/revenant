import("fixtures")

local PROBE = [[
#import <CoreLocation/CoreLocation.h>
int main(void) {
    CLLocation *location = [[CLLocation alloc] initWithLatitude:0 longitude:0];
    return location != nil ? 0 : 1;
}
]]

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local source = path.join(folder, "location.m")
    io.writefile(source, PROBE)
    local program = path.join(folder, "location")
    fixtures.run(folder, opt.clang, {"-target", "armv7-apple-ios6.0", "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-fno-objc-arc",
                                     "--ld-path=" .. opt.ld64, "-framework", "Foundation", "-framework", "CoreLocation", source, "-o", program})
    local libraries = fixtures.run(folder, "xcrun", {"otool", "-L", program})
    if libraries:find("_LocationEssentials", 1, true) then
        table.insert(found, "the armv7 program loads _LocationEssentials, which iOS 6 does not have: " .. libraries:trim())
    end
    if not libraries:find("/System/Library/Frameworks/CoreLocation.framework/CoreLocation", 1, true) then
        table.insert(found, "the armv7 program does not load CoreLocation: " .. libraries:trim())
    end
    local bindings = fixtures.run(folder, "xcrun", {"nm", "-m", program})
    if not bindings:find("(undefined) external _OBJC_CLASS_$_CLLocation (from CoreLocation)", 1, true) then
        table.insert(found, "CLLocation does not bind to CoreLocation: " .. bindings:trim())
    end
    os.tryrm(folder)
    return found
end
