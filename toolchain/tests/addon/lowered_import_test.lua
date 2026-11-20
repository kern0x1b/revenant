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
    local weak = lowered.weak_absence()
    local present = "NSURLUbiquitousItemIsDownloadedKey"
    local declarations = {}
    for _, file in ipairs(os.files(path.join(output, "overlay", "**", "*.h"))) do
        for line in io.lines(file) do
            local code = (line:gsub("//.*$", ""))
            for _, name in ipairs(table.join(weak, {present})) do
                if not declarations[name] and code:find(name, 1, true) and code:find(";", 1, true)
                   and (code:find("extern", 1, true) or code:find("EXTERN", 1, true) or code:find("EXPORT", 1, true)) then
                    declarations[name] = code
                end
            end
        end
    end
    local strong, absent = {}, {}
    for _, name in ipairs(weak) do
        local line = declarations[name]
        if not line then
            table.insert(absent, name)
        elseif not line:find("weak_import", 1, true) and not line:find("API_AVAILABLE", 1, true) then
            table.insert(strong, name)
        end
    end
    if #absent > 0 then
        table.insert(found, "the lowered headers do not declare the device-absent members " .. table.concat(absent, ", "))
    end
    if #strong > 0 then
        table.insert(found, "the lowered headers bind device-absent members strongly: " .. table.concat(strong, ", "))
    end
    local function strong_declaration(line)
        return line:find(";", 1, true) and not line:find("weak_import", 1, true)
               and not line:find("API_AVAILABLE", 1, true)
    end
    if not strong_declaration("extern NSString * const NSURLUbiquitousItemDownloadingStatusKey;") then
        table.insert(found, "the weak-binding check cannot detect a strong device-absent declaration")
    end
    if strong_declaration(declarations[weak[1]] or "") then
        table.insert(found, "the weak-binding check mistook a weak device-absent declaration for a strong one")
    end
    local present_line = declarations[present] or ""
    if not present_line:find(";", 1, true) then
        table.insert(found, present .. " has no lowered declaration to check for a strong binding")
    elseif present_line:find("weak_import", 1, true) then
        table.insert(found, present .. " is exported by the iOS 6 dyld cache, so its lowered declaration must stay strong")
    end
    io.write("lowered_import: " .. #weak .. " device-absent externs, 0 strong, " .. present .. " stays strong\n")
    return found
end
