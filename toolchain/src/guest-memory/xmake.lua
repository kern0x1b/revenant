if get_config("component") ~= "" or not is_plat("iphoneos") then
    return
end

local SRC = os.scriptdir()

target("guest-memory")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/apple-ios")
    add_files(path.join(SRC, "src", "guest_memory.c"))
    add_headerfiles(path.join(SRC, "include", "revenant", "guest_memory.h"), {prefixdir = "revenant"})
    add_includedirs(path.join(SRC, "include"), {public = true})
target_end()
