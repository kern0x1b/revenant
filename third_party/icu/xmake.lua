package("icu")
    set_homepage("https://icu.unicode.org")
    set_description("ICU as static libraries for armv7 and iOS 6, and for the Mac that tests its data: the prebuilt data archive of the release, cut down with ICU's own icupkg, genrb and derb to the languages in keep-languages.txt and without the RBNF and transliteration trees")
    set_license("Unicode-3.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/unicode-org/icu/releases/download/release-$(version)/icu4c-$(version)-sources.tgz")
    add_versions("78.3", "3a2e7a47604ba702f345878308e6fefeca612ee895cf4a5f222e7955fabfe0c0")
    add_links("icui18n", "icuuc", "icudata")
    add_defines("U_STATIC_IMPLEMENTATION", "U_DISABLE_RENAMING=1")

    on_load(function (package)
        if package:is_plat("iphoneos") then
            package:add("deps", "revenant@libcxx", {alias = "libcxx"})
        end
    end)

    on_install("iphoneos", "macosx", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "toolchain", "modules")
        local parallel = import("parallel", {rootdir = modules, anonymous = true})
        local trees = {"", "curr/", "lang/", "region/", "zone/", "unit/", "coll/", "brkitr/", "rbnf/"}
        local dropped = {"rbnf/", "translit/"}
        local unindexed = {ja_JP_TRADITIONAL = true, th_TH_TRADITIONAL = true, de_ = true, de__PHONEBOOK = true, es_ = true, es__TRADITIONAL = true}

        local function language(name)
            return name:match("^([^_]*)")
        end

        local function make(dir, targets)
            parallel.hold(nil, function (width)
                os.vrunv("make", table.join({"-j" .. width}, targets or {}), {curdir = dir, envs = {ac_cv_prog_PYTHON = ""}})
            end)
        end

        local function trim(bin, archive)
            local keep, kept = {root = true}, 0
            for _, name in ipairs(io.readfile(path.join(package:scriptdir(), "keep-languages.txt")):split("%s+")) do
                keep[name] = true
                kept = kept + 1
            end
            local icupkg = path.join(bin, "icupkg")
            local work = path.absolute("data-trim")
            os.tryrm(work)
            local items = {}
            for _, line in ipairs(os.iorunv(icupkg, {"-l", archive}):split("\n")) do
                local item = line:trim():gsub("^icudt%d+[lbe]/", "")
                if item ~= "" then
                    items[item] = true
                end
            end
            local removed, added = {}, {}
            for _, tree in ipairs(trees) do
                local index = tree .. "res_index.res"
                if items[index] then
                    os.mkdir(path.join(work, "in", tree))
                    os.vrunv(icupkg, {"-x", index, "-d", path.join(work, "in"), archive})
                    local text = os.iorunv(path.join(bin, "derb"), {"-c", "-e", "UTF-8", "-s", path.join(work, "in", tree), "res_index.res"})
                    local indexed, lines = {}, {}
                    for _, line in ipairs(text:split("\n", {strict = true})) do
                        local key = line:match("^%s*([%w_]+)%s*{%s*\"\"%s*}%s*$")
                        if key then
                            indexed[key] = true
                        end
                        if not key or keep[language(key)] then
                            table.insert(lines, line)
                        end
                    end
                    local count = 0
                    for item in pairs(items) do
                        local stem = item:startswith(tree) and item:sub(#tree + 1):match("^([^/]+)%.res$")
                        if stem and (indexed[stem] or unindexed[stem]) and not keep[language(stem)] then
                            table.insert(removed, item)
                            count = count + 1
                        end
                    end
                    if count > 0 then
                        local source = path.join(work, "txt", tree)
                        io.writefile(path.join(source, "res_index.txt"), table.concat(lines, "\n") .. "\n")
                        os.mkdir(path.join(work, "out", tree))
                        os.vrunv(path.join(bin, "genrb"), {"-k", "-e", "UTF-8", "-s", source, "-d", path.join(work, "out", tree), "res_index.txt"})
                        table.insert(added, index)
                    end
                end
            end
            for item in pairs(items) do
                for _, prefix in ipairs(dropped) do
                    if item:startswith(prefix) then
                        table.insert(removed, item)
                    end
                end
            end
            removed = table.unique(removed)
            table.sort(removed)
            io.writefile(path.join(work, "removed.txt"), table.concat(removed, "\n") .. "\n")
            local argv = {"-r", path.join(work, "removed.txt")}
            if #added > 0 then
                io.writefile(path.join(work, "added.txt"), table.concat(added, "\n") .. "\n")
                table.join2(argv, {"-a", path.join(work, "added.txt"), "-s", path.join(work, "out")})
            end
            local trimmed = path.join(work, path.filename(archive))
            os.vrunv(icupkg, table.join(argv, {archive, trimmed}))
            os.cp(trimmed, archive)
            print("icu data: %d languages kept, %d items removed, %d indexes rewritten, without %s", kept, #removed, #added, table.concat(dropped, " "))
        end

        local configure = path.absolute(path.join("source", "configure"))
        local archive = path.absolute(path.join("source", "data", "in", "icudt" .. package:version():major() .. "l.dat"))
        local options = {"--enable-static", "--disable-shared", "--disable-tests", "--disable-samples", "--disable-extras"}
        local base = {ac_cv_prog_PYTHON = "", SOURCE_DATE_EPOCH = "0"}
        local host = path.absolute("build-host")
        os.mkdir(host)
        local hostenvs = table.join(base, {CC = "cc", CXX = "c++"})
        if package:is_plat("macosx") then
            local flags = "-arch " .. package:arch()
            hostenvs = table.join(hostenvs, {CFLAGS = flags, CXXFLAGS = flags, LDFLAGS = flags})
        end
        os.vrunv("sh", table.join({configure}, options, package:is_plat("macosx") and {"--prefix=" .. package:installdir()} or {}),
                 {curdir = host, envs = hostenvs})
        make(host)
        trim(path.join(host, "bin"), archive)
        if package:is_plat("macosx") then
            make(path.join(host, "data"), {"clean"})
            make(host)
            make(host, {"install"})
        else
            local cmake = import("apple.cmake", {rootdir = modules, anonymous = true})
            local chosen = cmake.toolchain(package)
            local target = {"-target", package:arch() .. "-apple-ios" .. chosen:config("deployment"), "-isysroot", chosen:config("sdkdir")}
            if chosen:config("linker_version") then
                table.insert(target, "-mlinker-version=" .. chosen:config("linker_version"))
            end
            local compiled = table.join(target, {"-O2"}, chosen:config("emulated_tls") and {"-femulated-tls"} or {})
            local linked = table.copy(target)
            for _, flag in ipairs(table.wrap(chosen:get("shflags"))) do
                if flag:startswith("-fuse-ld=") then
                    table.insert(linked, flag)
                end
            end
            local libcxx = import("apple.deps", {rootdir = modules, anonymous = true}).flags(package, "libcxx")
            local hosts = {armv7 = "arm-apple-darwin", armv7s = "arm-apple-darwin", arm64 = "aarch64-apple-darwin"}
            local cross = path.absolute("build-cross")
            os.mkdir(cross)
            local envs = table.join(base, {
                CC = chosen:tool("cc"),
                CXX = chosen:tool("cxx"),
                CFLAGS = table.concat(compiled, " "),
                CXXFLAGS = table.concat(table.join(compiled, libcxx.cflags, libcxx.cxxflags), " "),
                LDFLAGS = table.concat(linked, " "),
                IPHONEOS_DEPLOYMENT_TARGET = chosen:config("deployment")
            })
            os.vrunv("sh", table.join({configure, "--host=" .. assert(hosts[package:arch()], "ICU builds armv7, armv7s and arm64 for iPhoneOS"),
                                       "--with-cross-build=" .. host, "--disable-tools", "--disable-renaming",
                                       "--prefix=" .. package:installdir()}, options),
                     {curdir = cross, envs = envs})
            make(cross)
            make(cross, {"install"})
        end
        import("apple.install", {rootdir = modules, anonymous = true}).finish(package, {
            licenses = "LICENSE", prune = {"lib/pkgconfig", "lib/icu", "share", "bin", "sbin"}})
    end)

    on_test(function (package)
        for _, library in ipairs({"icudata", "icuuc", "icui18n"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), library .. " is not installed")
        end
        assert(os.isfile(path.join(package:installdir("include"), "unicode", "utypes.h")))
    end)
