# Write a package

A package is a library, a runtime or a tool that a port requires by name. A package in `packages/<group>/<name>/` is an xmake package whose `on_install` builds the upstream for the port's architecture and release, with the toolchain's flags. This guide shows the bridges that do the building, and the traps that cost a build to find. The packages that exist are in the [packages reference](../../reference/toolchain/packages.md).

## Pin the upstream

Name the upstream by URL and commit, and never commit a copy of its code:

    package("example")
        set_homepage("https://example.org/example")
        set_license("MIT")
        add_urls("https://example.org/example.git")
        add_versions("1.2.3", "<commit sha>")

A package with no `add_urls` never has `on_download` called, however complete that function is. The sources are fetched at the pinned commit.

Give a package defined in a port's `xmake.lua` a revision it raises by hand when its script changes in a way the hash cannot see:

    add_configs("revision", {default = "2", readonly = true})

A library that other packages link against is marked `package.strict_compatibility`, so what depends on it is rebuilt when it changes. A port sets `package.librarydeps.strict_compatibility` in its own project for its own packages.

## Build with CMake

A package whose upstream builds with CMake calls the bridge from its install script. The bridge writes a toolchain file from the `apple-ios` toolchain (clang, `-target`, `-isysroot`, ld64, the SDK, and the installed dependencies as find roots), then configures, builds and installs with Ninja:

    package("example")
        on_install("iphoneos", function (package)
            import("@addon.revenant.apple.cmake").install(package, {"-DBUILD_TESTING=OFF"})
        end)

The third argument takes options: `cflags`, `cxxflags`, `ldflags`, `shflags`, and `system` (`Darwin` for a project that recognises Apple only by that name). `targets` builds only those; `install = false` skips `cmake --install` and returns the build folder. `deps = true`, or the names of dependencies, turns what those packages declare (include folders, defines, flags, links) into the toolchain file, so a C++ package says `{deps = {"libcxx"}}` rather than spelling the runtime out. `prune` removes installed paths such as `lib/cmake` or `lib/*.la`, and `licenses` copies the named files into the package's licences.

xmake's own `package.tools.cmake` does not pass a custom compiler for `iphoneos`, so use the bridge.

## Build a list of sources

A library without a build system of its own is compiled from a list of sources:

    import("@addon.revenant.apple.sources").static(package, {
        files = {"src/a.c", "src/b.c"},
        includedirs = {"include"},
        defines = {},
        cflags = {}, cxxflags = {}, mflags = {}, mxxflags = {},
        deps = {}, headers = {}, headers_prefix = "", licenses = {"LICENSE"},
        prune = {}, name = "example"
    })

It writes `lib<name>.a` with the toolchain's flags, and takes the language of each file from its extension.

## Build with make or autotools

A script that runs make or autoconf itself passes the toolchain's environment, and ends with `finish`:

    local envs = import("package.tools.autoconf").buildenvs(package)
    import("@addon.revenant.apple.envs").build(package, envs)
    import("@addon.revenant.apple.install").finish(package, {prune = {"lib/*.la"}, licenses = {"COPYING"}})

The include builds autotools' own `m4` and `pkgconf` packages, because macOS's `/usr/bin/m4` is GNU M4 1.4.6, which autoconf 2.72 refuses. A host step of a two-stage build, such as a generator built for macOS, runs with the process environment, which does not carry the toolchain's.

Every package the port requires is built with `-O3`, as a release build of a Makefile or autotools project expects. An install script runs in the extracted source, so its current directory is the source root.

## Hand a symbol shim to a package

A package whose sources call a function an old release lacks takes the `apple-compat` shim for it:

    import("@addon.revenant.apple.compat").force_includes(package:dep("apple-compat"), {"clock_gettime"})

The flags it returns force the shim's header into each file.

## Depend on other packages

A package reaches a dependency by the dependency's own name, `package:dep("swift-bootstrap")`, whatever `alias` the port gave it. A miss is a `nil` that fails only where the value is first used.

`package:dep(name)` is keyed by name, so a host tool and a target that depend on the same library meet under one key, and the later one wins. Keep a host tool out of any package that other packages depend on. Where a dependency's folder goes to CMake or a linker, the dependency in `package:orderdeps()` whose name, plat and arch match the package is the right one.

## Checkouts

A package that builds from git repositories takes them with `checkout.pinned(sourcedir, repositories)` from `modules/checkout.lua`. It clones each repository, verifies it against the commit its tag names, and keeps the clones across installs. Before each install, what the last one changed is undone. The sources of a compiler are gigabytes, so an install that fails halfway, or a second architecture, does not clone them again.

Because the clones are kept, a recipe patches them in place and keeps its build tree beside the repositories, never inside one. The package manager of Swift 6.4 reads its resource bundles from `usr/share/pm`, which a toolchain cut to the compiler does not have.

## Swift libraries

A Swift library is a package that requires `revenant@swift-runtime`, compiles its modules with the runtime's compiler and flags, and installs them as static libraries with their `.swiftmodule`s. It names the folders a port's Swift finds them in:

    package:setenv("REVENANT_SWIFT_MODULES", swiftdir, path.join(package:installdir("include"), "CombineHelpers"))

The `swift` rule adds those folders to the compile of any target that requires the package.

## Traps

- **A `copy` that matches nothing is silent.** A download that leaves one directory is entered by the build, so `os.curdir()` is that directory. A copy written against the level above matches nothing and reports nothing, so a recipe that lays out an install asserts what it laid down.
- **A library built with a SOVERSION.** Its build tree holds `libfoo.dylib` as a link to `libfoo.1.2.3.dylib`. A copy of `*.dylib` that matches the unversioned name copies the link, not the file, and the package ends with a dangling symlink. Copy the real file, and recreate the short name with `os.symlink` if consumers link against it.
- **Two `xmake` processes on one project** hold each other's package locks. A build that appears to make no progress for a long time is usually a second one left over from an earlier run.
- **A build cut short** can leave `.git/index.lock` in the package's source cache under `~/.xmake/cache/packages/`. Remove that lock file before building again.
- **xmake asks before installing a package**, and a command run in the background waits for that answer forever. Pass `-y` there.
- **A changed backport source or build module** is a different package with its own install path, but a port caches how it resolved its packages. `xmake f -c` installs the new one; `xmake f` alone keeps the port linking against the install it had.
