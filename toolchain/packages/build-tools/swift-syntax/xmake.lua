package("swift-syntax")
    set_kind("library")
    set_homepage("https://github.com/swiftlang/swift-syntax")
    set_description("SwiftSyntax, the parser and macro machinery Apple ships inside its own toolchain, built for the host so that a port's macro plugin has a CompilerPlugin to conform to. The toolchain on this machine exports every macro protocol (AccessorMacro, PeerMacro, MemberAttributeMacro, MemberMacro, ExtensionMacro, FreestandingMacro, Macro) and *no* CompilerPlugin: it is behind @_spi(PluginMessage) in SwiftCompilerPluginMessageHandling, which is why a -load-plugin-executable cannot be written against the toolchain's own modules. This is the Apache-2.0 upstream at the tag that matches the 6.4 toolchain, built by upstream's own SwiftPM build for the host, and it is the one such package: TipKit's macros, AppIntents' and SwiftData's all take this one")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/swiftlang/swift-syntax.git")
    add_versions("604.0.0", "050f1a346fbbac0ca2cfb15a95274f7bd1cf0ccf")

    local digests = {}
    local inputs = {os.scriptdir() .. "/xmake.lua"}
    for _, patch in ipairs(os.files(os.scriptdir() .. "/patches/*")) do
        table.insert(inputs, patch)
    end
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe and the patches it applies, so a changed flag or a changed copy step is a different package.",
                            default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    add_configs("envs", {description = "The modules and the archives of this package's host build, for a macro plugin or a test that links them.",
                         default = "", type = "string"})

    local modules = {
        "SwiftBasicFormat", "SwiftCompilerPlugin", "SwiftCompilerPluginMessageHandling", "SwiftDiagnostics",
        "SwiftIDEUtils", "SwiftParser", "SwiftParserDiagnostics", "SwiftSyntax", "SwiftSyntaxBuilder",
        "SwiftSyntaxMacroExpansion", "SwiftSyntaxMacros", "SwiftLibraryPluginProvider",
    }

    on_load("@macosx", function (package)
        package:add("envs", {REVENANT_SWIFT_SYNTAX = package:installdir("lib"),
                             REVENANT_HOST_SWIFTC = os.getenv("SWIFT_EXEC") or "/usr/bin/swiftc"})
    end)

    on_install("@macosx", function (package)
        local build = path.join(package:installdir(), "build")
        os.mkdir(build)
        print("%s: the source is unpacked in %s", package:name(), os.curdir())
        for _, entry in ipairs(os.files(path.join(os.curdir(), "*"))) do
            print("%s:   %s", package:name(), path.filename(entry))
        end
        local function has_manifest(dir)
            return os.isfile(path.join(dir, "Package.swift"))
        end
        local source = os.curdir()
        if not has_manifest(source) then
            local nested = path.join(source, "swift-syntax")
            if has_manifest(nested) then
                source = nested
            else
                raise("%s unpacks swift-syntax, and neither %s nor %s holds a Package.swift",
                      package:name(), os.curdir(), nested)
            end
        end
        print("%s: building from %s", package:name(), source)
        local parallel = import("parallel", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "modules"), anonymous = true})
        parallel.hold(nil, function (jobs)
            local argv = {"nice", "-n", "10", "swift", "build", "--package-path", source, "--scratch-path", build,
                          "--triple", "arm64-apple-macosx13.0", "-c", "release", "--jobs", tostring(jobs)}
            for _, module in ipairs(modules) do
                table.insert(argv, "--target")
                table.insert(argv, module)
            end
            os.vrunv(argv[1], table.slice(argv, 2), {curdir = source})
            print("%s: built %s targets with --jobs %s", package:name(), #modules, jobs)
        end)
        local products = path.join(build, "release")
        local modules_copied, objects_copied = 0, 0
        for _, entry in ipairs(os.filedirs(path.join(products, "*.swiftmodule"))) do
            os.cp(entry, path.join(package:installdir("lib"), "swift", "host", path.filename(entry)))
            modules_copied = modules_copied + 1
        end
        for _, entry in ipairs(os.files(path.join(products, "*.o"))) do
            os.cp(entry, path.join(package:installdir("lib"), path.filename(entry)))
            objects_copied = objects_copied + 1
        end
        local copied = modules_copied + objects_copied
        for _, dir in ipairs({"SwiftSyntax", "_SwiftSyntaxCShims", "SwiftSyntaxPrivate"}) do
            local resources = path.join(products, "..", dir)
            if os.isdir(resources) then os.cp(resources, path.join(package:installdir("share"), dir)) end
        end
        if copied == 0 then
            raise("%s built, and %s holds no .swiftmodule and no object: the products moved", package:name(), products)
        end
        print(string.format("%s: %s installed at %s -- %s modules under lib/swift/host and %s objects beside them (%s files)",
                            package:name(), package:version_str(), package:installdir("lib"),
                            modules_copied, objects_copied, copied))
    end)
