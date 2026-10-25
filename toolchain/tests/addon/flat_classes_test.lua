local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})
local flat = import("flat_classes", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local SYMBOL = "_OBJC_CLASS_$_NSURLComponents"

local function ios6(sdk)
    return {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-Wno-incompatible-sysroot", "-isysroot", sdk}
end

local function binding(binary)
    local lines = {}
    for line in os.iorunv("nm", {"-m", binary}):gmatch("[^\n]+") do
        if line:find(SYMBOL, 1, true) then
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
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
    local cachefile = path.join(workspace.home(), "dyld", "6.0", "dyld_shared_cache_armv7")
    local reported = {}
    for _, entry in ipairs((dyld.missing_imports(cachefile, {app, outside}, output))) do
        table.insert(reported, entry[1] .. " " .. entry[2])
    end
    local text = table.concat(reported, "\n")
    if not text:find("outside _OBJC_CLASS_$_RevenantNotFlat", 1, true) then
        table.insert(found, "a flat-bound class outside the table passed the install check: " .. text)
    end
    if text:find("NSURLComponents", 1, true) then
        table.insert(found, "a flat-bound class in the table was reported missing: " .. text)
    end
    return found
end
