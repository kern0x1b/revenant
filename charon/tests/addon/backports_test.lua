import("fixtures")
import("core.package.package")

local function recipe_digest(folder, name, recipe, tree_files)
    local tree = path.join(folder, name)
    local root = path.join(tree, "packages", "a", "apple-backports")
    os.mkdir(root)
    os.cp(recipe, path.join(root, "xmake.lua"))
    for file, text in pairs(tree_files) do
        io.writefile(path.join(tree, file), text)
    end
    local instance, errors
    local raised = fixtures.refusal(function () instance, errors = package.load_from_repository("apple-backports", root) end)
    if not instance then
        return nil, raised or errors
    end
    return instance:extraconf("configs", "sources", "default")
end

local function digest_step(opt, folder, found)
    local recipe = path.join(opt.modules, "..", "packages", "a", "apple-backports", "xmake.lua")
    local tree_files = {
        [path.join("packages", "a", "apple-backports", "Foundation", "NSThing.m")] = "// a backport\n",
        [path.join("packages", "a", "apple-backports", "Foundation", "CharonThing.h")] = "// its header\n",
        [path.join("packages", "a", "apple-backports", "attach.c")] = "// the attach helper\n",
        [path.join("packages", "a", "apple-backports", "registry", "UIKit", "thing.json")] = '{"framework": "UIKit", "entries": []}\n',
        [path.join("packages", "a", "apple-backports", "registry", "flat.json")] = "[]\n",
        [path.join("packages", "a", "apple-backports", "notes.md")] = "notes\n",
        [path.join("modules", "apple", "backports.lua")] = "-- the build module\n",
        [path.join("addons", "c", "charon", "xmake.lua")] = 'add_versions("v0.8.4", "0")\n'
    }
    local before, errors = recipe_digest(folder, "digest-before", recipe, tree_files)
    if not before then
        table.insert(found, "the package description must load, and xmake answers it with " .. tostring(errors))
        return
    end
    local counted = 0
    for file, text in pairs(tree_files) do
        counted = counted + 1
        local changed = table.clone(tree_files)
        changed[file] = text .. "// changed\n"
        local digest = recipe_digest(folder, "digest-" .. counted, recipe, changed)
        local note = path.filename(file) == "notes.md"
        if note and digest ~= before then
            table.insert(found, "a note beside the sources is not built into a library and must not change the digest")
        elseif not note and digest == before then
            table.insert(found, "a change to " .. path.filename(file) .. " must be a different package digest")
        end
    end
    if recipe_digest(folder, "digest-again", recipe, tree_files) ~= before then
        table.insert(found, "the same sources must be the same digest")
    end
end

