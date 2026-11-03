local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/inputs.lua make <project> [--build DIR] [--app DIR] [--react-native DIR] [--only name,...] [--real package,...]
       ./xmakew l -P . frameworks/ReactNative/tools/inputs.lua compare <reference build> <built build> [--only name,...]
  make     writes the hand-made inputs of the React Native host into <project>/build, from the packages of this checkout and
           the application's node_modules: codegen (the application's codegen), rn-codegen (its component specs), rn-src (the
           react-native package with all its patches). <project> is the folder of the host; it holds ref/paseo, the application,
           or a link to it. The inputs are: codegen, rn-codegen, rn-headers, lib-headers, expo-core, expo-jsi, expo-pods, expo-src,
           nitro, unistyles, keyboard, screens, app-assets. --only makes the named ones. The Expo inputs take the packages that
           coverage.json marks real or partial and that the application's node_modules has; --real replaces them with the parity list of the spike (RN_EXPO_REAL).
  compare  checks each input of <built> against <reference>: the same file names, the same link targets and the same SHA-256
           of every file, after the absolute path of <built> is read as the path of <reference>. It prints every difference
           and exits 1 when there is one.]]

local app_config = import("app_config", {rootdir = os.scriptdir(), anonymous = true})
local json = import("core.base.json")

local INPUTS = {"codegen", "rn-codegen", "rn-src", "rn-headers", "lib-headers", "expo-jsi", "expo-pods", "expo-core", "expo-src", "nitro", "unistyles", "keyboard", "screens", "app-assets"}

local AGGREGATORS = {"Package.swift", "ReactAppDependencyProvider", "ReactCodegen/ReactCodegen.podspec"}

local FOLLY_DEPENDENCIES = {{"folly", "2024.11.18.00"}, {"boost", "1.84.0"}, {"glog", "0.3.5"}, {"fmt", "12.1.0"}, {"double-conversion", "1.1.6"}, {"fast_float", "8.0.0"}}

local CXX_FLAGS = {"-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", "-DRCT_NEW_ARCH_ENABLED=1", "-std=c++20"}

local PACKAGE_VERSIONS = {
    ["react-native"] = "0.86.3",
    ["react-native-codegen"] = "0.86.3",
    ["expo-modules-core"] = "57.0.23",
    ["react-native-screens"] = "4.26.2",
    ["react-native-reanimated"] = "4.5.5",
    ["react-native-worklets"] = "0.10.4",
    ["node"] = "26.13.0",
    ["libcxx"] = "23.1.1",
    ["swift"] = "6.4.0"
}

local PROBE_REQUIRES = {
    {"libcxx", "revenant@libcxx"},
    {"swift-runtime", "revenant@swift-runtime"},
    {"react-native-codegen", "revenant@react-native-codegen"},
    {"react-native", "revenant@react-native 0.86.3"},
    {"expo-modules-core", "revenant@expo-modules-core"},
    {"react-native-screens", "revenant@react-native-screens"},
    {"react-native-reanimated", "revenant@react-native-reanimated"},
    {"react-native-worklets", "revenant@react-native-worklets"},
    {"folly", "revenant@folly 2024.11.18.00"},
    {"boost", "revenant@boost 1.84.0"},
    {"glog", "revenant@glog 0.3.5"},
    {"fmt", "revenant@fmt 12.1.0"},
    {"double-conversion", "revenant@double-conversion 1.1.6"},
    {"fast_float", "revenant@fast_float 8.0.0"}
}

function checkout()
    return path.absolute(os.projectdir())
end

function cache_root()
    return os.getenv("REVENANT_CACHE") or path.join(checkout(), ".cache")
end

function store()
    return path.join(cache_root(), "xmake-global", ".xmake", "packages")
end

