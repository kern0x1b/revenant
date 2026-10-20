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

local function has_attribute(attributes, want)
    if type(attributes) ~= "table" then
        return false
    end
    if is_object(attributes) then
        return attributes[want] ~= nil
    end
    for _, item in ipairs(attributes) do
        if item == want then
            return true
        end
    end
    return false
end

local function access_level(node)
    local attributes = node.declAttributes
    if is_object(attributes) then
        return either(attributes.accessLevel, "public")
    end
    if type(attributes) == "table" then
        for _, item in ipairs(attributes) do
            if type(item) == "string" then
                if text.startswith(item, "public") then
                    return "public"
                end
                if text.startswith(item, "private") or text.startswith(item, "fileprivate") then
                    return "private"
                end
            end
        end
    end
    return "public"
end

local ours = {}

local function walk(node, nesting, public)
    if not is_object(node) then
        return
    end
    local printed = node.printedName
    local kind = node.kind
    if kind == "Import" or kind == "Accessor" or kind == "TypeNominal" or kind == "TypeNameAlias"
        or kind == "AssociatedType" then
        return
    end
    if has_attribute(node.declAttributes, "SPIAccessControl") then
        return
    end
    if text.truthy(node.overriding) then
        return
    end
    local is_public = access_level(node) == "public"
    if text.truthy(printed) and kind ~= "Root" then
        local base = string.match(string.gsub(printed, "<[^<>]*>", ""), "^([^%(]*)")
        if (public or is_public) and text.truthy(base) and not text.startswith(base, "_")
            and (utf8.len(base) or #base) > 1 then
            ours[#ours + 1] = {nesting[#nesting] or "", base, either(node.declKind, "")}
        end
    end
    local is_type = kind == "TypeDecl" and text.truthy(node.name)
    local nested = nesting
    if is_type then
        nested = {table.unpack(nesting)}
        nested[#nested + 1] = either(either(node.name, node.printedName), "")
    end
    for _, child in ipairs(node.children or {}) do
        walk(child, nested, public or (is_public and is_type))
    end
end

function main(...)
    local argv = {...}
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local surface_path = path.join(tree.run("api"), "apple-26-surface.tsv")
    if not os.isfile(surface_path) then
        io.stderr:write("# ERROR no Apple surface: " .. surface_path .. " is missing\n")
        io.stderr:write("# run tools/api-surface.lua apple first; the gate does not fall back to its own parse\n")
        os.exit(2)
    end

    local apple = {}
    local apple_count = 0
    local function declare(name)
        if apple[name] == nil then
            apple[name] = true
            apple_count = apple_count + 1
        end
    end
    for _, line in ipairs(text.split(io.readfile(surface_path), "\n")) do
        local parts = text.split(line, "\t")
        if #parts >= 2 and parts[2] ~= "" then
            local name = string.match(string.match(parts[2], "([^%.]*)$"), "^([^%(]*)")
            name = string.gsub(name, "^`+", "")
            name = string.gsub(name, "`+$", "")
            declare(name)
        end
    end
    io.stderr:write(string.format("# Apple surface from %s (%d names)\n", surface_path, apple_count))
    for _, name in ipairs({"==", "hash", "self", "Type", "init", "some", "get", "set"}) do
        declare(name)
    end

    local root = json.decode(io.readfile(argv[1])).ABIRoot
    walk(root, {}, false)

    local allowed = {}
    local allow_path = tree.api("allow-list.txt")
    if os.isfile(allow_path) then
        for _, line in ipairs(text.split(io.readfile(allow_path), "\n")) do
            if text.strip(line) ~= "" and not text.startswith(text.lstrip(line), "# ")
                and not text.startswith(text.lstrip(line), "//") then
                local name, _, reason = text.partition(line, "\t")
                allowed[text.strip(name)] = text.strip(reason)
            end
        end
    end
    local used = {}
    local allowed_count = 0
    for _ in pairs(allowed) do
        allowed_count = allowed_count + 1
    end
    io.stderr:write(string.format("# %d names on the allow-list\n", allowed_count))

    local invented = {}
    for _, entry in ipairs(ours) do
        local owner, name, access = entry[1], entry[2], entry[3]
        if apple[name] == nil then
            local key = nil
            if allowed[owner .. "#" .. name] ~= nil then
                key = owner .. "#" .. name
            elseif allowed["#" .. name] ~= nil then
                key = "#" .. name
            end
            if key then
                used[key] = true
            else
                invented[#invented + 1] = entry
            end
        end
    end

    local unused = {}
    for key in pairs(allowed) do
        if not used[key] then
            unused[#unused + 1] = key
        end
    end
    table.sort(unused)
    for _, key in ipairs(unused) do
        io.stderr:write("allowed\t" .. key .. "\t" .. allowed[key] .. "\n")
    end
    local used_count = 0
    for _ in pairs(used) do
        used_count = used_count + 1
    end
    io.stderr:write(string.format("# %d of the %d allow-listed names were used\n", used_count, allowed_count))

    local seen = {}
    local seen_count = 0
    for _, entry in ipairs(invented) do
        local owner, name, access = entry[1], entry[2], entry[3]
        local key = owner .. "\1" .. name
        if not seen[key] then
            seen[key] = true
            seen_count = seen_count + 1
            print(text.ljust(owner, 34) .. " " .. text.ljust(access, 10) .. " " .. name)
        end
    end
    io.stderr:write(string.format("# %d public names in ours that no 26.2 interface of the modules we re-export declares\n",
        seen_count))
    if os.getenv("STRICT") == "1" and seen_count > 0 then
        os.exit(1)
    end
end