local function placement_step(backports, opt, folder, found)
    if not opt.sdk or not opt.clang then
        table.insert(found, "the placement check needs an SDK and a compiler and was given neither, so it did not run")
        return
    end
    local work = path.join(folder, "placement")
    os.mkdir(path.join(work, "registry"))
    io.writefile(path.join(work, "registry", "Place.json"),
        '{"framework": "Place", "entries": [{"api": "foo()", "kind": "function", "introduced": "18.2",' ..
        ' "minimum": "6.0", "status": "implemented"}]}\n')
    local source = path.join(work, "foo.m")
    io.writefile(source, "void foo(void) { }\n")
    local object = path.join(work, "foo.o")
    backports.compile({triple = "armv7-apple-ios6.0", sdkdir = opt.sdk, deployment = "6.0", cc = opt.clang}, source, object)
    local releases, unplaced = backports.releases_in({architecture = "armv7", root = work, sdkdir = opt.sdk}, source, {object})
    if #unplaced > 0 then
        table.insert(found, "a function the registry names foo() must be placed by releases_in, which has the " ..
                            "symbol's name and needs the registry's spelling: " .. table.concat(unplaced, " "))
    end
    if not releases["18.2"] or not releases["18.2"]["foo"] then
        local found = {}
        for _, version in ipairs(table.orderkeys(releases)) do
            for _, name in ipairs(releases[version]) do table.insert(found, name .. " at " .. version) end
        end
        table.insert(found, "releases_in must place the function at the release the registry states, and placed: " ..
                            (#found > 0 and table.concat(found, " ") or "nothing"))
    end
end

local function surface_step(backports, opt, folder, found)
    if not opt.sdk or not opt.clang then
        table.insert(found, "the surface check needs an SDK and a compiler and was given neither, so it did not run")
        return
    end
    local source = path.join(folder, "surface", "NSDateInterval.m")
    io.writefile(source, "#import <Foundation/Foundation.h>\n" ..
                         "void charon_surface_helper(void);\n" ..
                         "void charon_surface_helper(void) { }\n" ..
                         "@implementation NSDateInterval\n@end\n")
    local object = path.join(folder, "surface", "NSDateInterval.o")
    backports.compile({triple = "armv7-apple-ios6.0", sdkdir = opt.sdk, deployment = "6.0", cc = opt.clang}, source, object)
    local listed = fixtures.run(folder, "xcrun", {"nm", "-arch", "armv7", "-m", object})
    if not listed:find("%) external _OBJC_CLASS_%$_NSDateInterval") then
        table.insert(found, "a class the backport implements must stay external in the object, or nothing can link it: " ..
                            (listed:match("[^\n]*_OBJC_CLASS_%$_NSDateInterval[^\n]*") or "it is not there at all"))
    end
    local release_six, release_ten = {}, {["_OBJC_CLASS_$_NSDateInterval"] = true, ["_OBJC_METACLASS_$_NSDateInterval"] = true}
    local kept, reexported = backports.band(release_six, {object})
    if #kept ~= 1 or #reexported ~= 0 then
        table.insert(found, string.format("a release without the class must keep the object, not %d of them with %d re-exported", #kept, #reexported))
    end
    local told = backports.duplicated({object}, {NSDateInterval = {image = "Foundation"}})
    if table.concat(told, " ") ~= "NSDateInterval (NSDateInterval.o)" then
        table.insert(found, "a class the release holds without exporting it must be named with the object that carries it, not " .. table.concat(told, " "))
    end
    if #backports.duplicated({object}, {NSSomethingElse = {}}) ~= 0 then
        table.insert(found, "a class no release holds is the backport's to carry")
    end
    local proxy_source = path.join(folder, "surface", "NSProxied.m")
    io.writefile(proxy_source, "#import <Foundation/Foundation.h>\n" ..
                               "@interface CharonNSProxied : NSObject\n@end\n@implementation CharonNSProxied\n@end\n" ..
                               "__asm__(\".globl _OBJC_CLASS_$_NSProxied\\n.set _OBJC_CLASS_$_NSProxied, _OBJC_CLASS_$_CharonNSProxied\\n\");\n")
    local proxy_object = path.join(folder, "surface", "NSProxied.o")
    backports.compile({triple = "armv7-apple-ios6.0", sdkdir = opt.sdk, deployment = "6.0", cc = opt.clang}, proxy_source, proxy_object)
    if #backports.duplicated({proxy_object}, {NSProxied = {image = "UIFoundation"}}) ~= 0 then
        table.insert(found, "a proxy for a class the release holds without exporting it is not a second class")
    end
    local hidden_object = path.join(folder, "surface", "NSProxiedHidden.o")
    fixtures.run(folder, "xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-isysroot", opt.sdk, "-fobjc-arc", "-fvisibility=hidden", "-c", proxy_source, "-o", hidden_object})
    if #backports.duplicated({hidden_object}, {NSProxied = {image = "UIFoundation"}}) ~= 0 then
        table.insert(found, "a proxy is one whether or not the compiler hid the class it defines under Charon's name")
    end
    local refused = fixtures.refusal(function () kept, reexported = backports.band(release_ten, {object}) end)
    if refused then
        table.insert(found, "the helpers and ivars an object holds beside a class are not API, and weighing them against a release refuses it: " .. refused)
        return
    end
    table.sort(reexported)
    if #kept ~= 0 or table.concat(reexported, ",") ~= "_OBJC_CLASS_$_NSDateInterval,_OBJC_METACLASS_$_NSDateInterval" then
        table.insert(found, string.format("a release that has the class must re-export it instead of defining it again, not keep %d objects and re-export %s",
                                          #kept, table.concat(reexported, ",")))
    end
    kept, reexported = backports.band(release_ten, {object}, function () return true end)
    table.sort(reexported)
    if #kept ~= 0 or table.concat(reexported, ",") ~= "_OBJC_CLASS_$_NSDateInterval,_OBJC_METACLASS_$_NSDateInterval" then
        table.insert(found, string.format("a class the release exports is the release's whichever release the object arrived in, so the band must not keep %d objects and re-export %s",
                                          #kept, table.concat(reexported, ",")))
    end
end

local function floor_step(backports, opt, folder, found)
    for _, deployment in ipairs({"4.1", "4.2", "6.0"}) do
        local wanted = deployment ~= "4.1"
        if backports.reexports(deployment) ~= wanted then
            table.insert(found, string.format("iOS %s %s re-export a symbol of another library", deployment, wanted and "does" or "does not"))
        end
    end
    local work = path.join(folder, "floor")
    os.mkdir(work)
    io.writefile(path.join(work, "libSystem.tbd"), fixtures.system_stub("dyld_stub_binder, _charon_reexported"))
    io.writefile(path.join(work, "carried.c"), "int charon_carried(void) { return 0; }\n")
    io.writefile(path.join(work, "reexported.list"), "_charon_reexported\n")
    for _, deployment in ipairs({"4.1", "4.2"}) do
        local refused = fixtures.refusal(function ()
            fixtures.run(work, "xcrun", {"clang", "-target", "armv7-apple-ios" .. deployment, "-Wno-incompatible-sysroot",
                                         "-fuse-ld=" .. opt.ld64, "-dynamiclib", "-nostdlib", "-L.", "-lSystem",
                                         "-Wl,-reexported_symbols_list,reexported.list", "-o", "carried" .. deployment .. ".dylib", "carried.c"})
        end)
        if (refused ~= nil) ~= (not backports.reexports(deployment)) then
            table.insert(found, string.format("the linker and the backports disagree about iOS %s: ld %s, backports say %s",
                                              deployment, refused and "refuses the list" or "takes the list",
                                              backports.reexports(deployment) and "it re-exports" or "it cannot"))
        end
    end
end

local function categories_step(backports, opt, folder, found)
    local work = path.join(folder, "categories")
    os.mkdir(work)
    io.writefile(path.join(work, "one.m"), "#import <Foundation/Foundation.h>\n@implementation NSProgress (ProbeOne)\n- (int)probeOne { return 1; }\n@end\n")
    io.writefile(path.join(work, "two.m"), "#import <Foundation/Foundation.h>\n@implementation NSProgress (ProbeTwo)\n+ (int)probeTwo { return 2; }\n@end\n")
    fixtures.run(work, opt.clang, {"-target", "armv7-apple-ios4.3", "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w",
                                   "-mlinker-version=" .. fixtures.linker_version(opt.ld64), "-fuse-ld=" .. opt.ld64, "-dynamiclib",
                                   "-framework", "Foundation", "-Wl,-rename_section,__DATA,__objc_catlist,__DATA,__charon_catlist",
                                   "one.m", "two.m", "-o", "libprobe.dylib"})
    local library = path.join(work, "libprobe.dylib")
    local named = table.concat(backports.unattached_categories({exports = {}}, {classes = {}}, {library}, "armv7"), " ")
    for _, member in ipairs({"-probeOne", "+probeTwo"}) do
        if not named:find(member, 1, true) then
            table.insert(found, "a category on a class neither the release nor the package exports must be named with every member it adds, " ..
                                "whichever categories ld64 merged into it, and " .. member .. " is missing from: " .. named)
        end
    end
    named = table.concat(backports.unattached_categories({exports = {["_OBJC_CLASS_$_NSProgress"] = true}}, {classes = {}}, {library}, "armv7"), " ")
    if named ~= "" then
        table.insert(found, "a category on a class the release exports is attached, and must not be named: " .. named)
    end
    io.writefile(path.join(work, "alias.m"),
                 "#import <Foundation/Foundation.h>\n" ..
                 "struct charon_alias { const void *proxy; const char *name; };\n" ..
                 "extern char charon_alias_class_NSProxied __asm__(\"_OBJC_CLASS_$_CharonNSProxied\");\n" ..
                 "@interface CharonNSProxied : NSObject\n@end\n@implementation CharonNSProxied\n@end\n" ..
                 "__asm__(\".globl _OBJC_CLASS_$_NSProxied\\n.set _OBJC_CLASS_$_NSProxied, _OBJC_CLASS_$_CharonNSProxied\\n\");\n" ..
                 "__attribute__((used, section(\"__DATA,__charon_alias\"))) static const struct charon_alias charon_alias_NSProxied = { &charon_alias_class_NSProxied, \"NSProxied\"};\n")
    fixtures.run(work, opt.clang, {"-target", "armv7-apple-ios4.3", "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w",
                                   "-mlinker-version=" .. fixtures.linker_version(opt.ld64), "-fuse-ld=" .. opt.ld64, "-dynamiclib",
                                   "-framework", "Foundation", "alias.m", "-o", "libalias.dylib"})
    local alias = path.join(work, "libalias.dylib")
    named = table.concat(backports.unattached_categories({exports = {}}, {classes = {}}, {alias}, "armv7"), " ")
    if named ~= "" then
        table.insert(found, "an alias whose proxy the band defines carries the class of a release that has none, and must not be named: " .. named)
    end
end

function failures(opt)
    local backports = import("apple.backports", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    digest_step(opt, folder, found)
    placement_step(backports, opt, folder, found)
    surface_step(backports, opt, folder, found)
    floor_step(backports, opt, folder, found)
    categories_step(backports, opt, folder, found)
    local seven = fixtures.object(folder, "seven", "__attribute__((visibility(\"default\"))) int arrived_seven = 7;\n__attribute__((visibility(\"default\"))) int also_seven(void) { return 7; }\nstatic int helper(void) { return 0; }\n")
    local eight = fixtures.object(folder, "eight", "__attribute__((visibility(\"default\"))) int arrived_eight = 8;\n")
    local methods = fixtures.object(folder, "methods", "static int added(void) { return 1; }\nint (*const hidden_table[])(void) = {added};\n")
    local mixed = fixtures.object(folder, "mixed", "__attribute__((visibility(\"default\"))) int arrived_seven_too = 7;\n__attribute__((visibility(\"default\"))) int arrived_eight_too = 8;\n")
    local release_six = {}
    local release_seven = {_arrived_seven = true, _also_seven = true, _arrived_seven_too = true}
    local kept, reexported = backports.band(release_six, {seven, eight, methods})
    if #kept ~= 3 or #reexported ~= 0 then
        table.insert(found, string.format("a release that has none of the symbols must keep every object, not %d with %d re-exported", #kept, #reexported))
    end
    kept, reexported = backports.band(release_seven, {seven, eight, methods})
    table.sort(reexported)
    if table.concat(kept, ",") ~= table.concat({eight, methods}, ",") or table.concat(reexported, ",") ~= "_also_seven,_arrived_seven" then
        table.insert(found, "a release that exports every symbol of an object must drop the object and re-export its symbols, not keep " .. table.concat(kept, ",") .. " and re-export " .. table.concat(reexported, ","))
    end
    kept, reexported = backports.band(release_seven, {seven, eight, methods}, function (candidate) return candidate == seven end)
    if table.concat(kept, ",") ~= table.concat({seven, eight, methods}, ",") or #reexported ~= 0 then
        table.insert(found, "an object that arrived after the band's release is kept whatever the release exports, not re-exported as " .. table.concat(reexported, ","))
    end
    kept, reexported = backports.band(release_seven, {seven, eight, methods}, function (candidate) return false end)
    table.sort(reexported)
    if table.concat(reexported, ",") ~= "_also_seven,_arrived_seven" then
        table.insert(found, "an object that arrived no later than the band's release is weighed by the release's exports: " .. table.concat(reexported, ","))
    end
    local kept_mixed = fixtures.refusal(function () kept = backports.band(release_seven, {mixed}, function () return true end) end)
    if kept_mixed or #kept ~= 1 then
        table.insert(found, "an object that arrived after the band's release is kept even where it holds names the release exports beside names it does not: " .. tostring(kept_mixed))
    end
    local errors = fixtures.refusal(function () backports.band(release_seven, {mixed}) end)
    if not errors or not errors:find("_arrived_seven_too", 1, true) or not errors:find("_arrived_eight_too", 1, true) then
        table.insert(found, "an object holding what a release exports beside what it does not must be refused naming both: " .. tostring(errors))
    end
    local uikit = "/System/Library/Frameworks/UIKit.framework/UIKit"
    local uifoundation = "/System/Library/PrivateFrameworks/UIFoundation.framework/UIFoundation"
    local release = {libraries = {[uikit] = {exports = {["_OBJC_CLASS_$_UIAlertController"] = true, ["_OBJC_METACLASS_$_UIAlertController"] = true, _UIApplicationDidFinishLaunchingNotification = true},
                                             reexports = {uifoundation}},
                                  [uifoundation] = {exports = {_NSFontAttributeName = true}, reexports = {}}}}
    local written = backports.stubs("armv7", {name = "UIKitBackports", frameworks = {"UIKit", "Foundation"}},
                                    {"_OBJC_CLASS_$_UIAlertController", "_NSFontAttributeName"}, {release, release}, folder)
    local stub = #written == 1 and io.readfile(written[1])
    if not stub or path.filename(written[1]) ~= "UIKit.tbd" then
        table.insert(found, "a symbol a framework re-exports must be taken from the framework the library links, not from the private library behind it: " .. table.concat(written, ","))
    elseif not stub:find("_NSFontAttributeName", 1, true) or not stub:find("UIAlertController", 1, true) or not stub:find("_UIApplicationDidFinishLaunchingNotification", 1, true) then
        table.insert(found, "a stub stands in for the whole library of its release, since it takes the place of the SDK's: " .. stub)
    end

    local listed = {"5.1.1", "6.0", "6.1.6", "7.0", "7.1.2", "8.0", "8.4.1", "9.0", "9.3.6", "10.0.1", "10.3.4"}
    local described = {}
    for _, range in ipairs(backports.band_ranges({"6.0", "7.0", "8.0", "9.0"}, listed)) do
        table.insert(described, range.first .. "-" .. range.last)
    end
    if table.concat(described, " ") ~= "6.0-6.1.6 7.0-7.1.2 8.0-8.4.1 9.0-10.3.4" then
        table.insert(found, "each release the backports' API arrived in opens a band running to the last catalog release before the next, and the last band to the catalog's end: " .. table.concat(described, " "))
    end
    described = {}
    for _, range in ipairs(backports.band_ranges({"6.0", "9.0", "11.0"}, listed)) do
        table.insert(described, range.first .. "-" .. range.last)
    end
    if table.concat(described, " ") ~= "6.0-8.4.1 9.0-10.3.4" then
        table.insert(found, "API of a release no firmware of the architecture reaches opens no band and stays in every one: " .. table.concat(described, " "))
    end
    local errors = fixtures.refusal(function () backports.band_ranges({"11.0"}, listed) end)
    if not errors or not errors:find("iOS 11.0 or later", 1, true) then
        table.insert(found, "a minimum release no catalog firmware reaches must be refused: " .. tostring(errors))
    end
    local dump = table.concat({
        "Dumping NSURLQueryItemReader:", "|-AvailabilityAttr 0x1 <col:1> ios 11.0 0 0 \"\" \"\" 0",
        "Dumping NSURLQueryItem:", "|-AvailabilityAttr 0x2 <col:1> macos 10.10 0 0 \"\" \"\" 0", "|-AvailabilityAttr 0x3 <col:1> ios 8.0 0 0 \"\" \"\" 0",
        "| `-ObjCMethodDecl 0x5 <col:1> - dataTaskWithURL:", "|   `-AvailabilityAttr 0x6 <col:1> ios 15.0 0 0 \"\" \"\" 0",
        "Dumping NSURLQueryItem:", "`-ObjCImplementation 0x4",
        "Dumping NSURLQueryItem:", "|-AvailabilityAttr 0x7 <col:1> ios 13.0 0 0 \"\" \"\" 0"}, "\n")
    if backports.introduced_version(dump, "NSURLQueryItem") ~= "8.0" or backports.introduced_version(dump, "NSURLComponents") then
        table.insert(found, "the release a declaration arrived in is the earliest iOS availability of its own declarations, not of their members or of another declaration the filter matched")
    end

    local dump = table.concat({
        "Dumping NSURLQueryItemReader:", "|-AvailabilityAttr 0x1 <col:1> ios 11.0 0 0 \"\" \"\" 0",
        "Dumping NSURLQueryItem:", "|-AvailabilityAttr 0x2 <col:1> macos 10.10 0 0 \"\" \"\" 0", "|-AvailabilityAttr 0x3 <col:1> ios 8.0 0 0 \"\" \"\" 0",
        "| `-ObjCMethodDecl 0x5 <col:1> - dataTaskWithURL:", "|   `-AvailabilityAttr 0x6 <col:1> ios 15.0 0 0 \"\" \"\" 0",
        "Dumping NSURLQueryItem:", "`-ObjCImplementation 0x4",
        "Dumping NSURLQueryItem:", "|-AvailabilityAttr 0x7 <col:1> ios 13.0 0 0 \"\" \"\" 0"}, "\n")
    if backports.introduced_version(dump, "NSURLQueryItem") ~= "8.0" or backports.introduced_version(dump, "NSURLComponents") then
        table.insert(found, "the release a declaration arrived in is the earliest iOS availability of its own declarations, not of their members or of another declaration the filter matched")
    end
    local named = backports.availability_names({"_OBJC_CLASS_$_NSDimension", "_OBJC_METACLASS_$_NSDimension",
                                                "_OBJC_IVAR_$_NSDimension._converter", "_NSCalendarIdentifierGregorian"})
    if not named["NSDimension"] or not named["NSCalendarIdentifierGregorian"] or named["OBJC_IVAR_$_NSDimension._converter"] then
        table.insert(found, "an ivar has no release of its own and is read as the class that holds it: " .. table.concat(table.orderkeys(named), " "))
    end

    local registry = path.join(folder, "registry")
    os.mkdir(registry)
    io.writefile(path.join(registry, "UIKit.json"), [[
        {"framework": "UIKit", "entries": [
            {"api": "UIStackView", "kind": "class", "introduced": "9.0", "status": "implemented", "facts": "facts/UIKit/UIStackView.md"},
            {"api": "-[UIView tintColorDidChange]", "kind": "method", "introduced": "7.0", "status": "implemented"},
            {"api": "UIFontTextStyleBody", "kind": "constant", "introduced": "7.0", "status": "implemented"},
            {"api": "UIBlurEffect", "kind": "class", "introduced": "8.0", "status": "absent", "reason": "the render server draws it", "effect": "the class is not there"}
        ]}
    ]])
    local carried = {classes = {UIStackView = true}, members = {["-[UIView tintColorDidChange]"] = true}, symbols = {UIFontTextStyleBody = true}}
    local undocumented = backports.check_registry(folder, carried)
    if undocumented ~= 2 then
        table.insert(found, "an entry that names no file of facts must be counted, not refused: " .. tostring(undocumented))
    end
    carried.members["-[UIView tintAdjustmentMode]"] = true
    errors = fixtures.refusal(function () backports.check_registry(folder, carried) end)
    if not errors or not errors:find("-[UIView tintAdjustmentMode]", 1, true) then
        table.insert(found, "a method the backports add without an entry in the registry must be refused naming it: " .. tostring(errors))
    end
    carried.members["-[UIView tintAdjustmentMode]"] = nil
    io.writefile(path.join(registry, "UIKit", "spellings.json"), [[
        [
            {"api": "UIView.directionalLayoutMargins", "kind": "property", "introduced": "11.0", "status": "implemented", "facts": "facts/UIKit/UIView.md"},
            {"api": "NSStringFromDirectionalEdgeInsets()", "kind": "function", "introduced": "11.0", "status": "implemented", "facts": "facts/UIKit/UIView.md"}
        ]
    ]])
    carried.members["-[UIView setDirectionalLayoutMargins:]"] = true
    carried.symbols["NSStringFromDirectionalEdgeInsets"] = true
    if fixtures.refusal(function () backports.check_registry(folder, carried) end) then
        table.insert(found, "a property's entry covers both of its accessors, and a function's entry is the same whether it is written with brackets or without")
    end
    carried.members["-[UIView setDirectionalLayoutMargins:]"] = nil
    carried.symbols["NSStringFromDirectionalEdgeInsets"] = nil
    os.rm(path.join(registry, "UIKit", "spellings.json"))
    carried.members["-[UIStackView setSpacing:]"] = true
    if fixtures.refusal(function () backports.check_registry(folder, carried) end) then
        table.insert(found, "a method of a class the registry describes needs no entry of its own: the class carries its surface")
    end
    carried.members["-[UIStackView setSpacing:]"] = nil
    io.writefile(path.join(registry, "UIKit", "absent.json"), [[
        [{"api": "UIStackView.customSpacing", "kind": "property", "introduced": "11.0", "status": "absent",
          "reason": "the release lays out no custom spacing", "effect": "the property is not there"}]
    ]])
    carried.answered = {["-[UIStackView setCustomSpacing:]"] = true}
    errors = fixtures.refusal(function () backports.check_registry(folder, carried) end)
    if not errors or not errors:find("listed as absent, but what is built answers it: UIStackView.customSpacing", 1, true) then
        table.insert(found, "a member the registry calls absent must not be answered by what is built, as a property the compiler synthesised from the SDK's interface is: " .. tostring(errors))
    end
    carried.answered = {["-[UIBlurEffect effectWithStyle:]"] = true}
    if fixtures.refusal(function () backports.check_registry(folder, carried) end) then
        table.insert(found, "an absent class whose name nothing built carries is not refused for a method of that name elsewhere")
    end
    carried.classes.UIBlurEffect = true
    errors = fixtures.refusal(function () backports.check_registry(folder, carried) end)
    if not errors or not errors:find("listed as absent, but what is built answers it: UIBlurEffect", 1, true) then
        table.insert(found, "a class the registry calls absent must not be built: " .. tostring(errors))
    end
    carried.classes.UIBlurEffect = nil
    carried.answered = nil
    os.rm(path.join(registry, "UIKit", "absent.json"))
    io.writefile(path.join(registry, "UIKit", "owed.json"), [[
        [{"api": "UIBlurEffect", "kind": "class", "introduced": "8.0", "status": "owed",
          "reason": "build the class UIBlurEffect", "effect": "until built: NSClassFromString answers nil"}]
    ]])
    carried.classes.UIBlurEffect = true
    local ok, _, _, _, stand_ins = pcall(backports.check_registry, folder, carried)
    local noted = false
    for _, name in ipairs(stand_ins or {}) do
        noted = noted or name == "UIBlurEffect"
    end
    if not ok or not noted then
        table.insert(found, "an owed class with a stand-in built must be a note naming it, not a refusal: " .. tostring(stand_ins or ok))
    end
    carried.classes.UIBlurEffect = nil
    os.rm(path.join(registry, "UIKit", "owed.json"))
    carried.classes.UIStackView = nil
    errors = fixtures.refusal(function () backports.check_registry(folder, carried) end)
    if not errors or not errors:find("UIStackView", 1, true) then
        table.insert(found, "an entry that says implemented while nothing of that name is built must be refused naming it: " .. tostring(errors))
    end
    carried.classes.UIStackView = true
    os.mkdir(path.join(registry, "Foundation"))
    io.writefile(path.join(registry, "Foundation", "ios11.json"), [[
        [
            {"api": "NSJSONWritingSortedKeys", "kind": "constant", "introduced": "11.0", "status": "ignored",
             "effect": "the release writes the keys in the order of the dictionary", "facts": "facts/Foundation/NSJSONSerialization.md"},
            {"api": "NSLocalizedFailureErrorKey", "kind": "constant", "introduced": "11.0", "status": "ignored",
             "effect": "the release leaves the failure out of -localizedDescription"}
        ]
    ]])
    errors = fixtures.refusal(function () backports.check_registry(folder, carried) end)
    if not errors or not errors:find("NSLocalizedFailureErrorKey is ignored without a file of facts", 1, true)
       or errors:find("NSJSONWritingSortedKeys", 1, true) then
        table.insert(found, "an API the release's own implementation answers differently is ignored, and must name the file of facts that says how: " .. tostring(errors))
    end
    io.writefile(path.join(registry, "Foundation", "ios11.json"), [[
        [
            {"api": "NSJSONWritingSortedKeys", "kind": "constant", "introduced": "11.0", "status": "ignored",
             "effect": "the release writes the keys in the order of the dictionary", "facts": "facts/Foundation/NSJSONSerialization.md"}
        ]
    ]])
    os.mkdir(path.join(registry, "UIKit"))
    io.writefile(path.join(registry, "UIKit", "ios10.json"), [[
        [{"api": "UIStackView", "kind": "class", "introduced": "9.0", "status": "implemented", "facts": "facts/UIKit/UIStackView.md"}]
    ]])
    errors = fixtures.refusal(function () backports.check_registry(folder, carried) end)
    if not errors or not errors:find("UIKit.json and UIKit/ios10.json", 1, true) then
        table.insert(found, "one API named by two files of the registry must be refused naming both: " .. tostring(errors))
    end
    os.rm(path.join(registry, "UIKit", "ios10.json"))
    io.writefile(path.join(registry, "UIKit", "floor.json"), [[
        [{"api": "NSLayoutConstraint", "kind": "class", "introduced": "6.0", "minimum": "6.0", "status": "absent",
          "reason": "auto layout arrived in 6.0", "effect": "below 6.0 the class is not there", "source": "the armv7 cache of iOS 5.1.1"}]
    ]])
    undocumented = backports.check_registry(folder, carried, nil, "6.0")
    if undocumented ~= 2 then
        table.insert(found, "a record of where an API begins needs no file of facts, only what the backports carry does: " .. tostring(undocumented))
    end
    os.rm(path.join(registry, "UIKit", "floor.json"))
    os.rm(path.join(registry, "Foundation", "ios11.json"))

    io.writefile(path.join(registry, "UIKit", "advice.json"), [[
        [
            {"api": "-[UIView setTintColor:]", "kind": "method", "introduced": "7.0", "status": "owed",
             "reason": "build the setter so the colour is remembered and drawn", "effect": "until built: the setter is not there"},
            {"api": "UIBlurEffect", "kind": "class", "introduced": "8.0", "maximum": "9.0", "status": "absent",
             "reason": "the release carries the class from 9.0", "effect": "the class is not there"},
            {"api": "NSJSONWritingSortedKeys", "kind": "constant", "introduced": "11.0", "status": "ignored",
             "effect": "the keys come out in the dictionary's own order", "facts": "facts/Foundation/NSJSONSerialization.md"}
        ]
    ]])
    local advised = backports.advice(folder, {["setTintColor:"] = true, UIBlurEffect = true, NSJSONWritingSortedKeys = true, ["description"] = true})
    local order = {}
    for _, entry in ipairs(advised) do
        table.insert(order, entry.api .. "=" .. entry.status)
    end
    if table.concat(order, " ") ~= "NSJSONWritingSortedKeys=ignored -[UIView setTintColor:]=owed UIBlurEffect=absent" then
        table.insert(found, "what a port calls is reported quietest first, since a missing class crashes where a different answer never shows: " .. table.concat(order, " "))
    end
    os.rm(path.join(registry, "UIKit", "advice.json"))
    io.writefile(path.join(registry, "UIKit", "declared.json"), [[
        {"framework": "UIKit", "entries": [
            {"api": "UIInteraction", "kind": "protocol", "introduced": "13.0", "minimum": "6.0", "status": "implemented",
             "effect": "the declaration is in the header", "facts": "facts/UIKit/UIInteraction.md"},
            {"api": "-[UIHeldDelegate held:]", "kind": "method", "introduced": "8.0", "minimum": "6.0", "status": "ignored",
             "effect": "the message is never sent", "facts": "facts/UIKit/UIHeldDelegate.md"}
        ]}
    ]])
    local declared_found = {classes = {}, members = {}, symbols = {}}
    local declared_inventory = {classes = {}, protocols = {UIHeldDelegate = true}}
    errors = fixtures.refusal(function () backports.check_registry(folder, declared_found, true, "6.0", {}, declared_inventory) end)
    if errors and (errors:find("UIInteraction", 1, true) or errors:find("UIHeldDelegate", 1, true)) then
        table.insert(found, "protocols exist only in a header, so an entry for one, or for a member of one the release does not carry, must not be refused for having nothing built or carried: " .. tostring(errors))
    end
    os.rm(path.join(registry, "UIKit", "declared.json"))

    local scripts = path.join(folder, "scripts")
    backports.write_scripts(scripts)
    local function device(version)
        local root = path.join(folder, "device-" .. version)
        os.tryrm(root)
        local home = path.join(root, "usr", "lib", "charon", backports.package_name())
        for _, band in ipairs({"6.0", "9.3.5"}) do
            os.mkdir(path.join(home, "bands", band))
            io.writefile(path.join(home, "bands", band, "libFoundationBackports.dylib"), band)
        end
        io.writefile(path.join(home, "bands", "ranges"), "6.0 6.1.3\n9.3.5 10.3.3\n")
        os.mkdir(path.join(root, "System", "Library", "CoreServices"))
        if version ~= "" then
            io.writefile(path.join(root, "System", "Library", "CoreServices", "SystemVersion.plist"),
                         "<plist version=\"1.0\">\n<dict>\n\t<key>ProductBuildVersion</key>\n\t<string>X</string>\n\t<key>ProductVersion</key>\n\t<string>" .. version .. "</string>\n</dict>\n</plist>\n")
        end
        return root, home
    end
    local function run(script, root, argument)
        local output = path.join(folder, "script.out")
        local status = os.execv("sh", {"-c", string.format("DPKG_ROOT='%s' sh '%s' %s > '%s' 2>&1", root, path.join(scripts, script), argument, output)}, {try = true})
        return status, io.readfile(output)
    end
    for _, case in ipairs({{"6.0", "6.0"}, {"6.1.2", "6.0"}, {"10.2", "9.3.5"}, {"10.3.3", "9.3.5"}}) do
        local root, home = device(case[1])
        local status, text = run("postinst", root, "configure")
        local linked = os.islink(path.join(home, "libFoundationBackports.dylib")) and os.readlink(path.join(home, "libFoundationBackports.dylib"))
        if status ~= 0 or linked ~= "bands/" .. case[2] .. "/libFoundationBackports.dylib" then
            table.insert(found, string.format("iOS %s must get the libraries of the %s band: status %s, link %s, %s", case[1], case[2], tostring(status), tostring(linked), text))
        end
        if case[1] == "6.0" then
            run("prerm", root, "upgrade")
            if not os.islink(path.join(home, "libFoundationBackports.dylib")) then
                table.insert(found, "an upgrade must keep the links, which the new postinst sets again")
            end
            run("prerm", root, "remove")
            if os.islink(path.join(home, "libFoundationBackports.dylib")) or #os.filedirs(path.join(home, "*.dylib")) > 0 then
                table.insert(found, "removing the package must take the links it set before dpkg removes its files, so its folders empty")
            end
        end
    end
    for _, case in ipairs({{"6.1.4", "holds no libraries built and checked for iOS 6.1.4; it holds them for iOS 6.0 to 6.1.3, 9.3.5 to 10.3.3"},
                           {"8.4.1", "holds no libraries built and checked for iOS 8.4.1"},
                           {"", "cannot read ProductVersion"}}) do
        local root, home = device(case[1])
        local status, text = run("postinst", root, "configure")
        if status == 0 or not text:find(case[2], 1, true) or os.islink(path.join(home, "libFoundationBackports.dylib")) then
            table.insert(found, string.format("iOS %s has no band and must be refused naming it, not given the nearest: status %s, %s", case[1], tostring(status), text))
        end
    end
    os.tryrm(folder)
    return found
end
