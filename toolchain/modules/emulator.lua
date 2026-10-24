import("core.base.json")
import("core.base.pipe")
import("core.base.process")
import("apple.dyld")
import("apple.macho")
import("gdb")
import("apple.firmware")
import("byteorder")

RESULTS = "private/var/revenant"
REPORTS = "private/var/logs/CrashReporter"
RUNNER = "usr/libexec/revenant-runner"
LAUNCHER = "usr/libexec/revenant-sblaunch"
INSTALLATION_CACHE = "private/var/mobile/Library/Caches/com.apple.mobile.installation.plist"
RUNNER_JOB = "System/Library/LaunchDaemons/org.revenant.emulator.runner.plist"
LAUNCHD_CONF = "private/etc/launchd.conf"
RUNNER_TASK = RESULTS .. "/job"
MIGRATOR = "System/Library/PrivateFrameworks/DataMigration.framework/Support/DataMigrator"
SETUP_KEYS = {{"SetupDone", "-bool", "YES"}, {"SetupFinishedAllSteps", "-bool", "YES"}, {"AssistantPresented", "-bool", "YES"}}
SETUP = "Applications/Setup.app/Setup"
LOCKDOWN_KEYS = {{"com\\.apple\\.purplebuddy-SetupState", "-string", "DONE"}}
CRASH_LOOP = 3
REGISTERS = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12", "sp", "lr", "pc", "cpsr"}
TIME_SCALE = 10
UNLOCK_SLIDE = "drag 50 430 300 430 900 40"

function launch_instructions(log)
    local text = os.isfile(log) and io.readfile(log) or ""
    local ticks = text:match("%[perf%-display%] label=launch cpu%-ticks=(%d+)")
    return ticks and tonumber(ticks) or nil
end

function last_visible_pixels(log)
    local text = os.isfile(log) and io.readfile(log) or ""
    local visible
    for pixels in text:gmatch("%[display%] frame=%d+ visible%-pixels=(%d+)") do
        visible = tonumber(pixels)
    end
    return visible
end

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

function profiles(emulator)
    local listed = {}
    for line in os.iorunv(emulator, {"profile", "--list"}):gmatch("[^\n]+") do
        table.insert(listed, line:trim())
    end
    return listed
end

function kernels(emulator)
    local known = {}
    for line in os.iorunv(emulator, {"abi"}):gmatch("[^\n]+") do
        local name = line:match("^%s+(darwin%S+)$")
        if name then
            table.insert(known, name)
        end
    end
    return known
end

function kernel(emulator, build)
    local output = try {function () return os.iorunv(emulator, {"abi", "--ios-build", build}) end}
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
            raise("the emulator has no profile for %s; it emulates %s", device.identifier, table.concat(emulated, ", "))
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
    raise("no device the emulator emulates (%s) runs %s release %s or later; pass -d and -r", table.concat(emulated, ", "), opt.architecture, opt.release)
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

