import("fixtures")

local MODES = [[
__attribute__((target("arm"))) int in_arm(int x) { return x + 1; }
__attribute__((target("thumb"))) int in_thumb(int x) { return x + 2; }
int (*table[])(int) = { in_arm, in_thumb };
int start(void) { return table[0](1) + table[1](1); }
]]

local LOCAL_MODES = [[
__attribute__((target("arm"))) static int in_arm(int x) { return x + 1; }
__attribute__((target("thumb"))) static int in_thumb(int x) { return x + 2; }
int (*table[])(int) = { in_arm, in_thumb };
]]

local function made_fixtures(folder, ld64)
    io.writefile(path.join(folder, "modes.c"), MODES)
    io.writefile(path.join(folder, "entry.c"), "int start(void) { return 0; }\n")
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    local made = {
        library = fixtures.link(folder, ld64, "libmodes.dylib", "armv7-apple-ios6.0", "modes.c", {"-dynamiclib"}),
        classic = fixtures.link(folder, ld64, "libclassic.dylib", "armv7-apple-ios3.0", "modes.c", {"-dynamiclib"}),
        executable = fixtures.link(folder, ld64, "modes", "armv7-apple-ios6.0", "modes.c", {"-Wl,-e,_start"}),
        arm64 = fixtures.link(folder, ld64, "wide", "arm64-apple-ios7.0", "entry.c", {"-Wl,-e,_start"}),
        ["arm64-small-pagezero"] = fixtures.link(folder, ld64, "narrow", "arm64-apple-ios7.0", "entry.c",
                                                 {"-Wl,-e,_start", "-Wl,-pagezero_size,0x1000"})
    }
    local table_at = fixtures.section_offset(folder, "libmodes.dylib", "__DATA", "__data")
    local arm, thumb = fixtures.slot(made.library, table_at), fixtures.slot(made.library, table_at + 4)
    made["arm-with-thumb-bit"] = fixtures.edited(made.library, path.join(folder, "libarmbit.dylib"), table_at, arm | 1)
    made["thumb-without-bit"] = fixtures.edited(made.library, path.join(folder, "libnobit.dylib"), table_at + 4, thumb & ~1)
    local classic = fixtures.section_offset(folder, "libclassic.dylib", "__DATA", "__data")
    made["classic-thumb-without-bit"] = fixtures.edited(made.classic, path.join(folder, "libclassicnobit.dylib"), classic + 4,
                                                        fixtures.slot(made.classic, classic + 4) & ~1)
    local data = io.readfile(made.executable, {encoding = "binary"})
    local zero = data:find("__PAGEZERO\0", 1, true) - 1
    made["armv7-pagezero-gap"] = fixtures.edited(made.executable, path.join(folder, "gapped"), zero + 20, 0x1000)
    fixtures.link(folder, ld64, "libwide.dylib", "arm64-apple-ios7.0", "entry.c", {"-dynamiclib"})
    fixtures.run(folder, "xcrun", {"lipo", "-create", made["thumb-without-bit"], "libwide.dylib", "-output", "fat.dylib"})
    made["fat-with-thumb-without-bit"] = path.join(folder, "fat.dylib")
    fixtures.run(folder, "xcrun", {"lipo", "-create", made.executable, made["arm64-small-pagezero"], "-output", "fat-narrow"})
    made["fat-arm64-small-pagezero"] = path.join(folder, "fat-narrow")
    return made, arm, thumb
end

