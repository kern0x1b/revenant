import("fixtures")

local function fake_target(folder, values, installdir, alias)
    -- A package that sets no CHARON_SHARED_PACKAGE: a runtime the program carries, not one it shares.
    local package = {installdir = function () return installdir end, envs = function () return {} end}
    return {
        name = function () return "tweak" end,
        scriptdir = function () return folder end,
        values = function (_, key) return values[key] end,
        dep = function () return nil end,
        pkg = function (_, name) return name == (alias or "runtime") and package or nil end
    }
end

local function references(folder, binary)
    local listed = {}
    for line in fixtures.run(folder, "xcrun", {"otool", "-L", binary}):gmatch("\n%s+(%S+)") do
        table.insert(listed, line)
    end
    return table.concat(listed, " ")
end

local function packages_target(declared, held)
    return {
        name = function () return "port" end,
        get = function (_, key) return key == "packages" and declared or nil end,
        pkg = function (_, name) return held[name] end
    }
end

-- A package the target adds and never receives is a binary built without it,
-- which the device only tells apart by failing, so the rules refuse the target.
local function packages_step(platform, found)
    local refused = fixtures.refusal(function () platform.verify_packages(packages_target({"ldid"}, {})) end)
    if not (refused and refused:find("adds package ldid", 1, true)) then
        table.insert(found, "a package the target adds and never receives must refuse the target, not " .. tostring(refused))
    end
    if fixtures.refusal(function () platform.verify_packages(packages_target({"ldid"}, {ldid = {}})) end) then
        table.insert(found, "a package the target receives must leave it alone")
    end
    if fixtures.refusal(function () platform.verify_packages(packages_target({"charon@absent"}, {})) end) then
        table.insert(found, "a name the project requires nowhere is no package of this target")
    end
end

-- A package is bundled under the name the target knows it by, and a require
-- named after its repository reaches the target under its alias, so the
-- repository's spelling finds nothing and has to say what to write instead.
local function bundled_step(bundle, found)
    local target = {
        name = function () return "tweak" end,
        values = function (_, key) return key == "charon.libraries" and {"charon@apple-backports"} or nil end,
        dep = function () return nil end,
        pkg = function () return nil end
    }
    local refused = fixtures.refusal(function () bundle.carried_libraries(target, "charon.libraries") end)
    if not (refused and refused:find("which is apple-backports", 1, true)) then
        table.insert(found, "a package bundled under the name of its repository must be told the name to use, not " .. tostring(refused))
    end
end

local function waivers_step(platform, found)
    local declared = {["charon.waive.pagezero"] = "a reason", ["charon.waive.weak-imports"] = "guarded"}
    local target = {values = function (_, key) return declared[key] end}
    local waived = platform.waivers(target)
    if waived.pagezero ~= "a reason" or waived["weak-imports"] ~= "guarded" then
        table.insert(found, "the waivers a target declares with charon.waive.<check> must reach the checks: " .. tostring(waived.pagezero) .. ", " .. tostring(waived["weak-imports"]))
    end
    if waived.entitlements or waived["thumb-interworking"] then
        table.insert(found, "a check the target does not waive must not be waived")
    end
end

-- A program links one build of the runtime and one of libc++: a package that was compiled against another build is refused,
-- naming both.
local function one_runtime_step(platform, folder, found)
    local function package(name, mark, linkdir)
        return {name = function () return name end,
                envs = function () return mark and {CHARON_SWIFT_RUNTIME_MARK = {mark}} or {} end,
                get = function (_, key) return key == "linkdirs" and {linkdir} or nil end}
    end
    local function target(...)
        local packages = {...}
        return {name = function () return "port" end, orderpkgs = function () return packages end}
    end
    local first, second = path.join(folder, "packages", "libcxx", "a"), path.join(folder, "packages", "libcxx", "b")
    for _, dir in ipairs({first, second}) do
        os.mkdir(dir)
        io.writefile(path.join(dir, "libc++.dylib"), "")
    end
    local none = path.join(folder, "empty")
    if fixtures.refusal(function () platform.verify_one_runtime(target(package("swift-runtime", "charon_swift_runtime_one", none), package("styx", "charon_swift_runtime_one", none), package("libcxx", nil, first))) end) then
        table.insert(found, "packages built against one runtime and one libc++ must pass")
    end
    local refused = fixtures.refusal(function () platform.verify_one_runtime(target(package("swift-runtime", "charon_swift_runtime_one", none), package("styx", "charon_swift_runtime_two", none))) end) or ""
    if not refused:find("2 builds of swift-runtime", 1, true) or not refused:find("charon_swift_runtime_one (swift-runtime)", 1, true) or not refused:find("charon_swift_runtime_two (styx)", 1, true) then
        table.insert(found, "a package built against another runtime must be refused, naming each build and who asks for it: " .. refused)
    end
    refused = fixtures.refusal(function () platform.verify_one_runtime(target(package("libcxx", nil, first), package("styx", nil, second))) end) or ""
    if not refused:find("2 builds of libcxx", 1, true) or not refused:find("(styx)", 1, true) then
        table.insert(found, "two builds of libc++ in one link must be refused: " .. refused)
    end
