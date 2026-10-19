-- prepare_boot_logo.lua: prepares an original IPSW AppleLogo in the emulator's host cache.
--
--     xmake l tools/prepare_boot_logo.lua SOURCE --host-cache DIR [--device TYPE] [--board CLASS]
--         [--keys FILE] [--imagetool PROGRAM] [--xpwntool PROGRAM]
--
-- SOURCE is an IPSW file or an extracted IPSW directory. Uses XPwn's xpwntool/imagetool for firmware codecs; never
-- modifies the rootfs.
--
-- This replaces tools/prepare_boot_logo.py. Zip members are read with unzip, plists are converted with plutil, and
-- digests come from shasum. Differences: a tool that runs past 60 seconds is killed by perl's alarm and reported as a
-- failed tool, not as a timeout; and the keys file is checked before the firmware member is copied, so when both are
-- wrong the keys error is the one reported.

local json = import("core.base.json")

local MAX_ASSET = 16 * 1024 * 1024
local TOOL_SECONDS = 60

-- the directory being written, removed when an error ends the run, as the Python's TemporaryDirectory was
local scratch = nil

local function fail(message)
    if scratch then
        os.rm(scratch)
    end
    io.stderr:write("boot logo: " .. message .. "\n")
    os.exit(1)
end

local function usage(message)
    io.stderr:write("usage: prepare_boot_logo.lua SOURCE --host-cache DIR [--device TYPE] [--board CLASS] [--keys FILE]\n")
    io.stderr:write("prepare_boot_logo.lua: error: " .. message .. "\n")
    os.exit(2)
end

