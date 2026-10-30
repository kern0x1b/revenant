import("lib.detect.find_tool")

local member = path.join(os.scriptdir(), "..")

local common = {
    {"PORT", "Cocoa"},
    {"DEVELOPER_MODE", "OFF"},
    {"SWIFT_REQUIRED", "OFF"},
    {"ENABLE_SWIFT_DEMO_URI_SCHEME", "OFF"},
    {"ENABLE_BACK_FORWARD_LIST_SWIFT", "OFF"},
    {"USE_HEADER_MAPS", "OFF"},
    {"WEBKIT_IOS6", "ON"},
    {"WEBKIT_IOS6_SIZE_OPTIMIZED", "ON"},
    {"WEBKIT_NO_AVAILABILITY_OVERLAY", "ON"},
    {"CMAKE_DISABLE_PRECOMPILE_HEADERS", "OFF"},
    {"USE_WEBP", "ON"},
    {"USE_WOFF2", "ON"},
    {"ENABLE_WEBKIT_LEGACY", "ON"},
    {"ENABLE_WEBKIT", "OFF"},
    {"ENABLE_TOUCH_EVENTS", "ON"},
    {"ENABLE_IOS_TOUCH_EVENTS", "OFF"},
    {"ENABLE_WEBKIT_OVERFLOW_SCROLLING_CSS_PROPERTY", "ON"},
    {"ENABLE_NOTIFICATIONS", "ON"},
    {"ENABLE_FULLSCREEN_API", "ON"},
    {"ENABLE_XSLT", "ON"},
    {"ENABLE_WEBGL", "ON"},
    {"ENABLE_MEDIA_STREAM", "ON"},
    {"ENABLE_WIRELESS_PLAYBACK_TARGET", "ON"},
    {"ENABLE_WIRELESS_PLAYBACK_TARGET_AVAILABILITY_API", "ON"},
    {"ENABLE_JIT", "ON"},
    {"ENABLE_DFG_JIT", "ON"},
    {"ENABLE_C_LOOP", "OFF"},
    {"ENABLE_FTL_JIT", "OFF"},
    {"USE_SYSTEM_MALLOC", "ON"},
    {"ENABLE_WEBGPU", "OFF"},
    {"ENABLE_WEBDRIVER", "OFF"},
    {"ENABLE_WEBINSPECTORUI", "OFF"},
    {"ENABLE_REMOTE_INSPECTOR", "OFF"},
    {"ENABLE_API_TESTS", "OFF"},
    {"ENABLE_TOOLS", "OFF"},
    {"ENABLE_MINIBROWSER", "OFF"},
    {"ENABLE_WEB_RTC", "OFF"},
    {"USE_LIBWEBRTC", "OFF"},
    {"ENABLE_MEDIA_RECORDER", "OFF"},
    {"ENABLE_WEB_CODECS", "OFF"},
    {"ENABLE_COCOA_WEBM_PLAYER", "OFF"},
    {"ENABLE_AV1", "OFF"},
    {"ENABLE_SPEECH_SYNTHESIS", "OFF"},
    {"ENABLE_WEB_SPEECH", "OFF"},
    {"ENABLE_GAMEPAD", "OFF"},
    {"ENABLE_PIXEL_FORMAT_RGBA16F", "OFF"},
    {"ENABLE_COMPRESSION_STREAM", "OFF"},
    {"ENABLE_APPLE_PAY", "OFF"},
    {"ENABLE_APPLE_PAY_COUPON_CODE", "OFF"},
    {"ENABLE_APPLE_PAY_SESSION_V3", "OFF"},
    {"USE_ANGLE_EGL", "OFF"},
    {"ENABLE_MEDIA_SOURCE", "OFF"},
    {"ENABLE_MEDIA_SOURCE_IN_WORKERS", "OFF"},
    {"ENABLE_ENCRYPTED_MEDIA", "OFF"},
    {"ENABLE_LEGACY_ENCRYPTED_MEDIA", "OFF"},
    {"ENABLE_WEB_AUTHN", "OFF"},
    {"ENABLE_WRITING_TOOLS", "OFF"},
    {"ENABLE_PAYMENT_REQUEST", "OFF"},
    {"ENABLE_IMAGE_DIFF", "OFF"},
    {"BROWSERENGINECORE_LIBRARY", "BROWSERENGINECORE_LIBRARY-NOTFOUND"},
    {"BROWSERENGINEKIT_LIBRARY", "BROWSERENGINEKIT_LIBRARY-NOTFOUND"},
    {"UNIFORMTYPEIDENTIFIERS_LIBRARY", "UNIFORMTYPEIDENTIFIERS_LIBRARY-NOTFOUND"}
}