local function invariant_failures(macho, made, arm, thumb)
    local found = {}
    if arm & 1 ~= 0 or thumb & 1 == 0 then
        return {string.format("ld64 must link the ARM pointer without bit 0 and the Thumb pointer with it: got %#x and %#x", arm, thumb)}
    end
    for _, expected in ipairs({
            {"library", nil}, {"classic", nil}, {"executable", nil},
            {"arm-with-thumb-bit", "ARM function _in_arm has bit 0 set"},
            {"thumb-without-bit", "Thumb function _in_thumb lacks bit 0"},
            {"classic-thumb-without-bit", "Thumb function _in_thumb lacks bit 0"},
            {"fat-with-thumb-without-bit", "Thumb function _in_thumb lacks bit 0"}}) do
        local name, reason = expected[1], expected[2]
        local problems, counted, into_code = macho.interworking_problems(made[name])
        if into_code ~= 2 then
            table.insert(found, string.format("%s: 2 rebased pointers lead into code, counted %d", name, into_code))
        end
        if counted ~= 2 then
            table.insert(found, string.format("%s: 2 pointers must be compared with their functions, got %d", name, counted))
        end
        if (reason and (#problems ~= 1 or not problems[1]:find(reason, 1, true))) or (not reason and #problems > 0) then
            table.insert(found, string.format("%s: expected %s, got %s", name, reason or "nothing", table.concat(problems, "; ")))
        end
    end
    for _, expected in ipairs({
            {"executable", nil}, {"arm64", nil}, {"library", nil},
            {"arm64-small-pagezero", "arm64 __PAGEZERO is 0x4000"},
            {"fat-arm64-small-pagezero", "arm64 __PAGEZERO is 0x4000"},
            {"armv7-pagezero-gap", "__PAGEZERO ends at 0x1000 and __TEXT starts at 0x4000"}}) do
        local name, reason = expected[1], expected[2]
        local problems = macho.pagezero_problems(made[name])
        if (not reason and #problems > 0) or (reason and (#problems ~= 1 or not problems[1]:find(reason, 1, true))) then
            table.insert(found, string.format("%s: pagezero expected %s, got %s", name, reason or "nothing", table.concat(problems, "; ")))
        end
    end
    return found
end

local function stripped_failures(macho, folder, ld64)
    local found = {}
    io.writefile(path.join(folder, "local.c"), LOCAL_MODES)
    fixtures.link(folder, ld64, "liblocal.dylib", "armv7-apple-ios6.0", "local.c", {"-dynamiclib"})
    os.cp(path.join(folder, "liblocal.dylib"), path.join(folder, "libstripped.dylib"))
    fixtures.run(folder, "xcrun", {"strip", "-x", "libstripped.dylib"})
    io.writefile(path.join(folder, "libimports.tbd"), fixtures.system_stub("_first, _second", "/usr/lib/libimports.dylib"))
    io.writefile(path.join(folder, "daemon.c"), "extern int first(void); extern int second(void);\nint start(void) { return first() + second(); }\n")
    fixtures.link(folder, ld64, "daemon", "armv7-apple-ios6.0", "daemon.c", {"-Wl,-e,_start", "-limports"})
    local problems, _, into_code = macho.interworking_problems(path.join(folder, "daemon"))
    if into_code > 0 or #problems > 0 then
        table.insert(found, "an executable whose only code pointers are dyld's lazy binding slots has no program pointer to check")
    end
    for _, case in ipairs({
            {"liblocal.dylib", {}, nil},
            {"libstripped.dylib", {}, "arrived stripped"},
            {"libstripped.dylib", {stripped = true}, nil},
            {"libstripped.dylib", {waived = {["thumb-interworking"] = "a reason"}}, nil}}) do
        local errors = fixtures.refusal(function () macho.verify(path.join(folder, case[1]), case[2]) end)
        if (case[3] and (not errors or not errors:find(case[3], 1, true))) or (not case[3] and errors) then
            table.insert(found, string.format("%s: expected %s, got %s", case[1], case[3] or "success", errors or "success"))
        end
    end
    return found
end

local function weak_import_failures(macho, compat, folder, ld64)
    local found = {}
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub("dyld_stub_binder, _clock_gettime, _openat, ___strlcpy_chk"))
    local sources = {
        late = "extern int clock_gettime(int, void *) __attribute__((weak_import));\nint use(void) { return clock_gettime(0, 0); }\n",
        guarded = "extern int openat(int, const char *, int) __attribute__((weak_import));\nint use(void) { return openat ? openat(0, \"x\", 0) : -1; }\n",
        strong = "extern unsigned long __strlcpy_chk(char *, const char *, unsigned long, unsigned long);\nunsigned long use(char *d) { return __strlcpy_chk(d, \"x\", 2, 2); }\n"
    }
    for name, source in pairs(sources) do
        io.writefile(path.join(folder, name .. ".c"), source)
        fixtures.link(folder, ld64, "lib" .. name .. ".dylib", "armv7-apple-ios6.0", name .. ".c", {"-dynamiclib"})
    end
    fixtures.link(folder, ld64, "libwide-arm64.dylib", "arm64-apple-ios7.0", "strong.c", {"-dynamiclib"})
    fixtures.run(folder, "xcrun", {"lipo", "-create", "libguarded.dylib", "libwide-arm64.dylib", "-output", "libfat.dylib"})
    fixtures.run(folder, "xcrun", {"lipo", "-create", "libstrong.dylib", "libwide-arm64.dylib", "-output", "libfatlate.dylib"})
    local arrived = {aligned_alloc = "13.0", clock_gettime = "10.0", fdopendir = "8.0", __strlcpy_chk = "7.0"}
    for _, case in ipairs({
            {"late", {}, "clock_gettime arrived in 10.0"},
            {"guarded", {}, nil},
            {"late", {["weak-imports"] = "a reason"}, nil},
            {"strong", {}, "dyld refuses to load it there: armv7: __strlcpy_chk arrived in 7.0"},
            {"strong", {["weak-imports"] = "a reason"}, "__strlcpy_chk arrived in 7.0"},
            {"fat", {}, nil},
            {"fatlate", {}, "armv7: __strlcpy_chk arrived in 7.0, after 6.0"}}) do
        local binary = path.join(folder, "lib" .. case[1] .. ".dylib")
        local errors = fixtures.refusal(function () macho.verify(binary, {waived = case[2], arrived = arrived}) end)
        if (case[3] and (not errors or not errors:find(case[3], 1, true))) or (not case[3] and errors) then
            table.insert(found, string.format("lib%s.dylib: expected %s, got %s", case[1], case[3] or "success", errors or "success"))
        end
    end
    return found
end

local function signing_failures(signing, folder, ldid)
    local found = {}
    local binary = path.join(folder, "liblocal.dylib")
    local entitlements = path.join(folder, "entitlements.plist")
    io.writefile(entitlements, [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>platform-application</key><true/><key>com.apple.private.security.no-container</key><true/></dict></plist>
]])
    signing.sign(ldid, binary, {entitlements = entitlements})
    local signed = signing.signed_entitlements(ldid, binary)
    if signed["platform-application"] ~= true then
        table.insert(found, "an entitled binary must carry what it was signed with")
    end
    local problems = signing.entitlement_problems({["platform-application"] = true, ["get-task-allow"] = true}, signed)
    if #problems ~= 1 or not problems[1]:find("get-task-allow is declared and the signature does not carry it", 1, true) then
        table.insert(found, "a declared entitlement the signature lacks must be named: " .. table.concat(problems, "; "))
    end
    return found
end

local function encryption_failures(macho, folder, ld64, sdk)
    local found = {}
    if macho.encrypted(path.join(folder, "liblocal.dylib")) then
        table.insert(found, "an ld64 link carries no LC_ENCRYPTION_INFO")
    end
    fixtures.run(folder, "xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-Wno-incompatible-sysroot", "-nostdlib", "-L.",
                                   "-lSystem", "-dynamiclib", "-o", "libstamped.dylib", "local.c"})
    local stamped = macho.encrypted(path.join(folder, "libstamped.dylib"))
    local listed = fixtures.run(folder, "xcrun", {"otool", "-l", "libstamped.dylib"}):find("LC_ENCRYPTION_INFO", 1, true) ~= nil
    if not listed then
        table.insert(found, "the system linker no longer stamps LC_ENCRYPTION_INFO on armv7, so this fixture proves nothing about the refusal")
    elseif not stamped then
        table.insert(found, "the Mach-O reader and otool disagree about LC_ENCRYPTION_INFO in an armv7 link by the system linker")
    end
    fixtures.link(folder, ld64, "libwide-stamped.dylib", "arm64-apple-ios7.0", "local.c", {"-dynamiclib"})
    if macho.encrypted(path.join(folder, "libwide-stamped.dylib")) then
        table.insert(found, "an arm64 slice's encryption info is not what iOS 6 refuses")
    end
    return found
