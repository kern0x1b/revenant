local BACKPORTS = "/usr/lib/revenant/org.revenant.backports/"

local function imports(file)
    local found, weak = {}, {}
    for line in os.iorunv("nm", {"-m", file}):gmatch("[^\n]+") do
        local symbol, library = line:match("%(undefined%) [%w ]-external (%S+) %(from (.-)%)")
        if symbol then
            found[symbol] = library
            weak[symbol] = line:find("weak external", 1, true) ~= nil
        end
    end
    return found, weak
end

local function binds(file)
    local found = {}
    for line in os.iorunv("xcrun", {"dyld_info", "-fixups", file}):gmatch("[^\n]+") do
        local library, symbol = line:match("%sbind%s+([^/%s]+)/(_OBJC_%S+)")
        if symbol then
            found[symbol] = found[symbol] or {}
            table.insert(found[symbol], library)
        end
    end
    return found
end

local function dependencies(file)
    local found = {}
    for line in os.iorunv("otool", {"-L", file}):gmatch("[^\n]+") do
        local install = line:match("^%s+(%S+) %(")
        if install then
            found[install] = true
        end
    end
    return found
end

local function build_backports(e, corpus, o, here)
    local sources = path.join(e.root, "frameworks", "Backports", "src")
    local folder = o("backports")
    os.mkdir(folder)
    local function object(source, name)
        corpus.armv7(e, {"-fobjc-arc", "-w", "-I", sources, "-c", source, "-o", o(name .. ".o")})
        return o(name .. ".o")
    end
    local function library(name, objects)
        corpus.armv7(e, table.join({"-dynamiclib", "-install_name", BACKPORTS .. "lib" .. name .. "Backports.dylib"}, objects,
                                   {"-framework", "Foundation", "-lobjc", "-o", path.join(folder, "lib" .. name .. "Backports.dylib")}))
    end
    library("Foundation", {object(path.join(sources, "Foundation", "NSMutableDictionaryAlias.m"), "alias"), object(path.join(here, "absent.m"), "absent")})
    library("UIKit", {object(path.join(here, "shadow.m"), "shadow")})
    library("System", {object(path.join(here, "dispatch.m"), "dispatch")})
    return folder
end

local function translated(corpus, translate, o, folder, backports, proxies)
    local options = {XL_LIBRARY = "1", BACKPORTS_DIR = backports, XL_PROXY_CLASSES = proxies and "1" or nil}
    translate.translate(o("SCFixture.dylib"), o("includes.h"), o(folder), {}, options)
    return o(folder .. "/SCFixture.dylib")
end

local function expect_bound(corpus, library, what, wanted)
    local from, bound = imports(library), binds(library)
    for symbol, expectation in pairs(wanted) do
        local library_name = from[symbol]
        if not library_name then
            corpus.fail("%s: the library imports no %s", what, symbol)
        end
        if (library_name:match("^lib.*Backports$") ~= nil) ~= expectation then
            corpus.fail("%s: %s is imported from %s, which is %s", what, symbol, library_name, expectation and "not a Backports library" or "a Backports library")
        end
        local entries = bound[symbol] or {}
        if #entries == 0 then
            corpus.fail("%s: dyld binds nothing to %s", what, symbol)
        end
        for _, entry in ipairs(entries) do
            if entry ~= library_name then
                corpus.fail("%s: a bind of %s names %s while the symbol table names %s", what, symbol, entry, library_name)
            end
        end
    end
    return bound
end