local variants = {
    system = {prefix = "ios6_class_names.h", options = {}},
    prefixed = {prefix = "ios6_class_prefix.h", prefixed = true,
                options = {ENABLE_MEDIA_STREAM = "OFF", ENABLE_NOTIFICATIONS = "OFF", ENABLE_WEBGL = "OFF"}}
}

local tuning = {"-mcpu=cortex-a9", "-mfpu=neon"}

local compat_sources = {
    "compat/ios6_compat.c",
    "compat/ios6_missing.c",
    "compat/ios6_missing_constants.c",
    "compat/ios6_coretext.c",
    "compat/ios6_coregraphics.c",
    "compat/ios6_missing_classes.m",
    "compat/ios6_uttype.m",
    "compat/ios6_palswift.m",
    "compat/ios6_uicolor.m",
    "compat/ios6_avaudio.m",
    "compat/ios6_media_stubs.cpp"
}

local packages = {"icu", "libcxx", "libxml2", "libxslt", "openssl", "wasm3", "brotli", "libpsl", "libwebp", "woff2"}

local function toolchain_module(name)
    return import("@addon.revenant." .. name, {anonymous = true})
end

function variant(name)
    return assert(variants[name], "the engine has the variants system and prefixed, not " .. tostring(name))
end

local function library(dir, name)
    return path.join(dir, "lib", "lib" .. name .. ".a")
end

local function quoted(text)
    return "\"" .. text:gsub("\\", "/") .. "\""
end

-- Apple's libtool drops the engine's LTO bitcode members it cannot read, and -no_warning_for_no_symbols hides it. The llvm
-- package's llvm-libtool-darwin keeps every member, so the engine's archives are made with it.
local function llvm_libtool(package)
    local tool = path.join(package:dep("llvm"):installdir("bin"), "llvm-libtool-darwin")
    assert(os.isfile(tool), "the llvm package has no llvm-libtool-darwin, which the engine's LTO bitcode archives are made with")
    return tool
end

