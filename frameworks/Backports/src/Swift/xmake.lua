if not is_plat("iphoneos") then
    return
end

local SRC = path.directory(os.scriptdir())

add_requires("revenant@swift-runtime", {alias = "swift-runtime"})
add_requires("revenant@libcxx", {alias = "libcxx"})
add_requires("revenant@micro-ecc", {alias = "micro-ecc"})

local LOCALIZED_STRING = "import Foundation\npublic func probe() -> LocalizedStringResource { return LocalizedStringResource(\"\") }"

local APPINTENTS_PROBES = {
    {flag = "REVENANT_APPINTENTS_ATTRIBUTED_STRING",
     body = "import Foundation\npublic func probe() -> AttributedString { return AttributedString(\"x\") }"},
    {flag = "REVENANT_APPINTENTS_MEASUREMENT",
     body = "import Foundation\npublic func probe() -> Measurement { return Measurement(value: 1, unit: UnitLength.meters) }"},
    {flag = "REVENANT_APPINTENTS_RECURRENCE_RULE",
     body = "import Foundation\npublic func probe() -> Calendar.RecurrenceRule { return Calendar.RecurrenceRule(weekOfMonth: 1, weekOfYear: 2, month: 3, dayOfWeek: 4) }"}
}

local CORESPOTLIGHT = "import CoreSpotlight\npublic func probe() -> CSSearchableItem {\n"
    .. "    return CSSearchableItem(uniqueIdentifier: \"x\", domainIdentifier: nil, attributeSet: CSSearchableItemAttributeSet(contentType: \"public.item\"))\n}\n"
    .. "public func probeIndex() -> CSSearchableIndex { return CSSearchableIndex.default() }\n"

local function add_flags(target, flags)
    for _, flag in ipairs(flags) do
        target:add("values", "swift.flags", flag)
    end
end

target("AppIntents")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_frameworks("Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "AppIntents", "*.swift"))
    end)
    on_config(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local flags, overlays = {}, {}
        local ports = table.wrap((target:pkg("swift-runtime"):envs() or {}).REVENANT_SWIFT_PORT_HEADERS)[1]
        if ports then
            table.insert(flags, "-DREVENANT_APPINTENTS_PORT_HEADERS")
            overlays = {"-Xcc", "-ivfsoverlay", "-Xcc", ports}
        end
        if swift.probe(target, LOCALIZED_STRING) then
            table.insert(flags, "-DREVENANT_APPINTENTS_CARRIES_LOCALIZED_STRING")
        end
        for _, probe in ipairs(APPINTENTS_PROBES) do
            if swift.probe(target, probe.body) then
                table.insert(flags, "-D" .. probe.flag)
            end
        end
        if swift.probe(target, CORESPOTLIGHT, {flags = overlays}) then
            table.insert(flags, "-DREVENANT_APPINTENTS_CORESPOTLIGHT")
        end
        table.join2(flags, overlays)
        add_flags(target, flags)
    end)

target("ActivityKit")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_deps("AppIntents")
    add_frameworks("Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "ActivityKit", "*.swift"))
    end)
    on_config(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        if swift.probe(target, LOCALIZED_STRING) then
            add_flags(target, {"-DREVENANT_PLATFORM_LOCALIZED_STRING"})
        else
            add_flags(target, {"-DREVENANT_CARRIES_LOCALIZED_STRING"})
        end
    end)

target("TipKit")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_deps("AppIntents")
    add_frameworks("Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "TipKit", "*.swift"))
    end)
    on_config(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        if swift.probe(target, LOCALIZED_STRING) then
            add_flags(target, {"-DREVENANT_PLATFORM_LOCALIZED_STRING"})
        else
            add_flags(target, {"-DREVENANT_CARRIES_LOCALIZED_STRING"})
        end
    end)

target("WidgetKit")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_deps("AppIntents", "ActivityKit")
    add_frameworks("Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "WidgetKit", "*.swift"))
    end)

local function port_overlay(target)
    local ports = table.wrap((target:pkg("swift-runtime"):envs() or {}).REVENANT_SWIFT_PORT_HEADERS)
    if #ports == 0 then
        return {}
    end
    return {"-vfsoverlay", table.concat(ports, path.envsep())}
end

local function createml(name, folder, deps, flags)
    target(name)
        set_kind("static")
        set_default(false)
        add_rules("@addon/revenant/swift")
        if #deps > 0 then
            add_deps(table.unpack(deps))
        end
        add_frameworks("Accelerate", "Foundation", "CoreFoundation")
        set_optimize("fastest")
        on_load(function (target)
            target:add("files", path.join(SRC, folder, "*.swift"))
        end)
        on_config(function (target)
            add_flags(target, table.join(port_overlay(target), flags or {}))
        end)
    target_end()
end

createml("TabularData", "TabularData", {}, {})
createml("CoreML", "CoreML", {}, {"-import-objc-header", path.join(SRC, "CoreML", "RevenantCoreML.h")})
createml("CreateMLComponents", "CreateMLComponents", {"TabularData", "CoreML"}, {})
createml("CreateML", "CreateML", {"CreateMLComponents", "TabularData", "CoreML"}, {})

target("MusicKit")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_packages("micro-ecc")
    add_frameworks("Foundation", "CoreGraphics")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "MusicKit", "*.swift"))
        target:add("files", path.join(SRC, "MusicKit", "RevenantC.c"))
        target:add("includedirs", path.join(SRC, "MusicKit", "include"), {public = true})
        target:add("cflags", "-Os", "-fvisibility=hidden")
    end)
    on_config(function (target)
        add_flags(target, {"-import-objc-header", path.join(SRC, "MusicKit", "include", "MusicKitC.h"), "-I", path.join(SRC, "MusicKit", "include")})
    end)
    target_end()

target("SwiftData")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_frameworks("CoreData", "Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "SwiftData", "*.swift"))
    end)
    on_config(function (target)
        add_flags(target, port_overlay(target))
    end)
    target_end()