end

function failures(opt)
    local platform = import("apple.platform", {rootdir = opt.modules, anonymous = true})
    local bundle = import("apple.bundle", {rootdir = opt.modules, anonymous = true})
    local found = {}
    packages_step(platform, found)
    one_runtime_step(platform, fixtures.scratch(), found)
    waivers_step(platform, found)
    bundled_step(bundle, found)
    local folder = fixtures.scratch()
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    local runtime = path.join(folder, "runtime")
    os.mkdir(path.join(runtime, "lib"))
    io.writefile(path.join(folder, "abi.c"), "int abi(void) { return 1; }\n")
    io.writefile(path.join(folder, "cxx.c"), "extern int abi(void);\nint cxx(void) { return abi(); }\n")
    io.writefile(path.join(folder, "tweak.c"), "extern int abi(void);\nint tweak(void) { return abi(); }\n")
    fixtures.link(folder, opt.ld64, path.join(runtime, "lib", "libabi.1.dylib"), "armv7-apple-ios6.0", "abi.c",
                  {"-dynamiclib", "-install_name", "@rpath/libabi.1.dylib"})
    fixtures.link(folder, opt.ld64, path.join(runtime, "lib", "libcxx.1.dylib"), "armv7-apple-ios6.0", "cxx.c",
                  {"-dynamiclib", "-install_name", "@rpath/libcxx.1.dylib", "-L" .. path.join(runtime, "lib"), "-labi.1"})
    local built = fixtures.link(folder, opt.ld64, "tweak.dylib", "armv7-apple-ios6.0", "tweak.c",
                                {"-dynamiclib", "-install_name", "/Library/MobileSubstrate/DynamicLibraries/tweak.dylib",
                                 "-L" .. path.join(runtime, "lib"), "-labi.1"})
    io.writefile(path.join(folder, "control"), "Package: org.example.carried\nArchitecture: iphoneos-arm\n")

    local root = path.join(folder, "root")
    local binary = path.join(root, "Library", "MobileSubstrate", "DynamicLibraries", "tweak.dylib")
    os.mkdir(path.directory(binary))
    os.cp(built, binary)
    local target = fake_target(folder, {["charon.libraries"] = "runtime", ["charon.control"] = "control"}, runtime)
    local placed, runtime_images = platform.place_carried(target, root, binary)
    local carried = path.join(root, "usr", "lib", "charon", "org.example.carried")
    if #runtime_images ~= 0 then
        table.insert(found, "a library carried from a package that is not the runtime is the program's to answer for, and must not be exempted: " .. table.concat(runtime_images, " "))
    end
    if #placed ~= 2 or not os.isfile(path.join(carried, "libabi.1.dylib")) then
        table.insert(found, "a tweak carries the library it loads into /usr/lib/charon/<Package>, got " .. table.concat(placed, " "))
    end
    if os.isfile(path.join(carried, "libcxx.1.dylib")) then
        table.insert(found, "a library of the package that no placed image loads must not be carried")
    end
    local listed = references(folder, binary)
    if not listed:find("/usr/lib/charon/org.example.carried/libabi.1.dylib", 1, true) or listed:find("@rpath", 1, true) then
        table.insert(found, "the tweak must load its runtime from its package's folder: " .. listed)
    end
    local identity = references(folder, path.join(carried, "libabi.1.dylib"))
    if not identity:startswith("/usr/lib/charon/org.example.carried/libabi.1.dylib") then
        table.insert(found, "the carried library must be identified by its installed path: " .. identity)
    end

    -- The copy of a library the runtime package installs is the runtime's image, as it is when the runtime is shared: the
    -- imports check reports its weak imports and does not refuse the program for them.
    local runtime_root = path.join(folder, "runtime-root")
    local runtime_binary = path.join(runtime_root, "Library", "MobileSubstrate", "DynamicLibraries", "tweak.dylib")
    os.mkdir(path.directory(runtime_binary))
    os.cp(built, runtime_binary)
    local carrying = fake_target(folder, {["charon.libraries"] = "swift-runtime", ["charon.control"] = "control"}, runtime, "swift-runtime")
    local _, exempted = platform.place_carried(carrying, runtime_root, runtime_binary)
    local expected = path.join(runtime_root, "usr", "lib", "charon", "org.example.carried", "libabi.1.dylib")
    if #exempted ~= 1 or exempted[1] ~= expected then
        table.insert(found, "the copy of a library carried from the runtime package must be exempted as the runtime's image, got " .. table.concat(exempted, " "))
    end

    -- What a program carries of a package is what it loads, through its own libraries as well (an application carries what
    -- reached() answers): the library its image names, the one that library names in turn, and not the rest the package holds.
    if not platform.reached then
        table.insert(found, "platform.reached answers which of a package's libraries a program's images load, and an application carries those")
    else
        local offered = {{name = "libabi.1.dylib", source = path.join(runtime, "lib", "libabi.1.dylib")},
                         {name = "libcxx.1.dylib", source = path.join(runtime, "lib", "libcxx.1.dylib")}}
        local function names(libraries)
            local listed = {}
            for _, library in ipairs(libraries) do
                table.insert(listed, library.name)
            end
            return table.concat(listed, " ")
        end
        local direct = names(platform.reached(offered, {built}))
        if direct ~= "libabi.1.dylib" then
            table.insert(found, "a program that loads one library of a package must carry that one and not the other, got: " .. direct)
        end
        local through = names(platform.reached(offered, {path.join(runtime, "lib", "libcxx.1.dylib")}))
        if through ~= "libabi.1.dylib" then
            table.insert(found, "a library the program's library loads must be carried with it, got: " .. through)
        end
        local none = names(platform.reached(offered, {path.join(runtime, "lib", "libabi.1.dylib")}))
        if none ~= "" then
            table.insert(found, "a program that loads no library of a package carries none of it, got: " .. none)
        end
    end

    local unnamed = fake_target(folder, {["charon.libraries"] = "runtime"}, runtime)
    local errors = fixtures.refusal(function () platform.place_carried(unnamed, path.join(folder, "unnamed"), built) end) or ""
    if not errors:find("charon.control", 1, true) then
        table.insert(found, "a tweak that carries a library without naming its package must be refused: " .. errors)
    end

    io.writefile(path.join(folder, "nameless"), "Name: Carried\nArchitecture: iphoneos-arm\n")
    local nameless = fake_target(folder, {["charon.libraries"] = "runtime", ["charon.control"] = "nameless"}, runtime)
    errors = fixtures.refusal(function () platform.place_carried(nameless, path.join(folder, "nameless-root"), built) end) or ""
    if not errors:find("no Package field", 1, true) then
        table.insert(found, "a control file without Package cannot name the folder, and must be refused: " .. errors)
    end
    -- A library a package the program depends on installs is pointed at by its installed name, and carried by nobody.
    local shared = path.join(folder, "shared-tweak.dylib")
    os.cp(built, shared)
    local provided = {["libabi.1.dylib"] = "/usr/lib/charon/org.example.shared/libabi.1.dylib"}
    bundle.retarget({shared}, {}, {provided = provided})
    listed = references(folder, shared)
    if not listed:find("/usr/lib/charon/org.example.shared/libabi.1.dylib", 1, true) or listed:find("@rpath", 1, true) then
        table.insert(found, "a program must load a library its dependency installs from that package's folder: " .. listed)
    end
    os.cp(built, shared)
    os.vrunv("xcrun", {"install_name_tool", "-change", "@rpath/libabi.1.dylib", "/usr/lib/elsewhere/libabi.dylib", shared})
    errors = fixtures.refusal(function () bundle.retarget({shared}, {}, {provided = provided}) end) or ""
    if not errors:find("installs that library there", 1, true) then
        table.insert(found, "a program that loads the library a package installs, under another file name from another folder, must be refused: " .. errors)
    end
    os.tryrm(folder)
    return found
end
