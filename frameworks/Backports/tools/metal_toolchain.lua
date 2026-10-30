PIN = {
    version = "27B47",
    metal = "32023.922",
    sha256 = "9a7f61869f1ec662b69634db473f81d7b18f947e9cd81601d4b2825f903b6265",
}

ENVIRONMENT = "REVENANT_METAL_TOOLCHAIN_DMG"

function mountPoint()
    return path.join(os.getenv("HOME"), "Library", "Caches", "revenant", "metal-toolchain", "mount")
end

function binDirectory(mount)
    return path.join(mount, "Metal.xctoolchain", "usr", "bin")
end

function verify(dmg)
    if not PIN.sha256 or PIN.sha256 == "" then
        raise("metal-toolchain: no sha256 is pinned, so the image cannot be verified")
    end
    if not dmg or dmg == "" then
        raise("metal-toolchain: set " .. ENVIRONMENT .. " to the exported MetalToolchain .dmg")
    end
    if not os.isfile(dmg) then
        raise("metal-toolchain: " .. dmg .. " is not a file")
    end
    local digest = hash.sha256(dmg)
    if digest ~= PIN.sha256 then
        raise("metal-toolchain: " .. dmg .. " is not the pinned image (sha256 " .. digest .. ")")
    end
end

function mount(dmg, where)
    if not dmg or dmg == "" then
        dmg = os.getenv(ENVIRONMENT)
    end
    verify(dmg)
    where = where or mountPoint()
    if not os.isfile(path.join(binDirectory(where), "metal")) then
        os.mkdir(where)
        os.vrunv("hdiutil", {"attach", "-readonly", "-nobrowse", "-noverify", "-mountpoint", where, dmg})
    end
    local bin = binDirectory(where)
    if not os.isfile(path.join(bin, "metal")) or not os.isfile(path.join(bin, "metallib")) then
        raise("metal-toolchain: " .. where .. " does not hold the Metal compiler after the mount")
    end
    return bin
end
