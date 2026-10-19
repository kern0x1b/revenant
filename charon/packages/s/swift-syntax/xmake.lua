package("swift-syntax")
    set_kind("library")
    set_homepage("https://github.com/swiftlang/swift-syntax")
    set_description("SwiftSyntax, the parser and macro machinery Apple ships inside its own toolchain, built for the host so that a port's macro plugin has a CompilerPlugin to conform to. The toolchain on this machine exports every macro protocol (AccessorMacro, PeerMacro, MemberAttributeMacro, MemberMacro, ExtensionMacro, FreestandingMacro, Macro) and *no* CompilerPlugin: it is behind @_spi(PluginMessage) in SwiftCompilerPluginMessageHandling, which is why a -load-plugin-executable cannot be written against the toolchain's own modules. This is the Apache-2.0 upstream at the tag that matches the 6.4 toolchain, built by upstream's own SwiftPM build for the host, and it is the one such package: TipKit's macros, AppIntents' and SwiftData's all take this one")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/swiftlang/swift-syntax.git")
    add_versions("604.0.0", "050f1a346fbbac0ca2cfb15a95274f7bd1cf0ccf")

    -- The package's identity, the way `charon@apple-backports` does it with `sources`: a **load-time**
    -- digest of the recipe file and of every patch beside it, so a changed recipe is a different
    -- install directory and nothing has to be removed from the shared store. It cannot be computed in
    -- `on_load` -- that is what kits r4 found, `package:commit()` is not callable while the recipe
    -- body is read -- and the upstream's own sources are not in this tree to hash either; **the
    -- pinned commit is covered by the version** (`add_versions("604.0.0", <commit>)`), so a
    -- different pin is a different version and a different directory, which is the half of the
    -- identity that is not this file.
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

    -- Where a dependent finds the modules and the archives: `rules/macro` reads this to compile a
    -- plugin executable, and the Swift side reads it to typecheck an expansion test.
    add_configs("envs", {description = "The modules and the archives of this package's host build, for a macro plugin or a test that links them.",
                         default = "", type = "string"})

    -- The modules a macro plugin needs, and the ones an expansion test needs on top of them. The C
    -- shims are in the list because SwiftParser and SwiftSyntax are built on them; they are not
    -- modules, and the SwiftPM build makes them as part of the same graph.
    -- The fourteen a plugin needs. `SwiftSyntaxMacrosTestSupport` is deliberately NOT in this list:
    -- it pulls `_SwiftSyntaxTestSupport`, which imports XCTest, and this machine's Command Line
    -- Tools ship none -- measured, and the facts record what that costs the expansion tests.
    local modules = {
        "SwiftBasicFormat", "SwiftCompilerPlugin", "SwiftCompilerPluginMessageHandling", "SwiftDiagnostics",
        "SwiftIDEUtils", "SwiftParser", "SwiftParserDiagnostics", "SwiftSyntax", "SwiftSyntaxBuilder",
        "SwiftSyntaxMacroExpansion", "SwiftSyntaxMacros", "SwiftLibraryPluginProvider",
    }

    on_load("@macosx", function (package)
        -- The host compiler goes out with the modules: a plugin is built for the host, and nothing
        -- else in the fleet publishes one (rules/macro reads it, and there is no producer for it
        -- before this), so it is named here beside what it is for.
        package:add("envs", {CHARON_SWIFT_SYNTAX = package:installdir("lib"),
                             CHARON_HOST_SWIFTC = os.getenv("SWIFT_EXEC") or "/usr/bin/swiftc"})
    end)

    on_install("@macosx", function (package)
        -- Upstream's own build, for the host, at the host's own architecture. This is not a
        -- convenience: swift-syntax's module graph (SwiftSyntax before SwiftParser before
        -- SwiftSyntaxMacros, the C shims under both) is upstream's to order, and a second
        -- hand-written compile of twenty modules would be a second thing to keep right.
        local build = path.join(package:installdir(), "build")
        os.mkdir(build)
        -- `sourcedir()`, not `sourcefile()`: there is no such method, and the install died on it
        -- before it ran a single compile -- "attempt to call a nil value (method 'sourcefile')",
        -- `.agent-work/runs/swift-syntax/globaldir/.xmake/cache/…/logs/install.txt`. The upstream
        -- root is the fetch's own directory, one level up from the package's `src/`.
        -- The fetch's own layout, read from the private store after the first run: the upstream root
        -- is `<cache>/<version>/source/swift-syntax`, and `Package.swift` and `Sources/` are in it.
        -- `sourcedir()` is that `source`, so the root is one level *down*, not up.
        -- Where the source is: inside `on_install` the working directory *is* the package's
        -- unpacked source -- that is how every recipe that runs `make` in its own tree works -- and
        -- a tag that unpacks into a subfolder makes that subfolder the root. So the root is measured
        -- here rather than assumed, and the reading goes into the log whether or not the build
        -- after it succeeds:
        --
        --     print("swift-syntax: cwd = " .. os.curdir())
        --     for _, entry in ipairs(os.files(path.join(os.curdir(), "*"))) do
        --         print("swift-syntax:   " .. path.filename(entry))
        --     end
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
        -- Serialised, and at the machine's low priority. `swift build` with no `--jobs` takes every
        -- core, and this runs *inside* a slow slot: the run that produced the log below reached
        -- `[243 / 478]` and stopped with no error line, the scratch directory gone with the failed
        -- install and the install dir empty -- the reading of a job that used the whole machine and
        -- was killed, not of a compile that failed. A heavy job shares this machine with every other
        -- band, so it takes its share of the cores (FLEET_HEAVY_CPUS when the caller sets it) and the
        -- lowered priority heavy.sh exports, and nothing else.
        local jobs = os.getenv("FLEET_HEAVY_CPUS") or "2"
        -- Per target, not the whole package. `swift build` with no target builds every product
        -- swift-syntax declares, and two of them need XCTest: the run measured it --
        -- "Sources/_SwiftSyntaxTestSupport/AssertEqualWithDiff.swift:15:16 unable to resolve module
        -- dependency: 'XCTest'", because the Command Line Tools on this machine ship no XCTest and
        -- the package's own graph carries it. A macro plugin needs the fourteen modules below and
        -- none of the test-support ones, so the build is asked for those by name and the XCTest
        -- targets stay out of the graph. What that costs is `SwiftSyntaxMacrosTestSupport` itself,
        -- which is the XCTest-dependent one: the expansion tests it provides cannot be built on a
        -- machine without XCTest, and the facts say so rather than the package pretending to ship it.
        local argv = {"nice", "-n", "10", "swift", "build", "--package-path", source, "--scratch-path", build,
                      "--triple", "arm64-apple-macosx13.0", "-c", "release", "--jobs", jobs}
        for _, module in ipairs(modules) do
            table.insert(argv, "--target")
            table.insert(argv, module)
        end
        os.vrunv(argv[1], table.slice(argv, 2), {curdir = source})
        print("%s: built %s targets with --jobs %s", package:name(), #modules, jobs)
        -- The products, and where they are: **measured**, by the run that installed this package
        -- for the first time. SwiftPM with `--target` puts each module's `.swiftmodule` and its
        -- object *flat* in `<scratch>/release/` -- there is no `Modules/` subdirectory, and there are
        -- no `.a` archives either, because a target-scoped build links no library product. What
        -- 19 `.swiftmodule` files and 21 objects are in there, and the recipe copies every one of
        -- them: the twelve the plugin's module list names, and the versioned `SwiftSyntaxNNN`
        -- modules SwiftPM emits alongside them, which are the same sources under their release
        -- names and which a consumer may equally import.
        -- A module is a **directory**, not a file: `SwiftSyntax.swiftmodule/` holds
        -- `arm64-apple-macos.swiftmodule` with the `.abi.json` and `.swiftdoc` beside it, and the
        -- compiler finds it through `-I <dir>`. Measured: 19 such directories and 21 objects, and
        -- `os.files("*.swiftmodule")` returns none of them -- the first version of this step copied
        -- files and copied nothing, which is the same failure the install showed and one level
        -- further down. So the modules come from `os.filedirs` and are copied whole, and the
        -- objects from `os.files`.
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
        -- `string.format`, not `print`'s own: Lua's print does not format, and the first run of
        -- this line printed its own placeholders instead of the values.
        print(string.format("%s: %s installed at %s -- %s modules under lib/swift/host and %s objects beside them (%s files)",
                            package:name(), package:version_str(), package:installdir("lib"),
                            modules_copied, objects_copied, copied))
    end)
