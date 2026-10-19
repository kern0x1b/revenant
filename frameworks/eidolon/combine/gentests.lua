import("core.base.json")
local text = import("lib.text", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local function keyed(list, key_of)
    local order, values = {}, {}
    for _, item in ipairs(list) do
        local key = key_of(item)
        if values[key] == nil then
            order[#order + 1] = key
        end
        values[key] = item
    end
    return order, values
end

local function stable_sort(items, key_of)
    local indexed = {}
    for i, item in ipairs(items) do
        indexed[i] = {item = item, key = key_of(item), index = i}
    end
    table.sort(indexed, function(a, b)
        if a.key ~= b.key then
            return a.key < b.key
        end
        return a.index < b.index
    end)
    local out = {}
    for i, entry in ipairs(indexed) do
        out[i] = entry.item
    end
    return out
end

local function fragments_text(node)
    local out = {}
    for _, fragment in ipairs(node["declarationFragments"] or {}) do
        out[#out + 1] = fragment["spelling"]
    end
    return text.join("", out)
end

local XCTEST_CASE_SUFFIXES = {"6XCTest0A4CaseC"}

function main(...)
    local args = {...}
    local graph = json.decode(io.readfile(args[1]))

    local symbols_order, syms = keyed(graph["symbols"], function(s)
        return s["identifier"]["precise"]
    end)

    local parent, members = {}, {}
    for _, r in ipairs(graph["relationships"]) do
        if r["kind"] == "inheritsFrom" then
            parent[r["source"]] = r["target"]
        elseif r["kind"] == "memberOf" then
            members[r["target"]] = members[r["target"]] or {}
            table.insert(members[r["target"]], r["source"])
        end
    end

    local function is_case(c)
        while parent[c] ~= nil do
            c = parent[c]
            for _, suffix in ipairs(XCTEST_CASE_SUFFIXES) do
                if string.sub(c, -#suffix) == suffix then
                    return true
                end
            end
            if c == "s:6XCTest0A4CaseC" then
                return true
            end
        end
        return false
    end

    local title_of = function(s)
        return s["names"]["title"]
    end

    local classes = {}
    for _, cid in ipairs(symbols_order) do
        classes[#classes + 1] = cid
    end
    classes = stable_sort(classes, function(cid)
        return title_of(syms[cid])
    end)

    local out, count = {}, 0
    for _, cid in ipairs(classes) do
        local s = syms[cid]
        if s["kind"]["identifier"] == "swift.class" and is_case(cid) then
            local cname = title_of(s)
            local owned = members[cid] or {}
            owned = stable_sort(owned, function(mid)
                if syms[mid] ~= nil then
                    return title_of(syms[mid])
                end
                return ""
            end)
            for _, mid in ipairs(owned) do
                local m = syms[mid]
                if m ~= nil and m["kind"]["identifier"] == "swift.method" then
                    local t = title_of(m)
                    if text.startswith(t, "test") and string.sub(t, -2) == "()" then
                        local d = fragments_text(m)
                        local name = string.sub(t, 1, -3)
                        if string.find(d, " async", 1, true) then
                            out[#out + 1] = "// async test skipped: " .. cname .. "." .. name
                        else
                            out[#out + 1] = string.format('_runTest(%s.self, "%s") { $0.%s }', cname, name, name)
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    out[#out + 1] = "exit(_finishTests())"
    io.writefile(args[2], "import XCTest\nimport Foundation\n" .. text.join("\n", out) .. "\n")
    print(string.format("%d tests", count))
end