function debugged(opt)
    local run = directory(opt.run)
    local log = path.join(run, "emulator.log")
    local errors = path.join(run, "emulator.stderr")
    os.tryrm(log)
    os.tryrm(errors)
    local port = opt.port or (12000 + os.getpid() % 2000)
    local argv = table.join({"boot", "--rootfs", opt.rootfs, "--device", opt.identifier, "--host-cache", opt.cache,
                             "--display", "headless", "--gles-backend", "software", "--network", opt.network or "isolated",
                             "--binary", opt.guest, "--gdb", tostring(port)}, core_arguments(opt))
    local envs = {}
    for name, value in pairs(table.join(os.getenvs(), {TMPDIR = opt.tmpdir, VK_ICD_FILENAMES = opt.icd})) do
        table.insert(envs, name .. "=" .. value)
    end
    directory(opt.tmpdir)
    directory(opt.cache)
    local proc = process.openv(opt.emulator, argv, {stdout = log, stderr = errors, envs = envs})
    local report = try {
        function ()
            local connection = gdb.connect(port, {patience = opt.patience or 120})
            local stopped = gdb.ask(connection, "c")
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
                registers[(second >> 12) & 0xf] = nil
            else
                registers = {}
            end
            at = at + 4
        else
            if first & 0xff78 == 0x4478 then
                local destination = (first & 7) | ((first >> 4) & 8)
                local known = registers[destination]
                registers[destination] = known and known.immediate and {address = (known.immediate + address + 4) & 0xffffffff} or nil
            elseif first & 0xffc0 == 0x6800 then
                local known = registers[(first >> 3) & 7]
                registers[first & 7] = known and known.address and inside("__objc_selrefs", known.address) and
                                       {selector = text(word(known.address))} or nil
            elseif first & 0xf800 == 0x2000 then
                registers[(first >> 8) & 7] = {immediate = first & 0xff}
            elseif first & 0xff00 == 0x4600 then
                registers[(first & 7) | ((first >> 4) & 8)] = registers[(first >> 3) & 0xf]
            else
                registers = {}
            end
            at = at + 2
        end
    end
    return numbers, unfollowed
end

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
            os.vrunv("cp", {"-c", "-p", source, target})
            local wanted, got = os.filesize(source), os.isfile(target) and os.filesize(target) or -1
            if got ~= wanted then
                remove(path.directory(destination))
                raise("%s is %d B in the package and %d B in the image, so the image would hold a program that was not built",
                       relative, wanted, got)
            end
        end
    end
end

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

function launch_command(identifier, seconds)
    return {"/" .. LAUNCHER, "--wait", tostring(seconds), "--stdout", "/" .. RESULTS .. "/app.stdout",
            "--stderr", "/" .. RESULTS .. "/app.stderr", identifier}
end

local function escaped(text)
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

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
        "<key>Label</key><string>org.revenant.emulator.runner</string>",
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
        elseif program:endswith("/revenant-runner") then
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

function report_output(folder, output)
    if output == 0 then
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

function launch_driver(opt)
    local driver = {phase = "launching", shots = {}, step = 0, unlocks = 0}
    local clock = opt.clock or os.mclock
    local scale = opt.scale or TIME_SCALE
    if table.contains(opt.steps, "until-exit") and not opt.seconds then
        raise("until-exit holds for the run's budget, and the run gave no seconds")
    end
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
                send("perf-begin launch")
                settle(state, send)
                return false
            end
            local stdout = path.join(opt.results, "test.stdout")
            local last = (os.isfile(stdout) and io.readfile(stdout) or ""):match("([^\n]*)\n$") or ""
            local idle = not driver.unlocking or (state.stable or {})[driver.unlocking]
            if idle and last:find("screen=locked", 1, true) then
                send(driver.unlocks == 0 and "unlock" or UNLOCK_SLIDE)
                driver.unlocks = driver.unlocks + 1
                driver.unlocking = (state.transition or 0) + 1
            end
        elseif driver.phase == "settling" then
            if not driver.settling and (state.transition or 0) > driver.after then
                driver.settling = state.transition
            end
            if driver.settling and (state.stable or {})[driver.settling] then
                if driver.launched and not driver.measured then
                    send("perf-end")
                    driver.measured = true
                end
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

function boot_expired(now, started, progressed, deadline, slowdown)
    local factor = slowdown or 1
    if now - progressed > deadline * factor * 1000 then
        return "stalled"
    end
    if now - started > deadline * 10 * factor * 1000 then
        return "deadline"
    end
    return nil
end

function host_slowdown()
    local cores = os.cpuinfo("ncpu")
    local load = machine_load()
    if load == nil or cores == nil or cores <= 0 then
        return 1
    end
    return math.max(1, load / cores)
end

function core_arguments(opt)
    if opt.cores == nil then
        return {}
    end
    return {"--cores", tostring(opt.cores)}
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
    local argv = table.join({"boot", "--rootfs", opt.rootfs, "--device", opt.identifier, "--host-cache", opt.cache,
                             "--display", "headless", "--gles-backend", "software", "--control-stdin",
                             "--network", opt.network or "isolated", "--frame-output", frame,
                             "--time-scale", tostring(scale)}, core_arguments(opt))
    if opt.perf then
        table.insert(argv, "--perf-summary")
    end
    local input, control = pipe.openpair("BB")
    local envs = {}
    for name, value in pairs(table.join(os.getenvs(), {TMPDIR = opt.tmpdir, VK_ICD_FILENAMES = opt.icd})) do
        table.insert(envs, name .. "=" .. value)
    end
    directory(opt.tmpdir)
    directory(opt.cache)
    local started = os.mclock()
    local progressed = started
    local slowdown, checked = host_slowdown(), started
    local proc = process.openv(opt.emulator, argv, {stdin = input, stdout = log, stderr = errors, envs = envs})
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
            if #chunk > 0 then
                progressed = os.mclock()
            end
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
        if os.mclock() - checked > 30000 then
            slowdown, checked = host_slowdown(), os.mclock()
        end
        local expired = boot_expired(os.mclock(), started, progressed, opt.deadline, slowdown)
        if expired then
            reason = expired
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

BUILD_SLOT = "REVENANT_BUILD_SLOT"

function build_slot_name()
    return BUILD_SLOT
end

function build_capacity()
    local cores = os.cpuinfo("ncpu") or 4
    return math.max(2, cores // 4)
end

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
        if path.filename(folder) ~= kept and recorded and recorded.emulator ~= opt.emulator_hash then
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

PRUNE_HOURS = 24

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

function prune(opt)
    opt = opt or {}
    local base = path.join(opt.root or root(), "images.noindex")
    local removed = {}
    if not os.isdir(base) then
        return removed
    end
    for _, owner in ipairs(os.dirs(path.join(base, "*"))) do
        local stale_owner = not used(owner, opt.hours)
        local empty = true
        for _, image in ipairs(os.dirs(path.join(owner, "*"))) do
            empty = false
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
    local written = {}
    for _, key in ipairs(table.join(setup_keys(opt.firmware, opt.build), LOCKDOWN_KEYS)) do
        table.insert(written, table.concat(key, " "))
    end
    local key = string.format("%s_%s_%s", opt.identifier, opt.build, hash.strhash128(opt.emulator_hash .. ";" ..
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
                raise("%s %s did not get past %s: the emulator %s (-t %d seconds); the emulator log is %s", opt.identifier, opt.build,
                      milestone(booted.state), booted.reason == "stalled" and "wrote nothing for that long" or "ran past its whole-boot limit",
                      opt.deadline, booted.log)
            end
            json.savefile(path.join(staging, "golden.json"), {identifier = opt.identifier, build = opt.build, emulator = opt.emulator_hash, seconds = booted.seconds})
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