end

local function input_minimum_failures(macho, folder)
    local found = {}
    io.writefile(path.join(folder, "part.c"), "int part(void) { return 1; }\n")
    fixtures.run(folder, "xcrun", {"clang", "-c", "-target", "armv7-apple-ios", "-miphoneos-version-min=6.0", "-o", "six.o", "part.c"})
    fixtures.run(folder, "xcrun", {"clang", "-c", "-target", "armv7-apple-ios", "-miphoneos-version-min=9.0", "-o", "nine.o", "part.c"})
    io.writefile(path.join(folder, "bare.s"), ".text\n.globl _bare\n_bare:\n bx lr\n")
    fixtures.run(folder, "xcrun", {"as", "-arch", "armv7", "-o", "bare.o", "bare.s"})
    fixtures.run(folder, "xcrun", {"libtool", "-static", "-o", "libmixed.a", "six.o", "nine.o", "bare.o"})
    local recorded = {}
    for _, entry in ipairs(macho.recorded_minimums(path.join(folder, "libmixed.a"), "armv7")) do
        recorded[entry.member] = entry.minimum and macho.version_text(entry.minimum) or "none"
    end
    if recorded["six.o"] ~= "6.0" or recorded["nine.o"] ~= "9.0" or not recorded["bare.o"] or recorded["bare.o"] == "6.0" then
        table.insert(found, "archive members must report their own minimums, got six.o=" .. tostring(recorded["six.o"]) .. " nine.o=" .. tostring(recorded["nine.o"]) .. " bare.o=" .. tostring(recorded["bare.o"]))
    end
    local single = macho.recorded_minimums(path.join(folder, "six.o"), "armv7")
    if #single ~= 1 or single[1].member or macho.version_text(single[1].minimum) ~= "6.0" then
        table.insert(found, "an object file reports one minimum and no member")
    end
    if #macho.recorded_minimums(path.join(folder, "six.o"), "arm64") ~= 0 then
        table.insert(found, "an armv7 object has nothing to say about arm64")
    end
    return found
