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

local function truthy(text)
    return text ~= nil and text ~= ""
end

local function escaped(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function macro_definition(package, name)
    local files = os.files(path.join(package, "**.h"))
    table.sort(files)
    for _, file in ipairs(files) do
        local lines = lines_of(io.readfile(file, {encoding = "binary"}))
        for index, line in ipairs(lines) do
            if line:match("^#define " .. escaped(name) .. "%f[^%w_]") then
                local body = {line}
                local position = index
                while body[#body]:match("\\%s*$") and position < #lines do
                    position = position + 1
                    table.insert(body, lines[position])
                end
                return table.concat(body, "\n")
            end
        end
    end
    return nil
end

local function to_set(text)
    local set = {}
    for item in text:gmatch("[^,]+") do
        set[item] = true
    end
    return set
end

local function methods(obj, root)
    local found = {}
    local stdout = nil
    try {
        function ()
            stdout = os.iorunv(path.join(root, "..", "xmakew"),
                {"l", path.join(root, "tools", "corpus", "objc-inventory.lua"), obj, "armv7"},
                {envs = {REVENANT_ROOT = root}, curdir = root})
        end,
        catch {
            function ()
                stdout = nil
            end
        }
    }
    if stdout == nil then
        return found
    end
    for _, line in ipairs(lines_of(stdout)) do
        local parts = fields_of(line)
        if #parts == 7 and parts[1] == "class" then
            found[parts[2]] = {instance = to_set(parts[5]), class = to_set(parts[6])}
        end
    end
    return found
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

local function defines(body, selector)
    for _, line in ipairs(lines_of(body)) do
        if line:match("^%s*[%-%+]%s*%(instancetype%)%s*" .. selector .. "%f[^%w_]") then
            return true
        end
    end
    return false
end

local function check_source(body, row, package, problems)
    for _, item in ipairs({{"init", "-", row["port-init"]}, {"new", "+", row["port-new"]}}) do
        local selector, sign, owed = item[1], item[2], item[3]
        local defined_by_hand = defines(body, selector)
        if owed == "none" then
            if defined_by_hand then
                table.insert(problems, selector .. " is defined here and Apple's own class carries neither: a definition would answer the caller what NSObject's already answers")
            end
        elseif owed == "construct" then
            if selector == "init" and not defined_by_hand then
                table.insert(problems, "the table says the release builds the object in -init and the block does not define one")
            end
        elseif row["port-macro"] == "-" then
            table.insert(problems, "the table says " .. selector .. " is owed and names no macro for it")
        else
            local macro = row["port-macro"]
            local definition = macro_definition(package, macro)
            if definition == nil then
                table.insert(problems, selector .. " is owed but " .. macro .. " is defined nowhere under " .. package)
            elseif not definition:find(sign .. "(instancetype)" .. selector, 1, true) then
                table.insert(problems, selector .. " is owed but " .. macro .. " does not define " .. selector)
            elseif not body:find("%f[%w_]" .. macro .. "%f[^%w_]") then
                table.insert(problems, selector .. " is owed and the block does not answer with " .. macro)
            elseif owed == "nil" then
                if definition:find("raise", 1, true) or definition:find("NSException", 1, true) then
                    table.insert(problems, "the measured body answers nil and the macro raises")
                end
                if not definition:match("%f[%w_]return%s+nil%s*;") then
                    table.insert(problems, "the measured body answers nil and the macro does not return nil")
                end
                if definition:find("[super init]", 1, true) then
                    table.insert(problems, "the measured body answers nil and the macro forwards to NSObject's -init")
                end
            else
                if not definition:find(row["exception"], 1, true) then
                    table.insert(problems, "the measured exception is " .. row["exception"] .. " and the macro raises something else")
                end
                if truthy(row["reason-template"]) then
                    if not definition:find('@"' .. row["reason-template"] .. '"', 1, true) then
                        table.insert(problems, string.format("the measured reason is built as '%s' and the macro carries no such format string", row["reason-template"]))
                    end
                    local reason = row["reason"] or ""
                    if reason:find(row["class"], 1, true) and not definition:find("NSStringFromClass([self class])", 1, true) then
                        table.insert(problems, "the measured reason names the class and the macro does not read it")
                    end
                    if not reason:find(row["class"], 1, true) and not definition:find("NSStringFromSelector(_cmd)", 1, true) then
                        table.insert(problems, "the measured reason does not name the class and the macro does not read the selector, which is what fills it")
                    end
                elseif truthy(row["reason"]) and not body:find('@"' .. row["reason"] .. '"', 1, true) and not definition:find('@"' .. row["reason"] .. '"', 1, true) then
                    table.insert(problems, string.format("the reason measured is '%s' and neither the block nor the macro carries it", row["reason"]))
                end
            end
        end
    end
end

local function check_object(carried, row, selector, problems)
    local kind = selector == "init" and "instance" or "class"
    local there = carried[kind]["-" .. selector] == true
    local owed = row["port-" .. selector]
    if (owed == "raise" or owed == "nil" or owed == "construct") and not there then
        table.insert(problems, string.format("%s is not in the class's %s list of %s, and the measured answer is %s", selector, kind, row["port-object"], owed))
    elseif owed == "none" and there then
        table.insert(problems, string.format("%s is in the class's %s list of %s, and Apple's own class carries neither", selector, kind, row["port-object"]))
    end
end

function main(package, objdir, root, ...)
    local wanted = {...}
    if package == nil or objdir == nil or root == nil or #wanted == 0 then
        raise("check-port.lua: pass the package directory, the compiled objects directory, the repository root and at least one framework")
    end
    local wanted_set = {}
    for _, framework in ipairs(wanted) do
        wanted_set[framework] = true
    end
    local rows = {}
    for _, row in ipairs(rows_of(path.join(os.scriptdir(), "expectations.tsv"))) do
        if wanted_set[row.framework] then
            table.insert(rows, row)
        end
    end
    if #rows == 0 then
        raise("check-port.lua: expectations.tsv holds no row for " .. table.concat(wanted, ", "))
    end
    local failures, ok = {}, 0
    for _, row in ipairs(rows) do
        local name, problems = row.class, {}
        local source = path.join(package, row["port-source"])
        local body = nil
        if os.isfile(source) then
            body = block_of(io.readfile(source, {encoding = "binary"}), name)
        end
        if body == nil then
            table.insert(problems, "no @implementation " .. name .. " in " .. row["port-source"])
        else
            check_source(body, row, package, problems)
        end
        local carried = {instance = {}, class = {}}
        local obj = path.join(objdir, row["port-object"])
        if not os.isfile(obj) then
            table.insert(problems, obj .. " does not exist")
        else
            carried = methods(obj, root)[name] or carried
            check_object(carried, row, "init", problems)
            check_object(carried, row, "new", problems)
        end
        local agrees = true
        for _, problem in ipairs(problems) do
            if problem:find("list of", 1, true) or problem:find("does not exist", 1, true) then
                agrees = false
            end
        end
        print(string.format("%-44s source: init=%-5s new=%-5s   object: %s", name, row["port-init"], row["port-new"], agrees and "agrees" or "DIFFERS"))
        if #problems > 0 then
            for _, problem in ipairs(problems) do
                table.insert(failures, name .. ": " .. problem)
            end
        else
            ok = ok + 1
        end
    end
    for _, failure in ipairs(failures) do
        print("FAIL " .. failure)
    end
    print(string.format("unavailable-init-port %s: %d of %d classes as measured, in the source and in the object, %d failures%s",
        table.concat(wanted, ","), ok, #rows, #failures, #failures == 0 and "" or "  <- SEE FAIL"))
    if #failures > 0 then
        os.exit(1)
    end
end
