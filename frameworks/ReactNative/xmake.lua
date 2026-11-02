if get_config("component") ~= "" and get_config("component") ~= "ReactNative" then
    return
end

target("react-native-inputs")
    set_kind("phony")
    set_default(false)
    add_tests("inputs")
    on_test(function (target, opt)
        local root = os.projectdir()
        local ok = os.execv(os.programfile(), {"l", "-P", root, path.join(os.scriptdir(), "tests", "inputs.lua")}, {try = true, curdir = root})
        if ok ~= 0 then
            opt.errors = "react-native-inputs failed"
        end
        return ok == 0
    end)
target_end()

if os.getenv("RN_DEPS_REPO") then
    add_requires("revenant@folly 2024.11.18.00", {alias = "folly"})
    add_requires("revenant@socketrocket 0.7.1", {alias = "socketrocket"})
end

includes("src/core")
includes("src/expo")
includes("tests")

target("react-native")
    set_kind("phony")
    set_default(false)
    add_tests("coverage")
    on_test(function (target, opt)
        local root = os.projectdir()
        local ok = os.execv(os.programfile(), {"l", "-P", root, path.join(root, "frameworks", "ReactNative", "tests", "coverage_test.lua")}, {try = true, curdir = root})
        if ok ~= 0 then
            opt.errors = "coverage failed"
        end
        return ok == 0
    end)
target_end()

if not is_plat("iphoneos") then
    return
end

local SRC = path.absolute(path.join(os.scriptdir(), "src", "glsl_translator"))

add_requires("revenant@glslang", {alias = "glslang"})
add_requires("revenant@spirv-cross", {alias = "spirv-cross"})

target("revenant-glsl-translator")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/apple-ios")
    set_optimize("smallest")
    add_cxxflags("-std=c++17", "-fexceptions", "-Wall", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability")
    add_files(path.join(SRC, "*.cpp"))
    add_headerfiles(path.join(SRC, "*.h"))
    add_includedirs(SRC, {public = true})
    add_packages("glslang", "spirv-cross", {public = true})
