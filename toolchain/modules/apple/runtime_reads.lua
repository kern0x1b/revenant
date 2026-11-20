local lowered = import("lowered", {rootdir = os.scriptdir(), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local FOLDER = path.join(os.scriptdir(), "..", "..", "src", "swift-runtime", "reads")
local RECORD = "REVENANT_RUNTIME_READS_RECORD"

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

local function cached(sdk, action)
    local own = hash.strhash128(io.readfile(path.join(os.scriptdir(), "runtime_reads.lua")))
    local key = hash.strhash128(lowered.lowering_key(sdk) .. "\0" .. own .. "\0" .. table.concat(headers(), "\n") .. "\n")
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
    local allowed = {}
    for _, key in ipairs(keys or lookups()) do
        allowed[key] = true
    end
    local record = os.getenv(RECORD)
    local seen = {}
    local check = {}
    function check.note(key)
        if not seen[key] then
            seen[key] = true
            if not allowed[key] and not (record and record ~= "") then
                raise("the Swift overlay lowering looks up %s, which %s does not list: run the runtime build once with %s=<folder>, copy swift-overlay-reads.txt from it and regenerate the digests (toolchain/tools/recipe_digests.lua)", key, lookups_file(), RECORD)
            end
        end
    end
    function check.finish()
        if record and record ~= "" then
            local keys = table.orderkeys(seen)
            byteorder.sort(keys)
            os.mkdir(record)
            io.writefile(path.join(record, "swift-overlay-reads.txt"), table.concat(keys, "\n") .. "\n")
            print("recorded %d Swift overlay lookups in %s", #keys, path.join(record, "swift-overlay-reads.txt"))
        end
    end
    return check
end
