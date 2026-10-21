if not is_plat("iphoneos") then
    return
end

local SRC = path.directory(os.scriptdir())

add_requires("revenant@swift-runtime", {alias = "swift-runtime"})
add_requires("revenant@libcxx", {alias = "libcxx"})

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
