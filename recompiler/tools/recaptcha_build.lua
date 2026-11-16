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
