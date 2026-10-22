import("fixtures")

local PROBE = [[
#import <Foundation/Foundation.h>
struct Flags { BOOL on : 1; };
const char *revenant_encoding(void) { return @encode(BOOL); }
int revenant_bit(void) { struct Flags f; f.on = YES; return f.on; }
]]

local FLAGS = {"-U__OBJC_BOOL_IS_BOOL", "-D__OBJC_BOOL_IS_BOOL=1"}

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local probe = path.join(folder, "bool.m")
    io.writefile(probe, PROBE)

    local function compile(name, flags, extra)
        local log = path.join(folder, name .. ".log")
        local args = table.join({"-fobjc-arc", "-Werror", "-Wno-incompatible-sysroot", "-target", "armv7-apple-ios6.0",
                                 "-miphoneos-version-min=6.0", "-isysroot", opt.sdk}, flags, extra, {probe})
        local code = os.execv(opt.clang, table.join(args, {"-o", path.join(folder, name)}), {try = true, stdout = log, stderr = log})
        return code == 0, io.readfile(log) or ""
    end

    local function encoding(name, flags)
        local ll = path.join(folder, name .. ".ll")
        local code = os.execv(opt.clang, table.join({"-S", "-emit-llvm", "-fobjc-arc", "-target", "armv7-apple-ios6.0",
                                                    "-miphoneos-version-min=6.0", "-isysroot", opt.sdk,
                                                    "-Wno-incompatible-sysroot"}, flags, {probe, "-o", ll}),
                              {try = true, stdout = path.join(folder, name .. ".ll.log"), stderr = path.join(folder, name .. ".ll.log")})
        if code ~= 0 then
            return nil
        end
        local text = io.readfile(ll) or ""
        if text:find('c"B\\00"', 1, true) then return "B" end
        if text:find('c"c\\00"', 1, true) then return "c" end
        return nil
    end

    local plain_ok, plain_log = compile("plain", {}, {"-c"})
    if plain_ok or not plain_log:find("bit-field", 1, true) then
        table.insert(found, "without the flag the one-bit BOOL bitfield must refuse to compile under -Werror, as it does on armv7")
    end
    local flagged_ok, flagged_log = compile("flagged", FLAGS, {"-c"})
    if not flagged_ok then
        table.insert(found, "with the apple.objc_bool flags the bitfield and the probe must compile under -Werror: " .. flagged_log:trim())
    end
    if encoding("plain-encoding", {}) ~= "c" then
        table.insert(found, "without the flag @encode(BOOL) must be \"c\" on armv7")
    end
    if encoding("flagged-encoding", FLAGS) ~= "B" then
        table.insert(found, "with the apple.objc_bool flags @encode(BOOL) must be \"B\" on armv7")
    end

    os.tryrm(folder)
    return found
end
