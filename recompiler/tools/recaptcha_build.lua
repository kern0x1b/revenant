local SDK_SHA256 = "5a42ec6a8f2682bb276185c97d4729a739badea58adc1f3bcdf9e2832348081b"

local INCLUDES = [[
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <DeviceCheck/DeviceCheck.h>
#import <Security/Security.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <AdSupport/AdSupport.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <CommonCrypto/CommonDigest.h>
#include "%s"
]]

local RUNTIME_LIBRARIES = {"libswiftCore", "libc++.1", "libc++abi.1", "libswiftCoreFoundation", "libswiftDarwin", "libswiftDispatch", "libswiftObjectiveC",
                            "libswift_Concurrency", "libswiftFoundation", "libswiftCoreGraphics", "libswiftNetwork", "libswiftCryptoKit"}
local OVERLAYS = {"Core", "CoreFoundation", "Darwin", "Dispatch", "ObjectiveC", "_Concurrency", "Foundation", "CoreGraphics", "Network"}

function sdk_sha256()
    return SDK_SHA256
end

function telegram_build()
    local directory = path.absolute(os.scriptdir())
    for _ = 1, 12 do
        local candidate = path.join(directory, "telegram-build")
        if os.isdir(path.join(candidate, ".agent-work")) then
            return candidate
        end
        local parent = path.directory(directory)
        if parent == directory then
            break
        end
        directory = parent
    end
end

function sdk_file()
    local named = os.getenv("XL_RECAPTCHA_SDK")
    if named and named ~= "" then
        return named
    end
    local build = telegram_build()
    if build then
        local candidate = path.join(build, ".agent-work", "recaptcha-sdk", "RecaptchaEnterprise.dylib")
        if os.isfile(candidate) then
            return candidate
        end
    end
end

function libraries_folder()
    local libs = os.getenv("XL_SWIFTOBJC_LIBS")
    if libs and libs ~= "" and os.isdir(libs) then
        return libs
    end
end

local function real_path(file)
    return (os.iorunv("readlink", {"-f", file}):gsub("%s+$", ""))
end

local function manifest_value(install, pattern)
    for _, folder in ipairs({install, (install:gsub("%.g%x+$", ""))}) do
        local manifest = path.join(folder, "manifest.txt")
        if os.isfile(manifest) then
            return io.readfile(manifest):match(pattern)
        end
    end
end

function runtime_recipe(root)
    local digest = io.readfile(path.join(root, "packages", "s", "swift-runtime", "port", "digest.lua"))
    return digest:match('swift_runtime_sources_digest%s*=%s*"(%x+)"') or raise("no swift_runtime_sources_digest in %s", path.join(root, "packages", "s", "swift-runtime", "port", "digest.lua"))
end

function check_runtime(libs, root, explicit)
    local recipe = runtime_recipe(root)
    local installs = {}
    for _, name in ipairs(RUNTIME_LIBRARIES) do
        local file = path.join(libs, name .. ".dylib")
        if os.isfile(file) then
            local install, hash = real_path(file):match("^(.*/swift%-runtime/[^/]+/(%x+)%.?g?%x*)/lib/")
            if install then
                installs[hash] = install
            end
        end
    end
    local found = table.keys(installs)
    table.sort(found)
    if #found ~= 1 then
        raise("the guest Swift runtime of %s must come from one revenant@swift-runtime install, and it comes from %d: %s", libs, #found, table.concat(found, ", "))
    end
    local key = found[1]
    local install = installs[key]
    local built = manifest_value(install, 'recipe%s*=%s*"(%x+)"')
    if explicit and explicit ~= "" then
        if key ~= explicit then
            raise("the guest Swift runtime of %s is the install %s, not the key %s that was asked for", libs, key, explicit)
        end
    elseif built ~= recipe then
        raise("the guest Swift runtime of %s is the install %s, built from the recipe %s, and this checkout's recipe is %s: point XL_SWIFTOBJC_LIBS at the install of the current recipe, or name the key with --runtime-key", libs, key, tostring(built), recipe)
    end
    for _, name in ipairs({"libswiftCryptoKit", "libswiftNetwork"}) do
        local file = path.join(libs, name .. ".dylib")
        if os.isfile(file) then
            local dependent = real_path(file):match("^(.*)/lib/[^/]+$")
            local against = dependent and manifest_value(dependent,'%["swift%-runtime"%]%s*=%s*{%s*buildhash%s*=%s*"(%x+)"')
            if against and against ~= key then
                raise("%s of %s was built against the Swift runtime %s, and the guest runtime is %s", name, libs, against, key)
            end
        end
    end
    return {key = key, recipe = built, core_sha256 = hash.sha256(path.join(libs, "libswiftCore.dylib"))}
end

function check_artifact_runtime(library, key)
    local marks = {}
    for mark in io.readfile(library, {encoding = "binary"}):gmatch("revenant_swift_runtime_(%x+)") do
        marks[mark] = true
    end
    local names = table.keys(marks)
    table.sort(names)
    if #names ~= 1 or names[1] ~= key then
        raise("%s carries the Swift runtime marks [%s], and the runtime it was translated against is %s", library, table.concat(names, ", "), key)
    end
end

function translate_sdk(e, out, sdk, libs, extra)
    local actual = hash.sha256(sdk)
    if actual ~= SDK_SHA256 then
        raise("%s has the sha256 %s, not the %s this recipe is written for", sdk, actual, SDK_SHA256)
    end
    local translate = import("translate", {rootdir = os.scriptdir(), anonymous = true})
    io.writefile(path.join(out, "includes.h"), string.format(INCLUDES, path.join(e.recompiler, "include", "swiftdemo-includes.h")))
    local images = {}
    local replaces = {"/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib")}
    for _, file in ipairs(RUNTIME_LIBRARIES) do
        table.insert(images, path.join(libs, file .. ".dylib"))
    end
    for _, overlay in ipairs(OVERLAYS) do
        table.insert(replaces, "/usr/lib/swift/libswift" .. overlay .. ".dylib=" .. path.join(libs, "libswift" .. overlay .. ".dylib"))
    end
    table.insert(replaces, "/System/Library/Frameworks/CryptoKit.framework/CryptoKit=" .. path.join(libs, "libswiftCryptoKit.dylib"))
    local options = {XL_LIBRARY = "1", XL_BASE = "0x18000000", XL_INSTALL_NAME = "@executable_path/Frameworks/RecaptchaEnterprise.dylib",
                     XL_REPLACES = table.concat(replaces, " "), XL_SWIFT_HOST_ANCESTORS = "1"}
    for key, value in pairs(extra or {}) do
        options[key] = value
    end
    translate.translate(sdk, path.join(out, "includes.h"), path.join(out, "xl"), images, options)
    return path.join(out, "xl")
end
