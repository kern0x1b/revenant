local stream = import("stream", {anonymous = true})
local host = import("host", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})
local swift_docs = import("swift_docs", {anonymous = true})

local ENV = "/usr/bin/env"
local CELL_COUNT = 10
local CELL = {framework = 1, kind = 2, usr = 3, container = 4, name = 5, side = 6, params = 7, brief = 8, comment = 9, decl = 10}
local MEMBER_KINDS = {method = true, property = true}
local UNESCAPE = {["\\"] = "\\", t = "\t", n = "\n", r = "\r"}

local injected = nil

function use(source)
    injected = source
end

local binary_memo = {}

local function binary(tree)
    local root = path.absolute(tree)
    if binary_memo[root] == nil then
        local file, notes = host.target_product(root, path.join(root, "tools", "found"), "decls")
        local built = "(build it from the tree: xmake f -P tools/found -y && xmake -P tools/found)"
        assert(os.isfile(file), "the extractor is not built: " .. file .. " " .. built .. (notes ~= "" and ("; xmake said: " .. notes) or ""))
        binary_memo[root] = file
    end
    return binary_memo[root]
end

local listed_cache = {}

local function listed(tree, sdk)
    local file = binary(tree)
    local key = file .. "\n" .. sdk
    if listed_cache[key] == nil then
        local names = {}
        local status, err = stream.run(ENV, {"IR_SDK=" .. sdk, file, "--list"}, function(line)
            local name = string.match(line, "^([^\t]*)")
            if name ~= "" then
                names[name] = true
            end
        end)
        assert(status == 0, "decls --list failed (status " .. status .. "): " .. host.tail(err, 300))
        listed_cache[key] = names
    end
    return listed_cache[key]
end

function available(tree, fw, sdk)
    if injected then
        return injected(fw, sdk) ~= nil
    end
    return listed(tree, sdk)[fw] == true
end

function decode(line)
    local cells = {}
    local pos = 1
    repeat
        local tab = string.find(line, "\t", pos, true)
        table.insert(cells, (string.gsub(string.sub(line, pos, tab and tab - 1 or #line), "\\(.)", UNESCAPE)))
        pos = tab and tab + 1
    until pos == nil
    return cells
end

local function side_of(kind, usr)
    if kind == "method" and string.find(usr, "(cm)", 1, true) then
        return "+"
    end
    if kind == "property" and string.find(usr, "(cpy)", 1, true) then
        return "+"
    end
    return "-"
end

local function api_of(kind, usr, name)
    if not MEMBER_KINDS[kind] then
        return nil
    end
    local owner = string.match(usr, "^c:objc%(%a+%)([^%(]+)")
    if owner == nil then
        return nil
    end
    return side_of(kind, usr) .. "[" .. owner .. " " .. name .. "]"
end

local function entry_of(cells)
    local raw, brief = cells[CELL.comment], cells[CELL.brief]
    return {
        kind = cells[CELL.kind],
        api = api_of(cells[CELL.kind], cells[CELL.usr], cells[CELL.name]),
        comment = raw ~= "" and raw or brief,
        from_brief = raw == "" and brief ~= "",
        decl = cells[CELL.decl],
        params = cells[CELL.params],
    }
end

function rows(tree, fw, sdk)
    if not available(tree, fw, sdk) then
        return nil, "the extractor does not list it"
    end
    local usr, api = {}, {}
    local function take(line)
        local cells = decode(line)
        assert(#cells == CELL_COUNT, "a doc row of " .. fw .. " has " .. #cells .. " cells, not " .. CELL_COUNT)
        local key = cells[CELL.usr]
        if key ~= "-" and usr[key] == nil then
            local entry = entry_of(cells)
            usr[key] = entry
            if entry.api ~= nil and api[entry.kind .. " " .. entry.api] == nil then
                api[entry.kind .. " " .. entry.api] = entry
            end
        end
    end
    local status, err = 0, ""
    if injected then
        local lines, failure = injected(fw, sdk)
        if failure ~= nil then
            status, err = 1, failure
        end
        for _, line in ipairs(lines) do
            take(line)
        end
    elseif (sdk_modules.module_of(sdk, fw) or {}).kind == "swift" then
        for _, line in ipairs(swift_docs.lines(sdk, fw)) do
            take(line)
        end
    else
        status, err = stream.run(ENV, {"IR_SDK=" .. sdk, binary(tree), "--doc", fw}, take)
    end
    assert(status == 0, "doc " .. fw .. ": the extractor lists it, but its doc rows cannot be produced: decls --doc exits with status "
           .. status .. (err ~= "" and (": " .. host.tail(err, 300)) or ""))
    return {usr = usr, api = api}
end