end

local function linker_option_failures(macho, folder)
    local found = {}
    io.writefile(path.join(folder, "asks.c"), "int kept;\n")
    fixtures.run(folder, "xcrun", {"clang", "-c", "-target", "armv7-apple-ios", "-miphoneos-version-min=6.0", "-Xclang", "--linker-option=-lasked", "-Xclang", "--linker-option=-lsecond", "-o", "asks.o", "asks.c"})
    local asked = {}
    for _, options in ipairs(macho.images(macho.read(path.join(folder, "asks.o")))[1].linker_options) do
        table.insert(asked, table.concat(options, " "))
    end
    if table.concat(asked, ",") ~= "-lasked,-lsecond" then
        table.insert(found, "an object that asks for libasked and libsecond must be read as -lasked then -lsecond, got " .. table.concat(asked, ","))
    end
    return found
end

local function entry_failures(macho, folder, ld64)
    local found = {}
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    io.writefile(path.join(folder, "thumbmain.c"), "__attribute__((target(\"thumb\"))) int main(void) { return 0; }\n")
    local good = fixtures.link(folder, ld64, "thumbmain", "armv7-apple-ios6.0", "thumbmain.c")
    local at = macho.images(macho.read(good))[1].entryoff_at
    local entry = fixtures.slot(good, at)
    if entry & 1 == 0 then
        table.insert(found, string.format("ld64 must keep the Thumb bit in LC_MAIN for a Thumb main, got %#x", entry))
    end
    local cleared = fixtures.edited(good, path.join(folder, "thumbmain-nobit"), at, entry & ~1)
    if fixtures.refusal(function () macho.verify(good) end) then
        table.insert(found, "a Thumb main with the Thumb bit in LC_MAIN must pass verify")
    end
    local problems = macho.entry_problems(cleared)
    if #problems ~= 1 or not problems[1]:find("without bit 0", 1, true) then
        table.insert(found, "a Thumb main without the bit in LC_MAIN must be refused, got " .. table.concat(problems, "; "))
    end
    local refused = fixtures.refusal(function () macho.verify(cleared) end)
    if not refused or not refused:find("the LC_MAIN entry", 1, true) then
        table.insert(found, "verify must refuse the same binary by name, got " .. tostring(refused))
    end
    return found
end

function failures(opt)
    local macho = import("apple.macho", {rootdir = opt.modules, anonymous = true})
    local compat = import("apple.compat", {rootdir = opt.modules, anonymous = true})
    local signing = import("apple.signing", {rootdir = opt.modules, anonymous = true})
    local folder = fixtures.scratch()
    local made, arm, thumb = made_fixtures(folder, opt.ld64)
    local found = invariant_failures(macho, made, arm, thumb)
    table.join2(found, stripped_failures(macho, folder, opt.ld64))
    table.join2(found, encryption_failures(macho, folder, opt.ld64, opt.sdk))
    table.join2(found, signing_failures(signing, folder, opt.ldid))
    table.join2(found, weak_import_failures(macho, compat, folder, opt.ld64))
    table.join2(found, input_minimum_failures(macho, folder))
    table.join2(found, linker_option_failures(macho, folder))
    table.join2(found, entry_failures(macho, folder, opt.ld64))
    os.tryrm(folder)
    return found
end
