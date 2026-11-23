import("core.base.bytes")

local source = debug.getinfo(1, "S").short_src or ""
if source:startswith("@") then
    source = source:sub(2)
end
local scriptdir = path.absolute(path.directory(source))
local byteorder = import("byteorder", {rootdir = scriptdir, anonymous = true})
local RECORD_LIMIT = 4100
local HASH_CHUNK = 1000
local NAMES = {next = function () return hash.uuid() end}

function names()
    return NAMES
end
local PRIVATE_FOLDERS = {".cache*/**", "build/**", ".xmake/**", ".claude/worktrees/**"}
local STORE_PACKAGES = {"llvm", "swift", "swift-bootstrap", "swift-runtime", "libcxx", "apple-compat", "iphoneos-sdk", "ld64", "ldid"}
local TOOL_NAMES = {"git", "rsync", "cmake", "ninja", "xcrun", "clang", "cc", "make", "sh"}
local compiled = {}
local installed_text

local function cache()
    return import("cache", {rootdir = scriptdir, anonymous = true})
end

function digest(text)
    return hash.sha256(bytes(text))
end

function git(folder, args)
    return os.iorunv("git", table.join({"-C", folder}, args))
end

function tracked(folder, pattern)
    local files = {}
    for file in git(folder, {"ls-files", "--", pattern}):gmatch("[^\n]+") do
        table.insert(files, file)
    end
    return files
end

function lists_folder()
    local pathname = path.join(cache().root(), "scratch", "prepush-lists")
    os.mkdir(pathname)
    return pathname
end

function git_records(folder, args, what)
    local scratch = lists_folder(folder)
    local file = path.join(scratch, "list-" .. NAMES.next())
    local text, failure
    try {
        function ()
            local status = os.execv("git", table.join({"-C", folder}, args), {stdout = file, stderr = file .. ".errors", try = true})
            if status ~= 0 then
                failure = string.format("git exited with status %s (%s)", tostring(status), (io.readfile(file .. ".errors") or ""):trim():sub(1, 200))
            else
                local handle = io.open(file, "rb")
                text = handle:read("*all")
                handle:close()
            end
        end,
        catch {
            function (raised)
                failure = tostring(raised):sub(1, 200)
            end
        },
        finally {
            function ()
                os.tryrm(file)
                os.tryrm(file .. ".errors")
            end
        }
    }
    if failure then
        raise("prepush: %s could not be read cleanly: %s; nothing was run and no remembered verdict was used", what or "a list of git", failure)
    end
    return text
end

