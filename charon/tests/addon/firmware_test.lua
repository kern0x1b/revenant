import("fixtures")

-- A system image as harvest sees it once mounted: one armv7 shared cache holding the given bytes.
local function image(folder, name, bytes)
    local mount = path.join(folder, name)
    io.writefile(path.join(mount, "System", "Library", "Caches", "com.apple.dyld", "dyld_shared_cache_armv7"), bytes)
    return mount
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local home = os.getenv("CHARON_HOME")
    os.setenv("CHARON_HOME", path.join(folder, "home"))
    local firmware = import("apple.firmware", {rootdir = opt.modules, anonymous = true})
    local dyld = import("apple.dyld", {rootdir = opt.modules, anonymous = true})
    local held = path.join(dyld.root(), "9.9", "dyld_shared_cache_armv7")
    local outside = dyld.outside_source(path.directory(held), "armv7")
    local first, other = {identifier = "iPad2,4", build = "99A1"}, {identifier = "iPhone4,1", build = "99A1"}

    local taken = firmware.harvest(image(folder, "first", "the cache of one firmware"), "9.9", first, "armv7")
    if table.concat(taken, " ") ~= "armv7" or io.readfile(held) ~= "the cache of one firmware" then
        table.insert(found, "a release with no cache takes the image's")
    end
    if not os.isdir(outside) then
        table.insert(found, "taking a cache takes the libraries beside it, even when there are none")
    end
    if not os.isfile(held .. ".source") or io.readfile(held .. ".source") ~= "iPad2,4 99A1\n" then
        table.insert(found, "a cache taken records the firmware it came from")
    end

    -- The same cache from another firmware is the same release: kept, and its libraries taken.
    os.tryrm(outside)
    local errors = fixtures.refusal(function () firmware.harvest(image(folder, "same", "the cache of one firmware"), "9.9", other, "armv7") end)
    if errors or not os.isdir(outside) then
        table.insert(found, "an image carrying the held cache is accepted: " .. tostring(errors))
    end

    -- Another cache is another firmware's: the held one is the ladder every gate reads.
    os.tryrm(outside)
    local refused
    taken, refused = firmware.harvest(image(folder, "another", "the cache of another firmware"), "9.9", other, "armv7")
    if taken or not refused or not refused:find("iPhone4,1 99A1", 1, true) then
        table.insert(found, "an image carrying another cache than the held one is refused by the firmware's name: " .. tostring(refused))
    end
    if io.readfile(held) ~= "the cache of one firmware" then
        table.insert(found, "a held cache is never written over")
    end
    if os.isdir(outside) then
        table.insert(found, "the libraries of a refused image are not taken")
    end

    -- An image with no cache of the requested architecture is not its firmware, and touches nothing.
    local none = path.join(folder, "none")
    io.writefile(path.join(none, "System", "Library", "Caches", "com.apple.dyld", "dyld_shared_cache_armv7s"), "an armv7s cache")
    local kind
    taken, refused, kind = firmware.harvest(none, "9.9", other, "armv7")
    if taken or kind ~= "absent" or os.isfile(path.join(path.directory(held), "dyld_shared_cache_armv7s")) then
        table.insert(found, "an image carrying no cache of the requested architecture is refused as absent, taking nothing: " .. tostring(refused))
    end

    -- The held cache of the requested architecture decides; another architecture's held cache is kept.
    local both = path.join(dyld.root(), "9.7")
    io.writefile(path.join(both, "dyld_shared_cache_armv7s"), "the held armv7s cache")
    io.writefile(path.join(both, "dyld_shared_cache_arm64"), "the held arm64 cache")
    local mixed = path.join(folder, "mixed")
    io.writefile(path.join(mixed, "System", "Library", "Caches", "com.apple.dyld", "dyld_shared_cache_armv7s"), "the held armv7s cache")
    io.writefile(path.join(mixed, "System", "Library", "Caches", "com.apple.dyld", "dyld_shared_cache_arm64"), "another arm64 cache")
    taken, refused = firmware.harvest(mixed, "9.7", other, "armv7s")
    if not taken or table.concat(taken, " ") ~= "armv7s" or io.readfile(path.join(both, "dyld_shared_cache_arm64")) ~= "the held arm64 cache" then
        table.insert(found, "an image carrying the held cache of the requested architecture is taken, and another architecture's held cache is kept: " .. tostring(refused))
    end

    -- A universal static library beside the cache is fat around an ar archive: no image, no library,
    -- and no reason to refuse the image (7.0's usr/lib/libQMIParser.a).
    local archive = image(folder, "archive", "the cache of one firmware")
    local fat = string.pack(">I4I4i4i4I4I4I4", 0xcafebabe, 1, 12, 9, 28, 16, 2) .. "!<arch>\n" .. string.rep("\0", 8)
    io.writefile(path.join(archive, "usr", "lib", "libArchive.a"), fat)
    os.tryrm(outside)
    errors = fixtures.refusal(function () firmware.harvest(archive, "9.9", first, "armv7") end)
    if errors or not os.isdir(outside) or os.isfile(path.join(outside, "usr", "lib", "libArchive.a")) then
        table.insert(found, "a fat static library beside the cache is neither a library taken nor a failure: " .. tostring(errors))
    end

    -- A system image's files are HFS-compressed, and a library beside the cache whose compressed data
    -- is large (TSReading beside 10.3.4's) comes out of os.cp flagged compressed with no data. The
    -- library is an armv7 dylib padded with random-looking bytes printed in hex, as xxd -p prints
    -- them, which ditto compresses to about 2.4 MB on an HFS+ image.
    local name = "/usr/lib/libLarge.dylib"
    local command = string.pack("<I4I4I4I4I4I4", 0xD, 24 + 24, 24, 0, 0x10000, 0x10000) .. name .. string.rep("\0", 24 - #name)
    local library = string.pack("<I4i4i4I4I4I4I4", 0xfeedface, 12, 9, 6, 1, #command, 0) .. command
    local padding, state = {}, 1
    for _ = 1, 50000 do
        local line = {}
        for _ = 1, 30 do
            state = (state * 1103515245 + 12345) & 0xFFFFFFFF
            table.insert(line, string.format("%02x", state >> 24))
        end
        table.insert(padding, table.concat(line) .. "\n")
    end
    library = library .. table.concat(padding)
    local plain = path.join(folder, "libLarge.dylib")
    io.writefile(plain, library, {encoding = "binary"})
    local hfs, volume = path.join(folder, "hfs.dmg"), path.join(folder, "hfs")
    os.vrunv("hdiutil", {"create", "-quiet", "-size", "40m", "-fs", "HFS+", "-volname", "charon", "-type", "UDIF", hfs})
    os.mkdir(volume)
    os.vrunv("hdiutil", {"attach", "-quiet", "-nobrowse", "-mountpoint", volume, hfs})
    try {
        function ()
            io.writefile(path.join(volume, "System", "Library", "Caches", "com.apple.dyld", "dyld_shared_cache_armv7"), "the cache of one firmware")
            os.mkdir(path.join(volume, "usr", "lib"))
            os.vrunv("ditto", {"--hfsCompression", plain, path.join(volume, "usr", "lib", "libLarge.dylib")})
            local flags = tonumber(os.iorunv("stat", {"-f", "%Xf", path.join(volume, "usr", "lib", "libLarge.dylib")}):trim(), 16)
            if flags & 0x20 == 0 then
                table.insert(found, "the fixture library is not HFS-compressed on the image, so the copy is not tested")
            end
            os.tryrm(outside)
            errors = fixtures.refusal(function () firmware.harvest(volume, "9.9", first, "armv7") end)
            local taken, bytes = path.join(outside, "usr", "lib", "libLarge.dylib"), nil
            local unread = errors or fixtures.refusal(function () bytes = io.readfile(taken, {encoding = "binary"}) end)
            if unread or bytes ~= library then
                table.insert(found, "a compressed library beside the cache is taken readable, byte for byte: " .. (unread or "the bytes differ"))
            end
        end,
        finally {
            function ()
                os.vrunv("hdiutil", {"detach", "-quiet", volume})
            end
        }
    }

    -- A tree unpacked from an IPS image carries the image's own permissions, and `dev` in a 6.1.3
    -- root filesystem is dr-xr-xr-x: a removal cannot empty it, because unlinking an entry inside a
    -- directory needs write permission on that directory. So the tree the libraries are taken into
    -- cannot be removed, and moving the staged tree onto its name nests it inside instead -- which is
    -- what left this machine's own 6.1.3 root filesystem holding a 6.1.3_10B329.partial/ inside
    -- 6.1.3_10B329/ on 2026-10-03. The libraries must land in the folder itself.
    os.tryrm(outside)
    os.mkdir(path.join(outside, "dev"))
    io.writefile(path.join(outside, "dev", "placeholder"), "an entry a removal cannot unlink")
    os.vrunv("chmod", {"555", path.join(outside, "dev")}) -- dr-xr-xr-x, as the image has it
    local readonly = image(folder, "readonly", "the cache of one firmware")
    -- a library beside the cache, and a real one: the same Mach-O the HFS case above built and
    -- macho.is_macho and shared_library both accept, because bytes that are not a Mach-O are not
    -- taken and this case would pass for the wrong reason.
    io.writefile(path.join(readonly, "usr", "lib", "libInside.dylib"),
                 io.readfile(plain, {encoding = "binary"}), {encoding = "binary"})
    taken = firmware.harvest(readonly, "9.9", first, "armv7")
    local landed = path.join(outside, "usr", "lib", "libInside.dylib")
    if not taken or not os.isfile(landed) then
        table.insert(found, "a folder that cannot be removed is replaced and not nested into: the library is at "
                    .. landed .. " and not below a staged tree inside it")
    end
    if os.exists(outside .. ".partial") or os.exists(outside .. ".replaced") then
        table.insert(found, "a folder replaced through a tree that cannot be removed leaves no staging tree beside it")
    end
    os.tryrm(outside)

    -- A held armv7s cache of iOS 10 came with the arm64 one from a 64-bit device's image: its
    -- libraries come from that firmware, found among the architectures the folder holds, though the
    -- armv7s devices are listed first; neither needs a download while both root filesystems are here.
    local json = import("core.base.json")
    json.savefile(path.join(folder, "home", "firmware", "catalog.json"), {sources = firmware.sources(), devices = {
        {identifier = "iPhone5,1", platform = "s5l8950x", firmwares = {{version = "9.8", build = "98A1", url = "https://example.invalid/a.ipsw", size = 1}}},
        {identifier = "iPhone6,1", platform = "s5l8960x", firmwares = {{version = "9.8", build = "98A1", url = "https://example.invalid/b.ipsw", size = 2}}}
    }})
    local function rootfs(identifier, caches)
        local root = path.join(folder, "home", "firmware", "rootfs", identifier, "9.8_98A1")
        io.writefile(path.join(root, "System", "Library", "CoreServices", "SystemVersion.plist"), "<plist/>")
        for name, bytes in pairs(caches) do
            io.writefile(path.join(root, "System", "Library", "Caches", "com.apple.dyld", name), bytes)
        end
    end
    rootfs("iPhone5,1", {dyld_shared_cache_armv7s = "the armv7s cache of a 32-bit device"})
    rootfs("iPhone6,1", {dyld_shared_cache_armv7s = "the armv7s cache of a 64-bit device", dyld_shared_cache_arm64 = "its arm64 cache"})
    local ten = path.join(dyld.root(), "9.8")
    io.writefile(path.join(ten, "dyld_shared_cache_armv7s"), "the armv7s cache of a 64-bit device")
    io.writefile(path.join(ten, "dyld_shared_cache_arm64"), "its arm64 cache")
    errors = fixtures.refusal(function () firmware.fetch("armv7s", "9.8", {}) end)
    if errors or not os.isdir(dyld.outside_source(ten, "armv7s")) or io.readfile(path.join(ten, "dyld_shared_cache_armv7s.source")) ~= "iPhone6,1 98A1\n" then
        table.insert(found, "the libraries of a held cache come from the firmware of any architecture that carries it: " .. tostring(errors))
    end

    os.setenv("CHARON_HOME", home or nil)
    os.tryrm(folder)
    return found
end
