import("core.base.json")
import("utils.progress")
import("dyld")
import("macho")

PLATFORMS = {
    armv6 = {"s5l8720x", "s5l8900x"},
    armv7 = {"s5l8920x", "s5l8922x", "s5l8930x", "s5l8940x", "s5l8942x", "s5l8945x"},
    armv7s = {"s5l8950x", "s5l8955x"},
    arm64 = {"s5l8960x", "t7000", "t7001", "s8000", "s8001", "s8003", "t8010", "t8011", "t8015"},
    arm64e = {"t8020", "t8027", "t8030", "t8101", "t8103", "t8110", "t8112", "t8120", "t8122", "t8130", "t8132",
              "t8140", "t8142", "t8150", "t8160"}
}

CATALOG = "https://api.ipsw.me/v4"
KEYS = "https://theapplewiki.com/api.php"
CACHE_FOLDER = "System/Library/Caches/com.apple.dyld"
PRODUCTS = {"iPhone", "iPad", "iPod"}
LIBRARY_FOLDERS = {"usr/lib", "System/Library/Frameworks", "System/Library/PrivateFrameworks"}

local function home()
    return path.directory(dyld.root())
end

local function architecture_of(platform)
    for architecture, platforms in pairs(PLATFORMS) do
        if table.contains(platforms, platform) then
            return architecture
        end
    end
end

local function download(url, output, opt)
    opt = opt or {}
    local argv = {"-fsSL", "--retry", "5", "--retry-all-errors", "-A", "charon", "-o", output}
    if opt.range then
        table.join2(argv, {"-r", opt.range})
    end
    table.insert(argv, url)
    os.vrunv("curl", argv)
end

local function fetch_json(url)
    local file = os.tmpfile() .. ".json"
    download(url, file)
    local decoded = json.loadfile(file)
    os.tryrm(file)
    return decoded
end

function sources()
    return {CATALOG, KEYS}
end

local function catalog_file()
    return path.join(home(), "firmware", "catalog.json")
end

