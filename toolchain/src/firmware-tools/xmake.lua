if get_config("component") ~= "" or is_plat("iphoneos") then
    return
end

target("revenant-firmware")
    set_kind("binary")
    set_plat("macosx")
    set_arch("arm64")
    set_default(false)
    on_build(function (target)
        os.mkdir(path.directory(target:targetfile()))
        os.vrunv("xcrun", {"swiftc", "-O", path.join(target:scriptdir(), "src", "revenant-firmware.swift"), "-o", target:targetfile()})
    end)
