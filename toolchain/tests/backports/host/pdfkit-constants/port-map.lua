local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules"), anonymous = true})

local function lines_of(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    return out
end

local function declaration(text)
    local name, literal = text:match("^NSString %*const%s+([%a_][%w_]*)%s*=%s*(.+);$")
    if name then
        return "string", name, literal:trim()
    end
    name, literal = text:match("^const CGFloat%s+([%a_][%w_]*)%s*=%s*(.+);$")
    if name then
        return "number", name, literal:trim()
    end
    return nil
end

local function objc_literal(literal)
    if literal:startswith('@"') and literal:endswith('"') then
        local inner = literal:sub(3, -2):gsub('\\"', '"'):gsub("\\\\", "\\")
        return inner
    end
    return literal
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        table.insert(keys, key)
    end
    byteorder.sort(keys)
    return keys
end

function main(port, out)
    local files = os.files(path.join(port, "PDFKitConstants*.m"))
    byteorder.sort(files)
    local rows, numeric = {}, {}
    for _, file in ipairs(files) do
        for _, line in ipairs(lines_of(io.readfile(file, {encoding = "binary"}))) do
            local kind, name, literal = declaration(line:trim())
            if kind == "number" then
                numeric[name] = literal
            elseif kind == "string" then
                rows[name] = objc_literal(literal)
            end
        end
    end
    local written = {}
    for _, name in ipairs(sorted_keys(rows)) do
        table.insert(written, name .. "\t" .. rows[name] .. "\n")
    end
    io.writefile(out, table.concat(written), {encoding = "binary"})
    local sentinels = {}
    for _, name in ipairs(sorted_keys(numeric)) do
        table.insert(sentinels, name .. "\t" .. numeric[name] .. "\n")
    end
    io.writefile(out .. ".numeric", table.concat(sentinels), {encoding = "binary"})
    local string_count, number_count = #sorted_keys(rows), #sorted_keys(numeric)
    print(string.format("  the port's objects carry %d string constants and %d numeric sentinels", string_count, number_count))
end
