local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})
local flat = import("flat_classes", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local SYMBOL = "_OBJC_CLASS_$_NSURLComponents"

local UIKIT_SYMBOL = "_OBJC_CLASS_$_UIPointerShape"

local function ios6(sdk)
    return {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-Wno-incompatible-sysroot", "-isysroot", sdk}
end

local FUNCTION = "_CTLineDraw"

local FUNCTION_PROBE = "#include <CoreText/CoreText.h>\nvoid *keep __attribute__((used)) = (void *)CTLineDraw;\nint main(void) { return 0; }\n"

local function binding(binary, symbol)
    local lines = {}
    for line in os.iorunv("nm", {"-m", binary}):gmatch("[^\n]+") do
        if line:find(symbol or SYMBOL, 1, true) then
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

local function function_failures(arguments, output, stubs, found)
    local source = path.join(output, "function.c")
    io.writefile(source, FUNCTION_PROBE)
    local object = path.join(output, "function.o")
    local log = path.join(output, "function.log")
    if os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-c", source, "-o", object}), {try = true, stdout = log, stderr = log}) ~= 0 then
        table.insert(found, "the armv7 iOS 6 CoreText probe does not compile: " .. (io.readfile(log) or ""))
        return
    end
    local plain = path.join(output, "function-plain")
    if os.execv(arguments.clang, table.join(ios6(arguments.sdk), {object, "-framework", "CoreText", "-o", plain}), {try = true, stdout = log, stderr = log}) ~= 0 then
        table.insert(found, "the CoreText control link failed: " .. (io.readfile(log) or ""))
        return
    end
    if not binding(plain, FUNCTION):find("(from CoreText)", 1, true) then
        table.insert(found, "the control link does not bind CTLineDraw to CoreText: " .. binding(plain, FUNCTION))
    end
    local tbd = io.readfile(path.join(stubs, "CoreText.framework", "CoreText.tbd"))
    if tbd:find("[%s,%[']" .. FUNCTION .. "'?[,%]%s]") then
        table.insert(found, "the CoreText stub still lists CTLineDraw")
    end
    local app = path.join(output, "function-app")
    local app_log = path.join(output, "function-app.log")
    local app_linked = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {object, "-framework", "CoreText", "-o", app},
                                flat.app_link_flags(arguments.sdk, stubs)), {try = true, stdout = app_log, stderr = app_log})
    if app_linked ~= 0 then
        table.insert(found, "the app link of the CoreText probe with the flat-class stubs failed: " .. (io.readfile(app_log) or ""))
        return
    end
    local bound = binding(app, FUNCTION)
    if bound:find("(from CoreText)", 1, true) or not bound:find("(dynamically looked up)", 1, true) then
        table.insert(found, "the CTLineDraw reference binds to CoreText instead of the flat namespace: " .. bound)
    end
end

