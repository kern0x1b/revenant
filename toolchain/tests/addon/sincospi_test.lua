local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

local SYMBOLS = {"__sinpi", "__cospi", "__tanpi", "__sincospi", "__sinpif", "__cospif", "__tanpif", "__sincospif"}

local DEFINES = {"-D__sinpi=revenant_sinpi", "-D__cospi=revenant_cospi", "-D__tanpi=revenant_tanpi",
                 "-D__sincospi=revenant_sincospi", "-D__sinpif=revenant_sinpif", "-D__cospif=revenant_cospif",
                 "-D__tanpif=revenant_tanpif", "-D__sincospif=revenant_sincospif", "-D__MAC_OS_X_VERSION_MIN_REQUIRED=1080"}

local function ios6(sdk)
    return {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-Wno-incompatible-sysroot", "-isysroot", sdk}
end

function failures(arguments)
    local implementation = path.join(os.scriptdir(), "..", "..", "src", "apple-compat", "src")
    local output = workspace.run("apple-compat-sincospi")
    os.rm(output)
    os.mkdir(output)
    local found = {}
    local probe = path.join(output, "simd_probe.cpp")
    io.writefile(probe, "#include <simd/simd.h>\nint main() { return 0; }\n")
    local before_log = path.join(output, "before.log")
    local before = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-x", "c++", "-c", probe, "-o", path.join(output, "before.o")}),
                            {try = true, stdout = before_log, stderr = before_log})
    local diagnostic = io.readfile(before_log) or ""
    if before == 0 or not diagnostic:find("no member named '__sincospif' in the global namespace", 1, true) then
        table.insert(found, "the armv7 iOS 6 SIMD probe did not reproduce the __sincospif declaration failure: " .. diagnostic)
    end
    local vfs = lowered.overlay(arguments.sdk, path.join(output, "overlay"))
    local after_log = path.join(output, "after.log")
    local after = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-ivfsoverlay", vfs, "-I" .. lowered.include_directory(path.join(output, "overlay")),
                                                          "-x", "c++", "-c", probe, "-o", path.join(output, "after.o")}),
                           {try = true, stdout = after_log, stderr = after_log})
    if after ~= 0 then
        table.insert(found, "the armv7 iOS 6 SIMD probe still fails with the lowered math header: " .. (io.readfile(after_log) or ""))
    end
    local objects = {}
    for _, symbol in ipairs(SYMBOLS) do
        local object = path.join(output, symbol .. ".o")
        local log = path.join(output, symbol .. ".compile.log")
        local built = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-std=c11", "-Os", "-fno-builtin", "-ffp-contract=off",
                                                              "-fvisibility=hidden", "-Wall", "-Wextra", "-Werror", "-c",
                                                              path.join(implementation, symbol .. ".c"), "-o", object}),
                              {try = true, stdout = log, stderr = log})
        if built ~= 0 then
            table.insert(found, symbol .. " does not compile for armv7 iOS 6: " .. (io.readfile(log) or ""))
        end
        table.insert(objects, object)
    end
    local link_probe = path.join(output, "link_probe.c")
    io.writefile(link_probe, table.concat({
        "void __sincospi(double, double *, double *);",
        "void __sincospif(float, float *, float *);",
        "double __sinpi(double);", "double __cospi(double);", "double __tanpi(double);",
        "float __sinpif(float);", "float __cospif(float);", "float __tanpif(float);",
        "int main(int argc, char **argv) {",
        "    double s, c; float fs, fc;",
        "    __sincospi(argc / 3.0, &s, &c); __sincospif(argc / 3.0f, &fs, &fc);",
        "    return (int)(__sinpi(argc) + __cospi(argc) + __tanpi(argc) + __sinpif(argc) + __cospif(argc) + __tanpif(argc) + s + c + fs + fc);",
        "}", ""}, "\n"))
    local linked_log = path.join(output, "link.log")
    local linked = os.execv(arguments.clang, table.join(ios6(arguments.sdk), {"-Os", link_probe}, objects, {"-o", path.join(output, "link_probe")}),
                            {try = true, stdout = linked_log, stderr = linked_log})
    if linked ~= 0 then
        table.insert(found, "the armv7 iOS 6 link of the eight symbols failed: " .. (io.readfile(linked_log) or ""))
    end
    local executable = path.join(output, "sincospi")
    local log = path.join(output, "build.log")
    local test_object = path.join(output, "sincospi_test.o")
    local compiled = {}
    local host_sources = {}
    for _, symbol in ipairs(SYMBOLS) do
        local object = path.join(output, symbol .. ".host.o")
        table.insert(host_sources, object)
        table.insert(compiled, table.join({"-std=c11", "-O2", "-Wall", "-Wextra", "-Werror", "-ffp-contract=off", "-fno-builtin", "-I" .. implementation},
                                          DEFINES, {"-c", path.join(implementation, symbol .. ".c"), "-o", object}))
    end
    table.insert(compiled, {"-std=c11", "-O2", "-Wall", "-ffp-contract=off", "-fno-builtin", "-c", path.join(os.scriptdir(), "sincospi.c"),
                            "-o", test_object})
    table.insert(compiled, table.join(host_sources, {test_object, "-lm", "-o", executable}))
    for _, command in ipairs(compiled) do
        local built = os.execv("cc", command, {try = true, stdout = log, stderr = log})
        if built ~= 0 then
            table.insert(found, "the host accuracy test did not compile: " .. (io.readfile(log) or ""))
            return found
        end
    end
    local ran = os.execv(executable, {}, {try = true, stdout = log, stderr = log, timeout = 600000})
    if ran ~= 0 then
        table.insert(found, "the host accuracy test failed: " .. (io.readfile(log) or ""))
    end
    return found
end
