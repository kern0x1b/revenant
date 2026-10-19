package("iphoneos-sdk")
    set_kind("toolchain")
    set_homepage("https://github.com/theos/sdks")
    set_description("The iPhoneOS SDK a build compiles and links against, fetched and verified on the machine that uses it, laid out as an Xcode developer folder with what Xcode once shipped and dropped: Csu's startup objects and libgcc_s.1 in usr/lib, and libarclite in the toolchain")
    set_license("LicenseRef-Apple-SDK")

    -- 16.4 is the theos archive of the 16.5 SDK; 26.2 is the SDK Telegram 12.9.2 is pinned to (versions.json, xcode 26.2), from the
    -- archive xybp888/iOS-SDKs publishes: a zip that carries a __MACOSX folder beside the SDK's own.
    add_urls("https://github.com/$(version)", {version = function (version)
        return ({["16.4"] = "theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz",
                 ["26.2"] = "xybp888/iOS-SDKs/releases/download/iOS26.2-SDKs/iPhoneOS26.2.sdk.zip"})[tostring(version)]
    end})
    add_versions("16.4", "5e0fd3f01266cce4ce012d4a99b38eb56578fca40d09edc81cd83dee958202fb")
    add_versions("26.2", "581b16f4f8902355364bd20f84cd46eb055b131c9b8cc2c7d6d229e36fd5067f")
    add_patches("16.4", "patches/16.4-driverkit-22-availability.patch")
    -- the stubs of 26.2 carry no `$ld$` marker, so what an older release lacks, and where it kept what it has, is told by those of
    -- the 16.5 SDK, the newest that has them, and by markers/iPhoneOS26.2.tsv for what 16.5 did not have
    add_resources("26.2", "markers", "https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz",
                  "5e0fd3f01266cce4ce012d4a99b38eb56578fca40d09edc81cd83dee958202fb")
    for _, version in ipairs({"16.4", "26.2"}) do
        add_resources(version, "csu", "https://github.com/apple-oss-distributions/Csu.git", "de2a331398a7d13a132a630bbf4d27c12b2466ec")
    end
    add_deps("charon@ld64", {alias = "ld64"})

    add_configs("layout", {description = "The SDK sits in the package at Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS<version>.sdk, where clang's driver finds the toolchain's libarclite and CMake's iOS platform files the SDK name.", default = "developer-folder", type = "string", readonly = true})

    local digests = {}
    local inputs = table.join({path.join(os.scriptdir(), "xmake.lua"), path.join(os.scriptdir(), "..", "..", "..", "modules", "apple", "sdkstubs.lua")},
                              os.files(path.join(os.scriptdir(), "usr", "**")), os.files(path.join(os.scriptdir(), "arclite", "*")),
                              os.files(path.join(os.scriptdir(), "blocks", "*")), os.files(path.join(os.scriptdir(), "markers", "*")))
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.relative(file, os.scriptdir()) .. "=" .. hash.sha256(file))
    end
    add_configs("additions", {description = "The digest of this recipe and the files it adds to the SDK, so a changed addition is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install("@macosx", function (package)
        import("core.base.json")
        if not os.isfile("SDKSettings.json") then
            local roots = os.dirs(path.join(os.curdir(), "iPhoneOS*.sdk"))
            if #roots ~= 1 then
                raise("the archive holds no SDKSettings.json, and %d iPhoneOS*.sdk folders beside it where one is wanted", #roots)
            end
            os.cd(roots[1])
        end
        local settings = json.loadfile("SDKSettings.json")
        local wanted = "iphoneos" .. package:version_str()
        if settings.CanonicalName ~= wanted then
            raise("the archive describes itself as %s, not %s", tostring(settings.CanonicalName), wanted)
        end
        local developer = path.join(package:installdir(), "Developer.app", "Contents", "Developer")
        local folder = path.join(developer, "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS" .. package:version_str() .. ".sdk")
        os.mkdir(folder)
        os.vcp("*", folder .. "/")
        local libraries = path.join(folder, "usr", "lib")

        local stubs = import("apple.sdkstubs", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "modules"), anonymous = true})
        local markers = package:resourcedir("markers")
        if markers then
            -- an SDK whose stubs carry none takes those of an older one, and the release each symbol it lacks came with
            local older = os.isfile(path.join(markers, "SDKSettings.json")) and markers or assert(os.dirs(path.join(markers, "iPhoneOS*.sdk"))[1], "the older SDK's archive holds no SDK")
            local first = stubs.releases(io.readfile(path.join(package:scriptdir(), "markers", "iPhoneOS" .. package:version_str() .. ".tsv")))
            local carried, versions, seen = {}, {}, {}
            for _, file in ipairs(os.files(path.join(older, "**.tbd"))) do
                local text = not file:find("/DriverKit/", 1, true) and io.readfile(file)
                if text and text:find("$ld$", 1, true) then
                    for _, part in ipairs(stubs.documents(text)) do
                        local doc = stubs.read(part)
                        for _, marker in ipairs(stubs.markers(doc)) do
                            local key = doc.install .. "\t" .. table.concat(marker.archs, ",") .. "\t" .. marker.token
                            if not seen[key] then
                                seen[key] = true
                                carried[doc.install] = carried[doc.install] or {}
                                table.insert(carried[doc.install], marker)
                                if marker.kind == "hide" and stubs.in_libsystem(doc.install) then
                                    versions[marker.version] = true
                                end
                            end
                        end
                    end
                end
            end
            versions = table.keys(versions)
            table.sort(versions, function (a, b) return stubs.older(a, b) end)

            -- libSystem, and the Objective-C runtime beside it: the two libraries every image links unconditionally and
            -- the compiler itself emits direct calls into (a struct-returning message send lowers to _objc_msgSend_stret
            -- with no source-level reference to it), so their 32-bit ABI is fixed across every release this project
            -- targets, unlike a framework's own surface. libobjc is not in_libsystem (libSystem never re-exports it -
            -- it is force-loaded and linked on its own), so it needs naming here beside it.
            local function is_runtime(install)
                return stubs.in_libsystem(install) or install == "/usr/lib/libobjc.A.dylib"
            end

            -- Those two families' own documents of the older SDK, by install name, read whether or not they carry a
            -- marker: a 32-bit-only symbol (SjLj unwinding, the compiler-rt helpers, the struct-return message sends, ...)
            -- an armv7/armv7s device still exports and this SDK's own stub of the same library has simply stopped
            -- naming, because no 26.2 device is 32-bit.
            local older_runtime = {}
            for _, file in ipairs(os.files(path.join(older, "**.tbd"))) do
                if not file:find("/DriverKit/", 1, true) then
                    for _, part in ipairs(stubs.documents(io.readfile(file))) do
                        local doc = stubs.read(part)
                        if is_runtime(doc.install) and not older_runtime[doc.install] then
                            older_runtime[doc.install] = doc
                        end
                    end
                end
            end

            local changed = 0
            for _, stub in ipairs(os.files(path.join(folder, "**.tbd"))) do
                local text = not stub:find("/DriverKit/", 1, true) and io.readfile(stub)
                if text then
                    local parts = stubs.documents(text)
                    for index, part in ipairs(parts) do
                        local install = stubs.install(part)
                        if carried[install] or stubs.in_libsystem(install) then
                            local wanted = stubs.group(carried[install] or {})
                            local doc = stubs.read(part)
                            if stubs.in_libsystem(install) then
                                table.join2(wanted, stubs.derived(doc, first, versions))
                            end
                            part = stubs.add_markers(part, wanted)
                            if older_runtime[install] then
                                part = stubs.add_symbols(part, stubs.dropped(older_runtime[install], doc))
                            end
                            parts[index] = part
                        end
                    end
                    if table.concat(parts) ~= text then
                        io.writefile(stub, table.concat(parts))
                        changed = changed + 1
                    end
                end
            end
            vprint("%d stubs of %s took markers from %s", changed, folder, older)
        end

        -- what iPhone OS 2 to 4.3 took from libgcc_s the libSystem stubs hide from 3.0 to 4.3; the package extends that to iPhone OS 2
        local extended = 0
        for _, stub in ipairs(table.join(os.files(path.join(libraries, "libSystem*.tbd")), os.files(path.join(libraries, "system", "*.tbd")))) do
            local text, count = io.readfile(stub):gsub("'%$ld%$hide%$os3%.0%$([%w_]+)'", function (symbol)
                return string.format("'$ld$hide$os2.0$%s', '$ld$hide$os2.1$%s', '$ld$hide$os2.2$%s', '$ld$hide$os3.0$%s'", symbol, symbol, symbol, symbol)
            end)
            if count > 0 then
                io.writefile(stub, text)
                extended = extended + 1
            end
        end
        if extended == 0 then
            raise("no libSystem stub in %s hides anything from iOS 3.0, so none says which of its symbols older releases took from libgcc_s", libraries)
        end
        for _, stub in ipairs(os.files(path.join(folder, "**.tbd"))) do
            local text = io.readfile(stub)
            if text:find("$ld$", 1, true) then
                local lines, item, targets, key, markers = {}, {}, nil, nil, {}
                local function has(list, architecture)
                    return list:find("%f[%w]" .. architecture .. "%f[%W]") ~= nil
                end
                local function flush()
                    table.join2(lines, item)
                    if targets and has(targets, "armv7") and not has(targets, "arm64") then
                        local wanted = {}
                        for _, marker in ipairs(markers) do
                            if tonumber(marker.major) >= 7 then
                                table.insert(wanted, marker.text)
                            end
                        end
                        if #wanted > 0 then
                            -- tbd 4 names targets (arm64-ios), tbd 3 architectures (arm64)
                            local names = key == "targets" and "arm64-ios, arm64e-ios" or "arm64, arm64e"
                            table.insert(lines, "  - " .. key .. ": [ " .. names .. " ]")
                            table.insert(lines, "    symbols: [ " .. table.concat(wanted, ", ") .. " ]")
                        end
                    end
                    item, targets, key, markers = {}, nil, nil, {}
                end
                for line in (text .. "\n"):gmatch("([^\n]*)\n") do
                    local named, listed = line:match("^  %- (%a+):%s+%[(.*)%]")
                    if not (named == "targets" or named == "archs") then
                        listed = nil
                    end
                    if listed or not line:startswith("    ") then
                        flush()
                    end
                    if listed then
                        targets, key = listed, named
                    end
                    if targets then
                        table.insert(item, line)
                        for marker, major in line:gmatch("('%$ld%$%a+%$os(%d+)%.%d+%$[^']+')") do
                            if marker:find("^'%$ld%$hide%$") or marker:find("^'%$ld%$add%$") then
                                table.insert(markers, {text = marker, major = major})
                            end
                        end
                    else
                        table.insert(lines, line)
                    end
                end
                flush()
                if lines[#lines] == "" then
                    table.remove(lines)
                end
                io.writefile(stub, table.concat(lines, "\n") .. "\n")
            end
        end
        os.vcp(path.join(package:scriptdir(), "usr", "lib", "*"), libraries .. "/")

        local csu = package:resourcedir("csu")
        local linker = path.join(package:dep("ld64"):installdir("bin"), "ld")
        local objects = {
            {"crt1.o", "2.0", {"start.s", "crt.c", "dyld_glue.s"}, {"-DCRT"}},
            {"crt1.3.1.o", "3.1", {"start.s", "crt.c"}, {"-DADD_PROGRAM_VARS"}},
            {"dylib1.o", "2.0", {"dyld_glue.s"}, {"-DCFM_GLUE"}},
            {"bundle1.o", "2.0", {"dyld_glue.s"}, {}}
        }
        for _, object in ipairs(objects) do
            local slices = {}
            for _, architecture in ipairs({"armv6", "armv7", "armv7s"}) do
                local slice = path.absolute(architecture .. "-" .. object[1])
                local sources = {}
                for _, source in ipairs(object[3]) do
                    table.insert(sources, path.join(csu, source))
                end
                os.vrunv("xcrun", table.join({"clang", "-r", "-target", architecture .. "-apple-ios", "-miphoneos-version-min=" .. object[2],
                                              "-isysroot", folder, "-Os", "-nostdlib", "-Wl,-keep_private_externs", "-fuse-ld=" .. linker},
                                             object[4], sources, {"-o", slice}))
                table.insert(slices, slice)
            end
            os.vrunv("xcrun", table.join({"lipo", "-create"}, slices, {"-output", path.join(libraries, object[1])}))
        end

        local archives = {}
        for _, architecture in ipairs({"armv6", "armv7", "armv7s", "arm64"}) do
            local objects = {}
            for _, source in ipairs(os.files(path.join(package:scriptdir(), "arclite", "*.m"))) do
                local object = path.absolute(architecture .. "-" .. path.basename(source) .. ".o")
                os.vrunv("xcrun", {"clang", "-target", architecture .. "-apple-ios2.0", "-isysroot", folder, "-Os", "-fno-objc-arc",
                                   "-c", source, "-o", object})
                table.insert(objects, object)
            end
            local archive = path.absolute(architecture .. "-libarclite.a")
            os.vrunv("xcrun", table.join({"libtool", "-static", "-o", archive}, objects))
            table.insert(archives, archive)
        end
        local blocks = {}
        for _, architecture in ipairs({"armv6", "armv7"}) do
            local object = path.absolute(architecture .. "-BlocksRuntime.o")
            os.vrunv("xcrun", {"clang", "-target", architecture .. "-apple-ios2.0", "-isysroot", folder, "-Os", "-fno-objc-arc",
                               "-c", path.join(package:scriptdir(), "blocks", "BlocksRuntime.m"), "-o", object})
            local archive = path.absolute(architecture .. "-libBlocksRuntime.a")
            os.vrunv("xcrun", {"libtool", "-static", "-o", archive, object})
            table.insert(blocks, archive)
        end
        os.vrunv("xcrun", table.join({"lipo", "-create"}, blocks, {"-output", path.join(libraries, "libBlocksRuntime.a")}))

        local arc = path.join(developer, "Toolchains", "XcodeDefault.xctoolchain", "usr", "lib", "arc")
        os.mkdir(arc)
        os.vrunv("xcrun", table.join({"lipo", "-create"}, archives, {"-output", path.join(arc, "libarclite_iphoneos.a")}))
    end)

    on_test(function (package)
        local developer = path.join(package:installdir(), "Developer.app", "Contents", "Developer")
        local folder = path.join(developer, "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS" .. package:version_str() .. ".sdk")
        assert(os.isfile(path.join(developer, "Toolchains", "XcodeDefault.xctoolchain", "usr", "lib", "arc", "libarclite_iphoneos.a")))
        assert(os.isfile(path.join(folder, "usr", "include", "simd", "base.h")))
        for _, name in ipairs({"crt1.o", "crt1.3.1.o", "dylib1.o", "bundle1.o", "libgcc_s.1.tbd", "libBlocksRuntime.a"}) do
            assert(os.isfile(path.join(folder, "usr", "lib", name)))
        end
    end)
