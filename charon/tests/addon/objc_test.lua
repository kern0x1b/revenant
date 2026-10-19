import("core.base.process")
import("fixtures")

local MESSAGES = [[
#import <Foundation/Foundation.h>
int main(void) { return [[NSMutableArray array] count] + [[NSObject new] hash] > 0; }
]]

local SELECTORS = [[
#import <Foundation/Foundation.h>
@protocol ProbeDelegate <NSObject>
@optional
- (void)probeDidFinishWithCount:(NSUInteger)count;
@end
@interface NSString (Probe)
- (NSString *)probe_reversed;
@end
@implementation NSString (Probe)
- (NSString *)probe_reversed { return self; }
@end
@interface Probe : NSObject
@property (nonatomic, assign) id<ProbeDelegate> delegate;
@end
@interface Listener : NSObject <ProbeDelegate>
@end
@implementation Listener
@end
@implementation Probe
- (void)finish {
    if ([self.delegate respondsToSelector:@selector(probeDidFinishWithCount:)]) {
        [self.delegate probeDidFinishWithCount:[@"x" probe_reversed].length];
    }
}
@end
]]

local HELD = [[
#import <Foundation/Foundation.h>
@interface Held : NSObject
- (void)heldMethod;
@end
@implementation Held
- (void)heldMethod {}
@end
]]

local INVENTORY = [[
function main(modules, cachefile, output)
    local found = import("apple.objc", {rootdir = modules, anonymous = true}).inventory(cachefile)
    local lines = {}
    for name, class in pairs(found.classes) do
        table.insert(lines, name .. " " .. table.concat(table.orderkeys(class.instance), ","))
    end
    table.sort(lines)
    io.writefile(output, table.concat(lines, "\n"))
end
]]

