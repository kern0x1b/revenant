local lib = import("vtlib", {rootdir = os.scriptdir(), anonymous = true})
local json = import("core.base.json")

local function load_record(path)
    return json.decode(lib.read_text(path))
end

function main(mode, first, second)
    if mode == "count" and first then
        print(lib.count_keys(load_record(first)))
    elseif mode == "diff" and first and second then
        local a, b = load_record(first), load_record(second)
        local seen, names = {}, {}
        for k in pairs(a) do
            seen[k] = true
            names[#names + 1] = k
        end
        for k in pairs(b) do
            if not seen[k] then
                seen[k] = true
                names[#names + 1] = k
            end
        end
        lib.sort_bytes(names)
        for _, k in ipairs(names) do
            if a[k] ~= b[k] then
                print(string.format("  caught: %-58s [%s] -> [%s]", k, lib.py_value(a[k]), lib.py_value(b[k])))
            end
        end
    else
        raise("records.lua: pass count FILE, or diff A B")
    end
end
