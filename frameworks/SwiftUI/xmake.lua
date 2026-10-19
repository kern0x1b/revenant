if is_plat("iphoneos") then
    target("SwiftUI")
        set_kind("static")
        add_rules("@addon/revenant/swift")
        add_deps("Combine")
        set_optimize("fastest")
        add_files("SwiftUI/Sources/SwiftUI/*.swift")
        add_values("swift.flags", "-enforce-exclusivity=unchecked", "-suppress-warnings")
        add_frameworks("UIKit", "QuartzCore", "CoreGraphics", "CoreData", "Foundation", "CoreFoundation")

    includes("SwiftUI", "rtpkg")
end