function installed(name, marker)
    local found = {}
    for _, dir in ipairs(os.dirs(path.join(store(), name:sub(1, 1), name, PACKAGE_VERSIONS[name] or "*", "*"))) do
        if os.exists(path.join(dir, marker)) then
            table.insert(found, dir)
        end
    end
    table.sort(found, function (a, b) return os.mtime(a) < os.mtime(b) end)
    return found[#found]
end

function install_packages()
    local probe = path.join(cache_root(), "react-native-inputs", "probe")
    os.mkdir(probe)
    local toolchain_link = path.join(probe, "toolchain")
    if not os.isdir(toolchain_link) then
        os.ln(path.join(checkout(), "toolchain"), toolchain_link)
    end
    local lines = {
        'set_project("rninputs")',
        'set_xmakever("3.1.2")',
        'add_rules("mode.release")',
        string.format('add_repositories("revenant %s")', checkout()),
        string.format('add_addons("revenant", {sourcedir = "%s"})', path.join(checkout(), "toolchain")),
        'set_config("apple_minimum", "6.0")',
        'includes("@addon/revenant/apple-ios")'
    }
    local names = {}
    for _, item in ipairs(PROBE_REQUIRES) do
        table.insert(lines, string.format('add_requires("%s", {alias = "%s"})', item[2], item[1]))
        table.insert(names, string.format('"%s"', item[1]))
    end
    table.insert(lines, 'target("inputs")')
    table.insert(lines, '    set_kind("phony")')
    table.insert(lines, string.format("    add_packages(%s)", table.concat(names, ", ")))
    table.insert(lines, "")
    io.writefile(path.join(probe, "xmake.lua"), table.concat(lines, "\n"))
    os.vrunv(path.join(checkout(), "xmakew"), {"f", "-P", probe, "-p", "iphoneos", "-a", "armv7", "-y"})
    local found = {}
    local expected = {
        ["react-native-codegen"] = "react-native/scripts/generate-codegen-artifacts.js",
        ["react-native"] = "src/react-native/package.json",
        ["expo-modules-core"] = "package.json",
        ["react-native-screens"] = "package.json",
        ["react-native-reanimated"] = "package.json",
        ["react-native-worklets"] = "package.json",
        ["node"] = "bin/node",
        ["libcxx"] = "include/c++/v1",
        ["swift"] = "include"
    }
    for name, marker in pairs(expected) do
        found[name] = installed(name, marker)
        if not found[name] then
            raise("%s %s is not installed in %s", name, PACKAGE_VERSIONS[name], store())
        end
    end
    return found
end

function swift_header(spec)
    local dir = path.join(cache_root(), "react-native-inputs", "swift", spec.name)
    os.tryrm(dir)
    os.mkdir(dir)
    local lines = {
        string.format("set_project(%q)", "rninputs-" .. spec.name),
        'set_xmakever("3.1.2")',
        string.format('add_repositories("revenant %s")', checkout()),
        string.format('add_addons("revenant", {sourcedir = %q})', path.join(checkout(), "toolchain")),
        'set_config("apple_minimum", "6.0")',
        'includes("@addon/revenant/apple-ios")'
    }
    local requires = {}
    for _, target in ipairs(spec.targets) do
        for _, package in ipairs(target.packages) do
            if not requires[package] then
                requires[package] = true
                local requirement = package == "swift-runtime" and "revenant@swift-runtime" or "revenant@" .. package
                table.insert(lines, string.format('add_requires("%s", {alias = "%s"})', requirement, package))
            end
        end
    end
    for _, target in ipairs(spec.targets) do
        table.insert(lines, string.format("target(%q)", target.name))
        table.insert(lines, '    set_kind("static")')
        table.insert(lines, '    add_rules("@addon/revenant/apple-ios", "@addon/revenant/swift")')
        table.insert(lines, '    set_default(false)')
        table.insert(lines, string.format("    set_values(%q, %q)", "swift.module", target.module))
        for _, dependency in ipairs(target.deps or {}) do
            table.insert(lines, string.format("    add_deps(%q)", dependency))
        end
        local names, sources, flags = {}, {}, {}
        for _, package in ipairs(target.packages) do
            table.insert(names, string.format("%q", package))
        end
        for _, source in ipairs(target.sources) do
            table.insert(sources, string.format("%q", source))
        end
        for _, flag in ipairs(target.flags) do
            table.insert(flags, string.format("%q", flag))
        end
        table.insert(flags, string.format("%q", "-module-cache-path"))
        table.insert(flags, string.format("%q", path.join(dir, "build", "modulecache", target.name)))
        table.insert(lines, string.format("    add_packages(%s)", table.concat(names, ", ")))
        table.insert(lines, string.format("    add_files(%s)", table.concat(sources, ", ")))
        table.insert(lines, string.format("    add_values(%q, %s)", "swift.flags", table.concat(flags, ", ")))
        table.insert(lines, "")
    end
    io.writefile(path.join(dir, "xmake.lua"), table.concat(lines, "\n"))
    os.vrunv(path.join(checkout(), "xmakew"), {"f", "-P", dir, "-p", "iphoneos", "-a", "armv7", "-y"})
    os.vrunv(path.join(checkout(), "xmakew"), {"build", "-P", dir, "-y", "-r", spec.build})
    if not os.isfile(spec.output) then
        raise("%s: the Swift compile did not write %s", spec.name, spec.output)
    end
end

function fresh_directory(dir)
    os.tryrm(dir)
    os.mkdir(dir)
end

function context(options)
    local build = path.absolute(options.build or path.join(options.project, "build"))
    local ref = path.absolute(options.app or path.join(build, "ref", "paseo"))
    local packages = install_packages()
    return {
        build = build,
        ref = ref,
        app = path.join(ref, "packages", "app"),
        nm = path.join(ref, "node_modules"),
        packages = packages,
        react_native = options["react-native"] or path.join(packages["react-native-codegen"], "react-native")
    }
end

function make_codegen(ctx)
    local out = path.join(ctx.build, "codegen")
    fresh_directory(out)
    local node = path.join(ctx.packages["node"], "bin", "node")
    local runner = path.join(ctx.react_native, "scripts", "generate-codegen-artifacts.js")
    os.cd(ctx.ref)
    os.vrunv(node, {runner, "-p", "packages/app", "-t", "ios", "-o", out})
    os.cd(checkout())
end

function make_rn_codegen(ctx)
    local source = path.join(ctx.build, "codegen")
    local out = path.join(ctx.build, "rn-codegen")
    fresh_directory(out)
    os.cp(path.join(source, "build"), path.join(out, "build"))
    local generated = path.join(out, "build", "generated", "ios")
    for _, item in ipairs(AGGREGATORS) do
        os.tryrm(path.join(generated, item))
    end
    for _, file in ipairs(os.files(path.join(generated, "ReactCodegen", "*"))) do
        local name = path.filename(file)
        if name:find("Provider", 1, true) and (name:endswith(".h") or name:endswith(".mm")) then
            os.rm(file)
        end
    end
end

function make_rn_src(ctx)
    local link = path.join(ctx.build, "rn-src")
    os.tryrm(link)
    os.ln(path.join(ctx.packages["react-native"], "src", "react-native"), link)
end

function headers_in(root, pattern, keep_order)
    local found = {}
    for _, file in ipairs(os.files(path.join(root, pattern))) do
        table.insert(found, file)
    end
    if not keep_order then
        table.sort(found, byte_less)
    end
    return found
end

function make_lib_headers(ctx)
    local out = path.join(ctx.build, "lib-headers", "NitroModules")
    fresh_directory(out)
    local root = path.join(ctx.nm, "react-native-nitro-modules")
    for _, sub in ipairs({"cpp", "ios"}) do
        for _, pattern in ipairs({"**.h", "**.hpp"}) do
            for _, file in ipairs(headers_in(path.join(root, sub), pattern)) do
                local link = path.join(out, path.filename(file))
                if os.exists(link) then
                    raise("%s is in two folders of NitroModules", path.filename(file))
                end
                os.ln(file, link)
            end
        end
    end
end

function make_expo_jsi(ctx)
    local out = path.join(ctx.build, "expo-jsi")
    fresh_directory(out)
    local sources = path.join(ctx.nm, "expo-modules-jsi", "apple", "Sources")
    local cxx = path.join(sources, "ExpoModulesJSI-Cxx", "include")
    local rn = path.join(ctx.build, "rn-src")
    local lines = {"module jsi {", string.format('  umbrella header "%s"', path.join(rn, "ReactCommon", "jsi", "jsi", "jsi.h")),
        string.format('  header "%s"', path.join(rn, "ReactCommon", "jsi", "jsi", "instrumentation.h")), "  export *", "  module * { export * }", "}"}
    write_lines(path.join(out, "module.modulemap"), lines)
    lines = {"module ExpoModulesJSI_Cxx {", "  requires cplusplus"}
    for _, file in ipairs(headers_in(cxx, "*.h")) do
        table.insert(lines, string.format('  header "%s"', file))
    end
    table.insert(lines, "  export *")
    table.insert(lines, "}")
    write_lines(path.join(out, "cxx.modulemap"), lines)
    write_lines(path.join(out, "features.rsp"), {"-enable-upcoming-feature", "NonisolatedNonsendingByDefault", "-enable-upcoming-feature", "InferIsolatedConformances",
        "-Xcc", "-fmodule-map-file=" .. path.join(out, "cxx.modulemap"), "-Xcc", "-Xclang", "-Xcc", "-femulated-tls"})
    os.mkdir(path.join(out, "include"))
    os.ln(path.join(sources, "ExpoModulesJSI-Cxx", "include", "Public"), path.join(out, "include", "ExpoModulesJSI"))
    local libcxx = installed("libcxx", path.join("include", "c++", "v1"))
    local swift = installed("swift", path.join("include"))
    write_lines(path.join(out, "libcxx.rsp"), {"-Xcc", "-isystem", "-Xcc", path.join(libcxx, "include", "c++", "v1"),
        "-Xcc", "-I" .. path.join(swift, "include"), "-Xcc", "-fapinotes-modules", "-Xcc", "-iapinotes-modules", "-Xcc", path.join(ctx.nm, "expo-modules-jsi", "apple", "APINotes")})
end

function write_lines(file, lines)
    io.writefile(file, table.concat(lines, "\n") .. "\n")
end

local EXPO_CORE_PACKAGE = "expo-modules-core"

local EXPO_PARITY_BASE = {"expo-asset", "expo-constants", "expo", "expo-crypto", "expo-keep-awake", "expo-linking", "expo-system-ui", "expo-application", "expo-glass-effect", "expo-localization"}

function installed_in_application(ctx, package)
    return os.isdir(path.join(ctx.app, "node_modules", package)) or os.isdir(path.join(ctx.ref, "node_modules", package))
end

function covered_packages(ctx)
    local data = json.decode(io.readfile(path.join(checkout(), "frameworks", "ReactNative", "src", "coverage.json")))
    local packages = {"expo"}
    for _, row in ipairs(data.rows) do
        if row.group == "sdk" and row.native and (row.status == "real" or row.status == "partial") and row.id:startswith("expo-") and row.id ~= EXPO_CORE_PACKAGE and installed_in_application(ctx, row.id) then
            table.insert(packages, row.id)
        end
    end
    return packages
end

function expo_packages(ctx)
    if ctx.options.real then
        local packages = table.clone(EXPO_PARITY_BASE)
        for _, package in ipairs(string.split(ctx.options.real, ",", {plain = true})) do
            if package ~= "" then
                table.insert(packages, package)
            end
        end
        return packages
    end
    return covered_packages(ctx)
end

function expo_dir(ctx, package)
    for _, base in ipairs({path.join(ctx.app, "node_modules"), path.join(ctx.ref, "node_modules")}) do
        if os.isdir(path.join(base, package)) then
            return path.join(base, package)
        end
    end
    return path.join(ctx.ref, "node_modules", package)
end

function pod_name(ctx, package)
    local PODS = {["expo-constants"] = "EXConstants"}
    if PODS[package] then
        return PODS[package]
    end
    for _, spec in ipairs(os.files(path.join(expo_dir(ctx, package), "ios", "*.podspec"))) do
        local name = io.readfile(spec):match("s%.name%s*=%s*['\"]([%w_]+)['\"]")
        if name then
            return name
        end
    end
end

function make_expo_pods(ctx)
    local out = path.join(ctx.build, "expo-pods")
    fresh_directory(out)
    for _, package in ipairs(expo_packages(ctx)) do
        local pod = pod_name(ctx, package)
        if pod then
            local dir = path.join(out, pod)
            os.mkdir(dir)
            for _, header in ipairs(headers_in(path.join(expo_dir(ctx, package), "ios"), "**.h")) do
                local link = path.join(dir, path.filename(header))
                if not os.exists(link) then
                    os.ln(header, link)
                end
            end
        end
    end
end

function rn_root(ctx)
    return path.join(ctx.packages["react-native"], "src", "react-native")
end

function newest_include(name, version)
    local newest, stamp = nil, 0
    for _, dir in ipairs(os.dirs(path.join(store(), name:sub(1, 1), name, version, "*", "include"))) do
        if os.mtime(dir) >= stamp then
            newest, stamp = dir, os.mtime(dir)
        end
    end
    return newest
end

function renderer_platform_dirs(ctx)
    local found = {}
    local renderer = path.join(rn_root(ctx), "ReactCommon", "react", "renderer")
    for _, platform in ipairs(os.dirs(path.join(renderer, "**", "platform"))) do
        if os.isdir(path.join(platform, "ios")) then
            table.insert(found, path.join(platform, "ios"))
        elseif os.isdir(path.join(platform, "cxx")) then
            table.insert(found, path.join(platform, "cxx"))
        end
    end
    return found
end

function rn_spec_dirs(ctx)
    local rn = rn_root(ctx)
    return {
        path.join(rn, "React", "FBReactNativeSpec"),
        path.join(ctx.build, "codegen", "build", "generated", "ios", "ReactCodegen"),
        path.join(rn, "React", "CoreModules"),
        path.join(rn, "ReactCommon", "react", "nativemodule", "core"),
        path.join(rn, "ReactCommon", "react", "nativemodule", "core", "platform", "ios"),
        path.join(rn, "React", "Base"),
        path.join(rn, "ReactCommon", "react", "runtime", "platform", "ios"),
        path.join(rn, "ReactCommon", "jsitooling"),
        path.join(rn, "ReactCommon", "react", "runtime")
    }
end

function cxx_response(ctx, leading, includes)
    local lines = {}
    local function xcc(value)
        table.insert(lines, "-Xcc")
        table.insert(lines, value)
    end
    for _, item in ipairs(leading) do
        xcc(item)
    end
    for _, dir in ipairs(includes) do
        xcc("-I" .. dir)
    end
    for _, dependency in ipairs(FOLLY_DEPENDENCIES) do
        local dir = newest_include(dependency[1], dependency[2])
        if dir then
            xcc("-I" .. dir)
        end
    end
    xcc("-I" .. path.join(ctx.build, "rn-headers"))
    for _, dir in ipairs(renderer_platform_dirs(ctx)) do
        xcc("-I" .. dir)
    end
    for _, dir in ipairs(rn_spec_dirs(ctx)) do
        xcc("-I" .. dir)
    end
    for _, flag in ipairs(CXX_FLAGS) do
        xcc(flag)
    end
    xcc("-I" .. path.join(rn_root(ctx), "ReactCommon", "yoga"))
    return lines
end

function podspec_public_headers(file)
    local block = io.readfile(file):match("public_header_files%s*=%s*%[(.-)%]") or ""
    local found = {}
    for header in block:gmatch('"([^"]+)"') do
        table.insert(found, header)
    end
    return found
end

function nitro_root(ctx)
    return path.join(ctx.nm, "react-native-nitro-modules")
end

function nitro_includes(ctx)
    local root = nitro_root(ctx)
    local cpp = path.join(root, "cpp")
    local ios = path.join(root, "ios")
    local rc = path.join(rn_root(ctx), "ReactCommon")
    local jsi = path.join(ctx.nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
    local dirs = {path.join(ctx.build, "lib-headers"), cpp}
    for _, sub in ipairs({"core", "jsi", "utils", "registry", "templates", "threading", "views", "prototype", "platform"}) do
        table.insert(dirs, path.join(cpp, sub))
    end
    for _, item in ipairs({ios, path.join(ios, "core"), path.join(ios, "utils"), rc, path.join(rc, "jsi"), path.join(rc, "runtimeexecutor"), path.join(rc, "callinvoker"), jsi, path.join(jsi, "Public")}) do
        table.insert(dirs, item)
    end
    return dirs
end

function expo_core_react_map(ctx)
    return path.join(ctx.build, "expo-core", "react.modulemap")
end

function expo_jsi_map(ctx)
    return path.join(ctx.build, "expo-jsi", "module.modulemap")
end

function make_nitro(ctx)
    local out = path.join(ctx.build, "nitro")
    fresh_directory(out)
    local root = nitro_root(ctx)
    local lines = {"module NitroModules {", string.format('  header "%s"', path.join(out, "Foundation.h"))}
    for _, header in ipairs(podspec_public_headers(path.join(root, "NitroModules.podspec"))) do
        table.insert(lines, string.format('  header "%s"', path.join(root, header)))
    end
    table.insert(lines, "  export *")
    table.insert(lines, "}")
    write_lines(path.join(out, "module.modulemap"), lines)
    write_lines(path.join(out, "Foundation.h"), {"#import <Foundation/Foundation.h>"})
    io.writefile(path.join(out, "imports.rsp"), "")
    write_lines(path.join(out, "flags.rsp"), cxx_response(ctx, {"-fmodule-map-file=" .. expo_jsi_map(ctx), "-fmodule-map-file=" .. path.join(out, "module.modulemap")}, nitro_includes(ctx)))
end

function make_unistyles(ctx)
    local out = path.join(ctx.build, "unistyles")
    fresh_directory(out)
    local root = path.join(ctx.nm, "react-native-unistyles")
    local ugen = path.join(root, "nitrogen", "generated", "ios")
    local ncpp = path.join(nitro_root(ctx), "cpp")
    local nios = path.join(nitro_root(ctx), "ios")
    local rc = path.join(rn_root(ctx), "ReactCommon")
    local jsi = path.join(ctx.nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
    local stub = path.join(out, "stub")
    os.mkdir(stub)
    io.writefile(path.join(stub, "Unistyles-Swift.h"), "")
    write_lines(path.join(out, "Foundation.h"), {"#import <Foundation/Foundation.h>"})
    write_lines(path.join(out, "module.modulemap"), {"module Unistyles {",
        string.format('  header "%s"', path.join(out, "Foundation.h")),
        string.format('  header "%s"', path.join(root, "ios", "Unistyles.h")),
        string.format('  header "%s"', path.join(ugen, "Unistyles-Swift-Cxx-Umbrella.hpp")),
        "  export *", "}"})
    local includes = {stub, ugen, path.join(ugen, "c++"), path.join(ugen, "..", "shared", "c++"), path.join(root, "cxx"), path.join(ctx.build, "lib-headers"),
        ncpp, path.join(ncpp, "core"), path.join(ncpp, "jsi"), path.join(ncpp, "utils"), path.join(ncpp, "registry"), path.join(ncpp, "templates"),
        path.join(ncpp, "threading"), path.join(ncpp, "views"), path.join(ncpp, "prototype"), path.join(ncpp, "platform"),
        path.join(root, "ios"), path.join(root, "ios", "core"), path.join(root, "ios", "utils"),
        nios, path.join(nios, "core"), path.join(nios, "utils"), path.join(nios, "platform"), path.join(nios, "threading"),
        rc, path.join(rc, "jsi"), path.join(rc, "runtimeexecutor"), path.join(rc, "callinvoker"), jsi, path.join(jsi, "Public")}
    write_lines(path.join(out, "flags.rsp"), cxx_response(ctx, {"-fmodule-map-file=" .. path.join(ctx.build, "nitro", "module.modulemap"), "-fmodule-map-file=" .. expo_core_react_map(ctx),
        "-I" .. path.join(ctx.build, "rn-headers"), "-fmodule-map-file=" .. expo_jsi_map(ctx), "-fmodule-map-file=" .. path.join(out, "module.modulemap")}, includes))
    local header = path.join(out, "swift-header", "Unistyles-Swift.h")
    local nitro = path.join(ctx.build, "nitro")
    local libcxx = "@" .. path.join(ctx.build, "expo-jsi", "libcxx.rsp")
    local swift_sources = os.files(path.join(root, "ios", "**.swift"))
    for _, file in ipairs(os.files(path.join(ugen, "swift", "**.swift"))) do
        table.insert(swift_sources, file)
    end
    swift_header({
        name = "unistyles",
        build = "unistyles",
        output = header,
        targets = {
            {
                name = "nitro",
                module = "NitroModules",
                packages = SWIFT_PACKAGES,
                sources = os.files(path.join(nitro_root(ctx), "ios", "**.swift")),
                flags = {"-swift-version", "5", libcxx, "@" .. path.join(nitro, "flags.rsp"), "@" .. path.join(nitro, "imports.rsp"), "-import-underlying-module"}
            },
            {
                name = "unistyles",
                module = "Unistyles",
                deps = {"nitro"},
                packages = SWIFT_PACKAGES,
                sources = swift_sources,
                flags = {"-swift-version", "5", libcxx, "@" .. path.join(out, "flags.rsp"), "-import-underlying-module", "-emit-clang-header-path", header}
            }
        }
    })
end

function by_depth(list)
    local function depth(file)
        local _, slashes = file:gsub("/", "")
        return slashes
    end
    table.sort(list, function (a, b)
        if depth(a) ~= depth(b) then
            return depth(a) < depth(b)
        end
        return byte_less(a, b)
    end)
    return list
end

function make_keyboard(ctx)
    local out = path.join(ctx.build, "keyboard")
    fresh_directory(out)
    local kc = path.join(ctx.app, "node_modules", "react-native-keyboard-controller", "ios")
    local lines = {}
    for _, header in ipairs(by_depth(headers_in(kc, "**.h", true))) do
        table.insert(lines, string.format('#import "%s"', header))
    end
    write_lines(path.join(out, "Bridge.h"), lines)
    local prefix = {"#ifdef __OBJC__", "#import <Foundation/Foundation.h>", "#import <UIKit/UIKit.h>"}
    write_lines(path.join(out, "prefix.pch"), table.join(prefix, {"#endif"}))
    write_lines(path.join(out, "prefix.h"), table.join(prefix, {"// the React umbrella import that clang modules would supply (RCTDirectEventBlock for the Swift-generated header)",
        "#import <React/RCTComponent.h>", "#import <React/RCTViewManager.h>", "#endif"}))
    local dirs = {kc, path.join(ctx.build, "rn-headers"), path.join(ctx.ref, "node_modules", "react-native", "ReactCommon", "yoga")}
    for _, dir in ipairs(os.dirs(path.join(kc, "*"))) do
        table.insert(dirs, dir)
    end
    local flags = {"-Xcc", "-fmodule-map-file=" .. expo_core_react_map(ctx)}
    for _, dir in ipairs(dirs) do
        table.insert(flags, "-Xcc")
        table.insert(flags, "-I" .. dir)
    end
    write_lines(path.join(out, "flags.rsp"), flags)
    local header = path.join(out, "react_native_keyboard_controller-Swift.h")
    swift_header({
        name = "keyboard",
        build = "keyboard",
        output = header,
        targets = {
            {
                name = "keyboard",
                module = "react_native_keyboard_controller",
                packages = {"swift-runtime", "libcxx"},
                sources = os.files(path.join(kc, "**.swift")),
                flags = {"-swift-version", "5", "-cxx-interoperability-mode=off", "@" .. path.join(out, "flags.rsp"), "-import-objc-header", path.join(out, "Bridge.h"), "-emit-clang-header-min-access", "public", "-emit-objc-header-path", header}
            }
        }
    })
    local link = path.join(ctx.build, "rn-headers", "react_native_keyboard_controller", "react_native_keyboard_controller-Swift.h")
    os.mkdir(path.directory(link))
    os.tryrm(link)
    os.ln(header, link)
end

function make_screens(ctx)
    local out = path.join(ctx.build, "screens")
    fresh_directory(out)
    local screens = path.join(ctx.app, "node_modules", "react-native-screens", "ios")
    local lines = {"#import <React/RCTViewComponentView.h>", "#import <React/RCTBridgeModule.h>"}
    for _, file in ipairs(headers_in(path.join(screens, "gamma"), "**.h", true)) do
        local text = io.readfile(file)
        if not text:find("<react/", 1, true) and not text:find("react/renderer", 1, true) then
            table.insert(lines, string.format('#import "%s"', file))
        end
    end
    write_lines(path.join(out, "Bridge.h"), lines)
    local rn = path.join(ctx.ref, "node_modules", "react-native")
    write_lines(path.join(out, "flags.rsp"), {"-Xcc", "-fmodule-map-file=" .. expo_core_react_map(ctx), "-Xcc", "-I" .. path.join(ctx.build, "rn-headers"),
        "-Xcc", "-I" .. path.join(rn, "ReactCommon", "yoga"), "-Xcc", "-I" .. path.join(rn, "React")})
end

local APP_ICONS = {{name = "Icon.png", size = 57}, {name = "Icon@2x.png", size = 114}}

local APP_SPLASHES = {{name = "Default.png", scale = 1, height = 480, width = 320}, {name = "Default@2x.png", scale = 2, height = 960, width = 640}}

local APP_HOST = "RNHost"

local EXPO_SPLASH_WIDTH = 200

local EXPO_SPLASH_BACKGROUND = "#ffffff"

function xml_text(text)
    return plain_replace(plain_replace(plain_replace(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
end

function splash_options(config)
    for _, plugin in ipairs(config.plugins or {}) do
        if type(plugin) == "table" and plugin[1] == "expo-splash-screen" then
            local options = plugin[2] or {}
            if not options.image then
                raise("expo-splash-screen names no image in the application configuration")
            end
            return options
        end
    end
    raise("the application configuration has no expo-splash-screen plugin, so the launch images cannot be made")
end

function pixel_width(file)
    return tonumber(os.iorunv("sips", {"-g", "pixelWidth", file}):match("pixelWidth:%s*(%d+)"))
end

function make_app_assets(ctx)
    local out = path.join(ctx.build, "app-assets")
    fresh_directory(out)
    local config = json.decode(app_config.public_json(ctx.app))
    if not config.name or not config.icon then
        raise("the application configuration names no name or no icon")
    end
    local options = splash_options(config)
    if (options.resizeMode or "contain") ~= "contain" then
        raise("expo-splash-screen resizes its image with %s, and only contain is made", options.resizeMode)
    end
    local icon = path.join(ctx.app, config.icon)
    local names = {}
    for _, item in ipairs(APP_ICONS) do
        local size = string.format("%d", item.size)
        os.vrunv("sips", {"-s", "format", "png", "-z", size, size, icon, "--out", path.join(out, item.name)})
        table.insert(names, item.name)
    end
    local logo = path.join(ctx.app, options.image)
    local color = (options.backgroundColor or EXPO_SPLASH_BACKGROUND):gsub("^#", ""):upper()
    for _, item in ipairs(APP_SPLASHES) do
        local width = string.format("%d", (options.imageWidth or EXPO_SPLASH_WIDTH) * item.scale)
        local source, scaled = logo, nil
        if pixel_width(logo) ~= tonumber(width) then
            scaled = os.tmpfile() .. ".png"
            os.vrunv("sips", {"-s", "format", "png", "-Z", width, logo, "--out", scaled})
            source = scaled
        end
        os.vrunv("sips", {"-s", "format", "png", "-p", string.format("%d", item.height), string.format("%d", item.width), "--padColor", color, source, "--out", path.join(out, item.name)})
        if scaled then
            os.rm(scaled)
        end
    end
    local plist = os.tmpfile() .. ".json"
    io.writefile(plist, json.encode({CFBundleDisplayName = config.name, CFBundleIconFiles = names, CFBundleName = APP_HOST, CFBundlePackageType = "APPL",
        MinimumOSVersion = "6.0", UIDeviceFamily = {1}, UIPrerenderedIcon = true, UIRequiredDeviceCapabilities = {"armv7"}}))
    os.vrunv("plutil", {"-convert", "xml1", "-o", path.join(out, "Info.plist"), plist})
    os.rm(plist)
    local icons = {}
    for _, name in ipairs(names) do
        table.insert(icons, "<string>" .. name .. "</string>")
    end
    write_lines(path.join(out, "Info.fragment.plist"), {'<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        '<plist version="1.0"><dict>',
        "<key>CFBundleDisplayName</key><string>" .. xml_text(config.name) .. "</string>",
        "<key>CFBundleIconFiles</key><array>" .. table.concat(icons) .. "</array>",
        "<key>UIPrerenderedIcon</key><true/>",
        "</dict></plist>"})
end

local EXPO_SKIP_FILES = {}

local EXPO_SKIP_MODULES = {}

local EXPO_ONLY = {expo = "Fetch"}

local EXPO_REWRITE = {
    ["FileSystemModule.swift"] = {package = "expo-file-system", replace = {{"@available(iOS 14, tvOS 14, *)\n", ""}}},
    ["FileSystemDownload.swift"] = {package = "expo-file-system", replace = {{"@available(iOS 14, tvOS 14, *)\n", ""}}},
    ["FileSystemFileHandle.swift"] = {package = "expo-file-system", replace = {{"@available(iOS 14, tvOS 14, *)\n", ""}}}
}

local STUB_OWNERS = {
    StubFileSystemModule = "expo-file-system", StubHapticsModule = "expo-haptics",
    StubAudioModule = "expo-audio", StubSharingModule = "expo-sharing", StubDocumentPickerModule = "expo-document-picker",
    StubImagePickerModule = "expo-image-picker", StubCameraModule = "expo-camera", StubSQLiteModule = "expo-sqlite", StubImageManipulatorModule = "expo-image-manipulator"
}

local STUB_MODULES = {"StubAudioModule", "StubDocumentPickerModule", "StubHapticsModule", "StubImagePickerModule", "StubSharingModule", "StubFileSystemModule", "StubTwoWayAudioModule", "StubHardwareKeyboardModule", "StubBackgroundNotificationTasksModule", "StubBadgeModule", "StubCameraModule", "StubImageManipulatorModule", "StubNotificationCategoriesModule", "StubNotificationPermissionsModule", "StubNotificationPresenterModule", "StubNotificationSchedulerModule", "StubNotificationsEmitterModule", "StubNotificationsHandlerModule", "StubPushTokenManagerModule", "StubSQLiteModule", "StubServerRegistrationModule"}

function expo_skipped(file)
    for _, name in ipairs(EXPO_SKIP_FILES) do
        if file:find(name, 1, true) then
            return true
        end
    end
    return false
end

function expo_swift_files(ctx, package)
    return headers_in(path.join(expo_dir(ctx, package), "ios", EXPO_ONLY[package] or ""), "**.swift")
end

function expo_real(ctx)
    local real = {}
    for _, package in ipairs(expo_packages(ctx)) do
        real[package] = true
    end
    return real
end

function make_expo_src(ctx)
    local out = path.join(ctx.build, "expo-src")
    fresh_directory(out)
    local seen = {}
    for _, package in ipairs(expo_packages(ctx)) do
        for _, file in ipairs(expo_swift_files(ctx, package)) do
            local name = path.filename(file)
            if expo_skipped(file) then
            elseif EXPO_REWRITE[name] and EXPO_REWRITE[name].package == package then
                seen[name] = true
                local text = io.readfile(file)
                for _, change in ipairs(EXPO_REWRITE[name].replace) do
                    text = plain_replace(text, change[1], change[2])
                end
                io.writefile(path.join(out, package .. "-" .. name), text)
            elseif seen[name] then
                io.writefile(path.join(out, package .. "-" .. name), io.readfile(file))
            else
                seen[name] = true
            end
        end
    end
end

function expo_classes(ctx)
    local classes = {}
    local real = expo_real(ctx)
    for _, package in ipairs(expo_packages(ctx)) do
        local config = io.readfile(path.join(expo_dir(ctx, package), "expo-module.config.json"))
        local apple = config:match('"apple"%s*:%s*{.-"modules"%s*:%s*%[(.-)%]')
        for name in (apple or ""):gmatch('"([^"]+)"') do
            if not EXPO_SKIP_MODULES[name] then
                table.insert(classes, string.format("      (module: %s.self, name: nil),", name))
            end
        end
    end
    for _, name in ipairs(STUB_MODULES) do
        local owner = STUB_OWNERS[name]
        if not (owner and real[owner]) then
            table.insert(classes, string.format("      (module: %s.self, name: nil),", name))
        end
    end
    return classes
end

SWIFT_PACKAGES = {"swift-runtime", "libcxx", "combine", "cryptokit", "swiftui"}

function byte_less(a, b)
    for index = 1, math.min(#a, #b) do
        local x, y = a:byte(index), b:byte(index)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

function make_expo_core_headers(ctx, out, ios, cpp)
    local include = path.join(out, "include", "ExpoModulesCore")
    os.mkdir(include)
    local flat = {}
    for _, root in ipairs({ios, cpp}) do
        for _, header in ipairs(headers_in(root, "**.h")) do
            local base = path.filename(header)
            if flat[base] then
                raise("%s is in two folders of ExpoModulesCore", base)
            end
            flat[base] = header
            os.ln(header, path.join(include, base))
        end
    end
    local public = {}
    for _, header in ipairs(headers_in(ios, "**.h")) do
        local rel = path.relative(header, ios)
        if not rel:find("+Private.h", 1, true) and not rel:startswith("Worklets/") and not rel:startswith("WorkletsAdapter/") then
            table.insert(public, path.filename(header))
        end
    end
    table.sort(public, byte_less)
    local ordered = {"ExpoModulesCore.h", "Foundation.h"}
    for _, base in ipairs(public) do
        if base ~= "ExpoModulesCore.h" then
            table.insert(ordered, base)
        end
    end
    io.writefile(path.join(out, "Foundation.h"), "#import <Foundation/Foundation.h>\n")
    local map = {"module ExpoModulesCore {"}
    for _, base in ipairs(ordered) do
        local target = base == "Foundation.h" and path.join(out, "Foundation.h") or path.join(include, base)
        table.insert(map, string.format('  header "%s"', target))
    end
    table.insert(map, "  export *")
    table.insert(map, "}")
    write_lines(path.join(out, "module.modulemap"), map)
    local react = {"module React {"}
    local rn_headers = path.join(ctx.build, "rn-headers", "React")
    for _, base in ipairs(io.readfile(path.join(checkout(), "frameworks", "ReactNative", "tools", "data", "expo-core-react-headers.txt")):split("\n", {plain = true})) do
        if base ~= "" then
            table.insert(react, string.format('  header "%s"', path.join(rn_headers, base)))
        end
    end
    table.insert(react, "  export *")
    table.insert(react, "}")
    write_lines(path.join(out, "react.modulemap"), react)
end

function make_expo_core(ctx)
    local out = path.join(ctx.build, "expo-core")
    fresh_directory(out)
    local nm = ctx.nm
    local bridge_lines = {}
    for _, package in ipairs(expo_packages(ctx)) do
        for _, header in ipairs(headers_in(path.join(expo_dir(ctx, package), "ios", EXPO_ONLY[package] or ""), "**.h")) do
            if os.isfile((header:gsub("%.h$", ".m"))) or os.isfile((header:gsub("%.h$", ".mm"))) then
                table.insert(bridge_lines, string.format('#import "%s"', header))
            end
        end
    end
    local bridging = path.join(out, "bridging.h")
    io.writefile(bridging, "#import <Foundation/Foundation.h>\n" .. table.concat(bridge_lines, "\n") .. "\n")
    local macros = path.join(nm, "@expo", "expo-modules-macros-plugin", "apple", "ExpoModulesMacros-tool")
    io.writefile(path.join(out, "implicit.rsp"), "-Xfrontend\n-import-module\n-Xfrontend\nFoundation\n-Xfrontend\n-import-module\n-Xfrontend\nUIKit\n-Xfrontend\n-import-module\n-Xfrontend\nCoreText\n-Xcc\n-I" .. path.join(ctx.build, "expo-pods") .. "\n-import-objc-header\n" .. bridging .. "\n-load-plugin-executable\n" .. macros .. "#ExpoModulesMacros\n")
    local provider = {"import ExpoModulesCore", "", "@objc(ExpoModulesProvider)", "public final class ExpoModulesProvider: ModulesProvider {",
        "  public override func getModuleClasses() -> [ExpoModuleTupleType] {", "    return [", table.concat(expo_classes(ctx), "\n"), "    ]", "  }", "",
        "  public override func getAppDelegateSubscribers() -> [ExpoAppDelegateSubscriber.Type] {", "    return []", "  }", "",
        "  public override func getReactDelegateHandlers() -> [ExpoReactDelegateHandlerTupleType] {", "    return []", "  }", "",
        "  public override func getAppCodeSignEntitlements() -> AppCodeSignEntitlements {", '    return AppCodeSignEntitlements.from(json: "{}")', "  }", "}"}
    write_lines(path.join(out, "ExpoModulesProvider.swift"), provider)
    local core = path.join(nm, "expo-modules-core", "ios")
    local rn = rn_root(ctx)
    local rc = path.join(rn, "ReactCommon")
    local jsi = path.join(nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
    local includes = {path.join(out, "include"), core, rc, path.join(rc, "jsi"), path.join(rc, "runtimeexecutor"), path.join(rc, "callinvoker"), jsi, path.join(jsi, "Public")}
    write_lines(path.join(out, "flags.rsp"), cxx_response(ctx, {"-fmodule-map-file=" .. expo_jsi_map(ctx), "-fmodule-map-file=" .. path.join(out, "module.modulemap"), "-fmodule-map-file=" .. path.join(out, "react.modulemap")}, includes))
    make_expo_core_headers(ctx, out, core, path.join(nm, "expo-modules-core", "common", "cpp"))
    local header = path.join(out, "swift-header", "ExpoModulesCore", "ExpoModulesCore-Swift.h")
    local sources = {}
    for _, file in ipairs(os.files(path.join(core, "**.swift"))) do
        local rel = path.relative(file, core)
        if not (rel:startswith("Worklets/") or rel:startswith("WorkletsAdapter/") or rel:startswith("WorkletsTests/")) then
            table.insert(sources, file)
        end
    end
    local jsi_out = path.join(ctx.build, "expo-jsi")
    local jsi_sources = {}
    for _, file in ipairs(os.files(path.join(nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI", "**.swift"))) do
        table.insert(jsi_sources, file)
    end
    local jsi_rn = path.join(ctx.build, "rn-src", "ReactCommon")
    local jsi_cxx = path.join(nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
    local jsi_includes = {jsi_rn, path.join(jsi_rn, "jsi"), path.join(jsi_rn, "runtimeexecutor"), path.join(jsi_rn, "callinvoker"),
        path.join(jsi_rn, "react", "renderer", "debug"), path.join(jsi_rn, "react", "timing"), path.join(jsi_rn, "react", "debug"),
        path.join(jsi_rn, "react", "performance", "timeline"), jsi_cxx, path.join(jsi_cxx, "Public")}
    local jsi_flags = {"-swift-version", "6", "-cxx-interoperability-mode=default", "@" .. path.join(jsi_out, "features.rsp"),
        "-Xcc", "-fmodule-map-file=" .. expo_jsi_map(ctx)}
    for _, dir in ipairs(jsi_includes) do
        table.insert(jsi_flags, "-Xcc")
        table.insert(jsi_flags, "-I" .. dir)
    end
    table.insert(jsi_flags, "@" .. path.join(jsi_out, "libcxx.rsp"))
    swift_header({
        name = "expo-core",
        build = "ExpoModulesCore",
        output = header,
        targets = {
            {
                name = "ExpoModulesJSI",
                module = "ExpoModulesJSI",
                packages = {"swift-runtime", "libcxx"},
                sources = jsi_sources,
                flags = jsi_flags
            },
            {
                name = "ExpoModulesCore",
                module = "ExpoModulesCore",
                deps = {"ExpoModulesJSI"},
                packages = SWIFT_PACKAGES,
                sources = sources,
                flags = {"-swift-version", "6", "@" .. path.join(jsi_out, "features.rsp"), "@" .. path.join(jsi_out, "libcxx.rsp"), "@" .. path.join(out, "flags.rsp"),
                    "-import-underlying-module", "-emit-objc-header", "-emit-objc-header-path", header}
            }
        }
    })
end

function rn_glob(root, pattern, excludes)
    local found = {}
    for _, file in ipairs(os.files(path.join(root, pattern))) do
        local rel = path.relative(file, root)
        local skip = false
        for _, excluded in ipairs(excludes or {}) do
            if rel:startswith(excluded) then
                skip = true
            end
        end
        if not skip then
            table.insert(found, rel)
        end
    end
    table.sort(found, byte_less)
    return found
end

function make_rn_headers(ctx)
    local out = path.join(ctx.build, "rn-headers")
    fresh_directory(out)
    local src = path.join(ctx.build, "rn-src")
    local app = path.join(ctx.ref, "node_modules", "react-native")
    local links, order = {}, {}
    local function put(dest, target)
        if not links[dest] then
            links[dest] = target
            table.insert(order, dest)
        end
    end
    local function place(rels, root, where, sub, sub_root)
        for _, rel in ipairs(rels) do
            local base = path.filename(rel)
            if where.top then
                put(base, path.join(root, rel))
            end
            if where.react then
                put("React/" .. base, path.join(root, rel))
            end
            if sub then
                put(sub .. "/" .. base, path.join(sub_root or root, rel))
            end
        end
    end
    local both = {top = true, react = true}
    local react_core = rn_glob(src, "React/**.h", {"React/Fabric/", "React/FBReactNativeSpec/", "React/Runtime/", "React/Tests/"})
    for _, pattern in ipairs({"Libraries/ActionSheetIOS/*.h", "Libraries/NativeAnimation/Drivers/*.h", "Libraries/NativeAnimation/Nodes/*.h", "Libraries/NativeAnimation/*.h", "Libraries/Blob/RCTBlobManager.h", "Libraries/Blob/RCTFileReaderModule.h", "Libraries/Image/*.h", "Libraries/LinkingIOS/*.h", "Libraries/Network/*.h", "Libraries/PushNotificationIOS/*.h", "Libraries/Settings/*.h", "Libraries/Text/**.h", "Libraries/Vibration/*.h", "Libraries/WebSocket/*.h"}) do
        for _, rel in ipairs(rn_glob(src, pattern)) do
            table.insert(react_core, rel)
        end
    end
    place(react_core, src, both)
    place(rn_glob(src, "React/FBReactNativeSpec/**.h"), src, both)
    place(rn_glob(src, "React/Runtime/*.h"), src, both)
    place(rn_glob(src, "Libraries/AppDelegate/*.h"), src, both, "React-RCTAppDelegate", app)
    place(rn_glob(src, "Libraries/TypeSafety/*.h"), src, both, "RCTTypeSafety")
    place(rn_glob(src, "Libraries/Required/*.h"), src, both, "RCTRequired")
    place(rn_glob(src, "Libraries/Blob/*.h"), src, both)
    place(rn_glob(src, "Libraries/Wrapper/**.h"), src, both)
    place(rn_glob(src, "Libraries/FBLazyVector/**/*.h"), src, both)
    place(rn_glob(src, "React/Fabric/**.h"), src, {react = true})
    place(rn_glob(src, "ReactApple/RCTSwiftUIWrapper/*.h"), src, {react = true}, "RCTSwiftUIWrapper")
    place(rn_glob(src, "ReactApple/RCTAnimatedModuleProvider/*.h"), src, {react = true})
    place(rn_glob(src, "ReactApple/Libraries/RCTFoundation/RCTDeprecation/Exported/*.h"), src, {react = true}, "RCTDeprecation")
    for _, pattern in ipairs({"react/nativemodule/core/ReactCommon/**.h", "callinvoker/ReactCommon/**.h", "runtimeexecutor/ReactCommon/**.h", "runtimeexecutor/platform/ios/ReactCommon/**.h"}) do
        place(rn_glob(path.join(src, "ReactCommon"), pattern), path.join(src, "ReactCommon"), {}, "ReactCommon")
    end
    put("FBLazyVector", path.join(src, "Libraries", "FBLazyVector", "FBLazyVector"))
    for _, dest in ipairs(order) do
        local link = path.join(out, dest)
        os.mkdir(path.directory(link))
        os.ln(links[dest], link)
    end
    for _, dir in ipairs({"reactperflogger", "react_native_keyboard_controller"}) do
        os.mkdir(path.join(out, dir))
    end
end

local MAKERS = {
    codegen = make_codegen,
    ["rn-headers"] = make_rn_headers,
    ["expo-src"] = make_expo_src,
    ["expo-core"] = make_expo_core,
    ["rn-codegen"] = make_rn_codegen,
    ["rn-src"] = make_rn_src,
    ["lib-headers"] = make_lib_headers,
    ["expo-jsi"] = make_expo_jsi,
    ["expo-pods"] = make_expo_pods,
    nitro = make_nitro,
    unistyles = make_unistyles,
    keyboard = make_keyboard,
    screens = make_screens,
    ["app-assets"] = make_app_assets
}

function selected(names)
    local chosen = {}
    if not names or names == "" then
        for _, name in ipairs(INPUTS) do
            chosen[name] = true
        end
        return chosen
    end
    for _, name in ipairs(string.split(names, ",", {plain = true})) do
        if not table.contains(INPUTS, name) then
            raise("%s is not an input of the React Native host", name)
        end
        chosen[name] = true
    end
    return chosen
end

function make(options)
    local ctx = context(options)
    ctx.options = options
    local chosen = selected(options.only)
    for _, name in ipairs(INPUTS) do
        if chosen[name] then
            if not MAKERS[name] then
                raise("the input %s is not generated yet", name)
            end
            print("make " .. name)
            MAKERS[name](ctx)
        end
    end
    print("made into " .. ctx.build)
end

function plain_replace(text, from, to)
    local parts, position = {}, 1
    while true do
        local first, last = text:find(from, position, true)
        if not first then
            break
        end
        table.insert(parts, text:sub(position, first - 1))
        table.insert(parts, to)
        position = last + 1
    end
    table.insert(parts, text:sub(position))
    return table.concat(parts)
end

function link_of(file)
    return os.iorunv("readlink", {file}):trim()
end

function sha256(file)
    return os.iorunv("shasum", {"-a", "256", file}):split(" ", {plain = true})[1]
end

function normalize(text, pairs_list)
    for _, pair in ipairs(pairs_list) do
        text = plain_replace(text, pair[1], pair[2])
    end
    return text
end

function digest(file, pairs_list)
    local data = io.readfile(file)
    local normalized = normalize(data, pairs_list)
    if normalized == data then
        return sha256(file)
    end
    local rewritten = os.tmpfile()
    io.writefile(rewritten, normalized)
    local result = sha256(rewritten)
    os.rm(rewritten)
    return result
end

function entries(root)
    local found = {}
    for kind, flag in pairs({file = "f", dir = "d", link = "l"}) do
        for _, item in ipairs(os.iorunv("find", {root, "-mindepth", "1", "-type", flag}):split("\n", {plain = true})) do
            if item ~= "" then
                found[path.relative(item, root)] = {kind = kind, file = item}
            end
        end
    end
    return found
end

function compare(reference, built, options)
    reference = path.absolute(reference)
    built = path.absolute(built)
    local pairs_list = {{built, reference}}
    for _, text in ipairs(options.rewrites or {}) do
        local from, to = text:match("^(.-)=(.*)$")
        if not from then
            raise("--rewrite takes BUILT=REFERENCE, not %s", text)
        end
        table.insert(pairs_list, {from, to})
    end
    local chosen = selected(options.only)
    local differences = 0
    for _, name in ipairs(INPUTS) do
        if chosen[name] then
            local left = path.join(reference, name)
            local right = path.join(built, name)
            if not os.exists(left) and not os.exists(right) then
                print(name .. ": absent in both")
            elseif os.islink(left) or os.islink(right) then
                if os.islink(left) and os.islink(right) and normalize(link_of(right), pairs_list) == link_of(left) then
                    print(string.format("%s: same link to %s", name, link_of(left)))
                else
                    differences = differences + 1
                    print(string.format("%s: link differs: %s vs %s", name, os.islink(left) and link_of(left) or "not a link", os.islink(right) and link_of(right) or "not a link"))
                end
            else
                local same = true
                local a = os.exists(left) and entries(left) or {}
                local b = os.exists(right) and entries(right) or {}
                local keys = {}
                for key in pairs(a) do keys[key] = true end
                for key in pairs(b) do keys[key] = true end
                local sorted = {}
                for key in pairs(keys) do table.insert(sorted, key) end
                table.sort(sorted, byte_less)
                for _, key in ipairs(sorted) do
                    local x, y = a[key], b[key]
                    if not x then
                        same = false
                        print(string.format("%s: only in built: %s", name, key))
                    elseif not y then
                        same = false
                        print(string.format("%s: only in reference: %s", name, key))
                    elseif x.kind ~= y.kind then
                        same = false
                        print(string.format("%s: kind differs: %s (%s vs %s)", name, key, x.kind, y.kind))
                    elseif x.kind == "file" then
                        if digest(x.file, {}) ~= digest(y.file, pairs_list) then
                            same = false
                            print(string.format("%s: content differs: %s", name, key))
                        end
                    elseif x.kind == "link" then
                        local target = link_of(x.file)
                        local other = link_of(y.file)
                        if normalize(other, pairs_list) ~= target then
                            same = false
                            print(string.format("%s: link differs: %s -> %s vs %s", name, key, target, other))
                        end
                    end
                end
                if same then
                    print(string.format("%s: same (%d entries)", name, #sorted))
                else
                    differences = differences + 1
                end
            end
        end
    end
    if differences > 0 then
        raise("%d input(s) differ", differences)
    end
end

function main(...)
    local args = {...}
    local command = args[1]
    local positional, options = {}, {}
    local index = 2
    while index <= #args do
        local arg = args[index]
        if arg == "--rewrite" then
            options.rewrites = options.rewrites or {}
            table.insert(options.rewrites, args[index + 1])
            index = index + 2
        elseif arg:startswith("--") then
            options[arg:sub(3)] = args[index + 1]
            index = index + 2
        else
            table.insert(positional, arg)
            index = index + 1
        end
    end
    if command == "make" and #positional == 1 then
        options.project = positional[1]
        make(options)
    elseif command == "compare" and #positional == 2 then
        compare(positional[1], positional[2], options)
    else
        print(USAGE)
    end
end