function options(ctx)
    local chosen = variant(ctx.variant)
    local found = {
        {"CMAKE_OSX_SYSROOT", ctx.sdk},
        {"CMAKE_OSX_ARCHITECTURES", ctx.arch},
        {"CMAKE_OSX_DEPLOYMENT_TARGET", ctx.deployment},
        {"CMAKE_SYSTEM_PROCESSOR", ctx.arch == "arm64" and "aarch64" or "arm"},
        {"CMAKE_C_COMPILER", ctx.cc},
        {"CMAKE_ASM_COMPILER", ctx.cc},
        {"CMAKE_OBJC_COMPILER", ctx.cc},
        {"CMAKE_CXX_COMPILER", ctx.cxx},
        {"CMAKE_OBJCXX_COMPILER", ctx.cxx}
    }
    if ctx.linker then
        table.insert(found, {"CMAKE_LINKER", ctx.linker})
    end
    for _, option in ipairs(common) do
        table.insert(found, {option[1], chosen.options[option[1]] or option[2]})
    end
    table.join2(found, {
        {"CMAKE_LIBTOOL", ctx.libtool},
        {"WEBKIT_IOS6_CRYPTO_LIB", library(ctx.openssl, "crypto")},
        {"WEBKIT_IOS6_COMPAT_LIB", ctx.compat},
        {"WEBKIT_IOS6_EXPORTS", ctx.exports},
        {"WEBKIT_IOS6_LIBCXX_DIR", ctx.libcxx},
        {"WebP_INCLUDE_DIR", path.join(ctx.libwebp, "include")},
        {"WebP_LIBRARY", library(ctx.libwebp, "webp")},
        {"WebP_DEMUX_LIBRARY", library(ctx.libwebp, "webpdemux")},
        {"WOFF2_INCLUDE_DIR", path.join(ctx.woff2, "include")},
        {"WOFF2_DEC_INCLUDE_DIR", path.join(ctx.woff2, "include")},
        {"WOFF2_LIBRARY", library(ctx.woff2, "woff2common")},
        {"WOFF2_DEC_LIBRARY", library(ctx.woff2, "woff2dec")},
        {"OPENSSL_ROOT_DIR", ctx.openssl},
        {"ICU_DIR", path.join(ctx.build, "packages", "ICU")},
        {"LibXml2_DIR", ctx.libxml2_config},
        {"LibXslt_DIR", ctx.libxslt_config},
        {"CMAKE_FIND_PACKAGE_PREFER_CONFIG", "ON"},
        {"CMAKE_PROJECT_WebKit_INCLUDE", path.join(ctx.build, "packages", "project-include.cmake")}
    })
    return found
end

-- The iOS 6 defines for every language. WebKit's iOS options enable Objective-C++ after the toolchain sets its
-- flags, so the flags alone do not reach the .mm precompiled header: the project carries them as definitions too.
local IOS6_DEFINES = {"WEBKIT_IOS6=1", "ENABLE_UNFAIR_LOCK=0", "ENABLE_OPUS=0", "WEBKIT_IOS6_NO_READLINE", "U_STATIC_IMPLEMENTATION", "U_DISABLE_RENAMING=1"}

function flags(ctx)
    local chosen = variant(ctx.variant)
    local defines = {}
    for _, define in ipairs(IOS6_DEFINES) do
        table.insert(defines, "-D" .. define)
    end
    local cflags = table.join({"-flto=thin", "-mllvm", "-hot-cold-split=false"}, tuning,
                              {"-isystem", ctx.stubs, "-include", path.join(ctx.stubs, chosen.prefix)}, defines)
    local cxxflags = {"-nostdinc++", "-isystem", path.join(ctx.libcxx, "include", "c++", "v1"),
                      "-include", path.join(ctx.stubs, "ios6_dispatch_compat.h"), "-D_LIBCPP_DISABLE_AVAILABILITY"}
    local shflags = {"-flto=thin", "-Wl,-compatibility_version,1.0.0", "-Wl,-current_version,1.0.0",
                     "-L" .. path.join(ctx.libxslt, "lib"), "-L" .. path.join(ctx.woff2, "lib"),
                     library(ctx.brotli, "brotlidec"), library(ctx.brotli, "brotlicommon")}
    return {cflags = cflags, cxxflags = cxxflags, shflags = shflags, ldflags = {library(ctx.libpsl, "psl")}}
end

function envs()
    return {OBJCFLAGS = "-DWEBKIT_IOS6_OBJC_EXTRAS", OBJCXXFLAGS = "-DWEBKIT_IOS6_OBJC_EXTRAS"}
end

