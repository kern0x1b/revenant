add_requires("revenant@react-native 0.86.3", {alias = "react-native"})
add_requires("revenant@react-native-screens 4.26.2", {alias = "react-native-screens"})
add_requires("revenant@node 26.13.0", {alias = "node", host = true})
add_requires("revenant@react-native-codegen 0.86.3", {alias = "react-native-codegen", host = true})
add_requires("revenant@folly 2024.11.18.00", {alias = "folly"})
add_requires("revenant@glog 0.3.5", {alias = "glog"})
add_requires("revenant@boost 1.84.0", {alias = "boost"})
add_requires("revenant@fmt 12.1.0", {alias = "fmt"})
add_requires("revenant@double-conversion 1.1.6", {alias = "double-conversion"})
add_requires("revenant@fast_float 8.0.0", {alias = "fast_float"})
add_requires("revenant@yoga 0.86.3", {alias = "yoga"})

-- The react-native-screens pod as CocoaPods builds it by default: the ios sources outside the Swift gamma project, the
-- stubs that stand in for that project, and the common subspec, whose headers CocoaPods flattens under rnscreens/.
target("rnscreens")
    add_rules("@addon/revenant/apple-ios")
    add_rules("@addon/revenant/rn-codegen")
    set_kind("static")
    set_default(false)
    set_values("rn.codegen.library", "react-native-screens")
    add_packages("react-native", "react-native-screens", "folly", "glog", "boost", "fmt", "double-conversion", "fast_float", "yoga")
    add_defines("RCT_NEW_ARCH_ENABLED=1", "FOLLY_MOBILE=1", "FOLLY_USE_LIBCPP=1", "FOLLY_CFG_NO_COROUTINES=1")
    add_mflags("-Werror=unguarded-availability-new", {force = true})
    add_mxflags("-Werror=unguarded-availability-new", {force = true})
    add_mflags("-fobjc-arc", {force = true})
    add_mxflags("-fobjc-arc", {force = true})
    add_mflags("-include", "UIKit/UIKit.h", {force = true})
    add_mxflags("-include", "UIKit/UIKit.h", {force = true})
    add_cxxflags("-std=c++20", {force = true})
    add_mxflags("-std=c++20", {force = true})
    add_cxxflags("-faligned-allocation", {force = true})
    add_mxflags("-faligned-allocation", {force = true})
    on_config(function (target)
        import("core.project.project")
        local root = project.required_package("react-native-screens"):installdir()
        local common = path.join(root, "common", "cpp")
        for _, file in ipairs(table.join(os.files(path.join(root, "ios", "**.m")), os.files(path.join(root, "ios", "**.mm")))) do
            if not path.relative(file, root):startswith("ios/gamma/") then
                target:add("files", file)
            end
        end
        for _, file in ipairs(table.join(os.files(path.join(common, "**.cpp")), os.files(path.join(root, "cpp", "**.cpp")))) do
            target:add("files", file)
        end
        local generated = target:data("rn.codegen.output")
        assert(generated, "the codegen of react-native-screens did not run, so its generated sources are missing")
        target:add("files", path.join(generated, "rnscreens", "rnscreens-generated.mm"))
        for _, file in ipairs(os.files(path.join(generated, "react", "renderer", "components", "rnscreens", "*.cpp"))) do
            target:add("files", file)
        end
        for _, dir in ipairs(table.join({path.join(root, "ios")}, os.dirs(path.join(root, "ios", "**")))) do
            if not path.relative(dir, root):startswith("ios/gamma") then
                target:add("includedirs", dir)
            end
        end
        local headers = path.join(target:autogendir(), "rnscreens-headers")
        local flat = path.join(headers, "rnscreens")
        os.rm(headers)
        os.mkdir(flat)
        for _, header in ipairs(table.join(os.files(path.join(common, "**.h")), os.files(path.join(root, "cpp", "**.h")))) do
            local link = path.join(flat, path.filename(header))
            assert(not os.isfile(link), path.filename(header) .. " is in two folders of rnscreens")
            os.ln(header, link)
        end
        target:add("includedirs", headers, flat, common)
    end)
target_end()