function failures(arguments)
    local found = {}
    local output = workspace.run("flat-classes")
    os.rm(output)
    os.mkdir(output)
    local overlay = lowered.overlay(arguments.sdk, path.join(output, "overlay"))
    local include = lowered.include_directory(path.join(output, "overlay"))
    local main = path.join(output, "main.m")
    io.writefile(main, "#import <Foundation/Foundation.h>\nint main(void) { return [NSURLComponents class] ? 0 : 1; }\n")
    local object = path.join(output, "main.o")
    local log = path.join(output, "compile.log")
    local compiled = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-fobjc-arc", "-ivfsoverlay", overlay, "-I" .. include,
                                                          "-c", main, "-o", object}), {try = true, stdout = log, stderr = log})
    if compiled ~= 0 then
        table.insert(found, "the armv7 iOS 6 probe does not compile: " .. (io.readfile(log) or ""))
        return found
    end
    local plain = path.join(output, "plain")
    local plain_log = path.join(output, "plain.log")
    local linked = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-fobjc-link-runtime", object, "-framework", "Foundation", "-o", plain}),
                            {try = true, stdout = plain_log, stderr = plain_log})
    if linked ~= 0 then
        table.insert(found, "the control link failed: " .. (io.readfile(plain_log) or ""))
        return found
    end
    if not binding(plain):find("(from Foundation)", 1, true) then
        table.insert(found, "the control link does not bind NSURLComponents to Foundation, so the test cannot tell the stub apart: " .. binding(plain))
    end
    local stubs = path.join(output, "stubs")
    local app = path.join(output, "app")
    local app_log = path.join(output, "app.log")
    local flags = flat.app_link_flags(arguments.sdk, stubs)
    if not os.isfile(path.join(stubs, "Foundation.framework", "Foundation.tbd")) then
        table.insert(found, "the stub directory has no Foundation.tbd")
    end
    local app_linked = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-fobjc-link-runtime", object, "-framework", "Foundation", "-o", app}, flags),
                                {try = true, stdout = app_log, stderr = app_log})
    if app_linked ~= 0 then
        table.insert(found, "the app link with the flat-class stubs failed: " .. (io.readfile(app_log) or ""))
        return found
    end
    local bound = binding(app)
    if bound:find("(from Foundation)", 1, true) or not bound:find("(dynamically looked up)", 1, true) then
        table.insert(found, "the app's NSURLComponents reference binds to Foundation instead of the flat namespace: " .. bound)
    end
    local dyld = import("dyld", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})
    local outside_source = path.join(output, "outside.c")
    io.writefile(outside_source, "extern char OBJC_CLASS_$_RevenantNotFlat;\nvoid *keep __attribute__((used)) = &OBJC_CLASS_$_RevenantNotFlat;\nint main(void) { return 0; }\n")
    local outside_object = path.join(output, "outside.o")
    local outside = path.join(output, "outside")
    local outside_log = path.join(output, "outside.log")
    local outside_built = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-c", outside_source, "-o", outside_object}),
                                   {try = true, stdout = outside_log, stderr = outside_log})
    local outside_linked = outside_built == 0 and os.execv(arguments.clang, table.join(ios6(arguments.sdk), {outside_object, "-framework", "Foundation",
                                   "-Xlinker", "-U", "-Xlinker", "_OBJC_CLASS_$_RevenantNotFlat", "-o", outside}),
                                   {try = true, stdout = outside_log, stderr = outside_log})
    if outside_linked ~= 0 then
        table.insert(found, "the probe with a flat-bound class outside the table did not link: " .. (io.readfile(outside_log) or ""))
        return found
    end
    local uikit_main = path.join(output, "uikit.m")
    io.writefile(uikit_main, "#import <UIKit/UIKit.h>\nint main(void) { return [UIPointerShape class] && [UIPointerStyle class] ? 0 : 1; }\n")
    local uikit_object = path.join(output, "uikit.o")
    local uikit_log = path.join(output, "uikit.log")
    if os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-fobjc-arc", "-ivfsoverlay", overlay, "-I" .. include, "-c", uikit_main, "-o", uikit_object}),
                {try = true, stdout = uikit_log, stderr = uikit_log}) ~= 0 then
        table.insert(found, "the armv7 iOS 6 UIKit pointer probe does not compile: " .. (io.readfile(uikit_log) or ""))
        return found
    end
    local uikit_plain = path.join(output, "uikit-plain")
    if os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-fobjc-link-runtime", uikit_object, "-framework", "UIKit", "-o", uikit_plain}),
                {try = true, stdout = uikit_log, stderr = uikit_log}) ~= 0 then
        table.insert(found, "the UIKit control link failed: " .. (io.readfile(uikit_log) or ""))
        return found
    end
    if not binding(uikit_plain, UIKIT_SYMBOL):find("(from UIKit)", 1, true) then
        table.insert(found, "the control link does not bind UIPointerShape to UIKit: " .. binding(uikit_plain, UIKIT_SYMBOL))
    end
    local uikit_app = path.join(output, "uikit-app")
    if os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-fobjc-link-runtime", uikit_object, "-framework", "UIKit", "-o", uikit_app}, flat.app_link_flags(arguments.sdk, stubs)),
                {try = true, stdout = uikit_log, stderr = uikit_log}) ~= 0 then
        table.insert(found, "the app link of the UIKit pointer probe with the flat-class stubs failed: " .. (io.readfile(uikit_log) or ""))
        return found
    end
    local uikit_bound = binding(uikit_app, UIKIT_SYMBOL)
    if uikit_bound:find("(from UIKit)", 1, true) or not uikit_bound:find("(dynamically looked up)", 1, true) then
        table.insert(found, "the UIPointerShape reference binds to UIKit instead of the flat namespace: " .. uikit_bound)
    end
    local cachefile = path.join(workspace.home(), "dyld", "6.0", "dyld_shared_cache_armv7")
    local reported = {}
    for _, entry in ipairs((dyld.missing_imports(cachefile, {app, outside, uikit_app}, output))) do
        table.insert(reported, entry[1] .. " " .. entry[2])
    end
    local text = table.concat(reported, "\n")
    if not text:find("outside _OBJC_CLASS_$_RevenantNotFlat", 1, true) then
        table.insert(found, "a flat-bound class outside the table passed the install check: " .. text)
    end
    if text:find("UIPointer", 1, true) then
        table.insert(found, "a flat-bound UIKit pointer class in the table was reported missing: " .. text)
    end
    if text:find("NSURLComponents", 1, true) then
        table.insert(found, "a flat-bound class in the table was reported missing: " .. text)
    end
    function_failures(arguments, output, stubs, found)
    return found
end
