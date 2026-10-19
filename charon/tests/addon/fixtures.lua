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

-- An armv7 object compiled from C source, symbols hidden unless the source says otherwise.
function object(folder, name, source)
    io.writefile(path.join(folder, name .. ".c"), source)
    run(folder, "xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot", "-fvisibility=hidden", "-c", name .. ".c", "-o", name .. ".o"})
    return path.join(folder, name .. ".o")
end

-- The version ld64 reports, which clang must be told to emit what that linker can take.
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
    local folder = os.tmpfile() .. ".dir"
    os.mkdir(folder)
    return folder
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

-- Installs this working tree as the addon a port reaches through @addon/charon, under a version named after the copy's
-- own commit, so a run against changed files is never answered with the addon a previous run installed.
function repository(folder)
    local root = path.absolute(path.join(os.scriptdir(), "..", ".."))
    local copy = path.join(folder, "charon")
    os.mkdir(copy)
    local listed = os.iorunv("git", {"-C", root, "ls-files", "-c", "-o", "--exclude-standard"})
    for _, file in ipairs(listed:split("\n", {plain = true})) do
        file = file:trim()
        if file ~= "" and os.isfile(path.join(root, file)) then
            os.mkdir(path.directory(path.join(copy, file)))
            os.cp(path.join(root, file), path.join(copy, file))
        end
    end
    for _, argv in ipairs({{"init", "-q", "-b", "main"}, {"add", "-A"},
                           {"-c", "user.name=charon", "-c", "user.email=charon@example.com", "commit", "-q", "-m", "the working tree"}}) do
        os.vrunv("git", table.join({"-C", copy}, argv))
    end
    local head = os.iorunv("git", {"-C", copy, "rev-parse", "HEAD"}):trim()
    local version = "v0.0.0-" .. head:sub(1, 12)
    os.vrunv("git", {"-C", copy, "tag", version})

    -- The recipe of the addon is read from this directory, while the addon itself is cloned from its history, so naming
    -- the copy and its one version here needs no commit of its own.
    --
    -- A plain filesystem path makes git clone with --local, hardlinking or copying loose objects straight out of this
    -- scratch .git rather than fetching them through git's own protocol; that copy step races intermittently against
    -- this same repository ("failed to copy file to .../objects/<hash>: No such file or directory", a different object
    -- each time - git's own warning names the fix). A file:// URL takes git off that fast path.
    local recipe = path.join(copy, "addons", "c", "charon", "xmake.lua")
    local text = io.readfile(recipe):gsub('add_urls%("[^"]*"%)', 'add_urls("file://' .. path.join(copy, ".git") .. '")', 1)
    io.writefile(recipe, text .. string.format('    add_versions("%s", "%s")\n', version, head))
    return copy, version
end

-- mode: the build mode to configure (-m), when the project declares mode rules.
function build(at, mode)
    os.vrunv("xmake", table.join({"f", "-p", "iphoneos", "-a", "armv7", "-y"}, mode and {"-m", mode} or {}), {curdir = at})
    os.vrunv("xmake", {"build", "-y"}, {curdir = at})
end
