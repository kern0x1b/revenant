import("core.base.json")
import("core.base.pipe")
import("core.base.process")
import("apple.dyld")
import("apple.macho")
import("gdb")
import("apple.firmware")
import("byteorder")

RESULTS = "private/var/charon"
REPORTS = "private/var/logs/CrashReporter"
RUNNER = "usr/libexec/charon-runner"
LAUNCHER = "usr/libexec/charon-sblaunch"
-- MobileInstallation's cache of the installed applications, which SpringBoard
-- lists and launches from.
INSTALLATION_CACHE = "private/var/mobile/Library/Caches/com.apple.mobile.installation.plist"
RUNNER_JOB = "System/Library/LaunchDaemons/org.charon.emulator.runner.plist"
-- launchd reads launchd.conf at boot through iOS 6.1; from 7 it does not, and
-- from 6.1 it ignores a LaunchDaemons plist its prebuilt job cache does not
-- list, so the runner starts from launchd.conf up to 6.x and from its plist
-- from 7.
LAUNCHD_CONF = "private/etc/launchd.conf"
RUNNER_TASK = RESULTS .. "/job"
MIGRATOR = "System/Library/PrivateFrameworks/DataMigration.framework/Support/DataMigrator"
SETUP_KEYS = {{"SetupDone", "-bool", "YES"}, {"SetupFinishedAllSteps", "-bool", "YES"}, {"AssistantPresented", "-bool", "YES"}}
-- Setup.app stores a SetupVersion when it finishes, and below the one it
-- stores it runs again at every boot as "Update Completed", while SpringBoard
-- launches nothing else. The number is a constant in Setup's own code and in no
-- file: Setup stores [NSNumber numberWithInt:N] under @"SetupVersion" (10A403
-- stores 2, 10B329 3), and the Setup of 5.0, 5.1.1 and 9.3.6 has no such key.
SETUP = "Applications/Setup.app/Setup"
-- What Setup.app leaves with lockdownd when it finishes, which iOS 6.1 asks
-- instead of the preferences; plutil reads a dot as a key-path separator, so
-- the dots are escaped.
LOCKDOWN_KEYS = {{"com\\.apple\\.purplebuddy-SetupState", "-string", "DONE"}}
CRASH_LOOP = 3
-- The registers a stopped guest is read by, in the order the debugger lays
-- them out; charon prints them in that order too.
REGISTERS = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12", "sp", "lr", "pc", "cpsr"}
-- A guest second takes this many host seconds. The emulator is one to two
-- orders of magnitude slower than the device it emulates, so at 1 the guest's
-- own watchdogs and RPC deadlines expire before it finishes: iOS 6.1.3 loses
-- SpringBoard every 100 s to a mediaserverd RPC timeout and loses every app
-- backboardd's launch watchdog reaches. See README for the measurements.
TIME_SCALE = 10

function directory(folder)
    if not os.isdir(folder) then
        try {function () os.mkdir(folder) end}
    end
    if not os.isdir(folder) then
        raise("cannot create the folder %s", folder)
    end
    return folder
end

function remove(folder)
    if os.isdir(folder) or os.isfile(folder) or os.islink(folder) then
        -- u+rwX, not u+w: a directory needs execute as well as write for the entries in it to be unlinked,
        -- and a root filesystem holds read-only directories - the dyld cache ships as one. Measured
        -- 2026-09-27 on the CommandLineTools host: u+w left
        -- rootfs/System/Library/Caches/com.apple.dyld at rw-r--r-- and rm answered "Permission denied" for
        -- the cache inside it, so every image that holds one could not be removed and stayed.
        os.execv("chmod", {"-R", "u+rwX", folder}, {try = true})
        os.tryrm(folder)
        if os.isdir(folder) or os.isfile(folder) or os.islink(folder) then
            raise("cannot remove %s", folder)
        end
    end
end

function root()
    return path.join(path.directory(dyld.root()), "emulator")
end

function profiles(shade)
    local listed = {}
    for line in os.iorunv(shade, {"profile", "--list"}):gmatch("[^\n]+") do
        table.insert(listed, line:trim())
    end
    return listed
end

function kernels(shade)
    local known = {}
    for line in os.iorunv(shade, {"abi"}):gmatch("[^\n]+") do
        local name = line:match("^%s+(darwin%S+)$")
        if name then
            table.insert(known, name)
        end
    end
    return known
end

function kernel(shade, build)
    local output = try {function () return os.iorunv(shade, {"abi", "--ios-build", build}) end}
    return output and output:match("abi: (%S+)")
end

function choose(devices, emulated, opt)
    local known = {}
    for _, device in ipairs(devices) do
        known[device.identifier:lower()] = device
    end
    local candidates = {}
    if opt.device then
        local device = known[opt.device:lower()] or raise("the firmware catalog knows no device %s", opt.device)
        if not table.contains(emulated, device.identifier) then
            raise("Shade has no profile for %s; it emulates %s", device.identifier, table.concat(emulated, ", "))
        end
        candidates = {device}
    else
        for _, device in ipairs(devices) do
            if firmware.architecture(device.platform) == opt.architecture and table.contains(emulated, device.identifier) then
                table.insert(candidates, device)
            end
        end
    end
    for _, device in ipairs(candidates) do
        local chosen
        for _, candidate in ipairs(device.firmwares) do
            if dyld.compare_versions(candidate.version, opt.release) >= 0 and (not chosen or dyld.compare_versions(candidate.version, chosen.version) < 0) then
                chosen = candidate
            end
        end
        if chosen then
            return {identifier = device.identifier, version = chosen.version, build = chosen.build}
        end
    end
    if opt.device then
        raise("%s has no firmware of release %s or later in the catalog; pass -r with a release it runs", opt.device, opt.release)
    end
    raise("no device Shade emulates (%s) runs %s release %s or later; pass -d and -r", table.concat(emulated, ", "), opt.architecture, opt.release)
end

