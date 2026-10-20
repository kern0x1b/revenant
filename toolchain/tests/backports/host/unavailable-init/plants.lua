local function lines_of(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    return out
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

local function rows_of(file)
    local header, rows = nil, {}
    for _, line in ipairs(lines_of(io.readfile(file, {encoding = "binary"}))) do
        if not line:startswith("#") and line:trim() ~= "" then
            local fields = fields_of(line)
            if header == nil then
                header = fields
            else
                local row = {}
                for index, name in ipairs(header) do
                    row[name] = fields[index]
                end
                table.insert(rows, row)
            end
        end
    end
    return rows
end

local function escaped(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function count(text, needle)
    local found, at = 0, 1
    while true do
        local first, last = text:find(needle, at, true)
        if not first then
            return found
        end
        found = found + 1
        at = last + 1
    end
end

local function newlines_escaped(text)
    return (text:gsub("\n", "\\n"))
end

local function anchor_line(source, cls)
    local text = io.readfile(source, {encoding = "binary"})
    local lines = lines_of(text)
    local joined = table.concat(lines, "\n")
    local prefix = "@implementation " .. cls
    for index = 1, #lines do
        local line = lines[index]
        if line:sub(1, #prefix) == prefix then
            local trimmed = line:gsub("%s+$", "")
            if not trimmed:endswith("{") then
                if lines[index + 1] == nil then
                    return nil
                end
                return line .. "\n" .. lines[index + 1]
            end
            local depth = 1
            local scan = index
            while scan < #lines and depth ~= 0 do
                local current = lines[scan + 1]
                local _, opened = current:gsub("{", "")
                local _, closed = current:gsub("}", "")
                depth = depth + opened - closed
                scan = scan + 1
            end
            if scan >= #lines then
                return nil
            end
            local pair = lines[scan] .. "\n" .. lines[scan + 1]
            if joined:find(pair, 1, true) then
                return pair
            end
            return lines[scan + 1]
        end
    end
    return nil
end

local function macro_takes_argument(package, macro)
    local files = os.files(path.join(package, "**.h"))
    table.sort(files)
    for _, file in ipairs(files) do
        for _, line in ipairs(lines_of(io.readfile(file, {encoding = "binary"}))) do
            if line:match("^#define " .. escaped(macro) .. "%(") then
                return true
            end
            if line:match("^#define " .. escaped(macro) .. "$") then
                return false
            end
        end
    end
    return false
end

local function call_of(row, package)
    local name = row["port-macro"]
    if name == nil or name == "" or name == "-" then
        return nil
    end
    if not macro_takes_argument(package, name) then
        return name
    end
    return name .. '(@"' .. (row["reason"] or "") .. '")'
end

local function block_of(text, cls)
    local lines = lines_of(text)
    local prefix = "@implementation " .. cls
    for start, line in ipairs(lines) do
        if line:sub(1, #prefix) == prefix and not line:sub(#prefix + 1):match("^%s*%(") then
            local body = {}
            for index = start + 1, #lines do
                if lines[index]:sub(1, 4) == "@end" then
                    return table.concat(body, "\n") .. (#body > 0 and "\n" or "")
                end
                table.insert(body, lines[index])
            end
        end
    end
    return nil
end

local function header_of(package, macro)
    local files = os.files(path.join(package, "**.h"))
    table.sort(files)
    for _, file in ipairs(files) do
        for _, line in ipairs(lines_of(io.readfile(file, {encoding = "binary"}))) do
            if line:match("^#define " .. escaped(macro) .. "%f[^%w_]") then
                return path.relative(file, package)
            end
        end
    end
    return nil
end

local function raise_line(package, header, exception)
    local body = io.readfile(path.join(package, header), {encoding = "binary"})
    local needle = "raise:" .. exception
    if body:find(needle, 1, true) then
        return needle
    end
    return nil
end

local function emit(...)
    local fields = {...}
    print(table.concat(fields, "\t"))
end

function main(table_file, package, ...)
    local wanted = {...}
    local rows = rows_of(table_file)
    if #wanted == 0 then
        local seen, names = {}, {}
        for _, row in ipairs(rows) do
            if not seen[row.framework] then
                seen[row.framework] = true
                table.insert(names, row.framework)
            end
        end
        table.sort(names)
        wanted = names
    end
    for _, framework in ipairs(wanted) do
        local mine, owes, none, nils = {}, {}, {}, {}
        for _, row in ipairs(rows) do
            if row.framework == framework then
                table.insert(mine, row)
                if row["port-init"] == "raise" or row["port-init"] == "nil" then
                    table.insert(owes, row)
                end
                if row["port-init"] == "none" then
                    table.insert(none, row)
                end
                if row["port-init"] == "nil" then
                    table.insert(nils, row)
                end
            end
        end
        if #owes > 0 or #none > 0 or #nils > 0 then
            local macro = #owes > 0 and owes[1]["port-macro"] or "-"
            local call, owner = nil, nil
            for _, row in ipairs(owes) do
                local candidate = call_of(row, package)
                if candidate ~= nil then
                    local body = block_of(io.readfile(path.join(package, row["port-source"]), {encoding = "binary"}), row.class)
                    if body ~= nil and count(body, candidate) == 1 then
                        call, owner = candidate, row
                        break
                    end
                    if body ~= nil and count(body, candidate) > 0 then
                        io.stderr:write(string.format("%s holds %d copies of %s in the @implementation of %s, so a plant written on it could replace the wrong one\n",
                            row["port-source"], count(body, candidate), candidate, row.class))
                        os.exit(1)
                    end
                end
            end
            if call then
                emit("a class that must refuse is left to NSObject instead", framework,
                    path.filename(owner["port-source"]), call, "/* " .. call .. " */")
            end
            if #none > 0 then
                local anchor = anchor_line(path.join(package, none[1]["port-source"]), none[1].class)
                local target = io.readfile(path.join(package, none[1]["port-source"]), {encoding = "binary"})
                local insert = "-(instancetype)init { return [super init]; }"
                if #owes > 0 then
                    local owed_call = call_of(owes[1], package)
                    if owed_call ~= nil and target:find(owed_call, 1, true) then
                        insert = owed_call
                    end
                end
                if anchor then
                    emit("a class that must NOT be defined gets a definition anyway", framework,
                        path.filename(none[1]["port-source"]), newlines_escaped(anchor),
                        newlines_escaped(anchor .. "\n" .. insert))
                end
            end
            for _, row in ipairs(nils) do
                local call_name = row["port-macro"]
                local source_text = io.readfile(path.join(package, row["port-source"]), {encoding = "binary"})
                if source_text:find(call_name, 1, true) then
                    emit("a class whose measured -init answers nil raises instead", framework,
                        path.filename(row["port-source"]), call_name,
                        "- (instancetype)init { [NSException raise:NSInternalInconsistencyException format:@\"raised\"]; return nil; }")
                    break
                end
            end
            if #owes > 0 then
                local header = header_of(package, macro)
                local other = owes[1].exception ~= "NSGenericException" and "NSGenericException" or "NSRangeException"
                local line = header and raise_line(package, header, owes[1].exception) or nil
                if header and line then
                    emit("the macro raises an exception that was not measured", framework,
                        path.filename(header), line, "raise:" .. other)
                end
            end
        end
    end
end
