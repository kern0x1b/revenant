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