function guest_path(rootfs, relative, opt)
    opt = opt or {}
    local resolved = rootfs
    local pending = relative:split("/", {plain = true})
    local hops = 0
    local index = 1
    while index <= #pending do
        local part = pending[index]
        index = index + 1
        if part == ".." then
            if resolved ~= rootfs then
                resolved = path.directory(resolved)
            end
        elseif part ~= "" and part ~= "." then
            local candidate = path.join(resolved, part)
            if (index <= #pending or opt.follow) and os.islink(candidate) then
                hops = hops + 1
                if hops > 40 then
                    raise("%s loops through its symbolic links inside %s", relative, rootfs)
                end
                local link = os.readlink(candidate)
                local rest = table.slice(pending, index)
                pending = link:split("/", {plain = true})
                table.join2(pending, rest)
                index = 1
                if link:startswith("/") then
                    resolved = rootfs
                end
            else
                resolved = candidate
            end
        end
    end
    return resolved
end

-- What the guest has loaded, asked of the guest itself: dyld keeps the list at
-- _dyld_all_image_infos, and the copy of dyld in the image says where that is.
-- The list carries the cache's libraries as well as the port's own, so an
-- address in a backtrace is named without reading the shared cache at all.
local function loaded_images(connection, rootfs)
    local file = path.join(rootfs, "usr", "lib", "dyld")
    if not os.isfile(file) then
        return {}
    end
    local data = macho.read(file)
    local address
    for _, image in ipairs(macho.images(data)) do
        address = address or macho.symbol(data, image, "_dyld_all_image_infos")
    end
    if not address then
        return {}
    end
    local count, array = gdb.word(connection, address + 4), gdb.word(connection, address + 8)
    if not count or not array or count == 0 or count > 4096 then
        return {}
    end
    local held = {}
    for index = 0, count - 1 do
        local base, name = gdb.word(connection, array + index * 12), gdb.word(connection, array + index * 12 + 4)
        if base and name then
            table.insert(held, {address = base, install = gdb.text(connection, name)})
        end
    end
    table.sort(held, function (a, b) return a.address < b.address end)
    return held
end

-- A symbol table for the images the rootfs holds as files - dyld, the port and
-- what it carries - so their frames are named and not only placed. What lives
-- only in the shared cache is placed by image and offset.
local function image_symbols(install, rootfs, architecture)
    local file = path.join(rootfs, install)
    if not os.isfile(file) or os.filesize(file) > 16 * 1024 * 1024 then
        return nil
    end
    return try {
        function ()
            local data = macho.read(file)
            local named = {}
            for _, image in ipairs(macho.images(data)) do
                if not architecture or image.architecture == architecture then
                    -- A symbol stands at the address the image was linked for,
                    -- and the guest loaded it wherever it did, so both are read
                    -- as offsets from the image's own first segment.
                    local first
                    for _, segment in ipairs(image.segments) do
                        if segment.name ~= "__PAGEZERO" and (not first or segment.vmaddr < first) then
                            first = segment.vmaddr
                        end
                    end
                    for address, symbols in pairs(macho.code_symbols(data, image)) do
                        table.insert(named, {address = address - (first or 0), name = symbols[1].name})
                    end
                end
            end
            table.sort(named, function (a, b) return a.address < b.address end)
            return #named > 0 and named or nil
        end
    }
end

function named_address(address, images, symbols)
    local found
    for _, image in ipairs(images) do
        if image.address <= address then
            found = image
        end
    end
    if not found then
        return string.format("0x%08x", address)
    end
    local offset = address - found.address
    local named = string.format("%s + 0x%x", path.filename(found.install), offset)
    local table_of = symbols and symbols[found.install]
    if table_of then
        local best
        for _, entry in ipairs(table_of) do
            if entry.address <= (offset & ~1) and (not best or entry.address > best.address) then
                best = entry
            end
        end
        if best then
            named = string.format("%s`%s + 0x%x", path.filename(found.install), best.name, (offset & ~1) - best.address)
        end
    end
    return named
end

-- A crash in the guest says only where it stopped, and where is a number. The
-- emulator answers a debugger on a port, so charon starts the program as the
-- guest's first process, asks the debugger for the registers and the frames the
-- moment the guest stops, and names the addresses with what the guest itself
-- says it has loaded. The program runs as pid 1: nothing else boots, so what
-- the report holds is the program and what it loads, and no service of the
-- release is between them.
function debugged(opt)
    local run = directory(opt.run)
    local log = path.join(run, "emulator.log")
    local errors = path.join(run, "emulator.stderr")
    os.tryrm(log)
    os.tryrm(errors)
    local port = opt.port or (12000 + os.getpid() % 2000)
    local argv = {"boot", "--rootfs", opt.rootfs, "--device", opt.identifier, "--host-cache", opt.cache,
                  "--display", "headless", "--gles-backend", "software", "--network", opt.network or "isolated",
                  "--binary", opt.guest, "--gdb", tostring(port)}
    local envs = {}
    for name, value in pairs(table.join(os.getenvs(), {TMPDIR = opt.tmpdir, VK_ICD_FILENAMES = opt.icd})) do
        table.insert(envs, name .. "=" .. value)
    end
    directory(opt.tmpdir)
    directory(opt.cache)
    local proc = process.openv(opt.shade, argv, {stdout = log, stderr = errors, envs = envs})
    local report = try {
        function ()
            local connection = gdb.connect(port, {patience = opt.patience or 120})
            local stopped = gdb.ask(connection, "c")
            -- A program that does not crash answers with its exit status
            -- instead of a signal, and there is nothing to read of it.
            if stopped and (stopped:startswith("W") or stopped:startswith("X")) then
                gdb.close(connection)
                return {stopped = stopped, exited = tonumber(stopped:sub(2, 3), 16) or 0, frames = {}, images = {}, log = log}
            end
            local held = gdb.registers(connection)
            if not held then
                raise("the guest stopped (%s) and the debugger cannot read its registers", tostring(stopped))
            end
            local walked = gdb.frames(connection, held)
            local images = loaded_images(connection, opt.rootfs)
            local symbols = {}
            for _, image in ipairs(images) do
                symbols[image.install] = image_symbols(image.install, opt.rootfs, opt.architecture)
            end
            local named = {}
            for _, frame in ipairs(walked) do
                table.insert(named, table.join(frame, {name = named_address(frame.address, images, symbols)}))
            end
            gdb.close(connection)
            return {stopped = stopped, signal = tonumber((stopped or ""):match("^T(%x%x)") or "0", 16),
                    registers = held, frames = named, images = images, log = log}
        end
    }
    proc:kill()
    proc:wait(2000)
    proc:close()
    if not report then
        raise("the guest was started under the debugger and never stopped where it could be read; the emulator log is %s", log)
    end
    return report
end

function results(rootfs)
    return guest_path(rootfs, RESULTS)
end

function clone(source, destination)
    remove(destination)
    os.mkdir(path.directory(destination))
    os.vrunv("cp", {"-c", "-R", source, destination})
end

-- The integers a 32-bit ARM image stores as NSNumbers under the constant
-- string key, read by following its registers through its Thumb-2 code from one
-- message send to the next, and the stores under that key it could not follow.
-- Only the few instructions such a store is made of are decoded; any other one
-- forgets every register, so a form this does not know is reported as not
-- followed, never guessed at.
local function stored_numbers(data, found, key)
    local sections = {}
    for _, section in ipairs(found.sections) do
        sections[section.name] = section
    end
    local function offset(address)
        for _, segment in ipairs(found.segments) do
            if address >= segment.vmaddr and address < segment.vmaddr + segment.vmsize then
                return found.base + segment.fileoff + address - segment.vmaddr
            end
        end
    end
    local function inside(name, address)
        local section = sections[name]
        return section and address >= section.addr and address < section.addr + section.size
    end
    local function word(address)
        return string.unpack("<I4", data, offset(address) + 1)
    end
    local function text(address)
        local at = offset(address)
        return at and data:sub(at + 1, data:find("\0", at + 1, true) - 1)
    end
    local code = sections["__text"]
    local numbers, unfollowed = {}, 0
    local registers = {}
    local at, finish = offset(code.addr), offset(code.addr) + code.size
    while at < finish do
        local address = code.addr + at - offset(code.addr)
        local first = string.unpack("<I2", data, at + 1)
        if (first >> 11) >= 0x1d then
            local second = string.unpack("<I2", data, at + 3)
            local kind = first & 0xfbf0
            if (kind == 0xf240 or kind == 0xf2c0) and second & 0x8000 == 0 then
                -- movw / movt rd, #imm16
                local immediate = ((first & 0xf) << 12) | (((first >> 10) & 1) << 11) | (((second >> 12) & 7) << 8) | (second & 0xff)
                local destination, known = (second >> 8) & 0xf, registers[(second >> 8) & 0xf]
                if kind == 0xf240 then
                    registers[destination] = {immediate = immediate}
                elseif known and known.immediate then
                    registers[destination] = {immediate = known.immediate | (immediate << 16)}
                else
                    registers[destination] = nil
                end
            elseif first & 0xf800 == 0xf000 and second & 0xc000 == 0xc000 then
                -- bl / blx: a message send, whose r0 is the receiver, r1 the selector, r2 and r3 the arguments
                local selector, value, stored = registers[1], registers[2], registers[3]
                if selector and selector.selector == "setObject:forKey:" and stored and stored.address and
                   inside("__cfstring", stored.address) and text(word(stored.address + 8)) == key then
                    if value and value.sent and (value.sent == "numberWithInt:" or value.sent == "numberWithInteger:") and
                       value.argument and value.argument.immediate then
                        table.insert(numbers, value.argument.immediate)
                    else
                        unfollowed = unfollowed + 1
                    end
                end
                local kept = {}
                for _, callee_saved in ipairs({4, 5, 6, 8, 10, 11}) do
                    kept[callee_saved] = registers[callee_saved]
                end
                kept[0] = {sent = selector and selector.selector, argument = value}
                registers = kept
            elseif first & 0xfff0 == 0xf8d0 then
                -- ldr.w rt, [rn, #imm12]
                registers[(second >> 12) & 0xf] = nil
            else
                registers = {}
            end
            at = at + 4
        else
            if first & 0xff78 == 0x4478 then
                -- add rdn, pc
                local destination = (first & 7) | ((first >> 4) & 8)
                local known = registers[destination]
                registers[destination] = known and known.immediate and {address = (known.immediate + address + 4) & 0xffffffff} or nil
            elseif first & 0xffc0 == 0x6800 then
                -- ldr rt, [rn]: a selector when rn points into the selector references
                local known = registers[(first >> 3) & 7]
                registers[first & 7] = known and known.address and inside("__objc_selrefs", known.address) and
                                       {selector = text(word(known.address))} or nil
            elseif first & 0xf800 == 0x2000 then
                -- movs rd, #imm8
                registers[(first >> 8) & 7] = {immediate = first & 0xff}
            elseif first & 0xff00 == 0x4600 then
                -- mov rd, rm
                registers[(first & 7) | ((first >> 4) & 8)] = registers[(first >> 3) & 0xf]
            else
                registers = {}
            end
            at = at + 2
        end
    end
    return numbers, unfollowed
end

-- The SetupVersion the firmware's own Setup stores, nil when its Setup stores
-- none; raises when it stores one that cannot be read.
function setup_version(rootfs, build)
    local file = guest_path(rootfs, SETUP, {follow = true})
    if not os.isfile(file) then
        return nil
    end
    local data = macho.read(file)
    if not data:find("\0SetupVersion\0", 1, true) then
        return nil
    end
    for _, found in ipairs(macho.images(data)) do
        if found.architecture == "armv7" or found.architecture == "armv7s" then
            local numbers, unfollowed = stored_numbers(data, found, "SetupVersion")
            local distinct = table.unique(numbers)
            if #distinct == 1 and unfollowed == 0 then
                return distinct[1]
            end
            raise("the SetupVersion of %s is not known: its Setup (%s) %s", build, file,
                  #distinct > 1 and ("stores " .. table.concat(distinct, " and ")) or
                  "stores one in a form not read here, and without it Setup runs again at every boot")
        end
    end
    raise("the SetupVersion of %s is not known: its Setup (%s) names one and has no armv7 code to read it from", build, file)
end

function setup_keys(rootfs, build)
    local keys = table.copy(SETUP_KEYS)
    local version = setup_version(rootfs, build)
    if version then
        table.insert(keys, {"SetupVersion", "-integer", tostring(version)})
    end
    return keys
end

function home(rootfs, build)
    local preferences = guest_path(rootfs, "private/var/mobile/Library/Preferences")
    os.mkdir(preferences)
    local keys = setup_keys(rootfs, build)
    for _, name in ipairs({"com.apple.purplebuddy", "com.apple.purplebuddy.notbackedup"}) do
        local file = path.join(preferences, name .. ".plist")
        if not os.isfile(file) then
            os.vrunv("plutil", {"-create", "binary1", file})
        end
        for _, key in ipairs(keys) do
            os.vrunv("plutil", {"-replace", key[1], key[2], key[3], file})
        end
        os.vrunv("xattr", {"-w", "hfsfuse.record.owner_id", "501", file})
        os.vrunv("xattr", {"-w", "hfsfuse.record.group_id", "501", file})
    end
    -- iOS 6.1 asks lockdownd instead of the preferences above: SpringBoard
    -- reads com.apple.purplebuddy/SetupState, which Setup.app sets to DONE
    -- when it finishes. 6.0 reads the preferences, so both are written. A
    -- firmware's root filesystem has no lockdownd store until lockdownd first
    -- runs, and lockdownd and the emulator both keep the keys they find in it,
    -- so it is started here with the setup state in it.
    local ark = guest_path(rootfs, "private/var/root/Library/Lockdown/data_ark.plist")
    os.mkdir(path.directory(ark))
    if not os.isfile(ark) then
        os.vrunv("plutil", {"-create", "xml1", ark})
    end
    for _, key in ipairs(LOCKDOWN_KEYS) do
        os.vrunv("plutil", {"-replace", key[1], key[2], key[3], ark})
    end
    os.vrunv("xattr", {"-w", "hfsfuse.record.owner_id", "0", ark})
    os.vrunv("xattr", {"-w", "hfsfuse.record.group_id", "0", ark})
end

-- The guest writes a report for every process it kills or that crashes, and
-- the report names the reason, which no emulator-side line can.
function reports(rootfs)
    local folder = guest_path(rootfs, REPORTS)
    local collected = {}
    for _, file in ipairs(os.files(path.join(folder, "*.plist"))) do
        local name = path.basename(file):match("^(.-)%-%d%d%d%d%-") or path.basename(file)
        local reason
        local printed = try {function () return os.iorunv("plutil", {"-extract", "description", "raw", "-o", "-", file}) end}
        for line in (printed or ""):gmatch("[^\n]+") do
            local named = line:match("^Reason:%s*(.+)$")
            if named then
                reason = named:trim()
                break
            end
        end
        table.insert(collected, {process = name, file = file, reason = reason})
    end
    table.sort(collected, function (left, right) return byteorder.less(left.file, right.file) end)
    return collected
end

local function ar_members(content, deb)
    if not content:startswith("!<arch>\n") then
        raise("%s is not a Debian package: it does not start with an ar header", deb)
    end
    local members, offset = {}, 8
    while offset + 60 <= #content do
        local header = content:sub(offset + 1, offset + 60)
        local name = header:sub(1, 16):trim():gsub("/$", "")
        local size = tonumber(header:sub(49, 58):trim())
        if not size then
            raise("%s has a damaged ar member header at byte %d", deb, offset)
        end
        members[name] = content:sub(offset + 61, offset + 60 + size)
        offset = offset + 60 + size + size % 2
    end
    return members
end

local function place(tree, rootfs)
    local entries = {}
    for _, entry in ipairs(os.filedirs(path.join(tree, "**"))) do
        table.insert(entries, path.relative(entry, tree))
    end
    byteorder.sort(entries)
    for _, relative in ipairs(entries) do
        local source = path.join(tree, relative)
        local target = guest_path(rootfs, relative)
        if os.islink(source) then
            os.tryrm(target)
            os.mkdir(path.directory(target))
            os.ln(os.readlink(source), target)
        elseif os.isdir(source) then
            os.mkdir(guest_path(rootfs, relative, {follow = true}))
        else
            os.mkdir(path.directory(target))
            os.tryrm(target)
            os.vrunv("cp", {"-p", source, target})
            local wanted, got = os.filesize(source), os.isfile(target) and os.filesize(target) or -1
            if got ~= wanted then
                remove(path.directory(destination))
                raise("%s is %d B in the package and %d B in the image, so the image would hold a program that was not built",
                       relative, wanted, got)
            end
        end
    end
end

-- dpkg runs a package's maintainer scripts with DPKG_ROOT naming the root it
-- installs into, and Charon's own scripts are written for it: the backports
-- package reads the release out of that root and links the libraries built for
-- it. The image is such a root, so the scripts run against it here exactly as
-- they run on a device.
local function maintainer_script(work, members, name, rootfs, deb, stage)
    local control
    for member, content in pairs(members) do
        if member:startswith("control.tar") then
            control = {name = member, content = content}
        end
    end
    if not control then
        return
    end
    local tree = path.join(work, "control")
    os.mkdir(tree)
    local archive = path.join(work, control.name)
    io.writefile(archive, control.content, {encoding = "binary"})
    os.vrunv("tar", {"-xpf", archive, "-C", tree})
    local script = path.join(tree, name)
    if not os.isfile(script) then
        return
    end
    os.vrunv("chmod", {"u+x", script})
    local output = os.tmpfile()
    local ok = os.execv("/bin/sh", {script, stage}, {envs = {DPKG_ROOT = path.absolute(rootfs)},
                                                    stdout = output, stderr = output, try = true})
    local said = os.isfile(output) and io.readfile(output):trim() or ""
    os.tryrm(output)
    if ok ~= 0 then
        raise("the %s of %s refused this image%s", name, path.filename(deb),
              said ~= "" and (": " .. said) or "")
    end
    if said ~= "" then
        cprint("${dim}%s: %s", name, said)
    end
end

-- What a package put in, and how big each file is, so an install can be compared with the build that
-- fed it. The hashes are printed and are not to be compared across installs: a binary Charon installs is
-- stripped and signed, and ldid's signature is not reproducible - two signatures of one input are the
-- same size and different bytes. The size and the build's own output are what a caller can compare.
function describe_files(folder)
    local described = {}
    for _, file in ipairs(os.files(path.join(folder, "**"))) do
        table.insert(described, {path = path.relative(file, folder), size = os.filesize(file),
                                 hash = hash.sha256(file)})
    end
    table.sort(described, function (a, b) return byteorder.less(a.path, b.path) end)
    return described
end

function install_deb(deb, rootfs)
    local members = ar_members(io.readfile(deb, {encoding = "binary"}), deb)
    local data
    for name, content in pairs(members) do
        if name:startswith("data.tar") then
            data = {name = name, content = content}
        end
    end
    if not data then
        raise("%s has no data.tar member to install", deb)
    end
    local work = os.tmpfile() .. ".deb"
    os.mkdir(path.join(work, "tree"))
    local archive = path.join(work, data.name)
    io.writefile(archive, data.content, {encoding = "binary"})
    os.vrunv("tar", {"-xpf", archive, "-C", path.join(work, "tree")})
    maintainer_script(work, members, "preinst", rootfs, deb, "install")
    place(path.join(work, "tree"), rootfs)
    maintainer_script(work, members, "postinst", rootfs, deb, "configure")
    local applications = {}
    for _, bundle in ipairs(os.dirs(path.join(work, "tree", "Applications", "*.app"))) do
        table.insert(applications, "Applications/" .. path.filename(bundle))
    end
    remove(work)
    return applications
end

-- What uicache does on a device, left to MobileInstallation itself: its cache
-- of the installed applications is removed from the image, and it builds the
-- cache again from /Applications at boot, as it does on a firmware's first
-- boot, whose root filesystem has none. SpringBoard then lists the application
-- and launches it by the bundle identifier this answers.
function register_application(rootfs, relative)
    local info = path.join(guest_path(rootfs, relative), "Info.plist")
    if not os.isfile(info) then
        raise("/%s has no Info.plist, so it is no application SpringBoard can list", relative)
    end
    local identifier = try {function () return os.iorunv("plutil", {"-extract", "CFBundleIdentifier", "raw", "-o", "-", info}):trim() end}
    if not identifier or identifier == "" then
        raise("%s names no CFBundleIdentifier, and SpringBoard launches an application by it", info)
    end
    remove(guest_path(rootfs, INSTALLATION_CACHE))
    return identifier
end

function install_launcher(rootfs, guest)
    local launcher = guest_path(rootfs, LAUNCHER)
    os.mkdir(path.directory(launcher))
    os.vrunv("cp", {"-p", path.join(guest, LAUNCHER), launcher})
end

-- The runner's command for launch: charon-sblaunch waits up to seconds for
-- SpringBoard to take the launch, and the application's output goes beside
-- the verdict.
function launch_command(identifier, seconds)
    return {"/" .. LAUNCHER, "--wait", tostring(seconds), "--stdout", "/" .. RESULTS .. "/app.stdout",
            "--stderr", "/" .. RESULTS .. "/app.stderr", identifier}
end

local function escaped(text)
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- The runner's job as it reads it: the deadline, the program and its
-- arguments, each word ended by a NUL, so no argument needs quoting.
function runner_task(argv, deadline)
    local words = {tostring(deadline)}
    for _, argument in ipairs(argv) do
        if argument:find("\0", 1, true) then
            raise("an argument of the test holds a NUL byte, which the runner's job cannot carry")
        end
        table.insert(words, argument)
    end
    return table.concat(words, "\0") .. "\0"
end

-- launchd.conf's line for the runner: launchctl splits it on whitespace, so it
-- names only the job file.
function runner_launch()
    return "bsexec .. /" .. RUNNER .. " --job /" .. RUNNER_TASK .. "\n"
end

function runner_job()
    local arguments = {"<string>/" .. RUNNER .. "</string>", "<string>--job</string>", "<string>/" .. RUNNER_TASK .. "</string>"}
    return table.concat({
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        '<plist version="1.0">',
        "<dict>",
        "<key>Label</key><string>org.charon.emulator.runner</string>",
        "<key>ProgramArguments</key><array>" .. table.concat(arguments) .. "</array>",
        "<key>RunAtLoad</key><true/>",
        "<key>LaunchOnlyOnce</key><true/>",
        "</dict>",
        "</plist>",
        ""}, "\n")
end

function install_runner(rootfs, guest, argv, deadline, release)
    local runner = guest_path(rootfs, RUNNER)
    os.mkdir(path.directory(runner))
    os.vrunv("cp", {"-p", path.join(guest, RUNNER), runner})
    local results = guest_path(rootfs, RESULTS)
    remove(results)
    os.mkdir(results)
    os.vrunv("chmod", {"0777", results})
    io.writefile(guest_path(rootfs, RUNNER_TASK), runner_task(argv, deadline))
    if dyld.compare_versions(release, "7.0") < 0 then
        local conf = guest_path(rootfs, LAUNCHD_CONF)
        local kept = os.isfile(conf) and io.readfile(conf) or ""
        if not kept:find(runner_launch(), 1, true) then
            if kept ~= "" and not kept:endswith("\n") then
                kept = kept .. "\n"
            end
            io.writefile(conf, kept .. runner_launch())
        end
    else
        io.writefile(guest_path(rootfs, RUNNER_JOB), runner_job())
    end
end

function scan(state, line)
    state.lines = (state.lines or 0) + 1
    state.names = state.names or {}
    state.exits = state.exits or {}
    state.crashes = state.crashes or {}
    state.fatal = state.fatal or {}
    if line:startswith("[control] ready") then
        state.ready = true
    elseif line:startswith("[display] frame=") then
        state.frames = (state.frames or 0) + 1
    end
    -- An input and a settle each start a transition, numbered in order, which
    -- is stable once the screen has stopped changing after it.
    local started = line:match("^%[transition%] input%-complete id=(%d+)") or line:match("^%[transition%] settle id=(%d+)")
    if started then
        state.transition = math.max(state.transition or 0, tonumber(started))
    end
    local stable = line:match("^%[transition%] internal%-stable id=(%d+)")
    if stable then
        state.stable = state.stable or {}
        state.stable[tonumber(stable)] = true
    end
    local snapshot = line:match("^%[control%] snapshot=(.-) frame=%d+$")
    if snapshot then
        state.snapshots = state.snapshots or {}
        state.snapshots[snapshot] = true
    end
    local pid, program = line:match("^%[process%] spawn%-setexec pid=(%d+) parent=%d+ suspended=%d (%S+)")
    if not pid then
        pid, program = line:match("^%[process%] exec pid=(%d+) (/%S+)")
    end
    if not pid then
        pid, program = line:match("^%[process%] spawn parent=%d+ child=(%d+) suspended=%d (%S+)")
    end
    if pid then
        state.names[pid] = path.filename(program)
        state.programs = state.programs or {}
        state.programs[pid] = program
        if program:endswith("SpringBoard.app/SpringBoard") then
            state.springboard = true
        elseif program:endswith("/DataMigrator") then
            state.migrator = pid
        elseif program:endswith("/charon-runner") then
            state.runner = pid
        end
    end
    local exited, status = line:match("^%[process%] exit pid=(%d+) status=(%-?%d+)")
    if exited then
        local signal = tonumber(line:match(" signal=(%d+)")) or 0
        state.exits[exited] = {status = tonumber(status), signal = signal}
        if exited == state.migrator and signal == 0 then
            state.migrated = true
        end
        if signal ~= 0 then
            local name = state.names[exited] or exited
            state.crashes[name] = (state.crashes[name] or 0) + 1
        end
    end
    -- A thread that sent a request and is still receiving its reply when the
    -- run ends waited for an answer that never came. A daemon parked on its
    -- service port is not that, and the emulator only reports the former.
    local stalled, request, seconds = line:match(
        "^%[mach%] stalled pid=(%d+) thread=%d+ request=(%d+).* guest%-seconds=(%d+)")
    if stalled then
        state.stalls = state.stalls or {}
        table.insert(state.stalls, {pid = stalled, request = tonumber(request),
                                    seconds = tonumber(seconds)})
    end
    local faulted, pc = line:match("^%[cpu%] fatal pid=(%d+) cpu=%d+ pc=(0x%x+)")
    if faulted then
        state.fatal[faulted] = {pc = pc, line = line}
    end
    return state
end

function scan_file(file, state)
    state = state or {}
    if os.isfile(file) then
        for line in io.readfile(file, {encoding = "binary"}):gmatch("[^\n]+") do
            scan(state, line)
        end
    end
    return state
end

function crash_loop(state)
    local looping, most = nil, 0
    for name, count in pairs(state.crashes or {}) do
        if count >= CRASH_LOOP and count > most then
            looping, most = name, count
        end
    end
    return looping
end

-- A target that measures time cannot be measured against a guest clock that
-- runs slower than the host's, and a converted number would be a guess about
-- what the target meant. Such a target says so and the run refuses instead.
function timing_refusal(timing, scale)
    if timing ~= "strict" or scale == 1 then
        return nil
    end
    return string.format("this port measures time (emulate.timing is strict) and the guest's clock runs %s " ..
                         "times slower than the host's; run it with --scale 1, which is slow enough that the " ..
                         "guest's own watchdogs will end long runs", tostring(scale))
end

function gap(state)
    local longest
    for _, stall in ipairs(state.stalls or {}) do
        if not longest or stall.seconds > longest.seconds then
            longest = {pid = stall.pid, request = stall.request, seconds = stall.seconds,
                       process = (state.names or {})[stall.pid] or stall.pid}
        end
    end
    return longest
end

function milestone(state)
    if not state.ready then
        return "emulator"
    end
    local looping = crash_loop(state)
    if looping then
        return looping
    end
    if not state.springboard then
        return "SpringBoard"
    end
    if state.migrator and not state.migrated then
        return "DataMigrator"
    end
    return "runner"
end

function verdict(state, results, opt)
    opt = opt or {}
    local file = path.join(results, "verdict.json")
    -- Guest seconds are the guest's own clock, which runs scale times slower
    -- than the host's; a test that measures time reads both and the scale.
    local timing = {scale = opt.scale or TIME_SCALE, host_seconds = opt.host_seconds, reports = opt.reports}
    if not os.isfile(file) then
        return table.join2({state = "boot-blocked", milestone = milestone(state), frame = opt.frame,
                            errors = opt.errors, gap = gap(state)}, timing)
    end
    local recorded = json.loadfile(file)
    local test = recorded.test or {}
    local result = table.join2({machine = recorded.machine, system = recorded.system,
                                guest_seconds = test.seconds, seconds = test.seconds,
                                stdout = path.join(results, "test.stdout"),
                                stderr = path.join(results, "test.stderr"),
                                output = test.output}, timing)
    if test.spawned ~= 1 then
        result.state = "fail"
        result.spawn_error = test.spawn_error
    elseif test.timed_out == 1 then
        result.state = "timeout"
    elseif test.signal then
        result.state = "crash"
        result.signal = test.signal
        result.frame = opt.frame
        for pid, name in pairs(state.names or {}) do
            if state.fatal and state.fatal[pid] and path.filename(test.path or "") == name then
                result.pc = state.fatal[pid].pc
            end
        end
    elseif test.exit == 0 then
        result.state = "pass"
    else
        result.state = "fail"
        result.exit = test.exit
    end
    return result
end

-- What a run's program said, and which of the three states that is, so silence is never read as a
-- program that printed nothing: it wrote something, it wrote nothing, or its output was not captured
-- because the runner could not open the file. The last is the runner's own verdict field, so a lost
-- output is told apart from an empty one instead of both printing nothing.
function report_output(folder, output)
    if output == 0 then
        -- The runner's own word is the one to believe: it could not open the file, so whatever is
        -- there is not the program's, and printing it would put the wrong text under its name.
        cprint("${color.warning}the program's output was not captured${clear}: the runner could not open it, and it says why in %s",
               path.join(folder, "results", "runner.stderr"))
        return false
    end
    local said = false
    for _, name in ipairs({"test.stdout", "test.stderr"}) do
        local file = path.join(folder, "results", name)
        if os.isfile(file) and os.filesize(file) > 0 then
            io.write(io.readfile(file))
            said = true
        end
    end
    if not said then
        cprint("${dim}the program wrote nothing to stdout or stderr${clear}")
    end
    return said
end

function describe(result)
    local reported = ""
    for _, report in ipairs(result.reports or {}) do
        if report.reason then
            reported = string.format(", %s: %s", report.process, report.reason)
            break
        end
    end
    if result.state == "crash" then
        return string.format("crash(signal %d%s%s)", result.signal, result.pc and (", pc " .. result.pc) or "",
                             result.frame and (", last frame " .. result.frame) or "")
    elseif result.state == "fail" then
        return result.exit and string.format("fail(exit %d)", result.exit) or string.format("fail(spawn error %d)", result.spawn_error or 0)
    elseif result.state == "boot-blocked" then
        local waited = ""
        if result.gap then
            waited = string.format(", %s waited %d guest s for a reply to request %d",
                                   result.gap.process, result.gap.seconds, result.gap.request)
        end
        return string.format("boot-blocked(%s%s%s)", result.milestone, reported, waited)
    end
    return result.state
end

-- The steps launch takes after the application is up, each followed by a
-- snapshot once the screen settles: the word and how many numbers follow it.
-- until-exit is the one step the emulator is not asked for: it is the driver's own, and holds the
-- guest until the application has ended, so a port whose application produces its result over
-- time is given the time to produce it and the frame kept is the one it ended on.
function parse_steps(words)
    local arity = {tap = 2, drag = 4, home = 0, ["until-exit"] = 0}
    local steps, index = {}, 1
    while index <= #words do
        local verb = words[index]
        local count = arity[verb]
        if not count then
            raise("launch takes the steps tap X Y, drag X1 Y1 X2 Y2, home and until-exit after the bundle identifier, and not %s", verb)
        end
        local step = {verb}
        for offset = 1, count do
            local number = tonumber(words[index + offset])
            if not number then
                raise("%s takes %d numbers, in points", verb, count)
            end
            table.insert(step, words[index + offset])
        end
        table.insert(steps, table.concat(step, " "))
        index = index + count + 1
    end
    return steps
end

-- What launch does while the guest runs, as the stop function of boot. It
-- unlocks the screen while charon-sblaunch says screen=locked, one unlock at a
-- time; once the launch is done and the application frontmost, it has the
-- emulator settle and takes a snapshot when the screen has stopped changing,
-- then takes each step, settles and takes a snapshot after it. A step of
-- until-exit holds instead of sending anything: it waits for the application to
-- end, and for the run's own budget to be spent if it never does, and says in
-- held which of the two happened. The budget is -s, the guest seconds the application
-- may run from the moment it is frontmost, which the host's clock counts at the time
-- scale (one guest second takes that many host seconds). The runner's verdict is not
-- the budget's end: it is written when charon-sblaunch returns, which is at launch.
-- Settling is the emulator's own measure, in
-- guest time: [transition] settle id=N, then internal-stable id=N. The driver
-- keeps where it ended in shots, failure, exit, held, held_seconds and application.
function launch_driver(opt)
    local driver = {phase = "launching", shots = {}, step = 0, unlocks = 0}
    local clock = opt.clock or os.mclock
    local scale = opt.scale or TIME_SCALE
    if table.contains(opt.steps, "until-exit") and not opt.seconds then
        raise("until-exit holds for the run's budget, and the run gave no seconds")
    end
    -- Guest seconds the application has run since SpringBoard made it frontmost.
    local function running()
        return (clock() - driver.launched) / 1000 / scale
    end
    local function settle(state, send)
        send("settle")
        driver.phase, driver.after, driver.settling = "settling", state.transition or 0, nil
    end
    function driver.stop(state, send)
        if not state.ready then
            return false
        end
        for pid, program in pairs(state.programs or {}) do
            if program:startswith(opt.application .. "/") and (not driver.application or driver.application.pid ~= pid) then
                driver.application = {pid = pid, program = program}
            end
        end
        local exited = driver.application and (state.exits or {})[driver.application.pid]
        -- An application that ends is the run's failure, unless the run asked for it with until-exit:
        -- then its ending is what the run was waiting for, and the holding step says so. Once it has said
        -- so (held), the exit is in the log for every tick that follows, through the settle and the snapshot.
        if exited and driver.phase ~= "holding" and not driver.held then
            driver.failure, driver.exit = "exited", exited
            return true
        end
        if driver.phase == "launching" then
            local verdict = path.join(opt.results, "verdict.json")
            if os.isfile(verdict) then
                local test = (json.loadfile(verdict) or {}).test or {}
                if test.spawned ~= 1 or test.exit ~= 0 then
                    driver.failure = "refused"
                    return true
                end
                driver.launched = clock()
                settle(state, send)
                return false
            end
            local stdout = path.join(opt.results, "test.stdout")
            local last = (os.isfile(stdout) and io.readfile(stdout) or ""):match("([^\n]*)\n$") or ""
            -- The unlock gesture is the next transition; another is sent only
            -- once that one has settled and the screen is still locked.
            local idle = not driver.unlocking or (state.stable or {})[driver.unlocking]
            -- charon-sblaunch names the lock state of a refusal as the token screen=locked, or screen=passcode when
            -- nothing can unlock it.
            if idle and last:find("screen=locked", 1, true) then
                send("unlock")
                driver.unlocks = driver.unlocks + 1
                driver.unlocking = (state.transition or 0) + 1
            end
        elseif driver.phase == "settling" then
            if not driver.settling and (state.transition or 0) > driver.after then
                driver.settling = state.transition
            end
            if driver.settling and (state.stable or {})[driver.settling] then
                driver.pending = path.join(opt.run, string.format("app-%d.png", #driver.shots))
                send("snapshot " .. driver.pending)
                driver.phase = "shooting"
            end
        elseif driver.phase == "shooting" then
            if (state.snapshots or {})[driver.pending] then
                table.insert(driver.shots, driver.pending)
                driver.step = driver.step + 1
                local step = opt.steps[driver.step]
                if not step then
                    return true
                end
                if step == "until-exit" then
                    driver.phase = "holding"
                    return false
                end
                send(step)
                driver.phase, driver.after = "stepping", state.transition or 0
            end
        elseif driver.phase == "holding" then
            -- The application's own end, or the run's budget spent, the first of the two; the exit is looked
            -- at first, so an application that ended is never reported as one that ran out of time.
            if driver.application and (state.exits or {})[driver.application.pid] then
                driver.held, driver.held_seconds = "exited", running()
                settle(state, send)
            elseif running() >= opt.seconds then
                driver.held, driver.held_seconds = "deadline", running()
                settle(state, send)
            end
        elseif driver.phase == "stepping" then
            if (state.transition or 0) > driver.after then
                settle(state, send)
            end
        end
        return false
    end
    return driver
end

function boot(opt)
    local run = opt.run
    os.mkdir(run)
    local log = path.join(run, "emulator.log")
    local errors = path.join(run, "emulator.stderr")
    local frame = path.join(run, "frame.png")
    os.tryrm(log)
    os.tryrm(errors)
    local scale = opt.scale or TIME_SCALE
    local argv = {"boot", "--rootfs", opt.rootfs, "--device", opt.identifier, "--host-cache", opt.cache,
                  "--display", "headless", "--gles-backend", "software", "--control-stdin",
                  "--network", opt.network or "isolated", "--frame-output", frame,
                  "--time-scale", tostring(scale)}
    local input, control = pipe.openpair("BB")
    local envs = {}
    for name, value in pairs(table.join(os.getenvs(), {TMPDIR = opt.tmpdir, VK_ICD_FILENAMES = opt.icd})) do
        table.insert(envs, name .. "=" .. value)
    end
    directory(opt.tmpdir)
    directory(opt.cache)
    local started = os.mclock()
    local proc = process.openv(opt.shade, argv, {stdin = input, stdout = log, stderr = errors, envs = envs})
    input:close()
    local state, offset, reason = {}, 0, "deadline"
    local pending = ""
    while true do
        local ok = proc:wait(500)
        if os.isfile(log) then
            local handle = io.open(log, "rb")
            handle:seek("set", offset)
            local chunk = handle:read("a") or ""
            handle:close()
            offset = offset + #chunk
            pending = pending .. chunk
            for line in pending:gmatch("([^\n]*)\n") do
                scan(state, line)
            end
            pending = pending:match("([^\n]*)$") or ""
        end
        if ok ~= 0 then
            reason = "exited"
            break
        end
        if opt.stop and opt.stop(state, function (command)
            control:write(command .. "\n", {block = true})
        end) then
            reason = "reached"
            break
        end
        if os.mclock() - started > opt.deadline * 1000 then
            break
        end
    end
    if reason ~= "exited" then
        control:write("quit\n", {block = true})
        if proc:wait(30000) == 0 then
            proc:kill()
            proc:wait(5000)
        end
    end
    control:close()
    proc:close()
    state = scan_file(log, {})
    return {state = state, reason = reason, seconds = (os.mclock() - started) / 1000, scale = scale,
            log = log, errors = errors, frame = os.isfile(frame) and frame or nil}
end

function capacity()
    local cores = os.cpuinfo("ncpu")
    local gigabytes = os.meminfo("totalsize") // 1024
    return math.max(1, math.min(cores // 3, gigabytes // 5))
end

-- The machine runs more than this factory: several sessions build packages at
-- the same time, and a run started on top of that measures the queue, not the
-- guest. A run waits for the machine to quiet down, but only for a while - a
-- busy machine must still make progress, and a slot held forever would be the
-- worse failure.
-- Builds of several sessions at once are what makes this machine slow, and a
-- build cannot be limited from the outside: a session opts in by starting its
-- build through the queue. The slot is taken by the outermost xmake only - a
-- build that starts another one passes this marker down, and the inner one
-- runs inside the slot the outer one holds, so a nested build cannot wait for
-- a slot its own parent is holding.
BUILD_SLOT = "CHARON_BUILD_SLOT"

function build_slot_name()
    return BUILD_SLOT
end

function build_capacity()
    local cores = os.cpuinfo("ncpu") or 4
    return math.max(2, cores // 4)
end

-- A slot stands for a share of the machine, not for a machine: a build that
-- takes every core inside one puts three times the cores to work when three
-- slots are held. xmake passes -j down to the cmake and ninja a package builds
-- with, and takes every core when it is not told otherwise, so a queued xmake
-- is told the share of its slot. A command that already says how many jobs it
-- wants keeps its own answer, a task that has no -j is left alone, and so is a
-- program that is not xmake: the queue holds the slot, it does not rewrite what
-- runs in it.
JOBS_TASKS = {build = true, test = true, require = true, pack = true, install = true}

function build_jobs(cores, capacity)
    return math.max(1, (cores or 4) // math.max(1, capacity or 1))
end

function queued_arguments(program, arguments, jobs)
    if path.basename(program) ~= "xmake" then
        return arguments
    end
    local task, given = nil, #arguments + 1
    for index, argument in ipairs(arguments) do
        if argument == "--" then
            given = index
            break
        elseif argument:startswith("-j") or argument:startswith("--jobs") then
            return arguments
        elseif not argument:startswith("-") and not task then
            task = argument
        end
    end
    if task and not JOBS_TASKS[task] then
        return arguments
    end
    return table.join(table.slice(arguments, 1, given - 1), {"-j", tostring(jobs)}, table.slice(arguments, given))
end

function holds_build_slot(environment)
    local value = (environment or os.getenvs())[BUILD_SLOT]
    return value ~= nil and value ~= ""
end

function crowded(load, cores)
    return load ~= nil and cores ~= nil and cores > 0 and load > cores
end

function machine_load()
    local read = try {function () return os.iorunv("sysctl", {"-n", "vm.loadavg"}) end}
    return tonumber((read or ""):match("([%d%.]+)"))
end

local function wait_for_quiet(opt)
    local cores = os.cpuinfo("ncpu")
    local patience = opt.patience or 120
    local started = os.mclock()
    local announced
    while crowded(machine_load(), cores) do
        if os.mclock() - started > patience * 1000 then
            cprint("${dim}the machine is still busy after %d s; starting anyway", patience)
            return
        end
        if not announced then
            cprint("${dim}waiting for the machine to quiet down before emulating (load %.1f on %d cores)",
                   machine_load() or 0, cores)
            announced = true
        end
        os.sleep(2000)
    end
end

function acquire(opt)
    opt = opt or {}
    local folder = directory(opt.folder or path.join(root(), "slots"))
    local count = opt.count or capacity()
    if opt.patience ~= 0 then
        wait_for_quiet(opt)
    end
    local announced
    local started = os.mclock()
    while true do
        for index = 1, count do
            local lock = io.openlock(path.join(folder, string.format("slot-%d.lock", index)))
            if lock and lock:trylock() then
                return {index = index, lock = lock}
            end
            if lock then
                lock:close()
            end
        end
        if not announced or os.mclock() - announced > 30000 then
            cprint("all %d emulator slots of this machine are taken; waiting for one (%d s so far)", count, (os.mclock() - started) // 1000)
            announced = os.mclock()
        end
        os.sleep(1000)
    end
end

function release(slot)
    slot.lock:unlock()
    slot.lock:close()
end

function clone_golden(rootfs, destination)
    local lock = io.openlock(path.directory(rootfs) .. ".lock")
    lock:lock({shared = true})
    local ok, errors = try {function () clone(rootfs, destination) return true end, catch {function (caught) return false, caught end}}
    lock:unlock()
    lock:close()
    if not ok then
        raise(errors)
    end
end

function retire(parent, opt, kept)
    for _, marker in ipairs(os.files(path.join(parent, opt.identifier .. "_" .. opt.build .. "_*", "golden.json"))) do
        local folder = path.directory(marker)
        local recorded = try {function () return json.loadfile(marker) end}
        if path.filename(folder) ~= kept and recorded and recorded.shade ~= opt.shade_hash then
            local lock = io.openlock(folder .. ".lock")
            if lock and lock:trylock() then
                remove(folder)
                lock:unlock()
                lock:close()
                os.tryrm(folder .. ".lock")
            end
        end
    end
end

-- How long an image, an owner's images, or the root filesystem one run booted is kept unused, in hours.
PRUNE_HOURS = 24

-- A folder another xmake emulate holds the lock of is in use, whatever its age.
function unlocks(folder)
    local lock = io.openlock(folder .. ".lock")
    if not lock then
        return false
    end
    local held = lock:trylock()
    if held then
        lock:unlock()
    end
    lock:close()
    return held
end

-- A folder counts as used when it or any direct child is newer than the age. One stat per child, never a
-- walk of a root filesystem: a run creates and removes the image's run/ and debug/ folder, so the image's
-- own mtime is the last time it was booted, and an owner's mtime follows the images under it.
function used(folder, hours)
    local limit = os.time() - (hours or PRUNE_HOURS) * 3600
    local newest = os.mtime(folder)
    for _, child in ipairs(os.files(path.join(folder, "*"))) do
        newest = math.max(newest, os.mtime(child))
    end
    for _, child in ipairs(os.dirs(path.join(folder, "*"))) do
        newest = math.max(newest, os.mtime(child))
    end
    return newest >= limit
end

-- The root filesystems runs booted that nothing has removed, the images nothing has booted for the age, and
-- the owners nothing has used for the age. A run that was killed cannot clean up after itself: there is no
-- signal handler in Lua and the process is gone, so the next xmake emulate is what bounds the cache. The
-- owner is a hash of the project directory, so every worktree and every scratch project keeps its own and
-- a clean of one project never reaches the others' - measured 2026-09-27, 125 root filesystems of about
-- 205 GB under images.noindex, one per run, across owners no clean had visited.
function prune(opt)
    opt = opt or {}
    local base = path.join(opt.root or root(), "images.noindex")
    local removed = {}
    if not os.isdir(base) then
        return removed
    end
    -- Judge an image by the lock a running xmake emulate really takes, plugins/emulate/main.lua:283's
    -- ctx.image .. ".lock", and the owner only by what is left of it. An owner has no lock anything takes,
    -- so asking for one judged nothing and then removed the images inside a live run's image, and asking
    -- created a stray <owner>.lock beside every owner it visited.
    for _, owner in ipairs(os.dirs(path.join(base, "*"))) do
        -- the owner's own staleness, read before anything is removed from it: deleting an image updates the
        -- owner's mtime, so a check after the pass sees a fresh owner and keeps it
        local stale_owner = not used(owner, opt.hours)
        local empty = true
        for _, image in ipairs(os.dirs(path.join(owner, "*"))) do
            empty = false
            -- the image first: an image nothing holds is removed as a directory, and its run/ and debug/
            -- clones go with it as part of it, not as a second thing removed. A held image is a live run's
            -- own working copy, and nothing inside it is touched.
            if unlocks(image) then
                if used(image, opt.hours) then
                    for _, name in ipairs({"run", "debug"}) do
                        local clone = path.join(image, name)
                        if os.isdir(clone) and not used(clone, opt.hours) then
                            remove(clone)
                            table.insert(removed, clone)
                        end
                    end
                else
                    remove(image)
                    table.insert(removed, image)
                    os.tryrm(image .. ".lock")
                end
            end
        end
        -- empty as it is *after* the pass: an image removed above left nothing, and the owner's age was read
        -- before that, because removing from a directory updates its mtime
        if #os.dirs(path.join(owner, "*")) == 0 and stale_owner then
            remove(owner)
            table.insert(removed, owner)
        end
    end
    return removed
end

function clean(opt)
    local base = opt.root or root()
    local removed = {}
    for _, name in ipairs({"tmp.noindex", "cache.noindex"}) do
        local folder = path.join(base, name)
        if os.isdir(folder) then
            remove(folder)
            table.insert(removed, folder)
        end
    end
    for _, stale in ipairs(os.dirs(path.join(base, "golden.noindex", "*.partial-*"))) do
        remove(stale)
        table.insert(removed, stale)
    end
    for _, folder in ipairs(opt.images or {}) do
        if os.isdir(folder) then
            remove(folder)
            table.insert(removed, folder)
        end
    end
    if opt.goldens then
        for _, marker in ipairs(os.files(path.join(base, "golden.noindex", "*", "golden.json"))) do
            local folder = path.directory(marker)
            local lock = io.openlock(folder .. ".lock")
            if lock and lock:trylock() then
                remove(folder)
                table.insert(removed, folder)
                lock:unlock()
                lock:close()
                os.tryrm(folder .. ".lock")
            end
        end
    end
    return removed
end

function golden(opt)
    -- The image is what the emulator and the home step made of the firmware, so
    -- it is keyed by both: a change to what home writes is another image.
    local written = {}
    for _, key in ipairs(table.join(setup_keys(opt.firmware, opt.build), LOCKDOWN_KEYS)) do
        table.insert(written, table.concat(key, " "))
    end
    local key = string.format("%s_%s_%s", opt.identifier, opt.build, hash.strhash128(opt.shade_hash .. ";" ..
                              table.concat(opt.steps or {"home"}, ";") .. ";" .. table.concat(written, ";")))
    local parent = path.join(opt.root or root(), "golden.noindex")
    local folder = path.join(parent, key)
    local marker = path.join(folder, "golden.json")
    if os.isfile(marker) then
        return path.join(folder, "rootfs")
    end
    directory(parent)
    local lock = io.openlock(path.join(parent, key .. ".lock"))
    lock:lock()
    local ok, errors = try {
        function ()
            if os.isfile(marker) then
                return true
            end
            for _, stale in ipairs(os.dirs(path.join(parent, key .. ".partial-*"))) do
                remove(stale)
            end
            local staging = path.join(parent, key .. ".partial-" .. os.getpid())
            local rootfs = path.join(staging, "rootfs")
            clone(opt.firmware, rootfs)
            home(rootfs, opt.build)
            local migrates = os.isfile(guest_path(rootfs, MIGRATOR))
            cprint("${bright}booting %s %s once past its first-boot migration${clear} for a golden image", opt.identifier, opt.build)
            local booted = opt.boot(table.join(opt, {rootfs = rootfs, run = staging, stop = function (state)
                return state.springboard and (state.migrated or not migrates)
            end}))
            if booted.reason ~= "reached" then
                raise("%s %s did not get past %s within %d seconds; the emulator log is %s", opt.identifier, opt.build,
                      milestone(booted.state), opt.deadline, booted.log)
            end
            json.savefile(path.join(staging, "golden.json"), {identifier = opt.identifier, build = opt.build, shade = opt.shade_hash, seconds = booted.seconds})
            remove(folder)
            os.mv(staging, folder)
            retire(parent, opt, key)
            return true
        end,
        catch {
            function (caught)
                return false, caught
            end
        }
    }
    lock:unlock()
    lock:close()
    if not ok then
        raise(errors)
    end
    return path.join(folder, "rootfs")
end