local function host_part(e, corpus, translate, o, here)
    local backports = build_backports(e, corpus, o, here)
    local fixed = translated(corpus, translate, o, "xl", backports, false)
    local CLASS, META = "_OBJC_CLASS_$_NSMutableDictionary", "_OBJC_METACLASS_$_NSMutableDictionary"
    local bound = expect_bound(corpus, fixed, "the translation", {
        [CLASS] = false, [META] = false, ["_OBJC_CLASS_$_NSURLQueryItem"] = true, ["_OBJC_CLASS_$_CASpringAnimation"] = true, ["_OBJC_CLASS_$_OS_dispatch_queue"] = true})
    if #bound[CLASS] < 2 then
        corpus.fail("the translation binds %s %d time(s): the superclass of SCDict and the class reference of the fixture are two binds", CLASS, #bound[CLASS])
    end
    local report = io.readfile(o("xl/report.txt"))
    local widths = {
        "-[SCNative scNative:]: host IMP from guest type encoding Q24@0:8q16 (q/Q as 32-bit long: category on system class NSObject) as L12@0:4l8",
        "-[SCGuestWide scBig:]: host IMP from guest type encoding q24@0:8q16 as q16@0:4q8"}
    for _, line in ipairs(widths) do
        if not report:find(line, 1, true) then
            corpus.fail("report.txt lacks the line\n%s\nA method added to a system class takes its q and Q as the 32-bit long of the armv7 caller, a method of a guest class keeps the 64-bit type:\n%s", line, report:gsub("[^\n]*\n", function(l) return l:find("SC", 1, true) and l or "" end))
        end
    end
    local rebound = io.readfile(o("xl/system-classes.txt"))
    local kept = io.readfile(o("xl/proxy-classes.txt"))
    for _, symbol in ipairs({CLASS, META}) do
        if not rebound:find(symbol .. " libFoundationBackports /System/Library/Frameworks/", 1, true) then
            corpus.fail("system-classes.txt does not list %s rebound from libFoundationBackports to a system framework:\n%s", symbol, rebound)
        end
    end
    if not kept:find("_OBJC_CLASS_$_NSURLQueryItem libFoundationBackports absent from the iOS 6 cache", 1, true) then
        corpus.fail("proxy-classes.txt does not list NSURLQueryItem as absent from the iOS 6 cache:\n%s", kept)
    end
    if not kept:find("_OBJC_CLASS_$_CASpringAnimation libUIKitBackports shadowed", 1, true) then
        corpus.fail("proxy-classes.txt does not list CASpringAnimation as shadowed:\n%s", kept)
    end
    if not kept:find("_OBJC_CLASS_$_OS_dispatch_queue libSystemBackports the iOS 6 cache does not export it from libSystem.B.dylib", 1, true) then
        corpus.fail("proxy-classes.txt does not list OS_dispatch_queue as a class the iOS 6 cache has and does not export:\n%s", kept)
    end
    local loaded = dependencies(fixed)
    for _, name in ipairs({"libFoundationBackports", "libUIKitBackports", "libSystemBackports"}) do
        if not loaded[BACKPORTS .. name .. ".dylib"] then
            corpus.fail("the translation does not load %s, which a class that only the Backports have binds to", name)
        end
    end
    os.cp(o("xl"), o("xl-proxy"))
    local control = translated(corpus, translate, o, "xl-proxy", backports, true)
    expect_bound(corpus, control, "the control with XL_PROXY_CLASSES=1", {[CLASS] = true, [META] = true})
    if #io.readfile(o("xl-proxy/system-classes.txt")) ~= 0 then
        corpus.fail("the control with XL_PROXY_CLASSES=1 rebound classes to the system library")
    end
    os.cp(o("xl"), o("xl-plain"))
    translate.translate(o("SCFixture.dylib"), o("includes.h"), o("xl-plain"), {}, {XL_LIBRARY = "1"})
    local uncovered = io.readfile(o("xl-plain/uncovered-classes.txt"))
    if uncovered ~= "_OBJC_CLASS_$_NSURLQueryItem\n_OBJC_CLASS_$_OS_dispatch_queue\n" then
        corpus.fail("the translation without BACKPORTS_DIR lists these classes as uncovered, not exactly NSURLQueryItem, which the iOS 6 cache lacks, and OS_dispatch_queue, which its libSystem does not export:\n%s", uncovered)
    end
    local _, weak = imports(o("xl-plain/SCFixture.dylib"))
    for _, symbol in ipairs({"_OBJC_CLASS_$_NSURLQueryItem", "_OBJC_CLASS_$_OS_dispatch_queue"}) do
        if weak[symbol] ~= true then
            corpus.fail("the translation without BACKPORTS_DIR does not import %s weakly, so a phone that does not export it stops at load", symbol)
        end
    end
    for _, symbol in ipairs({CLASS, META, "_OBJC_CLASS_$_CASpringAnimation"}) do
        if weak[symbol] ~= false then
            corpus.fail("the translation without BACKPORTS_DIR imports %s weakly or not at all, but the iOS 6 cache exports it", symbol)
        end
    end
    if io.readfile(o("xl/uncovered-classes.txt")) ~= "" then
        corpus.fail("the translation with the Backports lists uncovered classes:\n%s", io.readfile(o("xl/uncovered-classes.txt")))
    end
    print("ok (host part): NSMutableDictionary binds to the system library and NSURLQueryItem and CASpringAnimation to the Backports; the control with XL_PROXY_CLASSES=1 binds them all to the Backports; without BACKPORTS_DIR only the classes the cache lacks or does not export are uncovered and weak")
end

function main(out, ...)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local opt = corpus.options(...)
    local e
    e, out = corpus.setup("systemclasses", out)
    local here = path.absolute(os.scriptdir())
    local function o(file)
        return path.join(out, file)
    end

    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-Wl,-no_objc_category_merging", "-O2", "-w", "-fobjc-arc", "-dynamiclib", "-install_name", "@rpath/SCFixture.dylib",
                   "-framework", "Foundation", "-framework", "QuartzCore", "-I", here, path.join(here, "fixture.m"), "-o", o("SCFixture.dylib")})
    io.writefile(o("includes.h"), string.format('#include "%s"\n#include "%s"\n', path.join(e.recompiler, "include", "uikit-includes.h"), path.join(here, "SCFixture.h")))
    if not opt.device_only then
        host_part(e, corpus, translate, o, here)
    end
    if opt.host_only then
        return
    end

    local folder = os.getenv("REVENANT_ALIAS_LIBRARIES") or path.join(e.root, "build", "iphoneos", "armv7", "release")
    for _, name in ipairs({"Foundation", "UIKit"}) do
        if not os.isfile(path.join(folder, "lib" .. name .. "Backports.dylib")) then
            raise("%s holds no lib%sBackports.dylib: build the Backports component, or name the folder with REVENANT_ALIAS_LIBRARIES", folder, name)
        end
    end
    local fixed = translated(corpus, translate, o, "device", folder, false)
    local control = translated(corpus, translate, o, "device-proxy", folder, true)
    local sources = {path.join(here, "host.m"), path.join(e.recompiler, "src", "loader", "xl_loader.c")}
    corpus.armv7(e, table.join({"-O2", "-w", "-fobjc-arc", "-I", path.join(e.recompiler, "include"), "-framework", "Foundation"}, sources, {"-o", o("host")}))
    corpus.sign(e, o("host"))

    local device = corpus.device()
    local remote = device.scratch .. "/xl-systemclasses"
    local function launch(variant)
        device.run("rm -rf " .. remote .. "/" .. variant .. " && mkdir -p " .. remote .. "/" .. variant)
        device.copy(o(variant .. "/SCFixture.dylib"), remote .. "/" .. variant .. "/SCFixture.dylib")
        device.copy(o(variant .. "/SCFixture-classes.dylib"), remote .. "/" .. variant .. "/SCFixture-classes.dylib")
        device.copy(o("host"), remote .. "/" .. variant .. "/host")
        local text = try { function ()
            return device.run("cd " .. remote .. "/" .. variant .. " && chmod +x host && DYLD_FALLBACK_LIBRARY_PATH=. ./host ./SCFixture.dylib 2>&1; echo exit=$?")
        end } or ""
        io.writefile(o(variant .. ".txt"), text)
        return "\n" .. text:gsub("\r", "")
    end
    local names = {"superclass", "kind", "addEntriesFromDictionary", "removeAllObjects", "setDictionary", "absent", "shadowed", "dispatch", "wide", "native", "blocks"}
    local text = launch("device")
    for _, name in ipairs(names) do
        if not text:find("\nok " .. name .. "\n", 1, true) then
            io.write(text)
            corpus.fail("the translated fixture did not report ok for %s", name)
        end
    end
    if text:find("\nFAIL ", 1, true) or not text:find("\ndone\nexit=0\n", 1, true) then
        io.write(text)
        corpus.fail("the translated fixture reported a failure or did not run to its end")
    end
    local proxied = launch("device-proxy")
    if not proxied:find("\nFAIL superclass\n", 1, true) then
        io.write(proxied)
        corpus.fail("the control with XL_PROXY_CLASSES=1 did not fail at the superclass of SCDict: the test does not need the rebind")
    end
    print("ok")
end