function write_packages(ctx)
    local dir = path.join(ctx.build, "packages")
    local icu = path.join(dir, "ICU")
    local lines = {
        "set(ICU_FOUND TRUE)",
        "set(ICU_VERSION " .. ctx.icu_version .. ")",
        "set(ICU_INCLUDE_DIRS \"" .. path.join(ctx.icu, "include") .. "\")"
    }
    local components = {{"data", "icudata", {}}, {"uc", "icuuc", {"ICU::data"}}, {"i18n", "icui18n", {"ICU::uc"}}}
    for _, component in ipairs(components) do
        local target = "ICU::" .. component[1]
        table.join2(lines, {
            "if (NOT TARGET " .. target .. ")",
            "    add_library(" .. target .. " STATIC IMPORTED)",
            "    set_target_properties(" .. target .. " PROPERTIES",
            "        IMPORTED_LOCATION \"" .. library(ctx.icu, component[2]) .. "\"",
            "        INTERFACE_INCLUDE_DIRECTORIES \"" .. path.join(ctx.icu, "include") .. "\"",
            "        INTERFACE_COMPILE_DEFINITIONS \"U_STATIC_IMPLEMENTATION;U_DISABLE_RENAMING=1\"",
            "        INTERFACE_LINK_LIBRARIES \"" .. table.concat(component[3], ";") .. "\"",
            "        IMPORTED_LINK_INTERFACE_LANGUAGES CXX)",
            "endif ()",
            "set(ICU_" .. component[1]:upper() .. "_FOUND TRUE)",
            "set(ICU_" .. component[1]:upper() .. "_LIBRARY \"" .. library(ctx.icu, component[2]) .. "\")"
        })
    end
    table.insert(lines, "set(ICU_LIBRARIES ICU::i18n ICU::uc ICU::data)")
    io.writefile(path.join(icu, "ICUConfig.cmake"), table.concat(lines, "\n") .. "\n")
    io.writefile(path.join(icu, "ICUConfigVersion.cmake"), table.concat({
        "set(PACKAGE_VERSION " .. ctx.icu_version .. ")",
        "if (PACKAGE_FIND_VERSION VERSION_GREATER PACKAGE_VERSION)",
        "    set(PACKAGE_VERSION_COMPATIBLE FALSE)",
        "else ()",
        "    set(PACKAGE_VERSION_COMPATIBLE TRUE)",
        "    if (PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)",
        "        set(PACKAGE_VERSION_EXACT TRUE)",
        "    endif ()",
        "endif ()"
    }, "\n") .. "\n")
    local include = {
        "find_package(LibXml2 CONFIG REQUIRED)",
        "find_package(LibXslt CONFIG REQUIRED)",
        "string(APPEND CMAKE_EXE_LINKER_FLAGS \" -Wl,-rpath,@executable_path/Frameworks\")",
        "add_compile_definitions(" .. table.concat(IOS6_DEFINES, " ") .. ")",
        "add_compile_options(\"$<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:SHELL:-isystem " .. ctx.stubs .. ">\")",
        "add_compile_options(\"$<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:SHELL:-include " .. path.join(ctx.stubs, variant(ctx.variant).prefix) .. ">\")",
        "add_compile_options(\"$<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:SHELL:-include " .. path.join(ctx.stubs, "ios6_dispatch_compat.h") .. ">\")"
    }
    io.writefile(path.join(dir, "project-include.cmake"), table.concat(include, "\n") .. "\n")
    return dir
end

function arguments(ctx)
    local argv = {}
    for _, option in ipairs(options(ctx)) do
        table.insert(argv, "-D" .. option[1] .. "=" .. option[2])
    end
    local python = assert(find_tool("python3"), "the engine's build runs WebKit's own generators, which need python3 on the build machine")
    table.insert(argv, "-DPython_EXECUTABLE=" .. python.program)
    return argv
end

