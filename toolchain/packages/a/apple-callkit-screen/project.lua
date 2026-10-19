add_repositories("revenant @repository@")
add_addons("revenant")
set_config("apple_minimum", "@minimum@")
includes("@addon/revenant/apple-ios")

set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|@arch@")

target("revenant-callkit-screen")
    add_rules("@addon/revenant/tweak")
    add_files("RevenantCallScreenTweak.m")
    add_frameworks("UIKit", "Foundation", "QuartzCore", "CoreGraphics")
    set_values("tweak.filter", "springboard.plist")
    set_values("revenant.control", "control")
