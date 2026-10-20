local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules"), anonymous = true})

local function lines_of(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    return out
end

local function file_lines(text)
    local out, at = {}, 1
    while at <= #text do
        local stop = text:find("\n", at, true)
        if stop then
            table.insert(out, text:sub(at, stop - 1))
            at = stop + 1
        else
            table.insert(out, text:sub(at))
            break
        end
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

local function answer_ok(text)
    return text:match("^ok %S+$") ~= nil or text:match("^raises %S+ %([^%)]*%)$") ~= nil
end

local function parse(line)
    local name, own_init, own_new, rest = line:match("^CLASS (%S+) own%-init=(%d) own%-new=(%d) (.+)$")
    if not name then
        return nil
    end
    local init_part, new_part = rest:match("^init=(.-) new=(.+)$")
    if not init_part or not answer_ok(init_part) or not answer_ok(new_part) then
        return nil
    end
    return name, own_init, own_new, new_part
end

local function tail(text)
    return text:match("^%S+ (.*)$") or ""
end

function main(framework, output)
    if framework == nil or output == nil then
        raise("check-host.lua: pass the framework name and the probe's output for one class")
    end
    local expected = {}
    for _, row in ipairs(rows_of(path.join(os.scriptdir(), "expectations.tsv"))) do
        if row.framework == framework and row.oracle == "host" then
            table.insert(expected, row)
        end
    end
    if #expected == 0 then
        print(string.format("SKIP %s: expectations.tsv holds no row measured on the host", framework))
        return
    end
    local found, failures, ok = {}, {}, 0
    for _, line in ipairs(file_lines(io.readfile(output, {encoding = "binary"}))) do
        if line:startswith("NOFRAMEWORK") then
            local second = line:match("^%S+%s+(%S+)") or ""
            if #expected > 0 then
                table.insert(failures, string.format("%s could not be opened on this host, so its %d rows were not checked", framework, #expected))
                print(string.format("FAIL %s cannot be opened here: %s", framework, second))
            else
                print(string.format("SKIP %s: this host carries no %s, and the table holds no row of its own for it", framework, second:match("([^/]*)$")))
                return
            end
        end
        local name, own_init, own_new, new = parse(line)
        if name then
            found[name] = {own_init, own_new, new}
        else
            table.insert(failures, "unparsed probe line: " .. line)
        end
    end
    local named = {}
    for _, row in ipairs(expected) do
        named[row.class] = true
        local name = row.class
        if found[name] == nil then
            table.insert(failures, name .. ": the host does not declare it any more")
            print(string.format("%-44s ABSENT on the host", name))
        else
            local own_init, own_new, new = found[name][1], found[name][2], found[name][3]
            local want_new = nil
            if row.answer == "raises" then
                want_new = string.format("raises %s (%s)", row.exception, row.reason)
            end
            local same
            if want_new then
                same = own_init == row["own-init"] and own_new == row["own-new"] and tail(new) == tail(want_new)
            else
                same = own_init == row["own-init"] and own_new == row["own-new"] and new:startswith("ok")
            end
            if same then
                ok = ok + 1
                print(string.format("%-44s own-init=%s own-new=%s  %s", name, own_init, own_new, tail(new)))
            else
                table.insert(failures, string.format("%s: the host answers own-init=%s own-new=%s %s, and the table says own-init=%s own-new=%s %s",
                    name, own_init, own_new, tail(new), row["own-init"], row["own-new"], want_new and tail(want_new) or "ok"))
                print(string.format("%-44s DIFFERS from the table: %s", name, tail(new)))
            end
        end
    end
    local extra = {}
    for name in pairs(found) do
        if not named[name] then
            table.insert(extra, name)
        end
    end
    byteorder.sort(extra)
    for _, name in ipairs(extra) do
        table.insert(failures, name .. " is answered by the host and is not in the table")
    end
    for _, failure in ipairs(failures) do
        print("FAIL " .. failure)
    end
    print(string.format("unavailable-init-host %s: %d of %d classes as the table says, %d failures%s",
        framework, ok, #expected, #failures, #failures == 0 and "" or "  <- SEE FAIL"))
    if #failures > 0 then
        os.exit(1)
    end
end
