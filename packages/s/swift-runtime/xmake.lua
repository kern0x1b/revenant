package("swift-runtime")
    set_homepage("https://www.swift.org")
    set_description("The Swift runtime an iOS older than Swift itself does not ship: the standard library, concurrency, synchronization, regular expressions and observation, built for the port's architecture and oldest release from the sources of the swift package")
    set_license("Apache-2.0 WITH Swift-exception")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/swiftlang/swift.git")
    add_versions("6.4.0", "b8189d766d86ad7fc8106787d6ce9e402f38dd72")

    add_deps("revenant@swift 6.4.0", {alias = "swift", host = true, private = true, system = false})

    local renamed = {"clock_gettime", "clock_getres", "dispatch_get_global_queue", "memset_s", "os_system_version_get_current_version"}

    local sources = {
        {name = "platform", tag = "swift-6.2-RELEASE", commit = "1ff1cc1170617ab23ab74aa8b741c8daca1903f6",
         url = "https://github.com/swiftlang/swift.git", sparse = {"/stdlib/public/Platform/", "/LICENSE.txt"}},
        {name = "overlays", tag = "swift-5.4.3-RELEASE", commit = "282fe25d1757ff9974ade028d92111acdae6876a",
         url = "https://github.com/swiftlang/swift.git",
         sparse = {"/stdlib/public/Darwin/ObjectiveC/", "/stdlib/public/Darwin/Dispatch/", "/stdlib/public/Darwin/CoreFoundation/",
                   "/stdlib/public/Darwin/CoreGraphics/", "/stdlib/public/SwiftShims/ObjectiveCOverlayShims.h",
                   "/stdlib/public/SwiftShims/DispatchOverlayShims.h", "/stdlib/public/Darwin/Foundation/",
                   "/stdlib/public/SwiftShims/Foundation*.h", "/stdlib/public/SwiftShims/NS*Shims.h",
                   "/stdlib/public/SwiftShims/CoreFoundationOverlayShims.h", "/stdlib/public/SwiftShims/CF*Shims.h", "/LICENSE.txt"}},
        {name = "uikit", tag = "swift-5.2.5-RELEASE", commit = "71d85a7c28eed8f46241649a723ddf23989139c6",
         url = "https://github.com/swiftlang/swift.git",
         sparse = {"/stdlib/public/Darwin/UIKit/", "/stdlib/public/Darwin/QuartzCore/", "/stdlib/public/Darwin/CoreData/",
                   "/stdlib/public/SwiftShims/UIKitOverlayShims.h",
                   "/LICENSE.txt"}}
    }

    on_download(function (package, opt)
        if not package:config("shared") and import("@addon.revenant.prebuilt", {anonymous = true}).fetch(package) then
            return
        end
        local checkout = import("@addon.revenant.checkout", {anonymous = true})
        checkout.pinned(opt.sourcedir, sources)
    end)

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("recipe", {description = "The digest of this recipe and the changes it makes to the runtime's sources, so a changed flag or patch is a different runtime.", default = swift_runtime_sources_digest, type = "string", readonly = true})

    add_configs("library_evolution", {description = "Build the standard library, the runtime and concurrency with library evolution, for programs compiled by an SDK's Swift that bind to its resilient symbols. Writes no .swiftinterface, and an arm64 install stops after Darwin (the SDK has the other overlays); another build of its own, named by its own mark.", default = false, type = "boolean"})

    add_configs("shared", {description = "Install the libraries under absolute install names and leave what a Debian package holding them is written from, which the programs built against this runtime depend on instead of carrying the libraries: the program that depends on it writes and signs that package, so this package needs no host tool.", default = false, type = "boolean"})

    on_load("iphoneos", function (package)
        local sdk = assert(package:toolchains(), "swift-runtime is built with the apple-ios toolchain")[1]:config("sdk")
        package:add("deps", "revenant@apple-compat", {alias = "apple-compat", configs = {apple_sdk = sdk}})
        package:add("deps", "revenant@libcxx", {alias = "libcxx", configs = {packaged = package:config("shared") or nil}})
        package:add("links", "swiftCore")
        if package:config("shared") then
            local runtime = import("@addon.revenant.apple.shared_runtime", {anonymous = true})
            for _, kind in ipairs({"swift-runtime", "swift-runtime-ui"}) do
                package:add("linkdirs", path.join("share", "root", "usr", "lib", "revenant", runtime.package_name(kind, package:buildhash())))
            end
        else
            package:add("linkdirs", path.join("lib", "swift", "iphoneos"))
        end
        package:data_set("mark", "revenant_swift_runtime_" .. package:buildhash())
    end)

    on_install("iphoneos", function (package)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local gyb = import("@addon.revenant.gyb.template", {anonymous = true})
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local compat = import("@addon.revenant.apple.compat", {anonymous = true})
        local compiler = assert(package:dep("swift"), "the runtime is built with revenant@swift")
        local libcxx = assert(package:dep("libcxx"), "the runtime links the C++ runtime of revenant@libcxx")
        local shims = assert(package:dep("apple-compat"), "the runtime takes what the release lacks from revenant@apple-compat")
        local toolchain = cmake.toolchain(package)
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local swiftc = path.join(compiler:installdir("bin"), "swiftc")

        package:setenv("SWIFT_EXEC", swiftc)
        package:setenv("SWIFT_PLUGIN_PATH", path.join(compiler:installdir("lib"), "swift", "host", "plugins"))
        package:setenv("REVENANT_SWIFT_RUNTIME_MARK", package:data("mark"))
        if not package:config("shared") and import("@addon.revenant.prebuilt", {anonymous = true}).install(package) then
            return
        end
        local parallel = import("@addon.revenant.parallel", {anonymous = true})

        local marked = os.getenv("SWIFTRT_PROFILE") and {} or nil
        local phase = marked and os.mclock() or 0
        local function timed(name)
            if not marked then
                return
            end
            local now = os.mclock()
            marked[#marked + 1] = {name, (now - phase) / 1000}
            phase = now
            printf("swift-runtime: %-28s %8.1fs (so far)\n", name, marked[#marked][2])
        end
        local install = path.join(package:installdir("lib"), "swift")

        local stdlib_key = string.format("compiler=%s\nrecipe=%s\nminimum=%s\narch=%s\n",
                                         compiler:buildhash(), package:buildhash(), minimum, package:arch())
        local stdlib_stamp = path.absolute(".stdlib.key")
        local stdlib_kept = os.isfile(stdlib_stamp) and io.readfile(stdlib_stamp) == stdlib_key
                           and os.isdir(path.join(path.absolute("build"), "core"))
                           and os.isdir(path.absolute("swift-source"))
        if stdlib_kept then
            for _, scratch in ipairs({"overlay", "resources", "simd", "synchronization", "observation", "stringprocessing"}) do
                os.tryrm(path.join(path.absolute("build"), scratch))
            end
            print("swift-runtime: the standard library's build tree answers for these inputs and is kept")
        else
            os.tryrm(stdlib_stamp)
            os.tryrm(path.absolute("build"))
        end

        local source = path.absolute("swift-source")
        local gyb_defines = {CMAKE_SIZEOF_VOID_P = package:arch() == "arm64" and "8" or "4"}
        local function expand(template, output)
            gyb.expand_to(template, output, {defines = gyb_defines, line_directive = "", paths = {path.join(source, "utils")}})
            return output
        end
        local gyb_command = "-DGYB_COMMAND=" .. table.concat({os.programfile(), "l", import("@addon.revenant.data", {anonymous = true}).modules("gyb", "main.lua")}, ";")
        if not stdlib_kept then
            os.tryrm(source)
            os.vcp(path.join(compiler:installdir("share"), "swift-source"), source)
            local patches = os.files(path.join(package:scriptdir(), "patches", "*.patch"))
            table.sort(patches)
            for _, patch in ipairs(patches) do
                os.vrunv("patch", {"-p1", "-i", patch}, {curdir = source})
            end
        end

        if not stdlib_kept then
            io.writefile(path.join(source, "utils", "availability-macros.def"), swift.bundled_availability(source))
        end

        if not stdlib_kept then
            local overlay_shims = path.join(source, "stdlib", "public", "SwiftShims", "swift", "shims", "LibcOverlayShims.h")
            local renamed_shims, calls = io.readfile(overlay_shims):gsub("return openat%(", "return revenant_openat(")
            assert(calls == 1, "the shims of Swift " .. package:version_str() ..
                   " no longer call openat exactly once, and this runtime would ship a header that does not say what it does")
            local declared, declarations = renamed_shims:gsub("(int static inline _swift_stdlib_openat)",
                                                              "extern int revenant_openat(int directory, const char *path, int flags, ...);\n%1", 1)
            assert(declarations == 1, "the shims of Swift " .. package:version_str() .. " no longer declare _swift_stdlib_openat as they did")
            io.writefile(overlay_shims, declared)

            os.vrunv("cmake", {"-DStringProcessing_ROOT_DIR=" .. compiler:installdir("share"), "-P",
                               path.join(source, "Runtimes", "Resync.cmake")})
            assert(os.isdir(path.join(source, "Runtimes", "Supplemental", "StringProcessing", "_RegexParser")),
                   "the resync left the regular expression libraries without sources; the swift package installs them beside the release's")
        end

        local mark = package:data("mark")
        io.writefile("mark.c", string.format("/* The build of the Swift runtime a program was compiled against. */\n__attribute__((visibility(\"default\")))\nconst char %s = 0;\n", mark))
        os.vrunv(toolchain:tool("cc"), {"-target", triple, "-miphoneos-version-min=" .. minimum, "-isysroot",
                 toolchain:config("sdkdir"), "-Os", "-c", "mark.c", "-o", path.absolute("mark.o")})
        timed("sources")

        local linker_version = toolchain:config("linker_version") and
                               {"-Xclang-linker", "-mlinker-version=" .. toolchain:config("linker_version")} or {}
        local objc_linker = toolchain:config("linker_version") and {"-mlinker-version=" .. toolchain:config("linker_version")} or {}

        local use_ld = {}
        for _, flag in ipairs(table.wrap(toolchain:get("shflags"))) do
            if flag:startswith("-fuse-ld=") then
                use_ld = {"-use-ld=" .. flag:sub(#"-fuse-ld=" + 1)}
            end
        end

        local includes = compat.force_includes(shims, renamed)
        local shim_library = os.isfile(path.join(shims:installdir("lib"), "libapple-compat.a")) and
                             {"-L" .. shims:installdir("lib"), "-lapple-compat"} or {}
        local runtime_flags = table.join({"-clang-target", triple, "-Xfrontend", "-bundled-swift-runtime",
                                          "-runtime-compatibility-version", "none",
                                          "-disable-autolinking-runtime-compatibility-dynamic-replacements",
                                          "-Xfrontend", "-disable-autolinking-runtime-compatibility-concurrency",
                                          "-tools-directory", path.directory(toolchain:tool("cc")),
                                          "-sdk", toolchain:config("sdkdir"),
                                          "-Xclang-linker", "-nostdlib++"}, linker_version, {
                                          "-L" .. libcxx:installdir("lib"), "-lc++", "-lc++abi"}, shim_library)
        local linked = table.join({"-nostdlib++", "-L" .. libcxx:installdir("lib"), "-lc++", "-lc++abi"}, shim_library)

        local function toolchain_file(name, extra)
            extra = extra or {}
            return cmake.toolchain_file(package, {
                system = "Darwin", builddir = path.absolute(path.join("build", name)),
                cflags = includes, cxxflags = table.join(includes, extra.cxxflags or {}), ldflags = linked,
                shflags = extra.shflags or {},
                swift = {compiler = swiftc, flags = table.join(runtime_flags, extra.swiftflags or {})}})
        end

        local ninja = assert(import("lib.detect.find_tool")("ninja"), "ninja builds the Swift runtime").program
        local function configure(name, sourcedir, extra, configs)
            local builddir = path.absolute(path.join("build", name))
            os.vrunv("cmake", table.join({"-G", "Ninja", "-S", sourcedir, "-B", builddir,
                "-DCMAKE_TOOLCHAIN_FILE=" .. toolchain_file(name, extra), "-DCMAKE_POLICY_DEFAULT_CMP0195=NEW",
                "-DCMAKE_BUILD_TYPE=Release", "-DBUILD_SHARED_LIBS=ON", "-DCMAKE_INSTALL_PREFIX=" .. package:installdir(),
                "-DCMAKE_INSTALL_LIBDIR=lib", "-DCMAKE_MAKE_PROGRAM=" .. ninja}, configs))
            os.vrunv(ninja, table.join({"-C", builddir}, parallel.ninja(8, ninja)))
            os.vrunv("cmake", {"--install", builddir})
        end

        local no_interface = "-DSwiftCore_NO_MODULE_INTERFACE=" .. (package:config("library_evolution") and "ON" or "OFF")

        if stdlib_kept then
            os.vrunv("cmake", {"--install", path.absolute(path.join("build", "core"))})
        else
            configure("core", path.join(source, "Runtimes", "Core"), {
                cxxflags = {"-DSWIFT_CLASS_IS_SWIFT_MASK=1ULL"},
                swiftflags = {"-Xfrontend", "-disable-legacy-type-info"},
                shflags = {path.absolute("mark.o")}
            }, {
                "-DSwiftCore_SWIFTC_SOURCE_DIR=" .. source, gyb_command,
                "-DSwiftCore_ARCH_SUBDIR=" .. package:arch(), "-DSwiftCore_PLATFORM_SUBDIR=iphoneos",
                "-DSwiftCore_MODULE_TRIPLE=" .. package:arch() .. "-apple-ios",
                "-Ddispatch_IMPLIB=" .. path.join(toolchain:config("sdkdir"), "usr", "lib", "libSystem.tbd"),
                "-Ddispatch_INCLUDE_DIR=" .. path.join(toolchain:config("sdkdir"), "usr", "include"),
                "-DSwiftCore_ENABLE_CRASH_REPORTER_CLIENT=OFF", "-DSwiftCore_ENABLE_BACKTRACING=OFF",
                "-DSwiftCore_ENABLE_STDLIB_TRACING=OFF", "-DSwiftCore_ENABLE_CONCURRENCY=ON",
                "-DSwiftCore_ENABLE_STRICT_AVAILABILITY=OFF", "-DSwiftCore_ENABLE_LIBRARY_EVOLUTION=" .. (package:config("library_evolution") and "ON" or "OFF"),
                no_interface,
                "-DSwiftCore_ENABLE_OBJC_INTEROP=ON", "-DSwiftCore_ENABLE_TYPE_PRINTING=ON", "-DSwiftCore_ENABLE_REFLECTION=ON",
                "-DSwiftCore_ENABLE_VECTOR_TYPES=ON",
                "-DSwiftCore_INSTALL_NESTED_SUBDIR=OFF"})
        end
        io.writefile(stdlib_stamp, stdlib_key)
        timed("stdlib")

        local resources = path.absolute(path.join("build", "resources"))
        local platform = path.join(resources, "iphoneos")
        os.mkdir(platform)
        os.ln(path.join(install, "shims"), path.join(resources, "shims"))
        for _, entry in ipairs({"clang", "apinotes", "module.modulemap"}) do
            os.ln(path.join(compiler:installdir("lib"), "swift", entry), path.join(resources, entry))
        end
        local function offer(pattern)
            for _, built in ipairs(os.filedirs(pattern)) do
                os.tryrm(path.join(platform, path.filename(built)))
                os.ln(built, path.join(platform, path.filename(built)))
            end
        end
        offer(path.join(install, "*.swiftmodule"))
        offer(path.join(install, "*.dylib"))

        local platform_patches = os.files(path.join(package:scriptdir(), "patches", "platform", "*.patch"))
        table.sort(platform_patches)
        for _, patch in ipairs(platform_patches) do
            os.vrunv("patch", {"-p1", "-i", patch}, {curdir = path.absolute("platform")})
        end
        local platform_source = path.join(path.absolute("platform"), "stdlib", "public", "Platform")
        local generated = path.absolute(path.join("build", "overlay"))
        os.mkdir(generated)
        local overlay_sources = {}
        for _, name in ipairs({"Darwin", "tgmath"}) do
            table.insert(overlay_sources, expand(path.join(platform_source, name .. ".swift.gyb"), path.join(generated, name .. ".swift")))
        end
        for _, name in ipairs({"Platform.swift", "TiocConstants.swift", "POSIXError.swift", "MachError.swift"}) do
            table.insert(overlay_sources, path.join(platform_source, name))
        end
        local overlay_flags = table.join({"-target", triple, "-resource-dir", resources, "-module-name", "Darwin",
                                          "-parse-as-library", "-swift-version", "5", "-O", "-wmo",
                                          "-Xfrontend", "-disable-implicit-concurrency-module-import",
                                          "-Xfrontend", "-disable-implicit-string-processing-module-import",
                                          "-Xfrontend", "-disable-objc-attr-requires-foundation-module"}, use_ld,
                                         runtime_flags, swift.availability(source))
        local darwin_module = path.join(install, "Darwin.swiftmodule")
        os.mkdir(darwin_module)
        os.vrunv(swiftc, table.join(overlay_flags, {"-emit-module", "-emit-module-path",
                 path.join(darwin_module, package:arch() .. "-apple-ios.swiftmodule"),
                 "-emit-object", "-module-link-name", "swiftDarwin", "-o", path.join(generated, "Darwin.o")}, overlay_sources))
        os.vrunv(swiftc, table.join(overlay_flags, {"-emit-library", "-o", path.join(install, "libswiftDarwin.dylib"),
                 path.join(generated, "Darwin.o"), "-Xlinker", "-install_name", "-Xlinker", "@rpath/libswiftDarwin.dylib",
                 "-L" .. install, "-lswiftCore"}))
        offer(path.join(install, "Darwin.swiftmodule"))
        offer(path.join(install, "libswiftDarwin.dylib"))
        timed("darwin")

        local foundation_links = {}

        local function build_overlay(name, overlay_sources, links, objects, opt)
            local module = path.join(install, name .. ".swiftmodule")
            os.mkdir(module)
            local flags = table.join({"-target", triple, "-resource-dir", resources, "-module-name", name,
                                      "-parse-as-library", "-swift-version", "5", "-O", "-wmo",
                                      "-Xfrontend", "-disable-implicit-string-processing-module-import",
                                      "-Xcc", "-Rmodule-build", "-Xcc", "-Rmodule-import"}, use_ld,
                                     opt and opt.extra_flags or {},
                                     (opt and opt.concurrency) and {} or {"-Xfrontend", "-disable-implicit-concurrency-module-import"},
                                     runtime_flags, swift.availability(source))
            local object = path.join(generated, name .. ".o")
            local linked = {}
            for _, link in ipairs(links) do
                local library = link:match("^%-l(swift.+)$")
                table.insert(linked, library and path.join(install, "lib" .. library .. ".dylib") or link)
            end
            os.vrunv(swiftc, table.join(flags, {"-emit-module", "-emit-module-path",
                     path.join(module, package:arch() .. "-apple-ios.swiftmodule"),
                     "-emit-object", "-module-link-name", "swift" .. name, "-o", object}, overlay_sources))
            os.vrunv(swiftc, table.join(flags, {"-emit-library", "-o", path.join(install, "libswift" .. name .. ".dylib"),
                     object, table.unpack(objects or {})}, {"-Xlinker", "-install_name", "-Xlinker", "@rpath/libswift" .. name .. ".dylib",
                     "-L" .. install, "-lswiftCore"}, linked))
            offer(module)
            offer(path.join(install, "libswift" .. name .. ".dylib"))
            timed("overlay:" .. name)
        end

        if not package:is_arch("arm64") then
            local overlays = path.absolute("overlays")
            local overlay_patches = os.files(path.join(package:scriptdir(), "patches", "overlays", "*.patch"))
            table.sort(overlay_patches)
            for _, patch in ipairs(overlay_patches) do
                os.vrunv("patch", {"-p1", "-i", patch}, {curdir = overlays})
            end
            import("@addon.revenant.apple.lowered", {anonymous = true}).swift_overlays(overlays)

            local installed_shims = path.join(install, "shims")
            local shim_modules = path.join(installed_shims, "module.modulemap")
            for _, name in ipairs({"ObjectiveC", "Dispatch", "CoreFoundation", "Foundation"}) do
                os.vcp(path.join(overlays, "stdlib", "public", "SwiftShims", name .. "OverlayShims.h"), installed_shims .. "/")
                local module = "_Swift" .. name .. "OverlayShims"
                if not io.readfile(shim_modules):find(module, 1, true) then
                    io.writefile(shim_modules, io.readfile(shim_modules) ..
                                 string.format("\nmodule %s {\n  header \"%sOverlayShims.h\"\n}\n", module, name))
                end
            end
            local shim_headers = table.join(os.files(path.join(overlays, "stdlib", "public", "SwiftShims", "NS*Shims.h")),
                                            os.files(path.join(overlays, "stdlib", "public", "SwiftShims", "CF*Shims.h")))
            for _, header in ipairs(shim_headers) do
                os.vcp(header, installed_shims .. "/")
            end
            os.vcp(path.join(overlays, "stdlib", "public", "SwiftShims", "FoundationShimSupport.h"), installed_shims .. "/")
            local uikit = path.absolute("uikit")
            local uikit_patches = os.files(path.join(package:scriptdir(), "patches", "uikit", "*.patch"))
            table.sort(uikit_patches)
            for _, patch in ipairs(uikit_patches) do
                os.vrunv("patch", {"-p1", "-i", patch}, {curdir = uikit})
            end
            os.vcp(path.join(uikit, "stdlib", "public", "SwiftShims", "UIKitOverlayShims.h"), installed_shims .. "/")
            if not io.readfile(shim_modules):find("_SwiftUIKitOverlayShims", 1, true) then
                io.writefile(shim_modules, io.readfile(shim_modules) ..
                             "\nmodule _SwiftUIKitOverlayShims {\n  header \"UIKitOverlayShims.h\"\n}\n")
            end
            local function overlay_sources_of(name, files)
                local found = {}
                for _, file in ipairs(files) do
                    table.insert(found, path.join(overlays, "stdlib", "public", "Darwin", name, file))
                end
                return found
            end
            build_overlay("ObjectiveC", overlay_sources_of("ObjectiveC", {"ObjectiveC.swift"}), {"-lswiftDarwin"})
            local dispatch_object = path.join(generated, "Dispatch.mm.o")
            os.vrunv(toolchain:tool("cc"), table.join({"-target", triple, "-miphoneos-version-min=" .. minimum, "-isysroot",
                     toolchain:config("sdkdir"), "-Os", "-DOS_OBJECT_SWIFT3=1", "-c",
                     path.join(overlays, "stdlib", "public", "Darwin", "Dispatch", "Dispatch.mm"),
                     "-o", dispatch_object}, objc_linker))
            build_overlay("Dispatch", overlay_sources_of("Dispatch", {"Dispatch.swift", "Block.swift", "Data.swift", "IO.swift",
                                                                      "Private.swift", "Queue.swift", "Source.swift", "Time.swift"}),
                          {"-lswiftDarwin", "-lswiftObjectiveC"}, {dispatch_object})
            build_overlay("CoreFoundation", overlay_sources_of("CoreFoundation", {"CoreFoundation.swift"}),
                          {"-lswiftDarwin", "-framework", "CoreFoundation"})
            local graphics = expand(path.join(overlays, "stdlib", "public", "Darwin", "CoreGraphics", "CGFloat.swift.gyb"),
                                    path.join(generated, "CGFloat.swift"))
            build_overlay("CoreGraphics", table.join({graphics}, overlay_sources_of("CoreGraphics", {"CoreGraphics.swift", "Geometry.swift"})),
                          {"-lswiftDarwin", "-lswiftObjectiveC", "-lswiftCoreFoundation",
                           "-framework", "CoreGraphics", "-framework", "CoreFoundation"})

            local foundation = path.join(overlays, "stdlib", "public", "Darwin", "Foundation")
            local presentation_intent = path.join(os.projectdir(), "toolchain", "src", "swift-runtime", "overlay", "Foundation", "PresentationIntent.swift")
            local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
            local lowered_headers = lowered.overlay(toolchain:config("sdkdir"), path.absolute("lowered"))
            local flat = import("@addon.revenant.apple.flat_classes", {anonymous = true})
            local flat_flags = flat.link_flags(flat.stub_directory(toolchain:config("sdkdir"), path.join(generated, "flat-stubs")))
            local lowered_include = lowered.include_directory(path.absolute("lowered"))
            local values = expand(path.join(foundation, "NSValue.swift.gyb"), path.join(generated, "NSValue.swift"))
            local foundation_objects = {}
            for _, file in ipairs({"DataThunks.m", "BundleLookup.mm"}) do
                local object = path.join(generated, file .. ".o")
                os.vrunv(toolchain:tool("cc"), table.join({"-target", triple, "-miphoneos-version-min=" .. minimum, "-isysroot",
                         toolchain:config("sdkdir"), "-Os", "-I" .. path.join(source, "stdlib", "public", "SwiftShims"),
                         "-c", path.join(foundation, file), "-o", object}, objc_linker))
                table.insert(foundation_objects, object)
            end
            build_overlay("Foundation", table.join({values}, overlay_sources_of("Foundation", {
                "AffineTransform.swift", "Boxing.swift", "Calendar.swift", "CharacterSet.swift",
                "CheckClass.swift", "Codable.swift", "Collections+DataProtocol.swift", "ContiguousBytes.swift",
                "Data.swift", "DataProtocol.swift", "Date.swift", "DateComponents.swift", "DateInterval.swift",
                "Decimal.swift", "DispatchData+DataProtocol.swift", "FileManager.swift", "Foundation.swift",
                "IndexPath.swift", "IndexSet.swift", "JSONEncoder.swift", "Locale.swift", "Measurement.swift",
                "Notification.swift", "NSArray.swift", "NSCoder.swift", "NSData+DataProtocol.swift",
                "NSDate.swift", "NSDictionary.swift", "NSError.swift", "NSExpression.swift",
                "NSFastEnumeration.swift", "NSGeometry.swift", "NSIndexSet.swift", "NSItemProvider.swift",
                "NSNumber.swift", "NSObject.swift", "NSOrderedCollectionDifference.swift", "NSPredicate.swift",
                "NSRange.swift", "NSSet.swift", "NSSortDescriptor.swift", "NSString.swift", "NSStringAPI.swift",
                "NSStringEncodings.swift", "NSTextCheckingResult.swift", "NSUndoManager.swift", "NSURL.swift",
                "PersonNameComponents.swift", "PlistEncoder.swift", "Pointers+DataProtocol.swift",
                "Progress.swift", "ReferenceConvertible.swift", "Scanner.swift", "String.swift", "TimeZone.swift",
                "URL.swift", "URLCache.swift", "URLComponents.swift", "URLRequest.swift", "URLSession.swift",
                "UUID.swift"}), {presentation_intent}),
                          table.join(flat_flags, {"-lswiftDarwin", "-lswiftObjectiveC", "-lswiftDispatch", "-lswiftCoreFoundation", "-lswiftCoreGraphics",
                           "-framework", "Foundation", "-framework", "CoreFoundation"}), foundation_objects,
                          {concurrency = true,
                           extra_flags = {"-enable-experimental-feature", "Lifetimes", "-enable-experimental-feature", "AddressableTypes",
                                          "-enable-experimental-feature", "BuiltinModule",
                                          "-Xcc", "-ivfsoverlay", "-Xcc", lowered_headers, "-Xcc", "-I", "-Xcc", lowered_include}})

            local function generated_from(folder, name)
                return expand(path.join(uikit, "stdlib", "public", "Darwin", folder, name .. ".gyb"), path.join(generated, name))
            end
            foundation_links = table.join(flat_flags, {"-lswiftDarwin", "-lswiftObjectiveC", "-lswiftDispatch", "-lswiftCoreFoundation",
                                "-lswiftCoreGraphics", "-lswiftFoundation", "-framework", "Foundation", "-framework", "CoreFoundation"})
            build_overlay("QuartzCore", {generated_from("QuartzCore", "NSValue.swift")},
                          table.join(foundation_links, {"-framework", "QuartzCore"}))
            local initializers = path.join(generated, "DesignatedInitializers.mm.o")
            os.vrunv(toolchain:tool("cc"), table.join({"-target", triple, "-miphoneos-version-min=" .. minimum, "-isysroot",
                     toolchain:config("sdkdir"), "-Os", "-c", path.join(uikit, "stdlib", "public", "Darwin", "UIKit", "DesignatedInitializers.mm"),
                     "-o", initializers}, objc_linker))
            build_overlay("UIKit", {path.join(uikit, "stdlib", "public", "Darwin", "UIKit", "UIKit.swift"),
                                    generated_from("UIKit", "UIKit_FoundationExtensions.swift")},
                          table.join(foundation_links, {"-lswiftQuartzCore", "-framework", "QuartzCore", "-framework", "UIKit"}), {initializers})

            local coredata = path.join(uikit, "stdlib", "public", "Darwin", "CoreData")
            local conformances = path.join(generated, "CoreData.mm.o")
            os.vrunv(toolchain:tool("cc"), table.join({"-target", triple, "-miphoneos-version-min=" .. minimum, "-isysroot",
                     toolchain:config("sdkdir"), "-Os", "-c", path.join(coredata, "CoreData.mm"), "-o", conformances}, objc_linker))
            build_overlay("CoreData", {path.join(coredata, "CocoaError.swift"), path.join(coredata, "NSManagedObjectContext.swift")},
                          table.join(foundation_links, {"-framework", "CoreData"}), {conformances})
        end

        for _, library in ipairs({"Synchronization", "Observation", "StringProcessing"}) do
            local core_include = path.absolute(path.join("build", "core", "include"))
            configure(library:lower(), path.join(source, "Runtimes", "Supplemental", library),
                      {swiftflags = {"-resource-dir", resources, "-Xcc", "-I" .. core_include}, cxxflags = {"-I" .. core_include}}, {
                "-DSwiftCore_DIR=" .. path.absolute(path.join("build", "core", "cmake", "SwiftCore")),
                "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=YES", no_interface, gyb_command})
            offer(path.join(install, "*.swiftmodule"))
            offer(path.join(install, "iphoneos", "*.swiftmodule"))
            offer(path.join(install, "iphoneos", package:arch(), "*.dylib"))
            timed("supplemental:" .. library)
        end

        local simd = path.absolute("simd")
        os.mkdir(simd)
        local simd_module = os.files(path.join(toolchain:config("sdkdir"), "usr", "lib", "swift", "simd.swiftmodule", "*-apple-ios.swiftinterface"))
        assert(#simd_module > 0, "the SDK at %s carries no simd.swiftmodule; the Swift half of simd cannot be built",
               toolchain:config("sdkdir"))
        table.sort(simd_module, function (a, b) return path.basename(a) < path.basename(b) end)
        os.vcp(simd_module[1], path.join(simd, "simd.swift"))
        local simd_text = {}
        for line in io.readfile(path.join(simd, "simd.swift")):gmatch("[^\n]+") do
            if not line:startswith("// swift-") and not line:startswith("// swift-module-flags-ignorable") then
                table.insert(simd_text, line)
            end
        end
        io.writefile(path.join(simd, "simd.swift"), table.concat(simd_text, "\n") .. "\n")
        local simd_release = toolchain:config("sdkdir"):match("iPhoneOS([%d%.]+)%.sdk$")
        assert(simd_release, "the SDK at " .. toolchain:config("sdkdir") .. " is not an iPhoneOS SDK the simd patches name")
        local simd_patches = os.files(path.join(os.scriptdir(), "patches", "simd", simd_release, "*.patch"))
        assert(#simd_patches > 0, "the simd overlay has no patch for the iPhoneOS " .. simd_release .. " SDK; add patches/simd/" .. simd_release)
        table.sort(simd_patches)
        for _, patch in ipairs(simd_patches) do
            os.vrunv("patch", {"-p1", "-i", patch}, {curdir = simd})
        end
        local simd_links = {"-lswiftDarwin", "-lswiftObjectiveC", "-framework", "Foundation", "-framework", "CoreFoundation"}
        build_overlay("simd", {path.join(simd, "simd.swift")}, simd_links, nil)

        local platform_dir = path.join(install, "iphoneos")
        os.mkdir(platform_dir)
        for _, built in ipairs(table.join(os.filedirs(path.join(install, "*.swiftmodule")), os.files(path.join(install, "*.dylib")),
                                          os.files(path.join(platform_dir, package:arch(), "*.dylib")))) do
            os.vmv(built, path.join(platform_dir, path.filename(built)))
        end
        os.tryrm(path.join(platform_dir, package:arch()))
        for _, entry in ipairs({"clang", "apinotes", "module.modulemap"}) do
            os.tryrm(path.join(install, entry))
            os.vcp(path.join(compiler:installdir("lib"), "swift", entry), path.join(install, entry))
        end
        os.vcp(path.join(path.absolute("platform"), "LICENSE.txt"), package:installdir("licenses") .. "/")
        timed("install:layout")
        if package:config("shared") then
            local runtime = import("@addon.revenant.apple.shared_runtime", {anonymous = true})
            local name, ui = runtime.package_name("swift-runtime", package:buildhash()), runtime.package_name("swift-runtime-ui", package:buildhash())
            local version = runtime.package_version(package:buildhash())
            local libraries, ui_libraries = {}, {}
            for _, library in ipairs(os.files(path.join(platform_dir, "*.dylib"))) do
                table.insert(({libswiftQuartzCore = ui_libraries, libswiftUIKit = ui_libraries})[path.basename(library)] or libraries, library)
            end
            local cxx = runtime.package_name("libcxx", libcxx:buildhash())
            local depends, ui_depends = {string.format("%s (= %s)", cxx, runtime.package_version(libcxx:buildhash()))}, {string.format("%s (= %s)", name, version)}
            runtime.stage({packages = {{name = name, version = version, title = "Swift runtime " .. package:buildhash():sub(1, 8),
                                        description = "The Swift runtime and the overlays of one build of Revenant's revenant@swift-runtime,",
                                        depends = depends,
                                        libraries = libraries},
                                       {name = ui, version = version, title = "Swift runtime UI " .. package:buildhash():sub(1, 8),
                                        description = "The overlays of QuartzCore and UIKit of one build of Revenant's revenant@swift-runtime,",
                                        depends = ui_depends,
                                        libraries = ui_libraries}},
                           root = path.join(package:installdir("share"), "root"),
                           metadata = path.join(package:installdir("share"), "shared-packages"), strip = {"-x"}})
            for _, library in ipairs(table.join(libraries, ui_libraries)) do
                os.rm(library)
            end
            package:setenv("REVENANT_SHARED_PACKAGE", name .. "=" .. cxx .. ";" .. ui .. "=" .. name)
            timed("package")
        end
        if not package:config("shared") then
            import("@addon.revenant.prebuilt", {anonymous = true}).pack(package)
        end
        if marked then
            print("swift-runtime: where the install went, every phase in the order it ran:")
            local total = 0
            for _, row in ipairs(marked) do
                printf("swift-runtime:   %-26s %8.1fs\n", row[1], row[2])
                total = total + row[2]
            end
            printf("swift-runtime:   %-26s %8.1fs\n", "total", total)
        end
    end)

    on_install("macosx", function (package)
        raise("%s is the Swift runtime of iOS, so configure the project for iOS before requiring it: ./xmakew f -P . -p iphoneos -a armv7 --component=Swift", package:name())
    end)

    on_test(function (package)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local resources = path.join(package:installdir("lib"), "swift")
        local install = path.join(resources, "iphoneos")
        local libraries = install
        local installed = {}
        if package:config("shared") then
            local shared = import("@addon.revenant.apple.shared_runtime", {anonymous = true})
            libraries = path.join(package:installdir("share"), "root", shared.folder_of(shared.package_name("swift-runtime", package:buildhash())))
            for _, kind in ipairs({"swift-runtime", "swift-runtime-ui"}) do
                assert(os.isfile(path.join(package:installdir("share"), "shared-packages", shared.package_name(kind, package:buildhash()) .. ".json")),
                       "the shared runtime left no description of its " .. kind .. " package")
            end
            local ui = path.join(package:installdir("share"), "root", shared.folder_of(shared.package_name("swift-runtime-ui", package:buildhash())))
            for _, library in ipairs({"swiftQuartzCore", "swiftUIKit"}) do
                assert(os.isfile(path.join(ui, "lib" .. library .. ".dylib")), "the UI package has no lib" .. library .. ".dylib")
                assert(not os.isfile(path.join(libraries, "lib" .. library .. ".dylib")), "lib" .. library .. ".dylib is in the runtime package too")
            end
            assert(#os.files(path.join(install, "*.dylib")) == 0, "the shared runtime keeps a second copy of its libraries")
            installed = os.files(path.join(ui, "*.dylib"))
        end
        table.join2(installed, os.files(path.join(libraries, "*.dylib")))
        for _, library in ipairs({"swiftCore", "swift_Concurrency", "swiftDarwin", "swiftSynchronization", "swiftObservation",
                                  "swift_StringProcessing", "swift_RegexParser", "swiftRegexBuilder"}) do
            assert(os.isfile(path.join(libraries, "lib" .. library .. ".dylib")), "the runtime has no lib" .. library .. ".dylib")
        end
        for _, module in ipairs({"Swift", "_Concurrency", "Darwin", "Synchronization", "Observation", "_StringProcessing"}) do
            assert(os.isdir(path.join(install, module .. ".swiftmodule")) or os.isfile(path.join(install, module .. ".swiftmodule")),
                   "the runtime has no " .. module .. " module")
        end
        local linked = {}
        for _, alias in ipairs({"libcxx"}) do
            local dep = package:dep(alias)
            if dep then
                table.join2(linked, os.files(path.join(dep:installdir("lib"), "*.dylib")))
            end
        end
        local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})
        local read = dyld.image_imports(installed, linked, package:arch())
        local found = {}
        for _, library in ipairs(table.orderkeys(read.imports)) do
            local names = {}
            for symbol, weak in pairs(read.imports[library]) do
                if weak and not read.exported[symbol] and not read.flat[library][symbol] then
                    names[symbol] = true
                end
            end
            found[library] = table.orderkeys(names)
        end
        local toolchain = assert(package:toolchains(), "the runtime is built with the apple-ios toolchain")[1]
        toolchain:load()

        local differs = import("@addon.revenant.apple.runtime_guards", {anonymous = true}).compare(found, {
            imports = read.imports, exported = read.exported,
            minimum = toolchain:config("deployment")})
        assert(#differs == 0, "the runtime's imports and its guard table differ at " .. toolchain:config("deployment") ..
               ":\n  " .. table.concat(differs, "\n  "))

        local placeable = import("@addon.revenant.apple.firmware", {anonymous = true}).source(package:arch(), toolchain:config("deployment"))
        dyld.check(placeable, table.join(installed, linked), package:installdir(),
                   {exempt = linked, runtime = installed, guards = import("@addon.revenant.apple.runtime_guards", {anonymous = true}).guards()})

        for _, entry in ipairs({"shims", "clang", "apinotes", "module.modulemap"}) do
            assert(os.exists(path.join(resources, entry)),
                   "the runtime installs no " .. entry .. ", and a port could not use it as a resource directory")
        end
        local exported = os.iorunv("xcrun", {"nm", "-gU", path.join(libraries, "libswiftCore.dylib")})
        assert(exported:find("%s_" .. package:data("mark") .. "%s"),
               "libswiftCore.dylib does not carry the mark of the build it is, so a program could be linked against another")

        local compiler = assert(package:dep("swift"), "the runtime is built with revenant@swift")
        local source = os.tmpfile() .. ".swift"
        io.writefile(source, "import Darwin\nimport Synchronization\npublic func held() -> Int32 { return Darwin.getpid() }\n")
        local _, loaded = os.iorunv(path.join(compiler:installdir("bin"), "swiftc"),
                                 {"-target", package:arch() .. "-apple-ios" .. toolchain:config("deployment"),
                                  "-clang-target", package:arch() .. "-apple-ios" .. toolchain:config("deployment"),
                                  "-sdk", toolchain:config("sdkdir"), "-resource-dir", resources, "-Rmodule-loading",
                                  "-Xfrontend", "-bundled-swift-runtime", "-typecheck", source})
        for _, module in ipairs({"Darwin", "Synchronization", "Swift"}) do
            local from = loaded:match("loaded module '" .. module .. "'; source: '([^']*)'")
            assert(from and from:startswith(resources),
                   "a port would compile against " .. module .. " from " .. (from or "nowhere") .. ", not against this runtime's own")
        end
        os.tryrm(source)

        local folder = os.tmpfile() .. ".dir"
        os.mkdir(folder)
        io.writefile(path.join(folder, "port.c"), "int main(void) { return 0; }\n")
        local common = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-Wno-incompatible-sysroot"}
        for _, flag in ipairs(table.wrap(toolchain:get("shflags"))) do
            if flag:startswith("-fuse-ld=") or flag:startswith("-mlinker-version=") then
                table.insert(common, flag)
            end
        end
        local function links(mark)
            return try { function ()
                os.vrunv(toolchain:tool("cc"), table.join(common, {path.join(folder, "port.c"), "-L" .. libraries, "-lswiftCore",
                         "-Wl,-u,_" .. mark, "-o", path.join(folder, "port")}))
                return true
            end }
        end
        assert(links(package:data("mark")), "a port must link against the runtime it was built against, by its mark")
        assert(not links("revenant_swift_runtime_not_this_build"),
               "a port must not link against a runtime whose mark it does not name; the mark is what keeps builds apart")
        os.tryrm(folder)
        os.tryrm(path.absolute("build"))
        os.tryrm(path.absolute("swift-source"))
        os.tryrm(path.absolute(".stdlib.key"))
    end)