function prefix_exports(header, source, destination)
    local renames = {}
    for line in io.readfile(header):gmatch("[^\n]+") do
        local from, to = line:match("^#define ([%w_]+) (Rev[%w_]+)$")
        if from then
            renames[from] = to
        end
    end
    local text = io.readfile(source)
    if not text:endswith("\n") then
        text = text .. "\n"
    end
    local out, renamed = {}, 0
    for line in text:gmatch("([^\n]*)\n") do
        local stripped = line:trim()
        local written = line
        for _, kind in ipairs({"CLASS", "METACLASS", "IVAR"}) do
            local lead = "_OBJC_" .. kind .. "_$_"
            if stripped:startswith(lead) then
                local name, rest = stripped:sub(#lead + 1):match("^([%w_]+)(.*)$")
                if name and (rest == "" or rest:startswith(".")) and renames[name] then
                    written = lead .. renames[name] .. rest
                    renamed = renamed + 1
                end
                break
            end
        end
        table.insert(out, written)
    end
    io.writefile(destination, table.concat(out, "\n") .. "\n")
    return renamed, out
end

function context(package, build)
    local cmake = toolchain_module("apple.cmake")
    local chosen = cmake.toolchain(package)
    local function dir(name)
        return assert(package:dep(name), package:name() .. " has no dependency " .. name):installdir()
    end
    local function config(name)
        local found = os.dirs(path.join(dir(name), "lib", "cmake", name .. "*"))
        return assert(found[1], name .. " installed no CMake package configuration under lib/cmake")
    end
    local source = path.join(dir("webkit"), "src")
    local ctx = {
        variant = package:config("variant"),
        carried = package:config("carried"),
        sdk = chosen:config("sdkdir"),
        arch = package:arch(),
        deployment = chosen:config("deployment"),
        cc = chosen:tool("cc"),
        cxx = chosen:tool("cxx"),
        libtool = llvm_libtool(package),
        source = source,
        build = build,
        stubs = path.join(member, "compat", "stubs"),
        libcxx = dir("libcxx"),
        icu = dir("icu"),
        icu_version = package:dep("icu"):version_str(),
        libwebp = dir("libwebp"),
        woff2 = dir("woff2"),
        brotli = dir("brotli"),
        libpsl = dir("libpsl"),
        openssl = dir("openssl"),
        libxml2 = dir("libxml2"),
        libxslt = dir("libxslt"),
        libxml2_config = config("libxml2"),
        libxslt_config = config("libxslt"),
        compat = path.join(build, "compat", "libios6compat.a")
    }
    if variant(ctx.variant).prefixed then
        ctx.exports = path.join(build, "WebKitLegacy-iOS-rev.exp")
    else
        ctx.exports = path.join(source, "Source", "WebKitLegacy", "WebKitLegacy-iOS.exp")
    end
    return ctx
end

local function cmake_program()
    return assert(find_tool("cmake"), "cmake is needed to build the engine").program
end

local function ninja_program()
    return assert(find_tool("ninja"), "ninja is needed to build the engine").program
end

local function build_with(package, builddir, targets, environment)
    local parallel = toolchain_module("parallel")
    os.vrunv(cmake_program(), table.join({"--build", builddir}, parallel.cmake_ninja(),
                                         targets and table.join({"--target"}, targets) or {}), {envs = environment})
end

function compat(package, ctx)
    local cmake = toolchain_module("apple.cmake")
    local folder = path.join(ctx.build, "compat-source")
    local builddir = path.join(ctx.build, "compat")
    local sources = {}
    for _, source in ipairs(compat_sources) do
        table.insert(sources, "    " .. quoted(path.join(member, source)))
    end
    local libcxx = path.join(ctx.libcxx, "include", "c++", "v1")
    local lines = {
        "cmake_minimum_required(VERSION 3.21)",
        "project(ios6compat C CXX OBJC)",
        "add_library(ios6compat STATIC",
        table.concat(sources, "\n") .. ")",
        "set_target_properties(ios6compat PROPERTIES CXX_STANDARD 23 CXX_STANDARD_REQUIRED ON CXX_EXTENSIONS OFF ARCHIVE_OUTPUT_DIRECTORY " .. quoted(builddir) .. ")",
        "target_include_directories(ios6compat SYSTEM PRIVATE",
        "    " .. quoted(ctx.stubs),
        "    \"$<$<COMPILE_LANGUAGE:CXX>:" .. libcxx .. ">\")",
        "set_source_files_properties(" .. quoted(path.join(member, "compat", "ios6_compat.c")) .. " PROPERTIES INCLUDE_DIRECTORIES " .. quoted(path.join(ctx.libpsl, "include")) .. ")",
        "target_compile_options(ios6compat PRIVATE",
        "    -O2 -fno-objc-arc -Wno-builtin-requires-header -Wno-protocol -Wno-objc-designated-initializers",
        "    \"$<$<COMPILE_LANGUAGE:OBJC,CXX>:SHELL:-include " .. path.join(ctx.stubs, "ios6_dispatch_compat.h") .. ">\"",
        "    \"$<$<COMPILE_LANGUAGE:CXX>:-nostdinc++>\")",
        "target_compile_definitions(ios6compat PRIVATE",
        "    WEBKIT_IOS6_NO_READLINE",
        "    $<$<COMPILE_LANGUAGE:OBJC>:WEBKIT_IOS6_OBJC_EXTRAS>",
        "    $<$<COMPILE_LANGUAGE:CXX>:_LIBCPP_DISABLE_AVAILABILITY>)"
    }
    io.writefile(path.join(folder, "CMakeLists.txt"), table.concat(lines, "\n") .. "\n")
    local environment = {SOURCE_DATE_EPOCH = "0", IPHONEOS_DEPLOYMENT_TARGET = ctx.deployment}
    os.vrunv(cmake_program(), {"-G", "Ninja", "-S", folder, "-B", builddir,
                               "-DCMAKE_MAKE_PROGRAM=" .. ninja_program(),
                               "-DCMAKE_TOOLCHAIN_FILE=" .. cmake.toolchain_file(package, {builddir = builddir, cflags = tuning}),
                               "-DCMAKE_BUILD_TYPE=Release"}, {envs = environment})
    build_with(package, builddir, {"ios6compat"}, environment)
    assert(os.isfile(ctx.compat), "the compat library did not land at " .. ctx.compat)
end

local function cache_entries(builddir)
    local found = {}
    for line in io.readfile(path.join(builddir, "CMakeCache.txt")):gmatch("[^\n]+") do
        local name, kind, value = line:match("^([%w_%-]+):([%w_]+)=(.*)$")
        if name then
            found[name] = {kind = kind, value = value}
        end
    end
    return found
end

function verify_configured(ctx)
    local values = cache_entries(ctx.build)
    local problems = {}
    local carry = {"-isystem", "-isysroot", "-I", "-L", "-F", "-B", "-include"}
    local checked = 0
    for _, name in ipairs({"CMAKE_C_FLAGS", "CMAKE_CXX_FLAGS", "CMAKE_OBJC_FLAGS", "CMAKE_OBJCXX_FLAGS",
                           "CMAKE_SHARED_LINKER_FLAGS", "CMAKE_EXE_LINKER_FLAGS", "CMAKE_MODULE_LINKER_FLAGS"}) do
        local words = (values[name] and values[name].value or ""):split("%s+")
        for index, word in ipairs(words) do
            for _, prefix in ipairs(carry) do
                local named
                if word == prefix and words[index + 1] then
                    named = words[index + 1]
                elseif word:startswith(prefix .. "/") then
                    named = word:sub(#prefix + 1)
                end
                if named then
                    checked = checked + 1
                    if not os.exists(named) then
                        table.insert(problems, string.format("%s in %s names %s, which does not exist", prefix, name, named))
                    end
                end
            end
        end
    end
    local prefix = path.join(ctx.stubs, variant(ctx.variant).prefix)
    for _, name in ipairs({"CMAKE_C_FLAGS", "CMAKE_CXX_FLAGS", "CMAKE_OBJC_FLAGS", "CMAKE_OBJCXX_FLAGS"}) do
        if not (values[name] and values[name].value:find(prefix, 1, true)) then
            table.insert(problems, string.format("%s does not include %s, so the build directory was configured for another variant", name, prefix))
        end
    end
    if not values.WEBKIT_IOS6_EXPORTS or values.WEBKIT_IOS6_EXPORTS.value ~= ctx.exports then
        table.insert(problems, string.format("WEBKIT_IOS6_EXPORTS is not %s", ctx.exports))
    end
    local include = values.CMAKE_PROJECT_WebKit_INCLUDE
    if not include or not os.isfile(include.value) then
        table.insert(problems, "CMAKE_PROJECT_WebKit_INCLUDE is not a file, so find_package was never told to prefer the packages' own configurations")
    end
    for key, entry in pairs(values) do
        if key:startswith("CMAKE_PROJECT_") and key:endswith("_INCLUDE") and entry.value ~= "" and not os.isfile(entry.value) then
            table.insert(problems, string.format("%s names %s, which is not there", key, entry.value))
        end
    end
    local sysroot = values.CMAKE_OSX_SYSROOT and values.CMAKE_OSX_SYSROOT.value or ""
    if sysroot == "" then
        table.insert(problems, "CMakeCache.txt carries no CMAKE_OSX_SYSROOT")
    else
        for key, entry in pairs(values) do
            local lowered = key:lower()
            if entry.kind == "PATH" and entry.value:startswith(sysroot) then
                for _, name in ipairs(packages) do
                    if lowered:startswith(name .. "_") then
                        table.insert(problems, string.format("%s resolved to %s, inside the SDK, instead of the %s package", key, entry.value, name))
                    end
                end
            end
        end
    end
    if #problems > 0 then
        raise("the engine was configured wrongly:\n  %s", table.concat(problems, "\n  "))
    end
    vprint("engine configuration: %d flag paths exist, the project include is applied, no package resolved into the SDK", checked)
end

local function nm(arguments, files)
    return os.iorunv("xcrun", table.join({"nm"}, arguments, files))
end

function verify_exports(ctx)
    local binary = path.join(ctx.build, "WebKitLegacy.framework", "WebKitLegacy")
    local listed, exported = {}, {}
    for line in io.readfile(ctx.exports):gmatch("[^\n]+") do
        local symbol = line:trim()
        if symbol ~= "" and not symbol:startswith("#") then
            listed[symbol] = true
        end
    end
    for symbol in nm({"-gUj"}, {binary}):gmatch("%S+") do
        exported[symbol] = true
    end
    local missing, unlisted = {}, {}
    for symbol in pairs(listed) do
        if not exported[symbol] then
            table.insert(missing, symbol)
        end
    end
    for symbol in pairs(exported) do
        if not listed[symbol] then
            table.insert(unlisted, symbol)
        end
    end
    table.sort(missing)
    table.sort(unlisted)
    if #missing > 0 or #unlisted > 0 then
        raise("%s was not linked with %s: %d listed symbols not exported (first: %s), %d exported symbols not listed (first: %s)",
              binary, ctx.exports, #missing, table.concat(table.slice(missing, 1, 3), " "), #unlisted, table.concat(table.slice(unlisted, 1, 3), " "))
    end
end

-- The engine's objects are LTO bitcode, which Apple's nm cannot read (it fails on LLVM 23's). llvm-nm of LLVM 23 or later can.
local function object_nm()
    local tool = find_tool("llvm-nm", {version = true})
    if not tool or not tool.version or tonumber(tool.version:match("^(%d+)") or 0) < 23 then
        raise("the compat audit reads the engine's bitcode with llvm-nm of LLVM 23 or later, which must be on PATH ahead of Apple's")
    end
    return tool.program
end

local function defined_symbols(files)
    local found = {}
    for first = 1, #files, 400 do
        local listing = os.iorunv(object_nm(), table.join({"--defined-only", "-g"}, table.slice(files, first, first + 399)))
        for line in listing:gmatch("[^\n]+") do
            local kind, symbol = line:match("^%S+ ([TDBSCWV]) (%S+)$")
            if kind then
                found[symbol] = true
            end
        end
    end
    return found
end

-- The compiler emits these block-runtime helpers in each unit that uses a block of that layout, so the compat library's copies and the engine's are the same compiler output.
local function compiler_block_helper(symbol)
    return symbol:startswith("___block_descriptor_") or symbol:startswith("___copy_helper_block_") or symbol:startswith("___destroy_helper_block_")
end

function verify_compat(ctx)
    local objects = {}
    for _, object in ipairs(os.files(path.join(ctx.build, "**.o"))) do
        if not object:find("/compat/", 1, true) then
            table.insert(objects, object)
        end
    end
    if #objects == 0 then
        raise("no object files under %s to audit the compat library against", ctx.build)
    end
    table.join2(objects, os.files(path.join(ctx.icu, "lib", "*.a")))
    local stubs = defined_symbols({ctx.compat})
    local engine = defined_symbols(objects)
    local clash, count, total = {}, 0, 0
    for symbol in pairs(stubs) do
        count = count + 1
        if engine[symbol] and not symbol:startswith("__OBJC_") and not compiler_block_helper(symbol) then
            table.insert(clash, symbol)
        end
    end
    for _ in pairs(engine) do
        total = total + 1
    end
    table.sort(clash)
    if #clash > 0 then
        raise("these stubs of the compat library shadow the engine's own definitions:\n  %s", table.concat(clash, "\n  "))
    end
    vprint("compat audit: none of the %d stub symbols shadows one of the engine's %d", count, total)
end

function install(package)
    local cmake = toolchain_module("apple.cmake")
    -- CMake keeps the flags of its first configure in the cache, so the variants cannot share a build directory: the
    -- second one would compile with the first one's prefix header.
    local build = path.absolute("build-" .. package:config("variant"))
    os.mkdir(build)
    local ctx = context(package, build)
    if ctx.carried == "jsc" and not variant(ctx.variant).prefixed then
        raise("carried=jsc is the prefixed variant's JavaScriptCore alone: the system variant replaces all three frameworks")
    end
    import("carry", {rootdir = os.scriptdir(), anonymous = true}).verify(ctx.source)
    compat(package, ctx)
    if variant(ctx.variant).prefixed then
        local renamed = prefix_exports(path.join(ctx.stubs, "ios6_class_prefix.h"),
                                       path.join(ctx.source, "Source", "WebKitLegacy", "WebKitLegacy-iOS.exp"), ctx.exports)
        vprint("%d exported classes renamed with the Rev prefix", renamed)
    end
    write_packages(ctx)
    local given = flags(ctx)
    local environment = table.join(envs(), {SOURCE_DATE_EPOCH = "0", IPHONEOS_DEPLOYMENT_TARGET = ctx.deployment})
    local argv = {"-G", "Ninja", "-S", ctx.source, "-B", build,
                  "-DCMAKE_MAKE_PROGRAM=" .. ninja_program(),
                  "-DCMAKE_TOOLCHAIN_FILE=" .. cmake.toolchain_file(package, {builddir = build, cflags = given.cflags, cxxflags = given.cxxflags,
                                                                              shflags = given.shflags, ldflags = given.ldflags}),
                  "-DCMAKE_BUILD_TYPE=Release",
                  "-DCMAKE_MACOSX_BUNDLE=OFF"}
    table.join2(argv, arguments(ctx))
    os.vrunv(cmake_program(), argv, {envs = environment})
    verify_configured(ctx)
    local targets = ctx.carried == "jsc" and {"JavaScriptCore"} or nil
    build_with(package, build, targets, environment)
    if ctx.carried == "all" then
        verify_exports(ctx)
    end
    verify_compat(ctx)
    local stage = import("stage", {rootdir = os.scriptdir(), anonymous = true})
    if variant(ctx.variant).prefixed then
        stage.bundle(package, ctx)
    else
        import("symbols", {rootdir = os.scriptdir(), anonymous = true}).verify(build)
        stage.system(package, ctx)
    end
    os.cp(path.join(ctx.source, "Source", "WebCore", "LICENSE-LGPL-2.1"), package:installdir("licenses") .. "/")
    os.cp(path.join(ctx.source, "Source", "WebCore", "LICENSE-APPLE"), package:installdir("licenses") .. "/")
end
