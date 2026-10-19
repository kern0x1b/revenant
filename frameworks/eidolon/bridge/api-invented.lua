-- api-invented.lua OURS26 : the public members our module has that Apple's 26.2 interface does not.
--
--     xmake l api-invented.lua ours.json
--
-- The typed diff in api-diff.lua asks what Apple's declarations are missing here. This asks the other question,
-- which nothing else did: what does this module declare that Apple does not? A member invented rather than
-- reimplemented is a row the ledger counts as covered and the reader of the API never asked for, so every such
-- name is a line in the output.
--
-- The oracle is the union of the 26.2 interfaces of every module SwiftUI reaches through its `@_exported import`
-- lines, written by `bridge/surface-swiftui.sh` and read from `apple-26-surface.tsv` (APPLE_26_SURFACE overrides
-- it). Judging a re-export against SwiftUI's interface alone called half the standard library invented, and
-- reading the interfaces with regular expressions instead of a parser called 40 of Apple's own witnesses
-- invented; both are fixed, and a missing surface file is an error rather than a different answer.

import("core.base.json")
local text = import("lib.text", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local function either(a, b)
    if text.truthy(a) then
        return a
    end
    return b
end

-- a JSON object as opposed to a JSON array (both decode to a Lua table; an array has an element 1)
local function is_object(v)
    return type(v) == "table" and v[1] == nil
end

-- Python's `x in declAttributes`: a key of an object, an element of an array
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

-- The digester lists an access level only when it is not the one the context already implies, so a member of a
-- public type is public unless it says otherwise.
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

-- the names the walk judges, as {owner, name, declaration kind}
local ours = {}

local function walk(node, nesting, public)
    if not is_object(node) then
        return
    end
    local printed = node.printedName
    -- A TypeNameAlias is a use of a typealias inside a signature (`Swift.Void`, `Self.Configuration`), printed
    -- qualified, with no declaration kind and no usr: the declaration it names is judged where it is declared.
    local kind = node.kind
    if kind == "Import" or kind == "Accessor" or kind == "TypeNominal" or kind == "TypeNameAlias"
        or kind == "AssociatedType" then
        return
    end
    -- An @_spi declaration is visible only to a client that imports its group by name (`@_spi(Probe) import`), so
    -- it is not part of the API an app is written against, and neither is anything inside it.
    if has_attribute(node.declAttributes, "SPIAccessControl") then
        return
    end
    -- An override is the name of the declaration it overrides, which is judged where that one is declared (a
    -- method of UIKit is Objective-C and is in no .swiftinterface, so judging the override would call UIKit's own
    -- name invented).
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
    local surface_path = either(os.getenv("APPLE_26_SURFACE"), path.join(os.scriptdir(), "apple-26-surface.tsv"))
    if not os.isfile(surface_path) then
        io.stderr:write("# ERROR no Apple surface: " .. surface_path .. " is missing\n")
        io.stderr:write("# run bridge/surface-swiftui.sh first; the gate does not fall back to its own parse\n")
        os.exit(2)
    end

    -- The surface file is what bridge/surface-swiftui.sh writes: the interfaces of every module SwiftUI reaches
    -- through its `@_exported import` lines, read by swift-syntax's SwiftParser. A parser sees what regular
    -- expressions cannot - an associatedtype witness printed as a `var`, a nested `typealias` printed as a
    -- property, an enum `case`, a `subscript`, a static in a constrained extension - and every such row used to be
    -- a name Apple declares and this gate called invented.
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
            -- the last dotted component, without the parameters, and without the backticks a keyword is written in
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

    -- the allow-list: a name this port carries that no interface of the modules the port declares against declares
    -- either, with the reason it is here. `#name` is the name under any type.
    local allowed = {}
    local allow_path = path.join(os.scriptdir(), "api-allow-list.txt")
    if os.isfile(allow_path) then
        for _, line in ipairs(text.split(io.readfile(allow_path), "\n")) do
            -- a comment is a `#` with a space after it: `#name` is the bare form for any type
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
    -- to stderr, never to stdout: stdout is the invented list, and a row that is not invented does not belong in
    -- the count api-surface.sh prints
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
    -- The oracle is SwiftUI's own interface, so the standard library and Foundation that this module re-exports are
    -- all "invented" by that measure. STRICT=1 makes a non-empty list fail; until the re-exports are whitelisted the
    -- list is reported and the check does not stop a build.
    if os.getenv("STRICT") == "1" and seen_count > 0 then
        os.exit(1)
    end
end