function split_records(text, what)
    local records = {}
    if text == "" then
        return records
    end
    for record in text:gmatch("[^\0]+") do
        if #record > RECORD_LIMIT then
            raise("prepush: %s could not be read cleanly: a record of %d bytes is no path; nothing was run and no remembered verdict was used", what, #record)
        end
        table.insert(records, record)
    end
    local _, boundaries = text:gsub("%z", "")
    if boundaries ~= #records then
        raise("prepush: %s could not be read cleanly: the output of git is not a list of records that each end at a boundary (%d records, %d boundaries); nothing was run and no remembered verdict was used", what, #records, boundaries)
    end
    return records
end

local function dirty_pathspec()
    local spec = {"--", "."}
    for _, folder in ipairs(PRIVATE_FOLDERS) do
        table.insert(spec, ":(exclude,glob)" .. folder)
    end
    return spec
end

function dirty_entries(folder, reader)
    local what = "the list of uncommitted files"
    local tokens, entries = split_records((reader or git_records)(folder, table.join({"status", "--porcelain=v1", "--untracked-files=all", "-z"}, dirty_pathspec()), what), what), {}
    local index = 1
    while index <= #tokens do
        if not tokens[index]:find("^[ MTADRCU%?!][ MTADRCU%?!] ") then
            raise("prepush: %s could not be read cleanly: a record that is no status line (%d bytes, starts with %q); nothing was run and no remembered verdict was used", what, #tokens[index], tokens[index]:sub(1, 12))
        end
        local status = tokens[index]:sub(1, 2)
        table.insert(entries, {status = status, file = tokens[index]:sub(4)})
        if status:find("[RC]") then
            index = index + 1
            if index > #tokens then
                raise("prepush: %s could not be read cleanly: a rename or copy without its source; nothing was run and no remembered verdict was used", what)
            end
        end
        index = index + 1
    end
    return entries
end

function manifest(folder, reader, hasher)
    local current = {}
    for line in git(folder, {"ls-files", "-s"}):gmatch("[^\n]+") do
        local mode, sha, file = line:match("^(%d+) (%x+) %d\t(.+)$")
        current[file] = mode .. " " .. sha
    end
    local pending, dirty = {}, 0
    for _, entry in ipairs(dirty_entries(folder, reader)) do
        local full = path.join(folder, entry.file)
        dirty = dirty + 1
        if os.islink(full) then
            current[entry.file] = "link " .. os.readlink(full)
        elseif os.isfile(full) then
            table.insert(pending, entry.file)
        else
            current[entry.file] = "deleted"
        end
    end
    local digests = {}
    for from = 1, #pending, HASH_CHUNK do
        local chunk = table.slice(pending, from, math.min(from + HASH_CHUNK - 1, #pending))
        for line in (hasher or git)(folder, table.join({"hash-object", "--"}, chunk)):gmatch("[^\n]+") do
            table.insert(digests, line)
        end
    end
    if #digests ~= #pending then
        raise("prepush: the content of the uncommitted files could not be read cleanly: %d files, %d digests; nothing was run and no remembered verdict was used", #pending, #digests)
    end
    for index, file in ipairs(pending) do
        current[file] = "file " .. digests[index]
    end
    return current, dirty
end

function pattern_of(glob)
    local found = compiled[glob]
    if not found then
        local escaped = glob:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0")
        if escaped:endswith("/") then
            found = "^" .. escaped .. ".*$"
        else
            local wide = escaped:gsub("%*%*/", "\1"):gsub("%*%*", "\1"):gsub("%*", "[^/]*")
            found = "^" .. wide:gsub("\1", ".*") .. "$"
        end
        compiled[glob] = found
    end
    return found
end

function matches(file, globs)
    for _, glob in ipairs(globs or {}) do
        if file:match(pattern_of(glob)) then
            return true
        end
    end
    return false
end

function reads_of(step)
    local reads = step.reads
    if type(reads) == "function" then
        reads = reads()
    end
    return reads or {"**"}
end

function manifest_digest(files)
    local lines = {}
    for file, value in pairs(files) do
        table.insert(lines, file .. " " .. value)
    end
    byteorder.sort(lines)
    return digest(table.concat(lines, "\n"))
end

function cached_value(folder, key, compute)
    local file = path.join(cache().store(), "suite-memo", folder, key)
    local value = try { function () return io.readfile(file) end }
    if value then
        return value
    end
    value = compute()
    os.mkdir(path.directory(file))
    local temporary = file .. ".tmp." .. hash.uuid()
    io.writefile(temporary, value)
    os.mv(temporary, file)
    local folder = path.directory(file)
    local kept = {}
    for _, entry in ipairs(os.files(path.join(folder, "*"))) do
        table.insert(kept, string.format("%d %s", os.mtime(entry), entry))
    end
    byteorder.sort(kept)
    for index = 1, #kept - 40 do
        os.tryrm(kept[index]:match("^%d+ (.*)$"))
    end
    return value
end

function selected(files, step, always)
    local reads = reads_of(step)
    local lines = {}
    for file, value in pairs(files) do
        if (matches(file, reads) and not matches(file, step.skips or {})) or matches(file, always or {}) then
            table.insert(lines, file .. " " .. value)
        end
    end
    byteorder.sort(lines)
    return lines
end

function environment_of(step)
    local values = {}
    for _, name in ipairs(step.env or {}) do
        table.insert(values, name .. "=" .. (os.getenv(name) or ""))
    end
    return table.concat(values, "\n")
end

function ambient_environment(skips)
    local lines = {}
    for name, value in pairs(os.getenvs()) do
        if (name:find("^REVENANT_") or name == "XMAKE_GLOBALDIR") and not (skips or {})[name] and value ~= "" then
            table.insert(lines, name .. "=" .. value)
        end
    end
    byteorder.sort(lines)
    return table.concat(lines, "\n")
end

function inputs(folder, reader, hasher)
    local files, dirty = manifest(folder, reader, hasher)
    return {
        files = files,
        dirty = dirty,
        tool = digest(os.iorunv(os.programfile(), {"--version"})),
        host = os.host() .. "/" .. os.arch(),
    }
end

function key_of(input, step, version, always, skips)
    local facts = step.facts and step.facts() or ""
    return digest(table.concat({version, step.name, step.version or "1", input.tool, input.host, ambient_environment(skips), environment_of(step), facts,
                                 table.concat(selected(input.files, step, always), "\n")}, "\n"))
end

local function checkout()
    return path.directory(path.directory(scriptdir))
end

local function toolchain_facts()
    local facts = {}
    for _, probe in ipairs({{"xcode-select", {"-p"}}, {"xcodebuild", {"-version"}}, {"xcrun", {"--show-sdk-path"}}, {"xcrun", {"--show-sdk-version"}}}) do
        table.insert(facts, try { function () return (os.iorunv(probe[1], probe[2]):gsub("%s+", " ")) end } or "none")
    end
    return table.concat(facts, "\n")
end

function resolved_tools()
    local lines = {}
    for _, name in ipairs(TOOL_NAMES) do
        local found = try { function () return os.iorunv("sh", {"-c", "command -v " .. name}):trim() end } or "none"
        local version = try { function () return os.iorunv("sh", {"-c", name .. " --version 2>&1 | head -n 1"}):trim() end } or ""
        table.insert(lines, name .. "=" .. found .. " " .. version)
    end
    return table.concat(lines, "\n")
end

function store_installs(folder)
    local lines = {}
    local packages = folder or path.join(cache().store(), "xmake-global", ".xmake", "packages")
    for _, name in ipairs(STORE_PACKAGES) do
        for _, install in ipairs(os.filedirs(path.join(packages, name:sub(1, 1), name, "*", "*"))) do
            local line = path.relative(install, packages):gsub("%.g[^/]+$", "")
            if os.islink(install) then
                line = line .. " -> " .. path.filename(os.readlink(install)):gsub("%.g[^/]+$", "")
            end
            local manifest = path.join(install, "manifest.txt")
            table.insert(lines, line .. " " .. (os.isfile(manifest) and hash.sha256(manifest) or "no manifest"))
        end
    end
    byteorder.sort(lines)
    return table.concat(lines, "\n")
end

function sdk_content()
    local sdk = import("sdk", {rootdir = path.join(checkout(), "frameworks", "Backports", "tools"), anonymous = true})
    local analysis = import("analysis_cache", {rootdir = scriptdir, anonymous = true})
    local lines = {}
    for _, real in ipairs(analysis.sdk_paths()) do
        table.insert(lines, try { function () return sdk.cache_key(real) end } or "unreadable")
    end
    byteorder.sort(lines)
    return table.concat(lines, "\n")
end

local function inode(folder)
    return try { function () return os.iorunv("stat", {"-f", "%i", folder}):trim() end } or ""
end

local function cached_facts(name, signature, compute)
    local folder = path.join(cache().store(), "suite-memo", "facts", name)
    local file = path.join(folder, digest(signature))
    local value = try { function () return io.readfile(file) end }
    if value then
        return value
    end
    value = compute()
    os.mkdir(folder)
    local temporary = file .. ".tmp." .. hash.uuid()
    io.writefile(temporary, value)
    os.mv(temporary, file)
    return value
end

function installed_facts(log)
    if not installed_text then
        local began = os.time()
        if log then
            log("reading the installed toolchain (xcode, the tools on the path, the store's packages, the SDK), once")
        end
        installed_text = table.concat({toolchain_facts(), resolved_tools(), store_installs(), sdk_content()}, "\n--\n")
        if log then
            log(string.format("the installed toolchain is read, %ds", os.time() - began))
        end
    end
    return installed_text
end

function slug(name)
    return (name:gsub("%s+", "-"))
end

function recalled(store, name, key)
    local file = path.join(store, slug(name), key)
    if not os.isfile(file) then
        return nil
    end
    local record = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        local field, value = line:match("^(%S+) (.*)$")
        if field then
            record[field] = value
        end
    end
    return record.verdict == "ok" and record or nil
end

function remembered(store, name, key, record, keep)
    local folder = path.join(store, slug(name))
    os.mkdir(folder)
    local lines = {"verdict ok"}
    for _, field in ipairs({"seconds", "worktree", "head", "at"}) do
        table.insert(lines, field .. " " .. tostring(record[field]))
    end
    local temporary = path.join(folder, key .. ".tmp." .. hash.uuid())
    io.writefile(temporary, table.concat(lines, "\n") .. "\n")
    os.mv(temporary, path.join(folder, key))
    local kept = {}
    for _, file in ipairs(os.files(path.join(folder, "*"))) do
        if not file:find(".tmp.", 1, true) then
            table.insert(kept, string.format("%d %s", os.mtime(file), file))
        end
    end
    byteorder.sort(kept)
    for index = 1, #kept - (keep or 40) do
        os.tryrm(kept[index]:match("^%d+ (.*)$"))
    end
end
