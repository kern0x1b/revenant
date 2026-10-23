local BACKPORTS = "/usr/lib/revenant/org.revenant.backports/"

local SYSTEM_LIBRARIES = {
    ["/usr/lib/libSystem.B.dylib"] = true,
    ["/usr/lib/libobjc.A.dylib"] = true,
    ["/usr/lib/libc++.1.dylib"] = true,
    ["/usr/lib/libicucore.A.dylib"] = true,
}

local IOS6_FRAMEWORKS = {
    AVFoundation = true, AddressBook = true, AddressBookUI = true, AudioToolbox = true, CFNetwork = true,
    CoreFoundation = true, CoreGraphics = true, CoreLocation = true, CoreMedia = true, CoreMotion = true,
    CoreText = true, CoreVideo = true, EventKit = true, EventKitUI = true, Foundation = true, GameKit = true,
    ImageIO = true, MapKit = true, MediaPlayer = true, MessageUI = true, MobileCoreServices = true, OpenGLES = true,
    QuartzCore = true, Security = true, Social = true, StoreKit = true, SystemConfiguration = true, UIKit = true,
}

local function allowed(dylib)
    if string.sub(dylib, 1, #BACKPORTS) == BACKPORTS then
        return true
    end
    if SYSTEM_LIBRARIES[dylib] then
        return true
    end
    local framework = string.match(dylib, "^/System/Library/Frameworks/([%w_]+)%.framework/")
    return framework ~= nil and IOS6_FRAMEWORKS[framework] == true
end

function main(binary)
    assert(binary and os.isfile(binary), "the probe is not linked: " .. tostring(binary))
    local text = os.iorunv("/usr/bin/otool", {"-L", binary})
    local loads, refused, backports = {}, {}, 0
    for line in text:gmatch("[^\n]+") do
        local dylib = string.match(line, "^%s+(%S+) %(")
        if dylib then
            table.insert(loads, dylib)
            if string.sub(dylib, 1, #BACKPORTS) == BACKPORTS then
                backports = backports + 1
            end
            if not allowed(dylib) then
                table.insert(refused, dylib)
            end
        end
    end
    print(text)
    assert(backports > 0, "the probe links no Backports library")
    assert(#refused == 0, "the probe loads libraries iOS 6 does not have, or not a Backports library: " .. table.concat(refused, ", "))
    print(string.format("probe ok: %d load commands, %d from Backports, all of them iOS 6 libraries", #loads, backports))
end
