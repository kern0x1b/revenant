import("fixtures")

local PROBE = [[
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
int revenant_orientation(void) { return (int)UIDeviceOrientationUnknown; }
]]

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local probe = path.join(folder, "probe.mm")
    io.writefile(probe, PROBE)
    local cxx_modules = import("apple.cxx_modules", {rootdir = opt.modules, anonymous = true})

    local base = {"-target", "arm64-apple-ios13.0", "-isysroot", opt.sdk, "-fmodules", "-fimplicit-module-maps", "-std=c++20"}

    local log = path.join(folder, "probe.log")
    local code = os.execv(opt.clang, table.join({"-fsyntax-only"}, base, cxx_modules.flags(), {probe}),
                          {try = true, stdout = log, stderr = log})
    if code ~= 0 then
        table.insert(found, "an Objective-C++ translation unit that imports UIKit must compile with the toolchain's flags under -fmodules -std=c++20 "
                            .. "against the iOS SDK, as Apple's clang does: " .. (io.readfile(log) or ""):trim())
    end

    local driver = path.join(folder, "driver.log")
    os.execv(opt.clang, table.join({"-###"}, base, cxx_modules.flags(), {"-fcxx-modules", probe}),
             {try = true, stdout = driver, stderr = driver})
    if not (io.readfile(driver) or ""):find('"-fmodules"', 1, true) then
        table.insert(found, "an explicit -fcxx-modules after the toolchain's flags must turn C++ modules back on, since the last flag wins")
    end

    os.tryrm(folder)
    return found
end
