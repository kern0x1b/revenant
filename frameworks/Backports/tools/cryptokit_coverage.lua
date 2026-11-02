local KINDS = {struct = true, enum = true, class = true, protocol = true, typealias = true, actor = true, extension = true}
local MODIFIERS = {public = true, open = true, internal = true, fileprivate = true, private = true, final = true,
                   indirect = true, nonisolated = true, static = true, mutating = true, nonmutating = true,
                   override = true, required = true, convenience = true, dynamic = true}
local MEMBERS = {func = true, var = true, let = true, init = true, subscript = true, case = true}
local PREFIXES = {"CryptoKit", "Crypto", "CryptoExtras", "_CryptoExtras"}
local IMPLIED = {Element = true, Iterator = true, AllCases = true}
local IMPLIED_MEMBERS = {hash = true, hashValue = true, ["?"] = true, byteCount = true, withUnsafeBytes = true, description = true}

local function unprefix(name)
    for _, prefix in ipairs(PREFIXES) do
        if name:sub(1, #prefix + 1) == prefix .. "." then
            return name:sub(#prefix + 2)
        end
    end
    return name
end

local function code(raw)
    local line = raw:gsub('"[^"]*"', '""')
    local at = line:find("//", 1, true)
    if at then
        line = line:sub(1, at - 1)
    end
    return line
end

local function head(body)
    local words = {}
    local rest = body
    while true do
        local word, after = rest:match("^(@?[%w_]+)%s+(.*)$")
        if not word or not (word:sub(1, 1) == "@" or MODIFIERS[word]) then
            break
        end
        table.insert(words, word)
        rest = after
    end
    local kind, name = rest:match("^([%a]+)%s+([%a_][%w_%.]*)")
    if not kind or not KINDS[kind] then
        return nil
    end
    return kind, unprefix(name), words
end

local function member(body)
    for word in body:gmatch("[%a_][%w_]*") do
        if MEMBERS[word] then
            local after = body:match("%f[%w_]" .. word .. "%f[^%w_]%s*(.*)$") or ""
            if word == "init" or word == "subscript" then
                return word, word
            end
            local name = after:match("^([%a_][%w_]*)") or "?"
            return word, name
        end
    end
    return nil
end

local function public(words)
    for _, word in ipairs(words) do
        if word == "public" or word == "open" then
            return true
        end
    end
    return false
end

local function parse(file, report)
    local stack = {}
    local depth = 0
    local pending
    for raw in io.lines(file) do
        local text = code(raw)
        local body = text:match("^%s*(.-)%s*$"):gsub("^@available%b()%s*", "")
        local owner = stack[#stack]
        if body ~= "" then
            local kind, name, words = head(body)
            if kind then
                local parent = owner and owner.name or ""
                local qualified = parent ~= "" and parent .. "." .. name or name
                if kind ~= "extension" and public(words) then
                    table.insert(report.types, {kind = kind, name = qualified, file = file})
                end
                if body:find("{", 1, true) then
                    pending = kind == "extension" and name or qualified
                end
            else
                local keyword, member_name = member(body)
                if keyword and owner and owner.name ~= "" and body:find("%f[%w_]public%f[^%w_]") then
                    table.insert(report.members, {owner = owner.name, name = member_name, keyword = keyword, file = file})
                end
            end
        end
        for brace in text:gmatch("[{}]") do
            if brace == "{" then
                depth = depth + 1
                if pending then
                    table.insert(stack, {name = pending, depth = depth})
                    pending = nil
                end
            else
                while #stack > 0 and stack[#stack].depth >= depth do
                    table.remove(stack)
                end
                depth = depth - 1
            end
        end
    end
end

local function sources_of(path_or_dir)
    if os.isdir(path_or_dir) then
        return os.files(path.join(path_or_dir, "**.swift"))
    end
    return {path_or_dir}
end

function analyse(interface, roots)
    local sdk = {types = {}, members = {}}
    parse(interface, sdk)
    local provided = {types = {}, members = {}}
    for _, root in ipairs(roots) do
        for _, file in ipairs(sources_of(root)) do
            parse(file, provided)
        end
    end
    local known, known_members = {}, {}
    for _, record in ipairs(provided.types) do
        known[record.name] = true
    end
    for _, record in ipairs(provided.members) do
        known_members[record.owner .. "\0" .. record.name] = true
    end
    local result = {sdk_types = {}, uncovered_types = {}, implied_types = {}, sdk_members = {}, uncovered_members = {}, implied_members = {}}
    local seen = {}
    for _, record in ipairs(sdk.types) do
        if not seen[record.name] then
            seen[record.name] = true
            table.insert(result.sdk_types, record)
            local last = record.name:match("([^%.]+)$")
            if not known[record.name] and IMPLIED[last] and record.kind == "typealias" then
                table.insert(result.implied_types, record)
            elseif not known[record.name] then
                table.insert(result.uncovered_types, record)
            end
        end
    end
    seen = {}
    for _, record in ipairs(sdk.members) do
        local key = record.owner .. "\0" .. record.name
        if not seen[key] then
            seen[key] = true
            table.insert(result.sdk_members, record)
            if not known_members[key] and IMPLIED_MEMBERS[record.name] then
                table.insert(result.implied_members, record)
            elseif not known_members[key] then
                table.insert(result.uncovered_members, record)
            end
        end
    end
    return result
end

function main(interface, ...)
    assert(interface and os.isfile(interface), "the SDK swiftinterface is not a file: " .. tostring(interface))
    local roots = table.pack(...)
    assert(roots.n > 0, "name at least one swift-crypto source directory or wrapper directory")
    local result = analyse(interface, roots)
    print(string.format("sdk types %d", #result.sdk_types))
    print(string.format("covered types %d", #result.sdk_types - #result.uncovered_types - #result.implied_types))
    print(string.format("implied by a conformance %d", #result.implied_types))
    print(string.format("uncovered types %d", #result.uncovered_types))
    for _, record in ipairs(result.uncovered_types) do
        print(string.format("  %s %s", record.kind, record.name))
    end
    print(string.format("sdk members %d", #result.sdk_members))
    print(string.format("covered members %d", #result.sdk_members - #result.uncovered_members - #result.implied_members))
    print(string.format("implied members %d", #result.implied_members))
    print(string.format("uncovered members %d", #result.uncovered_members))
    for _, record in ipairs(result.uncovered_members) do
        print(string.format("  %s.%s", record.owner, record.name))
    end
    return result
end
