set_project("swiftui-consumer")
set_version("0.0.1")
-- What a program that imports SwiftUI needs of charon: the package as a dependency, and nothing else. The rule for Swift
-- sources (rules/swift) adds the -I of every dependency's CHARON_SWIFT_MODULES, and the linker takes the package's links and
-- frameworks, so this file is the whole of what "a package other recipes can add_deps" has to mean.
local root = os.getenv("SWIFTUI_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.13")
add_requires("charon@swiftui")
set_config("apple_minimum", os.getenv("SWIFTUI_MINIMUM") or "6.1.3")
includes("@addon/charon/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("consumer")
    add_rules("@addon/charon/daemon")
    add_files("main.swift")
    add_packages("swiftui")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")