local function wiki_firmwares()
    local titles, continue = {}, nil
    repeat
        local listed = fetch_json(KEYS .. "?action=query&list=allpages&apprefix=Firmware/&aplimit=500&format=json" .. (continue and ("&apcontinue=" .. continue:gsub(" ", "_")) or ""))
        for _, page in ipairs(listed.query.allpages) do
            local product = page.title:match("^Firmware/(%a+)")
            if product and table.contains(PRODUCTS, product) then
                table.insert(titles, page.title)
            end
        end
        continue = listed.continue and listed.continue.apcontinue
    until not continue
    local found = {}
    for first = 1, #titles, 50 do
        local batch = table.slice(titles, first, math.min(first + 49, #titles))
        local pages = fetch_json(KEYS .. "?action=query&prop=revisions&rvprop=content&rvslots=main&format=json&titles=" .. table.concat(batch, "|"):gsub(" ", "_"))
        for _, page in pairs(pages.query.pages) do
            local content = page.revisions and page.revisions[1].slots.main["*"] or ""
            local current
            for line in (content .. "\n"):gmatch("([^\n]*)\n") do
                local url = line:match("%[(https?://[^%s%]]+_[Rr]estore%.ipsw)")
                if url then
                    local identifiers, version, build = path.filename(url):match("^(.-)_([%d%.]+)_(%w+)_[Rr]estore%.ipsw$")
                    local listed = {}
                    for identifier in (identifiers or ""):gmatch("%a+%d+,%d+") do
                        table.insert(listed, identifier)
                    end
                    current = #listed > 0 and {identifiers = listed, version = version, build = build:upper(), url = url, size = 0} or nil
                    if current then
                        table.insert(found, current)
                    end
                elseif current and line:match("^|%s*[%d,]+%s*$") then
                    current.size = tonumber((line:gsub("[^%d]", "")))
                    current = nil
                elseif line:startswith("|-") then
                    current = nil
                end
            end
        end
    end
    return found
end

local function refresh_catalog()
    cprint("fetching the firmware catalog from %s and %s", CATALOG, KEYS)
    local devices, by_identifier = {}, {}
    for _, device in ipairs(fetch_json(CATALOG .. "/devices")) do
        local product = device.identifier:match("^(%a+)%d")
        if table.contains(PRODUCTS, product) then
            local listed = fetch_json(CATALOG .. "/device/" .. device.identifier .. "?type=ipsw")
            local firmwares, builds = {}, {}
            for _, firmware in ipairs(listed.firmwares or {}) do
                if firmware.url and firmware.url ~= "" then
                    table.insert(firmwares, {version = firmware.version, build = firmware.buildid:upper(), url = firmware.url, size = firmware.filesize})
                    builds[firmware.buildid:upper()] = true
                end
            end
            local entry = {identifier = device.identifier, platform = device.platform, firmwares = firmwares, builds = builds}
            table.insert(devices, entry)
            by_identifier[device.identifier:lower()] = entry
        end
    end
    for _, firmware in ipairs(wiki_firmwares()) do
        for _, identifier in ipairs(firmware.identifiers) do
            local device = by_identifier[identifier:lower()]
            if device and not device.builds[firmware.build] then
                device.builds[firmware.build] = true
                table.insert(device.firmwares, {version = firmware.version, build = firmware.build, url = firmware.url, size = firmware.size})
            end
        end
    end
    for _, device in ipairs(devices) do
        device.builds = nil
    end
    local catalog = {sources = sources(), devices = devices}
    os.mkdir(path.directory(catalog_file()))
    json.savefile(catalog_file(), catalog)
    return catalog
end

local function releases(catalog, architecture)
    local found = {}
    for _, device in ipairs(catalog.devices) do
        if architecture_of(device.platform) == architecture then
            for _, firmware in ipairs(device.firmwares) do
                table.insert(found, table.join(firmware, {identifier = device.identifier}))
            end
        end
    end
    return found
end

local function unknown_platforms(catalog)
    local unknown = {}
    for _, device in ipairs(catalog.devices) do
        if not architecture_of(device.platform) then
            unknown[device.platform] = true
        end
    end
    return table.orderkeys(unknown)
end

function candidates(architecture, minimum)
    if not PLATFORMS[architecture] then
        raise("no Apple device runs %s; the architectures devices use are %s", architecture, table.concat(table.orderkeys(PLATFORMS), ", "))
    end
    local catalog = os.isfile(catalog_file()) and json.loadfile(catalog_file())
    if catalog and table.concat(catalog.sources or {}, " ") ~= table.concat(sources(), " ") then
        catalog = nil
    end
    local function choose(from)
        local earliest
        for _, firmware in ipairs(releases(from, architecture)) do
            if dyld.compare_versions(firmware.version, minimum) >= 0 and (not earliest or dyld.compare_versions(firmware.version, earliest) < 0) then
                earliest = firmware.version
            end
        end
        local chosen = {}
        for _, firmware in ipairs(releases(from, architecture)) do
            if earliest and firmware.version == earliest then
                table.insert(chosen, firmware)
            end
        end
        table.sort(chosen, function (a, b) return a.size < b.size end)
        return earliest, chosen
    end
    local release, chosen
    if catalog then
        release, chosen = choose(catalog)
    end
    if not release then
        catalog = refresh_catalog()
        release, chosen = choose(catalog)
    end
    if not release then
        local unknown = unknown_platforms(catalog)
        raise("no %s firmware in the catalog of %s is release %s or later%s", architecture, CATALOG, minimum,
              #unknown > 0 and ("; devices on " .. table.concat(unknown, ", ") .. " have no architecture in firmware.PLATFORMS yet") or "")
    end
    return release, chosen
end

function versions(architecture)
    local catalog = os.isfile(catalog_file()) and json.loadfile(catalog_file())
    if not catalog or table.concat(catalog.sources or {}, " ") ~= table.concat(sources(), " ") then
        catalog = refresh_catalog()
    end
    local found = {}
    for _, firmware in ipairs(releases(catalog, architecture)) do
        found[firmware.version] = true
    end
    local listed = table.orderkeys(found)
    table.sort(listed, function (a, b) return dyld.compare_versions(a, b) < 0 end)
    return listed
end

function release_for(architecture, minimum)
    return (candidates(architecture, minimum))
end

local function remote_tail(url, size)
    local file = os.tmpfile()
    download(url, file, {range = "-" .. size})
    local bytes = io.readfile(file, {encoding = "binary"})
    os.tryrm(file)
    return bytes
end

local function remote_range(url, first, count)
    local file = os.tmpfile()
    download(url, file, {range = first .. "-" .. (first + count - 1)})
    local bytes = io.readfile(file, {encoding = "binary"})
    os.tryrm(file)
    if #bytes ~= count then
        raise("%s answered %d bytes for a range of %d; the server does not serve byte ranges", url, #bytes, count)
    end
    return bytes
end

local function zip_members(url)
    local tail = remote_tail(url, 65557)
    local eocd
    for at = #tail - 21, 1, -1 do
        if tail:sub(at, at + 3) == "PK\5\6" then
            eocd = at
            break
        end
    end
    if not eocd then
        raise("%s is not a zip archive", url)
    end
    local entries, directory_size, directory_offset = string.unpack("<I2I4I4", tail, eocd + 10)
    local locator = eocd - 20
    if locator >= 1 and tail:sub(locator, locator + 3) == "PK\6\7" then
        local zip64_offset = string.unpack("<I8", tail, locator + 8)
        local record = remote_range(url, zip64_offset, 56)
        entries, directory_size, directory_offset = string.unpack("<I8I8I8", record, 33)
    end
    local directory = remote_range(url, directory_offset, directory_size)
    local members, at = {}, 1
    for _ = 1, entries do
        if directory:sub(at, at + 3) ~= "PK\1\2" then
            raise("the central directory of %s is damaged", url)
        end
        local method, _, _, crc, compressed, uncompressed, name_length, extra_length, comment_length = string.unpack("<I2I2I2I4I4I4I2I2I2", directory, at + 10)
        local local_offset = string.unpack("<I4", directory, at + 42)
        local name = directory:sub(at + 46, at + 45 + name_length)
        local extra, cursor = directory:sub(at + 46 + name_length, at + 45 + name_length + extra_length), 1
        while cursor + 4 <= #extra do
            local id, size = string.unpack("<I2I2", extra, cursor)
            if id == 1 then
                local field = cursor + 4
                if uncompressed == 0xFFFFFFFF then uncompressed, field = string.unpack("<I8", extra, field) end
                if compressed == 0xFFFFFFFF then compressed, field = string.unpack("<I8", extra, field) end
                if local_offset == 0xFFFFFFFF then local_offset = string.unpack("<I8", extra, field) end
            end
            cursor = cursor + 4 + size
        end
        members[name] = {method = method, crc = crc, compressed = compressed, uncompressed = uncompressed, offset = local_offset}
        at = at + 46 + name_length + extra_length + comment_length
    end
    return members
end

local function fetch_member(url, member, output)
    local header = remote_range(url, member.offset, 30)
    local name_length, extra_length = string.unpack("<I2I2", header, 27)
    local first = member.offset + 30 + name_length + extra_length
    local part = output .. ".part"
    local chunk = 64 * 1024 * 1024
    local done = os.isfile(part) and os.filesize(part) or 0
    while done < member.compressed do
        local count = math.min(chunk, member.compressed - done)
        local piece = os.tmpfile()
        download(url, piece, {range = (first + done) .. "-" .. (first + done + count - 1)})
        if os.filesize(piece) ~= count then
            raise("%s answered %d bytes for a range of %d", url, os.filesize(piece), count)
        end
        local sink = io.open(part, "ab")
        sink:write(io.readfile(piece, {encoding = "binary"}))
        sink:close()
        os.tryrm(piece)
        done = done + count
        progress.show(math.floor(done * 100 / member.compressed), "${color.build.object}downloading %s", path.filename(output))
    end
    if member.method == 0 then
        os.mv(part, output)
    elseif member.method == 8 then
        local gzip = output .. ".gz"
        local sink = io.open(gzip, "wb")
        sink:write("\31\139\8\0\0\0\0\0\0\3")
        sink:close()
        os.vrunv("sh", {"-c", "cat \"$1\" >> \"$2\"", "sh", part, gzip})
        sink = io.open(gzip, "ab")
        sink:write(string.pack("<I4I4", member.crc, member.uncompressed & 0xFFFFFFFF))
        sink:close()
        os.tryrm(part)
        os.vrunv("sh", {"-c", "gzip -dc \"$1\" > \"$2\"", "sh", gzip, output})
        os.tryrm(gzip)
    else
        raise("%s stores %s with compression method %d, which is neither stored nor deflate", url, path.filename(output), member.method)
    end
end

local function plist_values(url, members, name, keypaths)
    if not members[name] then
        return nil
    end
    local file = os.tmpfile() .. ".plist"
    fetch_member(url, members[name], file)
    local values = {}
    for _, keypath in ipairs(keypaths) do
        local value = try { function () return os.iorunv("plutil", {"-extract", keypath, "raw", "-o", "-", file}) end }
        if value and value:trim() ~= "" then
            table.insert(values, value:trim())
        end
    end
    os.tryrm(file)
    return values
end

local function system_images(url, members)
    local images = plist_values(url, members, "BuildManifest.plist",
                                {"BuildIdentities.0.Manifest.Cryptex1,SystemOS.Info.Path", "BuildIdentities.0.Manifest.OS.Info.Path"})
    if images and #images > 0 then
        return images
    end
    images = plist_values(url, members, "Restore.plist", {"SystemRestoreImages.User"})
    if not images or #images == 0 then
        raise("the firmware at %s names its system image in neither BuildManifest.plist nor Restore.plist", url)
    end
    return images
end

local function filevault_key(firmware, image)
    local search = fetch_json(KEYS .. "?action=query&list=search&srnamespace=2304&format=json&srsearch=" ..
                              ("intitle:%s intitle:%s"):format(firmware.build, firmware.identifier):gsub(" ", "+"))
    for _, hit in ipairs(search.query and search.query.search or {}) do
        if hit.title:find(" " .. firmware.build .. " ", 1, true) and hit.title:find(firmware.identifier, 1, true) then
            local page = fetch_json(KEYS .. "?action=query&prop=revisions&rvprop=content&rvslots=main&format=json&titles=" .. hit.title:gsub(" ", "_"))
            for _, found in pairs(page.query.pages) do
                local content = found.revisions[1].slots.main["*"]
                local name = content:match("|%s*RootFS%s*=%s*([%w%-]+)")
                local key = content:match("|%s*RootFSKey%s*=%s*(%x+)")
                if name and key and image:startswith(name) then
                    return key
                end
            end
        end
    end
    raise("%s lists no key for %s of %s %s", KEYS, image, firmware.identifier, firmware.build)
end

local function plain_image(firmware, file)
    local handle = io.open(file, "rb")
    local magic = handle:read(8)
    handle:close()
    if magic == "encrcdsa" then
        local decrypted = file .. ".decrypted"
        os.vrunv(firmware.tool, {"filevault", file, filevault_key(firmware, path.filename(file)), decrypted})
        os.tryrm(file)
        return decrypted
    elseif magic:startswith("AEA1") then
        local key = os.iorunv(firmware.tool, {"aea-key", file}):trim()
        local decrypted = file:gsub("%.aea$", "")
        os.vrunv("aea", {"decrypt", "-i", file, "-o", decrypted, "-key-value", "base64:" .. key})
        os.tryrm(file)
        return decrypted
    end
    return file
end

-- Copies a file out of a mounted system image with ditto, as rootfs() copies the whole image. The
-- image's files are HFS-compressed, and copyfile(3) with COPYFILE_ALL, which os.cp calls, gives a
-- larger one the compressed flag and no data, so it cannot be read at all (TSReading, iWorkImport
-- and FaceCore's .dat beside the caches of 7.0 to 10.3.4; COPYFILE_DATA alone and ditto keep them).
local function copy_out(file, target)
    os.vrunv("ditto", {file, target})
end

local function copy_libraries(mount, destination, accept)
    local copied = 0
    for _, top in ipairs(LIBRARY_FOLDERS) do
        for _, file in ipairs(os.files(path.join(mount, top, "**"))) do
            if macho.is_macho(file) and (not accept or accept(file)) then
                local target = path.join(destination, path.relative(file, mount))
                os.mkdir(path.directory(target))
                copy_out(file, target)
                copied = copied + 1
            end
        end
    end
    return copied
end

local function cache_folder(mount)
    for _, root in ipairs(table.join({mount}, os.dirs(path.join(mount, "*")))) do
        if os.isdir(path.join(root, CACHE_FOLDER)) then
            return path.join(root, CACHE_FOLDER)
        end
    end
end

-- Whether a Mach-O file is a shared library: one image of it names itself (LC_ID_DYLIB), which no
-- daemon, XPC service or other executable beside the libraries does.
local function shared_library(file)
    local images = try {
        function ()
            return macho.images(macho.read(file))
        end,
        catch {
            function (errors)
                raise("%s: %s", file, tostring(errors))
            end
        }
    }
    for _, image in ipairs(images) do
        if image.identity then
            return true
        end
    end
    return false
end

-- The libraries a system image carries as files beside its shared cache, for each architecture the
-- cache was taken for: on a cache image every library in the cache is gone from the disk, so the
-- shared libraries copy_libraries finds there are exactly what the cache lacks.
-- Empties a tree unpacked from an IPS image, and says whether it could. Those trees carry the
-- permissions the image gave them and `dev` in a 6.1.3 root filesystem is dr-xr-xr-x, so a removal
-- cannot empty it: unlinking an entry inside a directory needs write permission on the directory
-- itself, which that one does not give. Everything is made writable first and only then removed,
-- and the answer is the removal's own, so a caller can say what is left instead of stepping over it.
local function empty_tree(folder)
    -- chmod(1) and not os.chmod, which this xmake does not carry. Everything is made writable by its
    -- owner first, recursively, because a removal cannot unlink an entry inside a directory that does
    -- not give write permission, and one directory in the tree is enough for the whole removal to
    -- stop at it.
    os.vrunv("chmod", {"-R", "u+w", folder})
    os.tryrm(folder)
    return not os.exists(folder)
end

-- Puts a staged tree where a tree is expected, over whatever is there. The obvious pair of calls is
-- wrong here on this machine's own store, measured 2026-10-03, where 6.1.3_10B329/ held a nested
-- 6.1.3_10B329.partial/ and a System/ but no SystemVersion.plist:
--
--   * a tree unpacked from an IPS image carries the image's own permissions and `dev` in a 6.1.3 root
--     filesystem is dr-xr-xr-x, so os.tryrm(folder) stops at it and says nothing;
--   * os.mv(staging, folder) with `folder` a directory that is still there moves the staged tree
--     INSIDE it, which is the nesting that was measured -- and the run after that unpacked every
--     image again and nested it once more;
--   * and os.mv of the whole folder is no way out either: measured, moving a tree that holds a
--     read-only directory fails the same way a removal of it does.
--
-- So the tree that is there is emptied FIRST, and the staged tree is moved in only once the folder is
-- gone. A removal that stops half way therefore leaves the store holding what it held, rather than
-- half of one tree beside another or the new one inside the old; and both steps are checked by what
-- the store holds afterwards, because os.mv and os.tryrm answer nothing worth asking.
local function place_tree(staging, folder)
    if os.exists(folder) and not empty_tree(folder) then
        raise("%s could not be cleared, so %s is not put in place and the store still holds what it held",
              folder, staging)
    end
    os.mv(staging, folder)
    if os.exists(staging) or not os.isdir(folder) then
        raise("cannot move %s into place at %s, so the store holds neither", staging, folder)
    end
end

local function take_outside(root, folder, architectures)
    for _, architecture in ipairs(architectures) do
        local outside = dyld.outside_source(folder, architecture)
        local staging = outside .. ".partial"
        os.tryrm(staging)
        os.mkdir(staging)
        copy_libraries(root, staging, shared_library)
        place_tree(staging, outside)
    end
end

local function same_file(first, second)
    return os.filesize(first) == os.filesize(second) and hash.sha256(first) == hash.sha256(second)
end

-- Takes the shared caches of a mounted system image (or an unpacked root filesystem) into the
-- release's folder, with the libraries beside them. A cache already held is the ladder every gate
-- reads, chosen when it was first taken, and is never written over. Where the folder holds the
-- cache of architecture, the image is refused unless it carries that very cache: refused as absent
-- when it carries none (another system image of the same firmware may), as another when it carries
-- a different one. Another architecture's cache is taken only where none is held. Returns the
-- architectures taken, or nil, the refusal and "absent" or "another".
function harvest(mount, release, firmware, architecture)
    local folder = path.join(dyld.root(), release)
    local caches = cache_folder(mount)
    local wanted = architecture and path.join(folder, "dyld_shared_cache_" .. architecture)
    if wanted and os.isfile(wanted) then
        local carried = caches and path.join(caches, path.filename(wanted))
        if not carried or not os.isfile(carried) then
            return nil, string.format("%s %s carries no %s", firmware.identifier, firmware.build, path.filename(wanted)), "absent"
        elseif not same_file(carried, wanted) then
            return nil, string.format("%s %s carries another %s than the one held for iOS %s (%s), which is kept",
                                      firmware.identifier, firmware.build, path.filename(wanted), release, wanted), "another"
        end
        firmware.carries_held = true
    end
    local found = {}
    for _, file in ipairs(caches and os.files(path.join(caches, "dyld_shared_cache_*")) or {}) do
        local name = path.filename(file)
        if not name:find("%.symbols$") and not name:find("%.map$") and not name:find("%.atlas$") then
            local held = path.join(folder, name)
            local taken = false
            if not os.isfile(held) then
                os.mkdir(folder)
                copy_out(file, held .. ".partial")
                os.mv(held .. ".partial", held)
                taken = true
            elseif same_file(file, held) then
                taken = true
            end
            local cached = name:match("^dyld_shared_cache_([%w_]+)$")
            if taken and cached then
                io.writefile(held .. ".source", firmware.identifier .. " " .. firmware.build .. "\n")
                table.insert(found, cached)
            end
        end
    end
    take_outside(mount, folder, found)
    return found
end

local function mount_and_harvest(image, release, architecture, firmware)
    local mount = image .. ".mount"
    os.mkdir(mount)
    os.vrunv("hdiutil", {"attach", "-readonly", "-nobrowse", "-noverify", "-noautoopen", "-mountpoint", mount, image})
    -- xmake's try without a catch returns nil and drops the error, which then read as "holds no
    -- shared cache" for every firmware of the release: the error is kept and raised once detached.
    local found, refused, kind, failure
    try {
        function ()
            found, refused, kind = harvest(mount, release, firmware, architecture)
            if refused then
                return
            end
            if #found == 0 and os.isdir(path.join(mount, LIBRARY_FOLDERS[1])) and not cache_folder(mount) then
                local copied = copy_libraries(mount, path.join(dyld.root(), release, "libraries_" .. architecture))
                if copied > 0 then
                    found = {architecture}
                end
            end
        end,
        catch {
            function (errors)
                failure = errors
            end
        },
        finally {
            function ()
                os.vrunv("hdiutil", {"detach", mount})
                os.tryrm(mount)
            end
        }
    }
    if failure then
        raise(failure)
    end
    return found, refused, kind
end

-- The firmwares that can have carried a held cache, in the order to try them. harvest records the
-- firmware beside each cache it takes (<cache>.source); where it did, that one alone. Otherwise an
-- image carries a cache for each architecture its device runs - a 64-bit device of iOS 10 carries
-- armv7s beside arm64, and the armv7s caches of 10.x came that way - so the firmwares of every
-- architecture whose cache the release's folder holds can be it. Those come first, since a cache
-- held beside another architecture's was most likely taken from the same image; the requested
-- architecture's firmwares follow. The order only saves downloads: the bytes decide.
local function held_candidates(architecture, release, firmwares, folder, held)
    local recorded = os.isfile(held .. ".source") and io.readfile(held .. ".source"):trim()
    local ordered, seen = {}, {}
    local function add(list)
        for _, firmware in ipairs(list) do
            local key = firmware.identifier .. " " .. firmware.build
            if firmware.version == release and not seen[key] and (not recorded or key == recorded) then
                seen[key] = true
                table.insert(ordered, firmware)
            end
        end
    end
    for _, file in ipairs(os.files(path.join(folder, "dyld_shared_cache_*"))) do
        local other = path.filename(file):match("^dyld_shared_cache_([%w_]+)$")
        if other and other ~= architecture and PLATFORMS[other] then
            local _, more = candidates(other, release)
            add(more)
        end
    end
    add(firmwares)
    return ordered
end

-- Where rootfs() unpacks one firmware's root filesystem, and whether it is complete there.
local function rootfs_folder(firmware)
    return path.join(home(), "firmware", "rootfs", firmware.identifier, firmware.version .. "_" .. firmware.build)
end

local function unpacked(firmware)
    local folder = rootfs_folder(firmware)
    return os.isfile(path.join(folder, "System", "Library", "CoreServices", "SystemVersion.plist")) and folder or nil
end

function fetch(architecture, minimum, opt)
    opt = opt or {}
    local release, firmwares = candidates(architecture, minimum)
    local folder = path.join(dyld.root(), release)
    local held = dyld.held_source(folder, architecture)
    if held and (os.isdir(held) or os.isdir(dyld.outside_source(folder, architecture))) then
        return held, release
    end
    -- A cache taken before the libraries beside it were: they come from the firmware that cache is,
    -- found by its root filesystem where one is unpacked, else by harvest refusing every image whose
    -- cache is another. Which firmware a cache was first taken from is not recorded, and the smallest
    -- is not always it (6.1.3's is iPhone4,1's, from an unpacked root filesystem).
    if held then
        firmwares = held_candidates(architecture, release, firmwares, folder, held)
        for _, firmware in ipairs(firmwares) do
            local root = unpacked(firmware)
            local caches = root and cache_folder(root)
            local cache = caches and path.join(caches, path.filename(held))
            if cache and os.isfile(cache) and same_file(cache, held) then
                io.writefile(held .. ".source", firmware.identifier .. " " .. firmware.build .. "\n")
                cprint("${bright}taking the libraries of iOS %s for %s outside its shared cache${clear} from the root filesystem of %s %s", release, architecture, firmware.identifier, firmware.build)
                take_outside(root, folder, {architecture})
                return held, release
            end
        end
    end
    local tool = assert(opt.tool, "fetching firmware needs the charon-firmware tool")
    local failures = {}
    local function failed(firmware, reason)
        table.insert(failures, firmware.identifier .. " " .. firmware.build .. ": " .. reason)
        cprint("${color.warning}%s %s did not yield the %s libraries of iOS %s:${clear} %s", firmware.identifier, firmware.build, architecture, release, reason)
    end
    for _, firmware in ipairs(firmwares) do
        local refusal, broken
        local work = path.join(home(), "firmware", "work", firmware.identifier .. "_" .. firmware.build)
        local ok = try {
            function ()
                firmware.tool = tool
                cprint("${bright}fetching iOS %s for %s from %s %s${clear} (%s)", release, architecture, firmware.identifier, firmware.build, firmware.url)
                os.mkdir(work)
                local members = zip_members(firmware.url)
                local harvested = {}
                for _, name in ipairs(system_images(firmware.url, members)) do
                    if members[name] then
                        local file = path.join(work, path.filename(name))
                        if not os.isfile(file) then
                            fetch_member(firmware.url, members[name], file)
                        end
                        local image = plain_image(firmware, file)
                        local taken, refused, kind = mount_and_harvest(image, release, architecture, firmware)
                        os.tryrm(image)
                        if refused then
                            refusal = refused
                            if kind == "another" then
                                return false
                            end
                        end
                        table.join2(harvested, taken or {})
                        if table.contains(harvested, architecture) then
                            break
                        end
                    end
                end
                if refusal and not table.contains(harvested, architecture) then
                    return false
                end
                if not table.contains(harvested, architecture) then
                    raise("%s %s holds %s, not %s", firmware.identifier, firmware.build,
                          #harvested > 0 and table.concat(harvested, ", ") or "no shared cache or libraries", architecture)
                end
                return true
            end,
            catch {
                function (errors)
                    broken = tostring(errors)
                end
            },
            finally {
                function ()
                    os.tryrm(work)
                end
            }
        }
        if ok then
            return dyld.held_source(path.join(dyld.root(), release), architecture), release
        end
        failed(firmware, refusal or broken)
        -- This image carried the held cache and failed after it was matched. Whether another
        -- firmware carries the same bytes is known only once it is downloaded (7.0 has fifteen, and
        -- 6.1.3's iPhone2,1 carries another cache), so fetch stops on this failure rather than try them.
        if broken and firmware.carries_held then
            raise("%s %s carries the cache held for iOS %s and did not yield the %s libraries beside it:\n  %s",
                  firmware.identifier, firmware.build, release, architecture, table.concat(failures, "\n  "))
        end
    end
    raise("no firmware of iOS %s yielded the %s system libraries:\n  %s", release, architecture, table.concat(failures, "\n  "))
end

function source(architecture, minimum)
    local release = release_for(architecture, minimum)
    local folder = path.join(dyld.root(), release)
    local held = dyld.held_source(folder, architecture)
    if held then
        return held, release
    end
    local expected = dyld.compare_versions(release, "3.1") < 0 and "libraries_" or "dyld_shared_cache_"
    return path.join(folder, expected .. architecture), release
end

function ensure(architecture, minimum, opt)
    local held, release = source(architecture, minimum)
    if os.exists(held) then
        return held, release
    end
    local _, firmwares = candidates(architecture, minimum)
    local accepted = utils.confirm({default = true, description = string.format(
        "the imports of this %s build are checked against iOS %s, the earliest %s release not older than %s, whose system libraries are not under %s yet; fetch them from Apple's firmware %s %s (%d MB, only its system image is downloaded)",
        architecture, release, architecture, minimum, dyld.root(), firmwares[1].identifier, firmwares[1].build, math.floor(firmwares[1].size / 1048576))})
    if not accepted then
        raise("the imports of this %s build cannot be checked without the libraries of iOS %s; run xmake firmware --arch=%s fetch %s", architecture, release, architecture, release)
    end
    return fetch(architecture, minimum, opt)
end

function architecture(platform)
    return architecture_of(platform)
end

function catalog()
    local loaded = os.isfile(catalog_file()) and json.loadfile(catalog_file())
    if not loaded or table.concat(loaded.sources or {}, " ") ~= table.concat(sources(), " ") then
        loaded = refresh_catalog()
    end
    return loaded
end

function device_releases(identifier)
    local listed = catalog()
    for _, device in ipairs(listed.devices) do
        if device.identifier:lower() == identifier:lower() then
            return device
        end
    end
    local known = {}
    for _, device in ipairs(listed.devices) do
        table.insert(known, device.identifier)
    end
    raise("the firmware catalog knows no device %s; it knows %s", identifier, table.concat(known, ", "))
end

function device_firmware(identifier, minimum)
    local device = device_releases(identifier)
    local chosen
    for _, firmware in ipairs(device.firmwares) do
        if dyld.compare_versions(firmware.version, minimum) >= 0 and (not chosen or dyld.compare_versions(firmware.version, chosen.version) < 0) then
            chosen = firmware
        end
    end
    if not chosen then
        raise("%s has no firmware of release %s or later in the catalog", device.identifier, minimum)
    end
    return table.join(chosen, {identifier = device.identifier, platform = device.platform, architecture = architecture_of(device.platform)})
end

local function copy_tree(image, destination)
    local mount = image .. ".mount"
    os.mkdir(mount)
    os.vrunv("hdiutil", {"attach", "-readonly", "-nobrowse", "-noverify", "-noautoopen", "-mountpoint", mount, image})
    try {
        function ()
            os.mkdir(destination)
            os.vrunv("ditto", {mount, destination})
        end,
        finally {
            function ()
                os.vrunv("hdiutil", {"detach", mount})
                os.tryrm(mount)
            end
        }
    }
end

function rootfs(identifier, minimum, opt)
    opt = opt or {}
    local firmware = device_firmware(identifier, minimum)
    local folder = rootfs_folder(firmware)
    if os.isfile(path.join(folder, "System", "Library", "CoreServices", "SystemVersion.plist")) then
        return folder, firmware
    end
    firmware.tool = assert(opt.tool, "unpacking firmware needs the charon-firmware tool")
    cprint("${bright}unpacking the root filesystem of %s %s (%s)${clear} from %s", firmware.identifier, firmware.version, firmware.build, firmware.url)
    local work = path.join(home(), "firmware", "work", firmware.identifier .. "_" .. firmware.build)
    local staging = folder .. ".partial"
    -- A staged tree that already holds the release's own SystemVersion.plist is one this store
    -- unpacked and a run did not move into place, which is what an interrupted run and the nesting
    -- above both leave. Unpacking every image of the firmware again to arrive at the same tree is the
    -- whole cost of repairing one, and the images are hundreds of megabytes.
    if os.isfile(path.join(staging, "System", "Library", "CoreServices", "SystemVersion.plist")) then
        print("note the staged root filesystem of %s %s is already unpacked at %s; it is put in place as it is",
              firmware.identifier, firmware.build, staging)
        place_tree(staging, folder)
        return folder, firmware
    end
    os.tryrm(staging)
    os.mkdir(work)
    local members = zip_members(firmware.url)
    local images = system_images(firmware.url, members)
    for index = #images, 1, -1 do
        local name = images[index]
        if members[name] then
            local file = path.join(work, path.filename(name))
            if not os.isfile(file) then
                fetch_member(firmware.url, members[name], file)
            end
            local image = plain_image(firmware, file)
            local destination = staging
            if index < #images then
                destination = path.join(staging, "System", "Cryptexes", "OS")
            end
            copy_tree(image, destination)
            os.tryrm(image)
        end
    end
    os.tryrm(work)
    if not os.isfile(path.join(staging, "System", "Library", "CoreServices", "SystemVersion.plist")) then
        raise("the system image of %s %s holds no System/Library/CoreServices/SystemVersion.plist", firmware.identifier, firmware.build)
    end
    place_tree(staging, folder)
    if not os.isfile(path.join(folder, "System", "Library", "CoreServices", "SystemVersion.plist")) then
        -- the completeness check again, on the folder rather than on the staged tree: a move that
        -- nested instead of replacing leaves the staged tree inside the folder and the folder's own
        -- tree beside it, which passes every check made before the move and is a store nothing can
        -- read. Named here, where the store is, instead of by the next run's symptoms.
        raise("the root filesystem of %s %s is not in place at %s after the move, so the store holds a tree nothing can read",
              firmware.identifier, firmware.build, folder)
    end
    return folder, firmware
end
