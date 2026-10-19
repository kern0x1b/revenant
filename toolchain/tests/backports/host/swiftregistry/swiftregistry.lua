import("core.base.json")

local KINDS = { class = true, struct = true, enum = true, protocol = true, actor = true, typealias = true }
local REGISTRIES = { "RealityFoundation.json", "RealityKit.json" }
local MODULES = { "RealityFoundation", "RealityKit" }

local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local function is_word(c)
    return c ~= "" and (c:find("^[%w_]") ~= nil or c:byte() >= 128)
end

local function find_bounded(text, word, from)
    local start = from
    while true do
        local s, e = text:find(word, start, true)
        if not s then
            return nil
        end
        local before = s > 1 and text:sub(s - 1, s - 1) or ""
        local after = text:sub(e + 1, e + 1)
        if is_word(before) ~= is_word(text:sub(s, s)) and is_word(text:sub(e, e)) ~= is_word(after) then
            return s, e
        end
        start = s + 1
    end
end

local function sources(root)
    local text = {}
    for _, module in ipairs(MODULES) do
        local folder = path.join(root, "files", module)
        if not os.isdir(folder) then
            raise("no " .. module .. " overlay sources at " .. folder)
        end
        local files = os.files(path.join(folder, "*.swift"))
        table.sort(files, byte_less)
        for _, file in ipairs(files) do
            local handle = assert(io.open(file, "rb"))
            text[#text + 1] = handle:read("a")
            handle:close()
        end
    end
    return table.concat(text, "\n")
end

local function declares(tree, name)
    for kind in pairs(KINDS) do
        local from = 1
        while true do
            local _, kind_end = find_bounded(tree, kind, from)
            if not kind_end then
                break
            end
            local ws_end = tree:find("%S", kind_end + 1) or (#tree + 1)
            if ws_end > kind_end + 1 and tree:sub(ws_end, ws_end + #name - 1) == name then
                local last = ws_end + #name - 1
                if is_word(tree:sub(last, last)) ~= is_word(tree:sub(last + 1, last + 1)) then
                    return true
                end
            end
            from = kind_end + 1
        end
    end
    return false
end

local function provides(tree, owner, provided)
    local from = 1
    while true do
        local _, owner_end = find_bounded(tree, owner, from)
        if not owner_end then
            return false
        end
        local line_end = tree:find("\n", owner_end + 1, true) or (#tree + 1)
        local colon = tree:find(":", owner_end + 1, true)
        if colon and colon < line_end then
            local first = tree:find("%S", colon + 1) or (#tree + 1)
            local last_line = (tree:find("\n", first, true) or (#tree + 1)) - 1
            local s = find_bounded(tree, provided, first)
            if s and s <= last_line then
                return true
            end
        end
        from = owner_end + 1
    end
end

local function split(text, separator)
    local pieces = {}
    local start = 1
    while true do
        local s, e = text:find(separator, start, true)
        if not s then
            pieces[#pieces + 1] = text:sub(start)
            return pieces
        end
        pieces[#pieces + 1] = text:sub(start, s - 1)
        start = e + 1
    end
end

local function rows(registry)
    local handle = assert(io.open(registry, "rb"))
    local document = json.decode(handle:read("a"))
    handle:close()
    return document.entries or {}
end

function main(root)
    root = root or os.getenv("SWIFTREGISTRY_PACKAGE") or path.join(os.scriptdir(), "..", "..", "..", "..", "packages", "s", "swift-runtime")
    root = path.absolute(root)
    local tree = sources(root)
    local failures = {}
    local checked = 0
    for _, name in ipairs(REGISTRIES) do
        local registry = path.join(root, "registry", name)
        if not os.isfile(registry) then
            failures[#failures + 1] = name .. ": no such registry"
        else
            for _, row in ipairs(rows(registry)) do
                if row.status == "implemented" and KINDS[row.kind] then
                    checked = checked + 1
                    local qualified = row.api or raise(name .. ": a row has no api")
                    local declared = qualified:match("[^%.]*$")
                    local provided = (row.reason or ""):match("conformance%-provided:%s*([A-Za-z][A-Za-z0-9_]*)")
                    if provided then
                        local owner = qualified:find(".", 1, true) and split(qualified, ".")
                        owner = owner and owner[#owner - 1]
                        if owner and provides(tree, owner, provided) then
                            goto continue
                        end
                        failures[#failures + 1] = string.format("%s: %s says its conformance %s provides it, but files/ does not declare %s conforming to it",
                            name, qualified, provided, owner or "None")
                        goto continue
                    end
                    if not declares(tree, declared) then
                        failures[#failures + 1] = string.format("%s: %s (%s, %s) has no declaration in files/", name, qualified, row.kind, row.status)
                        goto continue
                    end
                    local steps = split(qualified, ".")
                    for i = 1, #steps - 1 do
                        if not declares(tree, steps[i]) then
                            failures[#failures + 1] = string.format("%s: %s names %s, which files/ does not declare, so the path cannot be written", name, qualified, steps[i])
                            break
                        end
                    end
                end
                ::continue::
            end
        end
    end
    if #failures > 0 then
        for _, failure in ipairs(failures) do
            print("FAIL " .. failure)
        end
        print(string.format("swiftregistry: FAILED - %d implemented type row(s) with no declaration, of %d checked", #failures, checked))
        os.exit(1)
    end
    print(string.format("ok   every implemented type row has a declaration (%d rows)", checked))
    print(string.format("swiftregistry: OK - %d implemented type rows, none without a declaration", checked))
end
