local USAGE = [[usage: ./xmakew l frameworks/WebKit/tools/probe-soft-links.lua [--tree DIR] [--output FILE]
  writes a C program that asks the phone for every constant PAL soft-links, framework by framework:
  PAL's soft-linked constant accessors assert when the symbol is not there, so on a release this old
  each absent constant is a crash waiting for the first page that reaches it, and the answer the probe
  prints is the finite list to guard. The constants are read from Source/WebCore/PAL/pal of the patched
  tree, the installed webkit package's unless --tree names one; the program goes to FILE or stdout.]]

local locations = {
    AVFoundation = "/System/Library/Frameworks/AVFoundation.framework/AVFoundation",
    CoreMedia = "/System/Library/Frameworks/CoreMedia.framework/CoreMedia",
    VideoToolbox = "/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox",
    UIKit = "/System/Library/Frameworks/UIKit.framework/UIKit",
    Contacts = "/System/Library/Frameworks/Contacts.framework/Contacts",
    Vision = "/System/Library/Frameworks/Vision.framework/Vision",
    PassKitCore = "/System/Library/PrivateFrameworks/PassKitCore.framework/PassKitCore",
    CoreMaterial = "/System/Library/PrivateFrameworks/CoreMaterial.framework/CoreMaterial",
    MediaExperience = "/System/Library/PrivateFrameworks/MediaExperience.framework/MediaExperience",
    DataDetectorsUI = "/System/Library/PrivateFrameworks/DataDetectorsUI.framework/DataDetectorsUI",
    ScreenCaptureKit = "/System/Library/Frameworks/ScreenCaptureKit.framework/ScreenCaptureKit",
    AppSSO = "/System/Library/PrivateFrameworks/AppSSO.framework/AppSSO",
    WebPrivacy = "/System/Library/PrivateFrameworks/WebPrivacy.framework/WebPrivacy"
}

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local given = tree.arguments({...}, {tree = "value", output = "value", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local pal = path.join(tree.engine_source(given.tree), "Source", "WebCore", "PAL", "pal")
    local found = {}
    for _, header in ipairs(os.files(path.join(pal, "**.h"))) do
        local text = io.readfile(header, {encoding = "binary"})
        for _, macro in ipairs({"SOFT_LINK_CONSTANT_FOR_HEADER", "SOFT_LINK_CONSTANT_MAY_FAIL_FOR_HEADER"}) do
            for framework, symbol in text:gmatch(macro .. "%(%s*PAL%s*,%s*([%w_]+)%s*,%s*([%w_]+)") do
                found[framework] = found[framework] or {}
                found[framework][symbol] = true
            end
        end
    end
    local out = {"#include <stdio.h>", "#include <dlfcn.h>", "", "int main(void)", "{",
                 "    void *handle; int missing = 0, present = 0;"}
    local skipped = {}
    for _, framework in ipairs(table.orderkeys(found)) do
        local where = locations[framework]
        if not where then
            table.insert(skipped, framework)
        else
            table.join2(out, {"", "    handle = dlopen(\"" .. where .. "\", RTLD_LAZY);", "    if (!handle)",
                              "        printf(\"FRAMEWORK MISSING " .. framework .. "\\n\");", "    else {"})
            for _, symbol in ipairs(table.orderkeys(found[framework])) do
                table.insert(out, "        if (dlsym(handle, \"" .. symbol .. "\")) present++;")
                table.insert(out, "        else { missing++; printf(\"missing " .. framework .. " " .. symbol .. "\\n\"); }")
            end
            table.insert(out, "    }")
        end
    end
    table.join2(out, {"", "    printf(\"present %d missing %d\\n\", present, missing);", "    return 0;", "}"})
    local program = table.concat(out, "\n") .. "\n"
    if given.output then
        io.writefile(given.output, program)
    else
        io.write(program)
    end
    if #skipped > 0 then
        io.stderr:print("install location unknown, not probed: " .. table.concat(skipped, ", "))
    end
end
