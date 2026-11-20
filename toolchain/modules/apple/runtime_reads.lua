local lowered = import("lowered", {rootdir = os.scriptdir(), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local FOLDER = path.join(os.scriptdir(), "..", "..", "src", "swift-runtime", "reads")
local RECORD = "REVENANT_RUNTIME_READS_RECORD"
local BACKPORTS_TOOLS = path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "tools")

function record_variable()
    return RECORD
end

function recording()
    local folder = os.getenv(RECORD)
    return folder ~= nil and folder ~= ""
end

function headers_file()
    return path.join(FOLDER, "lowered-reads.txt")
end

function lookups_file()
    return path.join(FOLDER, "swift-overlay-reads.txt")
end

local function lines_of(file)
    local found = {}
    if os.isfile(file) then
        for line in io.lines(file) do
            if line ~= "" then
                table.insert(found, line)
            end
        end
    end
    return found
end

function headers()
    return lines_of(headers_file())
end

function allowed_headers()
    local allowed = {}
    for _, relative in ipairs(headers()) do
        allowed[relative] = true
    end
    return allowed
end

function lookups()
    return lines_of(lookups_file())
end

function lowered_key(sdk)
    local identity = import("sdk", {rootdir = BACKPORTS_TOOLS, anonymous = true}).sdk_identity(sdk)
    local own = hash.strhash128(io.readfile(path.join(os.scriptdir(), "runtime_reads.lua")))
    return hash.strhash128(lowered.lowering_key(identity) .. "\0" .. own .. "\0" .. table.concat(headers(), "\n") .. "\n")
end

local function cached(sdk, action)
    local key = lowered_key(sdk)
    local file = path.join(import("@addon.revenant.cache", {anonymous = true}).root(), "runtime-reads", key)
    if os.isfile(file) then
        return io.readfile(file)
    end
    local value = action()
    os.mkdir(path.directory(file))
    local temp = file .. "." .. hash.strhash128(tostring({}) .. file) .. ".part"
    io.writefile(temp, value)
    os.mv(temp, file)
    return value
end

function lowered_rows(sdk, set, list)
    local only = {}
    for _, relative in ipairs(list or headers()) do
        only[path.join(sdk, relative)] = true
    end
    local changed = lowered.lowered_texts(sdk, set, {}, only)
    local rows = {}
    for file, text in pairs(changed) do
        local relative = path.relative(file, sdk)
        if not file:endswith(".h") or (only[file] and text ~= io.readfile(file)) then
            table.insert(rows, relative .. "=" .. hash.strhash128(text .. "\n"))
        end
    end
    byteorder.sort(rows)
    return hash.strhash128(table.concat(rows, "\n") .. "\n")
end

function lowered_digest(sdk, set)
    return cached(sdk, function ()
        return lowered_rows(sdk, set)
    end)
end

function swift_digest(set, keys)
    local names, types = lowered.swift_names(set), set.types or {}
    local rows = {}
    for _, key in ipairs(keys or lookups()) do
        local kind, name = key:match("^(%a+) (.*)$")
        assert(kind == "name" or kind == "type", "swift-overlay-reads.txt holds a line that is neither 'name <key>' nor 'type <key>': " .. key)
        local values = kind == "name" and names or types
        table.insert(rows, key .. "=" .. (values[name] and "1" or "0"))
    end
    return hash.strhash128(table.concat(rows, "\n") .. "\n")
end

function digest(sdk)
    local set = lowered.read_all_members()
    return hash.strhash128(lowered_digest(sdk, set) .. "\n" .. swift_digest(set))
end

function lookup_check(keys)
    local listed = keys or lookups()
    local allowed = {}
    for _, key in ipairs(listed) do
        allowed[key] = true
    end
    local record = recording() and os.getenv(RECORD) or nil
    local seen = {}
    local check = {}
    function check.note(key)
        if not seen[key] then
            seen[key] = true
            if not allowed[key] and not record then
                raise("the Swift overlay lowering looks up %s, which %s does not list: run the runtime build once with %s=<folder>, copy swift-overlay-reads.txt from it and regenerate the digests (toolchain/tools/recipe_digests.lua)", key, lookups_file(), RECORD)
            end
        end
    end
    function check.finish(complete)
        if record then
            local recorded = table.orderkeys(seen)
            byteorder.sort(recorded)
            os.mkdir(record)
            io.writefile(path.join(record, "swift-overlay-reads.txt"), table.concat(recorded, "\n") .. "\n")
            print("recorded %d Swift overlay lookups in %s; an install made with %s set must not be released", #recorded, path.join(record, "swift-overlay-reads.txt"), RECORD)
            return
        end
        if complete then
            local unused = {}
            for _, key in ipairs(listed) do
                if not seen[key] then
                    table.insert(unused, key)
                end
            end
            if #unused > 0 then
                raise("%s lists %d lookups this build never made (the first is %s), so the digest hashes answers that nothing reads: record the lookups again with %s=<folder>, copy swift-overlay-reads.txt from it and regenerate the digests (toolchain/tools/recipe_digests.lua)",
                      lookups_file(), #unused, unused[1], RECORD)
            end
        end
    end
    return check
end
