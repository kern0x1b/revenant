function failures(opt)
    local root = path.join(path.directory(opt.modules), "..")
    local isolate = import("isolate", {rootdir = path.join(root, "frameworks", "ReactNative", "tools"), anonymous = true})
    local found = {}

    if isolate.replace("a /x/p b /x/p/c", "/x/p", "/y") ~= "a /y b /y/c" then
        table.insert(found, "every occurrence of the old path must be rewritten")
    end
    if isolate.link_target("/x/p/build/rn", "/x/p", "/y") ~= "/y/build/rn" or isolate.link_target("/x/pp/rn", "/x/p", "/y") ~= nil then
        table.insert(found, "a link is retargeted only when it points into the old folder")
    end
    if isolate.folder_is_valid("/a/iso-test") or isolate.folder_is_valid("/a/Example") or not isolate.folder_is_valid("/a/iso") then
        table.insert(found, "a folder with test or Example in its path must be refused")
    end

    if isolate.host_bundle_id("/a/iso-Hermes_2", nil) ~= "org.revenant.rnhost.iso-hermes-2" or isolate.host_bundle_id("/a/x", "my.id") ~= "my.id" then
        table.insert(found, "a copy's bundle id must come from --bundle-id or from its folder's name")
    end

    local files = {
        ["/c/old/React/Fabric/Mounting/ComponentViews/TextInput/RCTTextInputUtils.mm"] = "x",
        ["/c/old/Libraries/Image/RCTImageUtils.mm"] = "y",
        ["/c/new/React/Fabric/Mounting/ComponentViews/TextInput/RCTTextInputUtils.mm"] = 'initWithString:attributedString.string ?: @""',
        ["/c/new/Libraries/Image/RCTImageUtils.mm"] = "CGSize s = {(CGFloat)width.doubleValue};",
        ["/c/new/ReactCommon/jsc/JSCRuntime.cpp"] = "extern \"C\" JSGlobalContextRef RNJscRuntimeContext(void);",
        ["/c/old/ReactCommon/jsc/JSCRuntime.cpp"] = "z"
    }
    local picked = isolate.patched_sources({"/c/old", "/c/new"}, function (file) return files[file] end, "/c/new")
    if isolate.patched_sources({"/c/old", "/c/new"}, function (file) return files[file] end, "/c/old") ~= nil then
        table.insert(found, "an install other than the recipe's key must not be picked")
    end
    if picked ~= "/c/new" then
        table.insert(found, "the install with all patches must be the one picked, got " .. tostring(picked))
    end

    local manifest_folder = path.join(os.tmpdir(), "iso-bundle-id-test", "iso-with-manifest")
    local plain_folder = path.join(os.tmpdir(), "iso-bundle-id-test", "iso-plain")
    os.tryrm(path.directory(manifest_folder))
    os.mkdir(path.join(manifest_folder, "build", "app-manifest"))
    os.mkdir(path.join(plain_folder, "build"))
    io.writefile(path.join(manifest_folder, "build", "app-manifest", "host.json"), '{"bundleId":"org.example.manifest","pods":["a:b"]}')
    if isolate.write_bundle_id(manifest_folder, nil) ~= "org.example.manifest" then
        table.insert(found, "without --bundle-id a copy keeps the bundleId of its manifest")
    end
    if isolate.write_bundle_id(manifest_folder, "org.example.given") ~= "org.example.given" or not io.readfile(path.join(manifest_folder, "build", "app-manifest", "host.json")):find('"bundleId":"org.example.given"', 1, true) then
        table.insert(found, "--bundle-id must win over the manifest and be written into it")
    end
    if isolate.write_bundle_id(plain_folder, nil) ~= "org.revenant.rnhost.iso-plain" then
        table.insert(found, "a folder without a manifest takes the bundle id of its name")
    end

    local env = isolate.build_environment({folder = "/f", cache = "/k", checkout = "/w", engine = "/e", swiftui = "/s", backports = "/b", real = ""})
    if env.RN_EXPO_REAL ~= nil or env.RN_SRC ~= "/f/build/rn-src" or env.REVENANT_CACHE ~= "/k" or env.REVENANT_PREBUILT_ONLY ~= "1" then
        table.insert(found, "the environment must name the folder's own sources and cache, and an empty --real must set no RN_EXPO_REAL")
    end
    if isolate.build_environment({folder = "/f", real = "expo-battery"}).RN_EXPO_REAL ~= "expo-battery" then
        table.insert(found, "--real must reach RN_EXPO_REAL")
    end

    if isolate.build_environment({folder = "/f", pkgdirs = "a=/d"}).RN_PKG_DIRS ~= "a=/d" then
        table.insert(found, "--pkgdirs must reach RN_PKG_DIRS")
    end

    local hermes_env = isolate.build_environment({folder = "/f", engine = "/e", hermes = true})
    if hermes_env.RN_JSC_ENGINE ~= nil or hermes_env.RN_HERMES ~= "1" then
        table.insert(found, "a Hermes build must not take the JavaScriptCore engine, and must set RN_HERMES")
    end
    if isolate.build_environment({folder = "/f", engine = "/e"}).RN_JSC_ENGINE ~= "/e" then
        table.insert(found, "a JavaScriptCore build must keep its engine")
    end

    local base = os.iorunv("mktemp", {"-d"}):trim()
    local project = path.join(base, "project")
    local folder = path.join(base, "copy")
    os.mkdir(path.join(project, "build", "rn-headers"))
    os.mkdir(path.join(project, "build", "ref", "paseo"))
    os.mkdir(path.join(project, "build", "iphoneos"))
    io.writefile(path.join(project, "xmake.lua"), "-- " .. project .. "\n")
    io.writefile(path.join(project, "build", "expo-core", "module.modulemap"), "header \"" .. project .. "/build/expo-core/a.h\"\n")
    io.writefile(path.join(project, "build", "iphoneos", "huge.o"), project)
    os.vrunv("ln", {"-s", path.join(project, "build", "expo-core", "module.modulemap"), path.join(project, "build", "rn-headers", "link.h")})
    local result = isolate.copy_project(project, folder)
    local resolved = os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
    if io.readfile(path.join(folder, "build", "expo-core", "module.modulemap")):find(project, 1, true) then
        table.insert(found, "a copied input must not name the original project")
    end
    if not io.readfile(path.join(folder, "xmake.lua")):find(folder, 1, true) then
        table.insert(found, "a copied project file must name the copy")
    end
    if os.isfile(path.join(folder, "build", "iphoneos", "huge.o")) then
        table.insert(found, "build products must not be copied")
    end
    if os.iorunv("readlink", {path.join(folder, "build", "rn-headers", "link.h")}):trim() ~= path.join(folder, "build", "expo-core", "module.modulemap") then
        table.insert(found, "a link into the original build must point into the copy")
    end
    if os.iorunv("readlink", {path.join(folder, "build", "ref")}):trim() ~= os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", path.join(project, "build", "ref")}):trim() then
        table.insert(found, "build/ref must stay a link to the shared read only tree")
    end
    if result.rewritten < 2 or resolved == "" then
        table.insert(found, "the copy must report the files it rewrote")
    end
    os.vrunv("rm", {"-rf", base})

    local rnbase = os.iorunv("mktemp", {"-d"}):trim()
    local rncache = path.join(rnbase, "cache")
    local install = path.join(rncache, "src", "react-native")
    io.writefile(path.join(install, "package.json"), "{}")
    io.writefile(path.join(install, "ReactCommon", "jsi", "jsi", "jsi.h"), "// jsi\n")
    io.writefile(path.join(install, "React", "Fabric", "Mounting", "ComponentViews", "TextInput", "RCTTextInputUtils.mm"), 'initWithString:attributedString.string ?: @""')
    io.writefile(path.join(install, "Libraries", "Image", "RCTImageUtils.mm"), "CGSize s = {(CGFloat)width.doubleValue};")
    io.writefile(path.join(install, "ReactCommon", "jsc", "JSCRuntime.cpp"), "extern \"C\" JSGlobalContextRef RNJscRuntimeContext(void);")
    local rncopy = path.join(rnbase, "copy")
    os.mkdir(path.join(rncopy, "build"))
    os.vrunv("ln", {"-s", path.join(rnbase, "a0b6.g1", "src", "react-native"), path.join(rncopy, "build", "rn-src")})
    if isolate.link_react_native(rncopy, rncache) ~= install or os.iorunv("readlink", {path.join(rncopy, "build", "rn-src")}):trim() ~= install then
        table.insert(found, "a dangling react-native link must be replaced by the install with all patches")
    end
    if not os.isfile(path.join(rncopy, "build", "rn-src", "ReactCommon", "jsi", "jsi", "jsi.h")) then
        table.insert(found, "the replaced react-native link must reach the sources")
    end
    local refused = false
    try {
        function () isolate.link_react_native(rncopy, path.join(rnbase, "empty")) end,
        catch { function () refused = true end }
    }
    if not refused then
        table.insert(found, "a cache without an install with all patches must be refused")
    end
    if isolate.command_status({"-c", "exit 0"}, {}) ~= 0 or isolate.command_status({"-c", "exit 3"}, {}) ~= 1 then
        table.insert(found, "a command's status is 0 when it succeeds and 1 when it fails, never nil")
    end
    os.vrunv("rm", {"-rf", rnbase})

    local copies = os.iorunv("mktemp", {"-d"}):trim()
    local bare = path.join(copies, "bare")
    os.mkdir(bare)
    if isolate.missing_input(bare) ~= "xmake.lua" then
        table.insert(found, "a folder without xmake.lua is no copy, and the missing file is named")
    end
    local whole = path.join(copies, "whole")
    os.mkdir(path.join(whole, "build"))
    io.writefile(path.join(whole, "xmake.lua"), "-- whole\n")
    for _, item in ipairs(isolate.input_names()) do
        os.mkdir(path.join(whole, "build", item))
    end
    if isolate.missing_input(whole) ~= nil then
        table.insert(found, "a copy with every input is complete")
    end
    os.vrunv("rm", {"-rf", path.join(whole, "build", "nitro")})
    if isolate.missing_input(whole) ~= path.join("build", "nitro") then
        table.insert(found, "a copy without one input names that input")
    end
    local refused
    try {
        function () isolate.build(bare, path.join(copies, "cache"), {}) end,
        catch { function (errors) refused = tostring(errors) end }
    }
    if not refused or refused:find("xmake.lua", 1, true) == nil or refused:find("nothing is built", 1, true) == nil then
        table.insert(found, "build refuses a folder that is no copy before it runs xmake, and names the missing file")
    end
    local defaults = path.join(copies, "defaults")
    os.mkdir(path.join(defaults, "build", "ref", "paseo", "node_modules", "expo-clipboard"))
    local picked = isolate.default_patched(defaults, nil)
    if #picked ~= 1 or picked[1] ~= "expo-clipboard" then
        table.insert(found, "the default path builds expo-clipboard from its patched recipe when the application has the package")
    end
    if #isolate.default_patched(defaults, "expo-battery") ~= 0 then
        table.insert(found, "--real replaces the default packages, so the default path adds no recipe")
    end
    if #isolate.default_patched(whole, nil) ~= 0 then
        table.insert(found, "a copy whose application lacks expo-clipboard takes no default recipe")
    end
    if isolate.recipe_version("expo-clipboard") ~= "57.0.2" then
        table.insert(found, "the recipe the default path installs is expo-clipboard 57.0.2, the version of the application")
    end
    os.vrunv("rm", {"-rf", copies})
    return found
end
