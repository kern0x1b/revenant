local json = import("core.base.json")
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules"), anonymous = true})

local USAGE = "usage: measure.lua names <registry folder> <out> | compare <registry folder> <measured.tsv> <table> <framework> <objects.tsv>"

local function documents(folder)
    local files = os.files(path.join(folder, "*.json"))
    byteorder.sort(files)
    local entries = {}
    for _, file in ipairs(files) do
        local document = json.decode(io.readfile(file))
        for _, entry in ipairs(document.entries or {}) do
            table.insert(entries, entry)
        end
    end
    return entries
end

local function fields_of(line)
    local out, at = {}, 1
    while true do
        local tab = line:find("\t", at, true)
        if not tab then
            table.insert(out, line:sub(at))
            return out
        end
        table.insert(out, line:sub(at, tab - 1))
        at = tab + 1
    end
end

local function table_rows(file)
    local rows, header = {}, true
    for line in io.lines(file) do
        if header then
            header = false
        elseif line:trim() ~= "" then
            local fields = fields_of(line)
            rows[fields[1]] = fields
        end
    end
    return rows
end

local function names(folder, out)
    local seen, list = {}, {}
    for _, entry in ipairs(documents(folder)) do
        if entry.kind == "constant" and not seen[entry.api] then
            seen[entry.api] = true
            table.insert(list, entry.api)
        end
    end
    byteorder.sort(list)
    local lines = {}
    for _, name in ipairs(list) do
        table.insert(lines, name .. "\n")
    end
    io.writefile(out, table.concat(lines))
end

local function carried(effect)
    local start = effect:find('"', 1, true)
    if start then
        local stop = effect:find('"', start + 1, true)
        if stop then
            return effect:sub(start + 1, stop - 1)
        end
    end
    local marker = "the string "
    local begin = effect:find(marker, 1, true)
    if begin then
        local first = begin + #marker
        local comma = effect:find(",", first, true)
        if comma and comma > first then
            return effect:sub(first, comma - 1):trim()
        end
        return effect:sub(first):trim()
    end
    return nil
end

local function shown(value)
    if value == nil then
        return "None"
    end
    return value
end

local function compare(folder, measured, out, framework, objects)
    local in_library = {}
    if os.isfile(objects) and #io.readfile(objects) > 0 then
        for name, fields in pairs(table_rows(objects)) do
            in_library[name] = fields[4]
        end
    end
    local rows, sources = {}, {}
    for name, fields in pairs(table_rows(measured)) do
        rows[name] = fields[4]
        sources[name] = fields[6] or "?"
    end
    local intro = {}
    for _, entry in ipairs(documents(folder)) do
        if entry.kind == "constant" then
            intro[entry.api] = {introduced = entry.introduced or "-", effect = entry.effect or ""}
        end
    end

    local agree, differ, absent, unextractable, wrong = {}, {}, {}, {}, {}
    for _, name in ipairs(byteorder.keys(intro)) do
        local want = carried(intro[name].effect)
        local got = rows[name]
        if got == "-" then
            table.insert(absent, name)
        elseif want == nil then
            table.insert(unextractable, name)
        elseif got ~= want then
            table.insert(differ, {name, want, got})
        elseif in_library[name] ~= nil and in_library[name] ~= "-" and in_library[name] ~= want then
            table.insert(wrong, {name, want, in_library[name]})
        else
            table.insert(agree, name)
        end
    end
    print(string.format("   %d agree, %d differ from the host, %d differ from the built library, %d not exported by the host, %d rows with no value to compare",
                        #agree, #differ, #wrong, #absent, #unextractable))
    for _, item in ipairs(wrong) do
        print(string.format("     THE LIBRARY SAYS %-48s row %s library %s", item[1], item[2], item[3]))
    end
    for _, name in ipairs(unextractable) do
        print("     NO VALUE IN THE ROW " .. name)
    end
    for _, item in ipairs(differ) do
        print(string.format("     DIFFERS %-56s port %s host %s", item[1], item[2], shown(item[3])))
    end
    for _, name in ipairs(absent) do
        print("     NOT ON THE HOST " .. name)
    end

    if #agree > 0 then
        local build = os.iorunv("sw_vers", {"-buildVersion"}):trim()
        if build == "" then
            build = "unknown"
        end
        local lines = {"api\tintroduced\tc-type\tvalue\thow-measured\tsource-binary\tos-build"}
        for _, name in ipairs(agree) do
            local how = "dlopen + dlsym on the host, decoded through CFStringGetCString as UTF-8, by tools/corpus/host-probe.c"
            if in_library[name] ~= nil then
                how = how .. "; and read out of the built library by tools/corpus/object-constant.c"
            end
            table.insert(lines, table.concat({name, intro[name].introduced, "NSString *const", rows[name], how,
                                              sources[name] or "?", "macOS " .. build}, "\t"))
        end
        io.writefile(out, table.concat(lines, "\n") .. "\n")
        print(string.format("   table written: %s (%d rows)", out, #agree))
    end
    return #differ > 0 or #absent > 0 or #wrong > 0 or #unextractable > 0
end

function main(command, ...)
    local arguments = {...}
    if command == "names" and #arguments == 2 then
        names(arguments[1], arguments[2])
    elseif command == "compare" and #arguments == 5 then
        if compare(arguments[1], arguments[2], arguments[3], arguments[4], arguments[5]) then
            os.exit(1)
        end
    else
        raise(USAGE)
    end
end
