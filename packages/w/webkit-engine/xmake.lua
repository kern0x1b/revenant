package("webkit-engine")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/WebKit")
    set_description("JavaScriptCore, WebCore and WebKitLegacy for armv7 and iOS 6, built from the webkit package's patched tree with CMake against the port's libraries: system stages the frameworks under usr/lib/rev-fw in place of the phone's own, prefixed lays them out for an application's Frameworks folder with every class renamed")
    set_license("LGPL-2.1-or-later AND BSD-2-Clause")
    set_policy("package.strict_compatibility", true)

    local JSC_API = {"JSGlobalContextCreateInGroup", "JSGlobalContextRetain", "JSGlobalContextRelease", "JSContextGetGlobalObject",
                     "JSGlobalContextSetInspectable", "JSEvaluateScript", "JSClassCreate", "JSObjectMake", "JSValueIsObjectOfClass",
                     "JSObjectGetPrivate", "JSObjectSetPrivate", "JSObjectGetProperty", "JSObjectSetProperty", "JSObjectGetPropertyForKey",
                     "JSObjectSetPropertyForKey", "JSObjectHasProperty", "JSObjectGetPropertyAtIndex", "JSObjectSetPropertyAtIndex",
                     "JSObjectGetPrototype", "JSObjectSetPrototype", "JSObjectIsFunction", "JSObjectCallAsFunction", "JSObjectCallAsConstructor",
                     "JSObjectMakeArray", "JSObjectCopyPropertyNames", "JSPropertyNameArrayGetCount", "JSPropertyNameArrayGetNameAtIndex",
                     "JSPropertyNameArrayRelease", "JSPropertyNameAccumulatorAddName", "JSObjectGetArrayBufferBytesPtr",
                     "JSObjectGetArrayBufferByteLength", "JSValueGetTypedArrayType", "JSStringCreateWithUTF8CString", "JSStringGetLength",
                     "JSStringGetMaximumUTF8CStringSize", "JSStringGetUTF8CString", "JSStringIsEqual", "JSStringRetain", "JSStringRelease",
                     "JSValueGetType", "JSValueIsArray", "JSValueIsEqual", "JSValueIsInstanceOfConstructor", "JSValueIsSymbol",
                     "JSValueIsUndefined", "JSValueMakeBoolean", "JSValueMakeNull", "JSValueMakeNumber", "JSValueMakeString",
                     "JSValueMakeSymbol", "JSValueMakeUndefined", "JSValueProtect", "JSValueUnprotect", "JSValueToBoolean", "JSValueToNumber",
                     "JSValueToObject", "JSValueToStringCopy"}

    local member = path.join(os.scriptdir(), "..", "..", "..", "frameworks", "WebKit")
    local modules = path.join(member, "src", "modules")
    local digests = {}
    local webkit = path.join(os.scriptdir(), "..", "webkit")
    local inputs = table.join({path.join(os.scriptdir(), "xmake.lua"), path.join(webkit, "xmake.lua"), path.join(member, "tests", "data", "carry-symbols.txt")},
                              os.files(path.join(webkit, "patches", "*.patch")),
                              os.files(path.join(member, "src", "modules", "*.lua")), os.files(path.join(member, "src", "compat", "**")))
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.relative(file, member) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe, the WebKit series it builds, the engine module, the compat library and the symbol baseline, so a changed patch, flag or stub is a different engine.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})
    add_configs("variant", {description = "system replaces the phone's frameworks beneath Mobile Safari; prefixed renames every class for an application that carries its own engine.", default = "system", type = "string", values = {"system", "prefixed"}})
    add_configs("carried", {description = "all builds JavaScriptCore, WebCore and WebKitLegacy; jsc builds JavaScriptCore alone, the framework a React Native host links, and the prefixed bundle carries only that.", default = "all", type = "string", values = {"all", "jsc"}})

    add_deps("cmake", "ninja", {kind = "binary"})
    add_deps("revenant@webkit", "revenant@icu", "revenant@brotli", "revenant@libpsl", "revenant@libwebp", "revenant@libxml2", "revenant@libxslt", "revenant@woff2")
    add_deps("revenant@openssl", {alias = "openssl"})
    add_deps("revenant@libcxx", {alias = "libcxx"})
    add_deps("revenant@ldid 2.1.5-procursus7+23.gaf86971", {alias = "ldid", host = true})

    on_install("iphoneos", function (package)
        if import("@addon.revenant.prebuilt", {anonymous = true}).install(package) then
            return
        end
        import("engine", {rootdir = modules, anonymous = true}).install(package)
        import("@addon.revenant.prebuilt", {anonymous = true}).pack(package)
    end)

    on_test(function (package)
        if package:config("variant") == "prefixed" then
            local carried = package:config("carried") == "jsc" and {"JavaScriptCore"} or {"JavaScriptCore", "WebCore", "WebKitLegacy"}
            for _, framework in ipairs(carried) do
                assert(os.isfile(path.join(package:installdir("bundle"), "Frameworks", framework .. ".framework", framework)), framework .. " is not in the bundle")
                assert(os.isdir(path.join(package:installdir("frameworks"), framework .. ".framework")), framework .. " is not linkable")
            end
            -- The JSC C API a React Native host calls. Each is declared with JS_EXPORT in the pinned
            -- JavaScriptCore/API headers and absent from iOS 6's own JavaScriptCore, so the prefixed build must export it.
            local jsc = path.join(package:installdir("bundle"), "Frameworks", "JavaScriptCore.framework", "JavaScriptCore")
            local exported = {}
            for line in os.iorunv("nm", {"-gU", jsc}):gmatch("[^\n]+") do
                local symbol = line:match("(%S+)$")
                if symbol then
                    exported[(symbol:gsub("^_", ""))] = true
                end
            end
            local missing = {}
            for _, name in ipairs(JSC_API) do
                if not exported[name] then
                    table.insert(missing, name)
                end
            end
            assert(#missing == 0, "the prefixed JavaScriptCore does not export " .. table.concat(missing, ", "))
            -- iOS 6 exports no XPC, and a lazily bound import of it fails only when it is called on the phone.
            for symbol in os.iorunv("nm", {"-u", jsc}):gmatch("%S+") do
                assert(not symbol:find("^_?xpc_"), jsc .. " imports " .. symbol .. ", which iOS 6 does not export")
            end
            local identity = "@executable_path/Frameworks/JavaScriptCore.framework/JavaScriptCore"
            assert(os.iorunv("otool", {"-D", jsc}):find(identity, 1, true), "the prefixed JavaScriptCore is not installed as " .. identity)
        else
            for _, framework in ipairs({"JavaScriptCore", "WebCore", "WebKit"}) do
                assert(os.isfile(path.join(package:installdir("stage"), "usr", "lib", "rev-fw", framework .. ".framework", framework)), framework .. " is not staged")
            end
            assert(os.isfile(path.join(package:installdir("stage"), "usr", "lib", "librev-c++.1.dylib")), "the C++ runtime is not staged")
        end
    end)
