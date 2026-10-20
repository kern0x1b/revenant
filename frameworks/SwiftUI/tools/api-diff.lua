import("core.base.json")
local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})

local function either(a, b)
    if text.truthy(a) then
        return a
    end
    return b
end

local function is_object(v)
    return type(v) == "table" and v[1] == nil
end

local function children(node)
    return node.children or {}
end

local function walk(node, path, out)
    if not is_object(node) then
        return
    end
    if text.truthy(node.usr) and text.truthy(node.declKind) then
        out[#out + 1] = {path = path, node = node}
    end
    local nested = path
    if node.kind == "TypeDecl" then
        nested = {table.unpack(path)}
        nested[#nested + 1] = either(either(node.name, node.printedName), "")
    end
    for _, child in ipairs(children(node)) do
        walk(child, nested, out)
    end
end

local function load(file)
    local root = json.decode(io.readfile(file)).ABIRoot
    if not root then
        raise("api-diff: " .. file .. " has no ABIRoot")
    end
    local found = {}
    walk(root, {}, found)
    return found
end

local function split_name(printed)
    local base, inner = string.match(printed, "^([^%(]+)%((.*)%)$")
    if not base then
        return nil, {}
    end
    local labels = {}
    if inner ~= "" then
        for _, label in ipairs(text.split(inner, ":")) do
            if label ~= "" then
                labels[#labels + 1] = label
            end
        end
    end
    return base, labels
end

local function key(owner, name)
    return owner .. "\1" .. name
end

local function covered_by_defaults(ours_shapes, owner, printed)
    local base, wanted = split_name(printed)
    if not base then
        return false
    end
    for _, shape in ipairs(ours_shapes[key(owner, base)] or {}) do
        local index = 1
        local extras_default = true
        for _, pair in ipairs(shape) do
            local label, has_default = pair[1], pair[2]
            if index <= #wanted and label == wanted[index] then
                index = index + 1
            elseif not has_default then
                extras_default = false
            end
        end
        if index == #wanted + 1 and extras_default then
            return true
        end
    end
    return false
end

local function signature(node)
    local parts = {}
    for _, child in ipairs(children(node)) do
        if string.sub(child.kind or "", 1, 4) == "Type" then
            parts[#parts + 1] = child.printedName or ""
        end
    end
    if #parts > 1 then
        return text.join(" -> ", {table.unpack(parts, 2)})
    end
    return ""
end

local function bare(printed)
    return string.match(printed, "^([^%(]*)")
end

local function sorted_strings(items)
    table.sort(items)
    return items
end

function main(...)
    local argv = {...}
    local flags, args = {}, {}
    local only = nil
    for i, a in ipairs(argv) do
        if text.startswith(a, "--") then
            flags[#flags + 1] = a
        else
            args[#args + 1] = a
        end
        if a == "--type" then
            only = argv[i + 1]
            if not only then
                raise("api-diff: --type needs a name")
            end
        end
    end
    local wants = function(flag)
        return text.contains(flags, flag)
    end
    if only then
        args = (function()
            local kept = {}
            for _, a in ipairs(args) do
                if a ~= only then
                    kept[#kept + 1] = a
                end
            end
            return kept
        end)()
    end

    local apple = load(args[1])
    local ours = load(args[2])
    local ours_usr = {}
    local ours_names = {}
    local ours_shapes = {}
    for _, entry in ipairs(ours) do
        local nesting, node = entry.path, entry.node
        local owner = nesting[#nesting] or ""
        if text.truthy(node.usr) then
            ours_usr[node.usr] = true
        end
        ours_names[key(owner, node.printedName or "")] = true
        local base, labels = split_name(node.printedName or "")
        local params = {}
        for i, child in ipairs(children(node)) do
            if string.sub(child.kind or "", 1, 4) == "Type" then
                params[#params + 1] = child
            end
        end
        local shape_params = {table.unpack(params, 2)}
        if text.truthy(base) and #shape_params == #labels then
            local shape = {}
            for i, label in ipairs(labels) do
                shape[#shape + 1] = {label, text.truthy(shape_params[i].hasDefaultArg)}
            end
            local k = key(owner, base)
            ours_shapes[k] = ours_shapes[k] or {}
            table.insert(ours_shapes[k], shape)
        end
    end

    local not_applicable = {}
    local listed = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true}).api("not-applicable.txt")
    if os.isfile(listed) then
        for _, line in ipairs(text.split(io.readfile(listed), "\n")) do
            if text.strip(line) ~= "" and not text.startswith(line, "#") then
                local name, _, reason = text.partition(line, "\t")
                not_applicable[name] = reason
            end
        end
    end

    local missing = {}
    local order = {}
    for _, entry in ipairs(apple) do
        local nesting, node = entry.path, entry.node
        local usr = node.usr
        local skip = not text.truthy(usr) or ours_usr[usr] or text.truthy(node.implicit)
        local printed = node.printedName or ""
        local under_underscore = false
        for _, p in ipairs(nesting) do
            if text.startswith(p, "_") then
                under_underscore = true
            end
        end
        if not skip and not text.startswith(printed, "_") and not under_underscore then
            local owner = nesting[#nesting] or ""
            if not only or owner == only then
                local kind = either(node.declKind, node.kind)
                local covered = (kind == "Func" or kind == "Constructor")
                    and covered_by_defaults(ours_shapes, owner, printed)
                if kind ~= "Accessor" and not covered then
                    local state = ours_names[key(owner, printed)] and "variant" or "absent"
                    local member = owner .. "#" .. bare(printed)
                    if state == "absent" and (not_applicable[owner] ~= nil or not_applicable[member] ~= nil) then
                        state = "not-applicable"
                    end
                    if not missing[owner] then
                        missing[owner] = {}
                        order[#order + 1] = owner
                    end
                    table.insert(missing[owner], {state, kind, printed, signature(node)})
                end
            end
        end
    end

    local seen_order = {}
    for i, owner in ipairs(order) do
        seen_order[owner] = i
    end
    table.sort(order, function(a, b)
        if #missing[a] ~= #missing[b] then
            return #missing[a] > #missing[b]
        end
        return seen_order[a] < seen_order[b]
    end)

    local total = {absent = 0, variant = 0, ["not-applicable"] = 0}
    for _, owner in ipairs(order) do
        local items = missing[owner]
        table.sort(items, function(a, b)
            for i = 1, 4 do
                if a[i] ~= b[i] then
                    return a[i] < b[i]
                end
            end
            return false
        end)
        for _, item in ipairs(items) do
            local state, kind, printed, sig = item[1], item[2], item[3], item[4]
            total[state] = total[state] + 1
            if wants("--variants") or state == "absent" or (state == "not-applicable" and wants("--not-applicable")) then
                print(owner .. "\t" .. state .. "\t" .. kind .. "\t" .. printed .. "\t" .. sig)
            end
        end
    end
    io.stderr:write(string.format("# absent %d, variant %d, not applicable %d (tests/data/api/not-applicable.txt, with reasons)\n",
        total["absent"], total["variant"], total["not-applicable"]))

    local used = {}
    for _, owner in ipairs(order) do
        for _, item in ipairs(missing[owner]) do
            if item[1] == "not-applicable" then
                used[not_applicable[owner] ~= nil and owner or owner .. "#" .. bare(item[3])] = true
            end
        end
    end
    local unused = {}
    for name in pairs(not_applicable) do
        if not used[name] then
            unused[#unused + 1] = name
        end
    end
    if #unused > 0 then
        io.stderr:write("# not-applicable.txt names types with nothing absent (remove them): "
            .. text.join(", ", sorted_strings(unused)) .. "\n")
    end

    if wants("--conformances") then
        local ours_conf = {}
        for _, entry in ipairs(ours) do
            local node = entry.node
            local declKind = node.declKind
            if declKind == "Struct" or declKind == "Class" or declKind == "Enum" or declKind == "Protocol" then
                local name = node.printedName or ""
                ours_conf[name] = ours_conf[name] or {}
                for _, c in ipairs(node.conformances or {}) do
                    ours_conf[name][c.printedName or ""] = true
                end
            end
        end
        for _, entry in ipairs(apple) do
            local node = entry.node
            local declKind = node.declKind
            if declKind == "Struct" or declKind == "Class" or declKind == "Enum" then
                local name = node.printedName or ""
                local wanted = {}
                for _, c in ipairs(node.conformances or {}) do
                    local conformed = c.printedName or ""
                    if not (ours_conf[name] and ours_conf[name][conformed]) and not text.startswith(conformed, "_")
                        and conformed ~= "Copyable" and conformed ~= "Escapable" and conformed ~= "Sendable"
                        and conformed ~= "BitwiseCopyable" then
                        wanted[conformed] = true
                    end
                end
                local gap = {}
                for g in pairs(wanted) do
                    gap[#gap + 1] = g
                end
                if #gap > 0 and (not only or name == only) then
                    print("CONFORMANCE\t" .. name .. "\t" .. text.join(", ", sorted_strings(gap)))
                end
            end
        end
    end
end
