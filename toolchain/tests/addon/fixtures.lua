SYSTEM_STUB = [[--- !tapi-tbd
tbd-version: 4
targets: [ armv7-ios, arm64-ios ]
install-name: '/usr/lib/libSystem.B.dylib'
exports:
  - targets: [ armv7-ios, arm64-ios ]
    symbols: [ %s ]
...
]]

function system_stub(symbols, installed)
    local text = SYSTEM_STUB:format(symbols or "dyld_stub_binder")
    if installed then
        text = text:gsub("/usr/lib/libSystem.B.dylib", installed)
    end
    return text
end

function run(folder, program, argv)
    return os.iorunv(program, argv, {curdir = folder})
end

function object(folder, name, source)
    io.writefile(path.join(folder, name .. ".c"), source)
    run(folder, "xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot", "-fvisibility=hidden", "-c", name .. ".c", "-o", name .. ".o"})
    return path.join(folder, name .. ".o")
end

function linker_version(ld64)
    local out, errors = os.iorunv(ld64, {"-v"})
    return ((out or "") .. (errors or "")):match("PROJECT:ld64%-(%S+)")
end

function link(folder, ld64, output, triple, source, extra)
    local linker = triple:startswith("armv7") and ld64 or "ld"
    run(folder, "xcrun", table.join({"clang", "-target", triple, "-Wno-incompatible-sysroot", "-fuse-ld=" .. linker,
                                     "-nostdlib", "-L.", "-lSystem"}, extra or {}, {"-o", output, source}))
    return path.join(folder, output)
end

function section_offset(folder, binary, segment, section)
    local listing = run(folder, "xcrun", {"otool", "-l", binary})
    for block in (listing .. "Section"):gmatch("(.-)Section") do
        if block:match("sectname%s+" .. section:gsub("_", "%%_") .. "%s") and block:match("segname%s+" .. segment:gsub("_", "%%_") .. "%s") then
            return tonumber(block:match("offset%s+(%d+)"))
        end
    end
    raise("%s has no %s,%s", binary, segment, section)
end

function slot(file, position)
    return string.unpack("<I4", io.readfile(file, {encoding = "binary"}), position + 1)
end

function edited(source, destination, position, value)
    local data = io.readfile(source, {encoding = "binary"})
    io.writefile(destination, data:sub(1, position) .. string.pack("<I4", value) .. data:sub(position + 5), {encoding = "binary"})
    return destination
end

function scratch()
    return import("@addon.revenant.workspace", {anonymous = true}).fresh("tests")
end

function empty_repository(folder)
    local main = path.join(folder, "main")
    if not os.isdir(main) then
        os.mkdir(main)
        os.vrunv("git", {"init", "-q", main})
        os.vrunv("git", {"-C", main, "symbolic-ref", "HEAD", "refs/heads/master"})
        os.vrunv("git", {"-C", main, "-c", "user.name=revenant", "-c", "user.email=revenant@example.invalid", "commit", "-q", "--allow-empty", "-m", "empty"})
    end
    return main
end

function refusal(action)
    local errors
    try {
        action,
        catch {
            function (raised)
                errors = tostring(raised)
            end
        }
    }
    return errors
end

local function working_tree(source, paths, destination, prefix)
    local listed = os.iorunv("git", table.join({"-C", source, "ls-files", "-c", "-o", "--exclude-standard", "--"}, paths))
    for _, file in ipairs(listed:split("\n", {plain = true})) do
        file = file:trim()
        if file:startswith(prefix) and os.isfile(path.join(source, file)) then
            local relative = file:sub(#prefix + 1)
            os.mkdir(path.directory(path.join(destination, relative)))
            os.cp(path.join(source, file), path.join(destination, relative))
        end
    end
end

local function commit(folder)
    for _, argv in ipairs({{"init", "-q", "-b", "main"}, {"add", "-A"},
                           {"-c", "user.name=revenant", "-c", "user.email=revenant@example.com", "commit", "-q", "-m", "the working tree"}}) do
        os.vrunv("git", table.join({"-C", folder}, argv))
    end
    return os.iorunv("git", {"-C", folder, "rev-parse", "HEAD"}):trim()
end

function repository(folder)
    local toolchain = path.directory(path.directory(path.absolute(os.scriptdir())))
    local top = path.directory(toolchain)
    local copy = path.join(folder, "revenant")
    local addon = path.join(folder, "revenant-addon")
    os.mkdir(copy)
    os.mkdir(addon)
    working_tree(top, {"packages", "addons", "toolchain"}, copy, "")
    working_tree(top, {"toolchain"}, addon, "toolchain/")
    commit(copy)
    local head = commit(addon)
    local version = "v0.0.0-" .. head:sub(1, 12)
    os.vrunv("git", {"-C", addon, "tag", version})

    local recipe = path.join(copy, "addons", "r", "revenant", "xmake.lua")
    local text = io.readfile(recipe):gsub('add_urls%("[^"]*"%)', 'add_urls("file://' .. path.join(addon, ".git") .. '")', 1)
    io.writefile(recipe, text .. string.format('    add_versions("%s", "%s")\n', version, head))
    return copy, version
end

function build(at, mode)
    os.vrunv(os.programfile(), table.join({"f", "-P", at, "-p", "iphoneos", "-a", "armv7", "-y"}, mode and {"-m", mode} or {}), {curdir = at})
    os.vrunv(os.programfile(), {"build", "-P", at, "-y"}, {curdir = at})
end
