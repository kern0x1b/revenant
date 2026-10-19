if is_plat("iphoneos") then
    target("CombineHelpers")
        set_kind("static")
        add_rules("@addon/charon/apple-ios")
        add_packages("libcxx")
        set_languages("c++17")
        set_optimize("faster")
        add_cxxflags("-include exception")
        add_files("Sources/CombineHelpers/CombineHelpers.cpp")
        add_includedirs("Sources/CombineHelpers/include", {public = true})

    target("Combine")
        set_kind("static")
        add_rules("@addon/charon/swift")
        add_deps("CombineHelpers")
        set_optimize("fastest")
        add_files("Sources/Combine/**.swift")
        add_frameworks("Foundation", "CoreFoundation")
end