local function armv7_cache(file, opt)
    local text, data, linkedit = 0x30000000, 0x30002000, 0x30003000
    local pieces, slots = {}, {}
    local function put(address, bytes)
        table.insert(pieces, {address - text, bytes})
    end
    local function words(address, ...)
        local values = {...}
        put(address, string.pack("<" .. string.rep("I4", #values), table.unpack(values)))
        return #values
    end
    local function pointers(address, ...)
        for index = 1, words(address, ...) do
            table.insert(slots, address + (index - 1) * 4)
        end
    end
    put(text, "dyld_v1   armv7\0")
    words(text + 0x10, 0x58, 3, 0x100, 1)
    put(text + 0x38, string.pack("<I8I8", linkedit - text, 0x100))
    for index, mapping in ipairs({{text, 0x2000, 5}, {data, 0x1000, 3}, {linkedit, 0x1000, 1}}) do
        put(text + 0x58 + (index - 1) * 32, string.pack("<I8I8I8I4I4", mapping[1], mapping[2], mapping[1] - text, mapping[3], mapping[3]))
    end
    put(text + 0x100, string.pack("<I8I8I8I4I4", text + 0x1000, 0, 0, 0x140, 0))
    put(text + 0x140, "/System/Library/Frameworks/Probe.framework/Probe\0")
    local sections = {{"__objc_classlist", data, 4}}
    if opt.charon then
        table.insert(sections, {"__charon_catlist", data + 0x100, 4})
    end
    local commands = {}
    for _, segment in ipairs({{"__TEXT", text + 0x1000, 5}, {"__DATA", data, 3, sections}, {"__LINKEDIT", linkedit, 1}}) do
        local section = ""
        for _, one in ipairs(segment[4] or {}) do
            section = section .. string.pack("<c16c16I4I4I4I4I4I4I4I4I4", one[1], segment[1], one[2], one[3], one[2] - text, 2, 0, 0, 0, 0, 0)
        end
        table.insert(commands, string.pack("<I4I4c16I4I4I4I4i4i4I4I4", 0x1, 56 + #section, segment[1], segment[2], 0x1000, segment[2] - text, 0x1000,
                                           segment[3], segment[3], #(segment[4] or {}), 0) .. section)
    end
    put(text + 0x1000, string.pack("<I4i4i4I4I4I4I4", 0xFEEDFACE, 12, 9, 6, #commands, #table.concat(commands), 0) .. table.concat(commands))
    put(text + 0x1800, "Probe\0probe\0v8@0:4\0" .. (opt.charon and "ported\0" or ""))
    words(text + 0x1900, 8, 0x7FFFFFFF)
    local class = data + 0x10
    pointers(data, class + (opt.slide or 0))
    pointers(class, data + 0x30, 0, 0, 0, data + 0x50)
    pointers(data + 0x30, data + 0x30, class, 0, 0, data + 0x70)
    words(data + 0x50, 0, 0, 0, 0)
    pointers(data + 0x60, text + 0x1800, opt.methods or data + 0x90, 0)
    words(data + 0x70, 1, 0, 0, 0)
    pointers(data + 0x80, text + 0x1800, 0, 0)
    words(data + 0x90, 12, 1)
    pointers(data + 0x98, text + 0x1806, text + 0x180c, text + 0x1001)
    if opt.charon then
        -- The category list of a library this repository built, which backports.lua's link renames, holding one
        -- selector the class does not define. No image of a release carries such a section.
        words(data + 0xB0, 12, 1)
        pointers(data + 0xB8, text + 0x1813, text + 0x180c, text + 0x1001)
        pointers(data + 0xC0, text + 0x1800, class, 0, 0)
        pointers(data + 0xC8, data + 0xB0, 0, 0)
        pointers(data + 0x100, data + 0xC0)
    end
    local bitmap = {}
    for index = 1, 128 do
        bitmap[index] = 0
    end
    for _, slot in ipairs(slots) do
        local index = (slot - data) // 4
        bitmap[index // 8 + 1] = bitmap[index // 8 + 1] | (1 << (index % 8))
    end
    put(linkedit, string.pack("<I4I4I4I4I4I4I2", 1, 24, 1, 26, 1, 128, 0) .. string.char(table.unpack(bitmap)))
    local bytes = string.rep("\0", 0x4000)
    for _, piece in ipairs(pieces) do
        bytes = bytes:sub(1, piece[1]) .. piece[2] .. bytes:sub(piece[1] + #piece[2] + 1)
    end
    io.writefile(file, bytes, {encoding = "binary"})
    return file
end

local function inventory_failures(folder, opt)
    local found = {}
    io.writefile(path.join(folder, "inventory.lua"), INVENTORY)
    for index, case in ipairs({{"a cache read from firmware", {}, "Probe -probe"},
                           {"a class whose method list address has its low bit set, as garbage from a device copy does", {methods = 0x30001901}, "Probe "},
                           {"an image carrying the category list a built library's link renames, which a release's image never does",
                            {charon = true}, nil, "holds 1 image this repository built, whose category section is renamed to __charon_catlist"},
                           {"a cache copied from a running device, its pages slid", {slide = 0x10000000}, nil, "copied from a running device: 1 of its pages hold pointers the device slid"}}) do
        local cachefile = armv7_cache(path.join(folder, "dyld_shared_cache_armv7_" .. index), case[2])
        local output, log = cachefile .. ".txt", cachefile .. ".log"
        local child = process.openv(os.programfile(), {"l", "inventory.lua", opt.modules, cachefile, output}, {curdir = folder, stdout = log, stderr = log})
        local finished = child:wait(60000)
        if finished == 0 then
            child:kill()
        end
        child:close()
        local said = os.isfile(log) and io.readfile(log) or ""
        if finished == 0 then
            table.insert(found, case[1] .. ": the inventory did not finish within a minute")
        elseif case[4] then
            if not said:find(case[4], 1, true) then
                table.insert(found, case[1] .. ": the inventory must refuse it saying " .. case[4] .. ", and said: " .. said)
            end
        elseif not os.isfile(output) or io.readfile(output) ~= case[3] then
            table.insert(found, case[1] .. ": the inventory must list " .. case[3] .. ", and listed " .. (os.isfile(output) and io.readfile(output) or "nothing: " .. said))
        end
    end
    return found
end

local function held_failures(folder, opt)
    local found = {}
    local objc = import("apple.objc", {rootdir = opt.modules, anonymous = true})
    local libraries = path.join(folder, "libraries_armv7")
    local device = path.join(libraries, "usr", "lib")
    os.mkdir(device)
    io.writefile(path.join(folder, "held.m"), HELD)
    fixtures.run(folder, opt.clang, {"-target", "armv7-apple-ios6.0", "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w",
                                     "-mlinker-version=" .. fixtures.linker_version(opt.ld64), "-fuse-ld=" .. opt.ld64, "-dynamiclib",
                                     "-framework", "Foundation", "-install_name", "/usr/lib/libheld.dylib",
                                     "held.m", "-o", path.join(device, "libheld.dylib")})
    local inventory = objc.inventory(libraries)
    local class = inventory.classes["Held"]
    if inventory.architecture ~= "armv7" then
        table.insert(found, "an inventory of a libraries folder must name the architecture the folder holds, not " .. tostring(inventory.architecture))
    end
    if not class then
        table.insert(found, "a release before 3.1 keeps its libraries as files, and the inventory must read their classes")
    else
        if not class.instance["-heldMethod"] then
            table.insert(found, "the inventory of a libraries folder must read a class's methods, and read " .. table.concat(table.orderkeys(class.instance), " "))
        end
        if class.image ~= "/usr/lib/libheld.dylib" then
            table.insert(found, "the inventory of a libraries folder must say which library a class comes from, not " .. tostring(class.image))
        end
    end
    os.mkdir(path.join(folder, "libraries_armv6"))
    local errors = fixtures.refusal(function () objc.inventory(path.join(folder, "libraries_armv6")) end)
    if not errors or not errors:find("holds no armv6 library", 1, true) then
        table.insert(found, "an inventory of a folder holding nothing of the architecture must refuse rather than report an empty system: " .. tostring(errors))
    end
    return found
end

-- The selector list known_selectors() keeps beside a release is named by the reader that wrote it. A shared
-- cache taken out of a firmware keeps that firmware's own mtime - 2011 for the held 4.3 one, 2013 for 6.1.3 -
-- so a comparison of times alone holds a list true for the machine's lifetime and a changed reader is never
-- read at all. A list this reader did not write is therefore not the answer, whatever its times say.
local function kept_failures(folder, opt)
    local found = {}
    local objc = import("apple.objc", {rootdir = opt.modules, anonymous = true})
    local libraries = path.join(folder, "kept", "libraries_armv7")
    os.mkdir(path.join(libraries, "usr", "lib"))
    io.writefile(path.join(folder, "kept", "held.m"), HELD)
    fixtures.run(path.join(folder, "kept"), opt.clang, {"-target", "armv7-apple-ios6.0", "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w",
                                                        "-mlinker-version=" .. fixtures.linker_version(opt.ld64), "-fuse-ld=" .. opt.ld64, "-dynamiclib",
                                                        "-framework", "Foundation", "-install_name", "/usr/lib/libheld.dylib",
                                                        "held.m", "-o", path.join(libraries, "usr", "lib", "libheld.dylib")})
    io.writefile(path.join(folder, "kept", "selectors_armv7.txt"), "charonNoSuchSelectorAnywhere\n")
    local known = objc.known_selectors(libraries)
    if known["-charonNoSuchSelectorAnywhere"] then
        table.insert(found, "a selector list beside the release that this reader did not write must not answer it, and it answered -charonNoSuchSelectorAnywhere")
    end
    if not known["-heldMethod"] then
        table.insert(found, "the reading is kept beside the release and read back: -heldMethod must be in the answer, and the answer names " ..
                    table.concat(table.slice(table.orderkeys(known), 1, 8), " "))
    end
    -- A second call must answer from the file the first one wrote and not read the library again, which is
    -- the whole reason the reading is kept: a marker left in the file survives only if it was read back.
    local list = path.join(folder, "kept", "selectors_armv7.txt")
    io.writefile(list, io.readfile(list) .. "charonMarkerInTheKeptList\n")
    if not objc.known_selectors(libraries)["-charonMarkerInTheKeptList"] then
        table.insert(found, "a second reading must answer from the file beside the release, and it read the library again")
    end
    local keyed = os.files(path.join(folder, "kept", "selectors_armv7.txt.reader"))
    if #keyed ~= 1 then
        table.insert(found, "the list this reader writes names the reader that wrote it beside it, and beside the release there are " .. #keyed ..
                    " such files: " .. table.concat(keyed, " "))
    end
    return found
end


local function stub_failures(folder, opt)
    local found = {}
    local version = fixtures.linker_version(opt.ld64)
    io.writefile(path.join(folder, "messages.m"), MESSAGES)
    local linked = {"-target", "arm64-apple-ios7.0", "-isysroot", opt.sdk, "-w", "-O2", "-fuse-ld=" .. opt.ld64, "-framework", "Foundation", "messages.m"}
    local unversioned = fixtures.refusal(function () fixtures.run(folder, opt.clang, table.join(linked, {"-o", "unversioned"})) end) or ""
    if not unversioned:find("objc_msgSendClass$", 1, true) then
        table.insert(found, "clang without -mlinker-version no longer emits class message stubs ld64 cannot synthesize; the toolchain may stop naming the linker version")
    end
    local errors = fixtures.refusal(function () fixtures.run(folder, opt.clang, table.join(linked, {"-mlinker-version=" .. tostring(version), "-o", "versioned"})) end)
    if errors then
        table.insert(found, "an arm64 executable for iOS 7.0 compiled for ld64 " .. tostring(version) .. " must link with it: " .. errors)
    else
        local imports = fixtures.run(folder, "xcrun", {"nm", "-u", "versioned"})
        if not imports:find("_objc_msgSend\n", 1, true) or imports:find("objc_msgSend%$") then
            table.insert(found, "messages compiled for ld64 must reach _objc_msgSend itself, not a selector stub: " .. imports)
        end
    end
    return found
end

local function selector_failures(folder, opt)
    local found = {}
    local objc = import("apple.objc", {rootdir = opt.modules, anonymous = true})
    io.writefile(path.join(folder, "selectors.m"), SELECTORS)
    for _, case in ipairs({{"armv7", "armv7-apple-ios6.0", "plain"}, {"arm64", "arm64-apple-ios7.0", "plain"},
                           {"armv7", "armv7-apple-ios6.0", "charon_catlist", {"-Wl,-rename_section,__DATA,__objc_catlist,__DATA,__charon_catlist"}}}) do
        local library = "libselectors_" .. case[1] .. "_" .. case[3] .. ".dylib"
        fixtures.run(folder, opt.clang, table.join({"-target", case[2], "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w", "-fobjc-arc",
                                                    "-mlinker-version=" .. fixtures.linker_version(opt.ld64), "-fuse-ld=" .. opt.ld64, "-dynamiclib", "-framework", "Foundation",
                                                    "selectors.m", "-o", library}, case[4] or {}))
        if case[4] and fixtures.run(folder, "xcrun", {"otool", "-l", library}):find("__objc_catlist", 1, true) then
            table.insert(found, "ld64 kept __objc_catlist under -rename_section, which the backports rely on")
        end
        local selectors = objc.binary_selectors(path.join(folder, library), case[1])
        for _, name in ipairs({"probe_reversed", "probeDidFinishWithCount:"}) do
            if not selectors.used["-" .. name] then
                table.insert(found, case[1] .. " " .. case[3] .. ": the library sends " .. name .. ", and its selector references must list it")
            elseif not selectors.implemented["-" .. name] then
                table.insert(found, case[1] .. " " .. case[3] .. ": " .. name .. " is defined by the library itself, in a category on a class it imports or a protocol it declares, and must count as implemented")
            end
        end
    end
    return found
end

-- An object file is not linked yet, so the class a category extends is not bound in its category
-- list but named by an external relocation of the slot; the inventory of the object has to read it,
-- or the category's members answer to no class and a band cannot tell which entries it carries.
local function object_failures(folder, opt)
    local found = {}
    local objc = import("apple.objc", {rootdir = opt.modules, anonymous = true})
    io.writefile(path.join(folder, "category.m"), "#import <Foundation/Foundation.h>\n@implementation NSObject (Probe)\n- (int)probeAddedMember { return 1; }\n@end\n")
    fixtures.run(folder, opt.clang, {"-target", "armv7-apple-ios6.0", "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-c", "category.m", "-o", "category.o"})
    local inventory = objc.binary_inventory(path.join(folder, "category.o"), "armv7")
    local class = inventory and inventory.classes and inventory.classes.NSObject
    if not class or not class.instance["-probeAddedMember"] then
        local named = {}
        for name in pairs(inventory and inventory.classes or {}) do
            table.insert(named, name)
        end
        table.insert(found, "the inventory of an object with a category on NSObject must list -probeAddedMember under NSObject, and names the classes " .. table.concat(named, " "))
    end
    return found
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    for _, check in ipairs({stub_failures, selector_failures, inventory_failures, held_failures, kept_failures, object_failures}) do
        table.join2(found, check(folder, opt))
    end
    os.tryrm(folder)
    return found
end
