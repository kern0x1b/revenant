add_repositories("charon @repository@")
add_addons("charon")
set_config("apple_minimum", "@minimum@")
includes("@addon/charon/apple-ios")

set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|@arch@")

target("charon-callkit-screen")
    add_rules("@addon/charon/tweak")
    add_files("CharonCallScreenTweak.m")
    add_frameworks("UIKit", "Foundation", "QuartzCore", "CoreGraphics")
    set_values("tweak.filter", "springboard.plist")
    set_values("charon.control", "control")
