local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

local PROBE = table.concat({
    "#import <Foundation/Foundation.h>",
    "id probeStatus(void) { return NSURLUbiquitousItemDownloadingStatusKey; }",
    "id probeDownloaded(void) { return NSURLUbiquitousItemIsDownloadedKey; }",
    "",
}, "\n")

function failures(arguments)
    local found = {}
    local output = workspace.run("lowered-import")
    os.rm(output)
    os.mkdir(output)
    local vfs = lowered.overlay(arguments.sdk, path.join(output, "overlay"))
    local source = path.join(output, "probe.m")
    io.writefile(source, PROBE)
    local object = path.join(output, "probe.o")
    local log = path.join(output, "compile.log")
    local built = os.execv(arguments.clang, {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-Wno-incompatible-sysroot",
                                             "-isysroot", arguments.sdk, "-ivfsoverlay", vfs, "-fobjc-arc", "-c", source, "-o", object},
                           {try = true, stdout = log, stderr = log})
    if built ~= 0 then
        table.insert(found, "the probe does not compile for armv7 iOS 6 with the lowered Foundation headers: " .. (io.readfile(log) or ""))
        return found
    end
    local bindings = os.iorunv("xcrun", {"nm", "-m", object})
    if not bindings:find("(undefined) weak external _NSURLUbiquitousItemDownloadingStatusKey", 1, true) then
        table.insert(found, "NSURLUbiquitousItemDownloadingStatusKey does not bind weakly for armv7 iOS 6, where Foundation has no such symbol " ..
                            "and a strong import stops the image from loading: " .. bindings:trim())
    end
    if not bindings:find("(undefined) external _NSURLUbiquitousItemIsDownloadedKey", 1, true) then
        table.insert(found, "NSURLUbiquitousItemIsDownloadedKey does not bind strongly for armv7 iOS 6, where Foundation exports it: " .. bindings:trim())
    end
    return found
end
