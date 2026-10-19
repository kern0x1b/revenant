function failures(opts)
    local found = {}
    local G = import("generate", {rootdir = opts.driver, anonymous = true})
    G.generate_bind(opts.driver)
    local spec = G.generate_spec()

    local function check(condition, message)
        if not condition then
            table.insert(found, message)
        end
    end

    local function refused(fn)
        local message = nil
        try { function () fn() end, catch { function (e) message = tostring(e) end } }
        return message
    end

    local counter = 0
    local function case_folder()
        counter = counter + 1
        local folder = path.join(opts.scratch, "case-" .. counter)
        os.mkdir(folder)
        return folder
    end

    local function write_file(folder, relative, text)
        local target = path.join(folder, relative)
        os.mkdir(path.directory(target))
        io.writefile(target, text or "")
    end

    local function loaded(folder, text)
        io.writefile(path.join(folder, "revenant.toml"), text)
        return spec.spec_load(folder)
    end

    local function contains(text, expected)
        return string.find(text, expected, 1, true) ~= nil
    end

    local function line_at(text, index)
        local at = 0
        for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
            at = at + 1
            if at == index then
                return line
            end
        end
        return ""
    end

    local MANIFEST = [==[
[port]
name = "example"
version = "1.0"

[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"

[target]
cppstd = 23
cpu = "cortex-a9"
fpu = "neon"
defines = ["-DEXAMPLE_PORT"]

[engine]
find-packages = ["LibXml2"]
project-name = "Example"
config-packages = ["LibXml2", "LibXslt"]

[[static-library]]
name = "compat"
sources = ["compat/a.c", "compat/b.m"]
standard = 23
include-system = ["compat/stubs", "${LIBCXX_DIR}/include/c++/v1"]
options = ["-O2", "-fno-objc-arc"]
definitions = ["$<$<COMPILE_LANGUAGE:OBJC>:EXTRAS>"]
source-include = { "compat/a.c" = "${PSL_INCLUDE_DIR}" }
cache = { LIBCXX_DIR = "{pkg:libcxx}", PSL_INCLUDE_DIR = "{include:libpsl}" }

[[device-library]]
name = "tweak"
sources = ["platform/tweak.c"]
install = "/Library/MobileSubstrate/DynamicLibraries"
packages = ["openssl"]
frameworks = ["CoreFoundation"]
libraries = ["objc"]
resources = [{ from = "platform/tweak.plist", as = "Tweak.plist" }]

[[device-library]]
name = "prefs"
cmake = "platform/prefs"

[application]
name = "Host"
sources = ["app/main.m"]
frameworks = ["UIKit"]
resources = ["app/cacert.pem", { from = "app/Localization/", as = "." }]

[tests.host]
runs = ["tests/run.py:on_host"]
needs = []
packages = { icu = "74.2@revenant/stable" }

[tests.gate]
runs = ["tests/device.py:gate"]
needs = ["device"]
]==]

    local BROKEN = {
        {"a device library with no install path", [==[
[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"
[[device-library]]
name = "tweak"
sources = ["a.c"]
]==]},
        {"a source whose language Revenant cannot name", [==[
[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"
[[static-library]]
name = "compat"
sources = ["a.rs"]
]==]},
        {"a target with neither sources nor cmake", [==[
[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"
[[static-library]]
name = "compat"
]==]},
        {"a resource that is neither a path nor a table with from and as", [==[
[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"
[application]
name = "Host"
sources = ["main.m"]
resources = [{ from = "images/" }]
]==]},
    }

    do
        local folder = case_folder()
        write_file(folder, "compat/stubs/.keep")
        local declared = loaded(folder, MANIFEST)
        local written = G.generate_written(declared)

        local static = written["static-library/CMakeLists.txt"]
        check(contains(static, "add_library(compat STATIC"), "a static library must be generated as STATIC")
        check(contains(static, "project(port-static C OBJC)"), "languages must come from the sources: got " .. line_at(static, 3))
        check(not contains(static, "find_package"), "a target that declares no package must get no find_package, and the engine list must not leak into a port project")
        check(contains(static, "CXX_STANDARD 23"), "a declared standard must be set on the target")
        check(not contains(static, "install("), "a static library is consumed by the build, so it must not be installed")
        check(contains(static, "${REVENANT_PORT}/compat/a.c"), "a declared source must be written against the port")
        check(not contains(static, "${REVENANT_PORT}/${LIBCXX_DIR}"), "a value that already starts at a cmake variable must be left exactly as declared")
        check(contains(static, "if (NOT REVENANT_PORT)"), "a generated project must refuse to configure when nothing told it where the port is")
        check(contains(static, "foreach (variable LIBCXX_DIR PSL_INCLUDE_DIR)"), "every cache variable a target names must be guarded: got " .. static)
        check(contains(static, "target_compile_definitions(compat PRIVATE"), "declared definitions must reach the target")
        check(contains(static, 'set_source_files_properties(${REVENANT_PORT}/compat/a.c PROPERTIES INCLUDE_DIRECTORIES "${PSL_INCLUDE_DIR}")'),
              "a per-source include must be set on that source and on no other")

        local device = written["device-library/CMakeLists.txt"]
        check(contains(device, "add_library(tweak SHARED"), "a device library must be SHARED, because a MODULE bypasses the linker we require")
        check(contains(device, "INSTALL_NAME_DIR /Library/MobileSubstrate/DynamicLibraries"), "a device library must record the path it is deployed to")
        check(contains(device, '"-framework CoreFoundation"') and contains(device, "objc"), "frameworks and libraries must both reach target_link_libraries")
        check(contains(device, 'include("${REVENANT_PACKAGES}")'), "a package declared on a target must reach that project")
        check(contains(device, "RENAME Tweak.plist"), "a renamed resource must keep its new name")
        check(not contains(device, "prefs"), "a target with cmake= must not be generated at all")

        local application = written["application/CMakeLists.txt"]
        check(contains(application, "add_executable(Host"), "an application must be an executable")
        check(contains(application, "install(TARGETS Host RUNTIME DESTINATION .)"), "an application must install its binary")
        check(contains(application, "install(FILES ${REVENANT_PORT}/app/cacert.pem DESTINATION .)"), "an application must install its declared resources")
        check(contains(application, "install(DIRECTORY ${REVENANT_PORT}/app/Localization/ DESTINATION .)"),
              "an application must install a declared resource folder, not drop it")

        local cross = written["cross-toolchain.cmake"]
        for _, expected in ipairs({"set(CMAKE_OSX_ARCHITECTURES ${REVENANT_ARCHITECTURE})",
                                   "-target ${REVENANT_TRIPLE} -isysroot ${REVENANT_SYSROOT}",
                                   "set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)",
                                   "set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)",
                                   "-DEXAMPLE_PORT"}) do
            check(contains(cross, expected), "the cross toolchain must carry " .. expected)
        end
        check(contains(cross, "CACHE PATH") and contains(cross, "REVENANT_SDK"),
              "the SDK must be remembered in the cache, because ninja re-runs cmake without the shell that configured it")

        local applied = written["project-include.cmake"]
        check(contains(applied, "find_package(LibXml2 REQUIRED CONFIG)") and contains(applied, "find_package(LibXslt REQUIRED CONFIG)"),
              "a package declared under config-packages must be found by config")
        check(contains(applied, "# Written by Revenant from revenant.toml"), "the applied file must say it is generated")
        check(contains(static, "# Written by Revenant from revenant.toml"), "a generated file must say it is generated")
        check(written["tests/host/conanfile.py"] == nil and written["tests/gate/conanfile.py"] == nil,
              "tier recipes are Conan's and are not written any more")
    end

    for _, case in ipairs(BROKEN) do
        local folder = case_folder()
        local message = refused(function () G.generate_written(loaded(folder, case[2])) end)
        check(message ~= nil, case[1] .. " must be refused")
    end

    do
        local folder = case_folder()
        for _, relative in ipairs({"compat/a.c", "compat/deep/b.c", "compat/c.m", "compat/skip/d.c"}) do
            write_file(folder, relative)
        end
        local globbed = [==[
[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"
[[static-library]]
name = "compat"
sources = ["compat/**/*.c", "compat/*.m"]
exclude = ["compat/skip/**"]
]==]
        local static = G.generate_written(loaded(folder, globbed))["static-library/CMakeLists.txt"]
        for _, expected in ipairs({"compat/a.c", "compat/deep/b.c", "compat/c.m"}) do
            check(contains(static, "${REVENANT_PORT}/" .. expected), "a source matched by a pattern must be built: " .. expected)
        end
        check(not contains(static, "compat/skip/d.c"), "a source under an exclude pattern must not be built")
        check(contains(static, "project(port-static C OBJC)"), "languages must come from the files a pattern matched")

        local cases = {
            {"a pattern that matches no file, beside one that does", {"compat/**/*.c", "compat/**/*.swift"}, {}, "matches no file"},
            {"sources that exclude takes every one of", {"compat/**/*.c"}, {"compat/**"}, "takes every one"},
        }
        for _, case in ipairs(cases) do
            local sources = {}
            for _, source in ipairs(case[2]) do
                table.insert(sources, '"' .. source .. '"')
            end
            local excluded = {}
            for _, pattern in ipairs(case[3]) do
                table.insert(excluded, '"' .. pattern .. '"')
            end
            local text = string.gsub(globbed, 'sources = %["compat/%*%*/%*%.c", "compat/%*%.m"%]',
                                     "sources = [" .. table.concat(sources, ", ") .. "]")
            text = string.gsub(text, 'exclude = %["compat/skip/%*%*"%]', "exclude = [" .. table.concat(excluded, ", ") .. "]")
            local message = refused(function () G.generate_written(loaded(folder, text)) end)
            if message == nil then
                table.insert(found, case[1] .. " must be refused")
            elseif not contains(message, case[4]) then
                table.insert(found, case[1] .. " must be refused for that reason, not another: " .. message)
            end
        end
    end

    do
        local folder = case_folder()
        write_file(folder, "main.c")
        local base = '[platform]\nuse = "apple-ios"\narch = "armv7"\nos-version = "6.0"\n[[executable]]\nname = "telegramd"\nsources = ["main.c"]\n'
        local text = G.generate_written(loaded(folder, base .. 'install = "/usr/libexec"\n'
                                       .. 'resources = [{ from = "main.c", as = "/etc/telegramd.conf" }]\n'))["executable/CMakeLists.txt"] or ""
        for _, expected in ipairs({"project(port-executable C)", "add_executable(telegramd",
                                   "install(TARGETS telegramd RUNTIME DESTINATION usr/libexec)", "RENAME telegramd.conf"}) do
            check(contains(text, expected), "an executable must be generated as a program installed where it says: missing " .. expected)
        end
        check(not contains(text, "add_library"), "an executable must not be generated as a library")
        local message = refused(function () G.generate_written(loaded(folder, base)) end)
        if message == nil or not contains(message, "install path") then
            table.insert(found, "an executable with no install path must be refused for that: " .. tostring(message))
        end
    end

    do
        local folder = case_folder()
        local text = G.generate_cross_toolchain(loaded(folder, '[platform]\nuse = "apple-ios"\narch = "armv8"\nos-version = "7.0"\n'))
        for _, expected in ipairs({"set(CMAKE_OSX_ARCHITECTURES ${REVENANT_ARCHITECTURE})", "-target ${REVENANT_TRIPLE}",
                                   "NOT REVENANT_ARCHITECTURE OR NOT REVENANT_TRIPLE"}) do
            check(contains(text, expected), "the cross toolchain must take the architecture and target from the build: " .. expected .. " is missing")
        end
        check(not contains(text, "armv8"), "the cross toolchain must not spell the declared architecture name clang does not know")
    end

    do
        local folder = case_folder()
        write_file(folder, "main.m")
        local application = G.generate_written(loaded(folder, '[platform]\nuse = "apple-ios"\narch = "armv7"\nos-version = "6.0"\n'
                                              .. '[application]\nname = "Host"\nsources = ["main.m"]\npackages = ["openssl"]\n'))["application/CMakeLists.txt"]
        check(not contains(application, "find_package(") and contains(application, 'include("${REVENANT_PACKAGES}")'),
              "a generated project must find its packages through the file the build writes from the graph")
    end

    do
        local folder = case_folder()
        write_file(folder, "first.m")
        write_file(folder, "first.mm")
        write_file(folder, "later.c")
        local ordered = [==[
[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"
[[static-library]]
name = "objcfirst"
sources = ["first.m", "first.mm"]
[[static-library]]
name = "clater"
sources = ["later.c"]
]==]
        local static = G.generate_written(loaded(folder, ordered))["static-library/CMakeLists.txt"]
        check(contains(static, "project(port-static C OBJC OBJCXX)"),
              "project() must enable C before OBJC whatever order the sources and targets come in: got " .. line_at(static, 3))
    end

    do
        local folder = case_folder()
        for _, relative in ipairs({"src/App/main.m", "src/Screens/Chat/Cells/cell.m", "src/Calls/call.mm", "src/Resources/x.m"}) do
            write_file(folder, relative)
        end
        local layered = [==[
[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"
[application]
name = "Host"
sources = ["src/**/*.m", "src/**/*.mm"]
exclude = ["src/Resources/**"]
include = ["src/**/"]
include-exclude = ["src/Resources/**"]
options = ["-O2"]
[application.options-for]
objc = ["-fobjc-arc"]
objcxx = ["-fobjc-arc", "-isystem /sdk/usr/include/c++/v1"]
[application.definitions-for]
objcxx = ["TGVOIP_NO_DSP"]
[application.include-system-for]
objcxx = ["${CXX_STDLIB}"]
]==]
        local application = G.generate_written(loaded(folder, layered))["application/CMakeLists.txt"]
        for _, folder_name in ipairs({"src", "src/App", "src/Screens", "src/Screens/Chat", "src/Screens/Chat/Cells", "src/Calls"}) do
            check(contains(application, "${REVENANT_PORT}/" .. folder_name .. "\n") or contains(application, "${REVENANT_PORT}/" .. folder_name .. ")"),
                  "an include pattern must reach " .. folder_name)
        end
        check(not contains(application, "src/Resources"), "a folder under include-exclude, and its sources, must not be used")
        for _, expected in ipairs({'"$<$<COMPILE_LANGUAGE:OBJC>:-fobjc-arc>"',
                                   '"$<$<COMPILE_LANGUAGE:OBJCXX>:SHELL:-isystem /sdk/usr/include/c++/v1>"',
                                   '"$<$<COMPILE_LANGUAGE:OBJCXX>:TGVOIP_NO_DSP>"',
                                   '"$<$<COMPILE_LANGUAGE:OBJCXX>:${CXX_STDLIB}>"'}) do
            check(contains(application, expected), "a per-language value must be written as " .. expected)
        end

        local cases = {
            {"an include pattern that matches no folder", 'include = ["src/**/"]', 'include = ["lib/**/"]', "matches no folder"},
            {"an include folder that is not there", 'include = ["src/**/"]', 'include = ["src/App", "app"]', "no such folder"},
            {"options for a language nobody named", "[application.options-for]\nobjc", "[application.options-for]\nswift", "not one of"},
            {"options for a language no source is in", "[application.options-for]\nobjc", "[application.options-for]\nc", "would apply to nothing"},
        }
        for _, case in ipairs(cases) do
            local text = string.gsub(layered, string.gsub(case[2], "%p", "%%%0"), (string.gsub(case[3], "%%", "%%%%")))
            local message = refused(function () G.generate_written(loaded(folder, text)) end)
            if message == nil then
                table.insert(found, case[1] .. " must be refused")
            elseif not contains(message, case[4]) then
                table.insert(found, case[1] .. " must be refused for that reason, not another: " .. message)
            end
        end
    end

    if opts.oracle ~= nil then
        local tree = opts.oracle
        local declared = spec.decl_for_variant(spec.spec_load(opts.port), opts.variant)
        local written = G.generate_written(declared)
        for _, relative in ipairs({"static-library/CMakeLists.txt", "device-library/CMakeLists.txt",
                                   "application/CMakeLists.txt", "project-include.cmake", "cross-toolchain.cmake"}) do
            local recorded_file = path.join(tree, relative)
            local recorded = os.isfile(recorded_file) and io.readfile(recorded_file) or nil
            if recorded == nil then
                table.insert(found, relative .. " is not in the recorded tree " .. tree)
            elseif written[relative] ~= recorded then
                table.insert(found, relative .. " differs from the recorded output in " .. tree)
            end
        end
    else
        table.insert(found, "no recorded build tree was given, so the byte comparison did not run")
    end

    return found
end