-- runs program with args under /bin/sh and returns its standard output without the status the wrapper appends, its
-- standard error and its exit status. Never raises: a failure is a status. The output is text; binary data goes to a
-- file instead, because os.iorunv does not keep the bytes of binary output.
local function run(program, args)
    local argv = {"-c", '"$@"; printf "\\n%s" "$?"', "sh", program}
    for _, arg in ipairs(args) do
        argv[#argv + 1] = arg
    end
    local stdout, stderr = os.iorunv("/bin/sh", argv)
    local body, status = string.match(stdout, "^(.*)\n(%d+)$")
    return body, tonumber(status), stderr
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function is_empty(t)
    for _ in pairs(t) do
        return false
    end
    return true
end

local function starts_with(s, prefix)
    return string.sub(s, 1, #prefix) == prefix
end

-- PurePosixPath(name).is_absolute() or ".." in its parts
local function unsafe_path(name)
    if starts_with(name, "/") then
        return true
    end
    for part in string.gmatch(name, "[^/]+") do
        if part == ".." then
            return true
        end
    end
    return false
end

local function basename(name)
    return string.match(name, "([^/]*)$")
end

-- the suffix of a name as PurePosixPath.suffix gives it: from its last dot, when the dot is inside the name
local function suffix(name)
    return string.match(basename(name), "^.+(%.[^.]*)$") or ""
end

-- the bytes of a file, read as binary
local function read_binary(file)
    local stream = io.open(file, "rb")
    local data = stream:read("a")
    stream:close()
    return data
end

local function write_binary(file, data)
    local stream = io.open(file, "wb")
    stream:write(data)
    stream:close()
end

-- the SHA-256 of a file, from shasum
local function sha256(file)
    local body, status = run("shasum", {"-a", "256", file})
    if status ~= 0 then
        fail("cannot hash " .. file)
    end
    return string.match(body, "^(%x+)")
end

local JSON_ESCAPES = {
    [34] = '\\"', [92] = "\\\\", [8] = "\\b", [9] = "\\t", [10] = "\\n", [12] = "\\f", [13] = "\\r",
}

-- the JSON string of a UTF-8 value, escaped the way json.dumps escapes one with its default ensure_ascii: controls
-- and everything above ASCII become \uXXXX, with a surrogate pair above the BMP
local function json_string(value)
    local out = {}
    for _, code in utf8.codes(value) do
        if JSON_ESCAPES[code] then
            out[#out + 1] = JSON_ESCAPES[code]
        elseif code >= 0x20 and code < 0x80 then
            out[#out + 1] = string.char(code)
        elseif code < 0x10000 then
            out[#out + 1] = string.format("\\u%04x", code)
        else
            local rest = code - 0x10000
            out[#out + 1] = string.format("\\u%04x\\u%04x", 0xD800 + (rest >> 10), 0xDC00 + (rest & 0x3FF))
        end
    end
    return '"' .. table.concat(out) .. '"'
end

-- the firmware the logo comes from: an IPSW zip, or an extracted directory
local function open_assets(source)
    local self = {source = source, names = {}}
    if os.isdir(source) then
        self.directory = true
        return self
    end
    if not os.isfile(source) then
        fail("no such IPSW or directory: " .. source)
    end
    local body, status = run("unzip", {"-Z1", source})
    if status ~= 0 then
        fail("IPSW is not a zip archive: " .. source)
    end
    for name in string.gmatch(body, "[^\n]+") do
        self.names[#self.names + 1] = name
    end
    return self
end

local function asset_path(self, name)
    return path.join(self.source, name)
end

local function asset_exists(self, name)
    if self.directory then
        return os.isfile(asset_path(self, name))
    end
    return contains(self.names, name)
end

-- copies a member, which must exist, to the file destination; a member over 16 MiB is refused
local function copy_asset(self, name, destination)
    if unsafe_path(name) then
        fail("invalid firmware asset path")
    end
    if not asset_exists(self, name) then
        fail("no such firmware asset: " .. name)
    end
    if self.directory then
        if os.filesize(asset_path(self, name)) > MAX_ASSET then
            fail("firmware asset exceeds 16 MiB")
        end
        local _, status = run("cp", {asset_path(self, name), destination})
        if status ~= 0 then
            fail("cannot copy firmware asset: " .. name)
        end
    else
        local _, status = run("/bin/sh", {"-c", 'unzip -p "$0" "$1" > "$2"', self.source, name, destination})
        if status ~= 0 then
            fail("cannot read firmware asset: " .. name)
        end
    end
    if os.filesize(destination) > MAX_ASSET then
        fail("firmware asset exceeds 16 MiB")
    end
end

-- a property list as a table, or an empty table when the member is absent
local function asset_plist(self, name)
    if not asset_exists(self, name) then
        return {}
    end
    local body, status
    if self.directory then
        body, status = run("plutil", {"-convert", "json", "-o", "-", asset_path(self, name)})
    else
        body, status = run("/bin/sh", {"-c", 'unzip -p "$0" "$1" | plutil -convert json -o - -', self.source, name})
    end
    if status ~= 0 then
        fail("not a property list: " .. name)
    end
    return json.decode(body)
end

-- the product, the build and the one AppleLogo member of the firmware the arguments select
local function select_logo(assets, device, board)
    local manifest = asset_plist(assets, "BuildManifest.plist")
    if is_empty(manifest) then
        manifest = asset_plist(assets, "BuildManifesto.plist")
    end
    local restore = asset_plist(assets, "Restore.plist")

    local products = manifest.SupportedProductTypes or {}
    if #products == 0 and restore.ProductType and restore.ProductType ~= "" then
        products = {restore.ProductType}
    end
    if device == nil and #products == 1 then
        device = products[1]
    end
    if device == nil or device == "" or (#products > 0 and not contains(products, device)) then
        fail("select a supported --device: " .. table.concat(products, ", "))
    end

    local build = manifest.ProductBuildVersion
    if build == nil or build == "" then
        build = restore.ProductBuildVersion
    end
    for _, value in ipairs({device, build or false}) do
        if type(value) ~= "string" or value == "." or value == ".." or not string.match(value, "^[A-Za-z0-9,._-]+$") then
            fail("missing or invalid firmware product/build metadata")
        end
    end

    -- the distinct logo paths; when there is one, member is that path
    local paths, count, member = {}, 0, nil
    local identities = manifest.BuildIdentities or {}
    for _, identity in ipairs(identities) do
        local device_class = ((identity.Info or {}).DeviceClass or "")
        if not board or board == "" or string.lower(device_class) == string.lower(board) then
            local logo = ((identity.Manifest or {}).AppleLogo or {})
            local logo_path = (logo.Info or {}).Path
            if logo_path and logo_path ~= "" and not paths[logo_path] then
                paths[logo_path] = true
                count = count + 1
                member = logo_path
            end
        end
    end
    if count == 0 and #identities == 0 then
        local names = assets.names
        if assets.directory then
            names = {}
            local body = run("/bin/sh", {"-c", 'cd "$0" 2>/dev/null && find Firmware -type f -name "applelogo*" 2>/dev/null; true', assets.source})
            for name in string.gmatch(body, "[^\n]+") do
                names[#names + 1] = name
            end
        end
        for _, name in ipairs(names) do
            local ext = suffix(name)
            if starts_with(name, "Firmware/") and starts_with(basename(name), "applelogo")
                    and (ext == ".img2" or ext == ".img3")
                    and (not board or board == "" or string.find(string.lower(name), "all_flash." .. string.lower(board) .. ".", 1, true)) then
                if not paths[name] then
                    paths[name] = true
                    count = count + 1
                    member = name
                end
            end
        end
    end
    if count ~= 1 then
        fail("expected one AppleLogo, found " .. count .. "; use --board to select the firmware identity")
    end
    return device, build, member
end

-- runs a converter with the time limit; a failure, or diagnostics that mean the image is incomplete, is an error
local function run_tool(program, args)
    local body, status, err = run("perl", {"-e", "alarm shift @ARGV; exec @ARGV or die", tostring(TOOL_SECONDS), program, table.unpack(args)})
    local diagnostics = (body or "") .. (err or "")
    -- Old XPwn sometimes reports a truncated decompression but exits zero and writes a PNG using uninitialized tail
    -- pixels. Never publish that image.
    local lower = string.lower(diagnostics)
    local incomplete = false
    for _, message in ipairs({
        "uncompressed data shorter than expected", "decompression error",
        "error converting", "unsupported color type", "unsupported compression",
    }) do
        if string.find(lower, message, 1, true) then
            incomplete = true
        end
    end
    if status ~= 0 or incomplete then
        fail(basename(program) .. " failed: " .. string.sub(diagnostics, -2000))
    end
end

-- the AppleLogo keys, from the keys file: an iv of 16 bytes and a key of 16, 24 or 32 bytes, both hexadecimal
local function load_keys(file)
    if not os.isfile(file) then
        fail("no such keys file: " .. file)
    end
    local keys = json.decode(read_binary(file))
    local function hex(value, lengths)
        if type(value) ~= "string" or string.find(value, "[^%x]") then
            return false
        end
        return contains(lengths, #value)
    end
    if type(keys) ~= "table" or not hex(keys.iv, {32}) or not hex(keys.key, {32, 48, 64}) then
        fail("keys JSON must contain hexadecimal iv (16 bytes) and key (16/24/32 bytes)")
    end
    return keys
end

local function prepare(args)
    local assets = open_assets(args.source)
    local product, build, member = select_logo(assets, args.device, args.board)
    local keys = args.keys and load_keys(args.keys) or nil

    -- conversion and atomic publication stay on the host-cache filesystem
    local directory = path.join(args.host_cache, "boot-logos", product)
    os.runv("mkdir", {"-p", directory})
    local destination = path.join(directory, build .. ".png")
    local index = 0
    repeat
        index = index + 1
        scratch = path.join(directory, string.format(".prepare-%d-%d", os.time(), index))
    until not os.exists(scratch)
    os.mkdir(scratch)

    local source = path.join(scratch, basename(member))
    copy_asset(assets, member, source)
    if keys then
        local decrypted = path.join(scratch, "decrypted.img3")
        run_tool(args.xpwntool, {source, decrypted, "-decrypt", "-iv", keys.iv, "-k", keys.key})
        source = decrypted
    end
    local png = path.join(scratch, "logo.png")
    run_tool(args.imagetool, {"extract", source, png})
    if not os.isfile(png) or os.filesize(png) > MAX_ASSET then
        fail("imagetool did not produce a bounded PNG; check the asset keys")
    end
    local output = read_binary(png)
    if #output < 45 or string.sub(output, 1, 8) ~= "\137PNG\r\n\26\n"
            or string.sub(output, 13, 16) ~= "IHDR" or string.sub(output, -8, -5) ~= "IEND" then
        fail("imagetool did not produce a complete PNG; check the asset keys")
    end
    local width, height = string.unpack(">I4I4", output, 17)
    if not (width > 0 and width <= 4096 and height > 0 and height <= 4096) then
        fail("logo dimensions exceed 4096x4096")
    end

    local metadata = path.join(scratch, "logo.json")
    write_binary(metadata, table.concat({
        "{\n",
        '  "product": ' .. json_string(product) .. ",\n",
        '  "build": ' .. json_string(build) .. ",\n",
        '  "asset": ' .. json_string(member) .. ",\n",
        '  "asset_sha256": "' .. sha256(path.join(scratch, basename(member))) .. '",\n',
        '  "png_sha256": "' .. sha256(png) .. '",\n',
        '  "width": ' .. width .. ",\n",
        '  "height": ' .. height .. "\n",
        "}\n",
    }))
    os.mv(metadata, (string.gsub(destination, "%.png$", ".json")))
    os.mv(png, destination)
    os.rm(scratch)
    scratch = nil
    print(string.format("Prepared %s (%dx%d) -> %s", member, width, height, destination))
end

function main(...)
    local argv = {...}
    local args = {imagetool = "imagetool", xpwntool = "xpwntool"}
    local options = {
        ["--host-cache"] = "host_cache", ["--device"] = "device", ["--board"] = "board",
        ["--keys"] = "keys", ["--imagetool"] = "imagetool", ["--xpwntool"] = "xpwntool",
    }
    local i = 1
    while i <= #argv do
        local arg = argv[i]
        if options[arg] then
            if i == #argv then
                usage("argument " .. arg .. ": expected one argument")
            end
            args[options[arg]] = argv[i + 1]
            i = i + 2
        elseif starts_with(arg, "--") or args.source then
            usage("unrecognized arguments: " .. arg)
        else
            args.source = arg
            i = i + 1
        end
    end
    if not args.source then
        usage("the following arguments are required: SOURCE")
    end
    if not args.host_cache then
        usage("the following arguments are required: --host-cache")
    end
    prepare(args)
end
