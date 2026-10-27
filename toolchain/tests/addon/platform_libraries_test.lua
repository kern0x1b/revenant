import("fixtures")

local function fake_target(values)
    return {
        name = function () return "probe" end,
        values = function (_, key) return values[key] end
    }
end

function failures(opt)
    local platform = import("apple.platform", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    io.writefile(path.join(folder, "entry.c"), "int platform_entry(void) { return 1; }\n")
    fixtures.link(folder, opt.ld64, "libplatform.1.dylib", "armv7-apple-ios6.0", "entry.c",
                  {"-dynamiclib", "-install_name", "/usr/lib/revenant/org.example.platform/libplatform.1.dylib"})
    local built = path.join(folder, "libplatform.1.dylib")
    io.writefile(path.join(folder, "base.c"), "int base_entry(void) { return 2; }\n")
    fixtures.link(folder, opt.ld64, "libbase.1.dylib", "armv7-apple-ios6.0", "base.c",
                  {"-dynamiclib", "-install_name", "/usr/lib/revenant/org.revenant.backports/libbase.1.dylib"})
    io.writefile(path.join(folder, "top.c"), "int base_entry(void);\nint top_entry(void) { return base_entry(); }\n")
    fixtures.link(folder, opt.ld64, "libtop.1.dylib", "armv7-apple-ios6.0", "top.c",
                  {"-dynamiclib", "-install_name", "/usr/lib/revenant/org.revenant.backports/libtop.1.dylib", path.join(folder, "libbase.1.dylib")})
    local top = path.join(folder, "libtop.1.dylib")
    local closed = platform.platform_libraries(fake_target({["revenant.platform"] = {top}}))
    if #closed ~= 2 or not table.contains(closed, path.join(folder, "libbase.1.dylib")) then
        table.insert(found, "a platform library's own platform-folder dependencies must be provided with it: " .. table.concat(closed, " "))
    end

    local libraries = platform.platform_libraries(fake_target({["revenant.platform"] = {built}}))
    if #libraries ~= 1 or libraries[1] ~= built then
        table.insert(found, "the platform libraries a target names must be the built dylibs themselves: " .. table.concat(libraries, " "))
    end
    local exports = os.iorunv("xcrun", {"nm", "-gU", built})
    if not exports:find("_platform_entry", 1, true) then
        table.insert(found, "the named platform library must export the symbols it provides: " .. exports)
    end

    local errors = fixtures.refusal(function ()
        platform.platform_libraries(fake_target({["revenant.platform"] = {path.join(folder, "libabsent.dylib")}}))
    end) or ""
    if not errors:find("not built", 1, true) then
        table.insert(found, "a platform library that is not built must be refused: " .. errors)
    end

    if #platform.platform_libraries(fake_target({})) ~= 0 then
        table.insert(found, "a target that names no platform library must provide none")
    end
    os.tryrm(folder)
    return found
end
