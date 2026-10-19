-- swiftregistry.lua - every row of packages/s/swift-runtime/registry/ that says `implemented` has a declaration in
-- packages/s/swift-runtime/files/.
--
-- Why this test exists: on 2026-09-28 the family review found `EnvironmentResource` used in five places in `ARView.swift`
-- and declared nowhere, with a registry row calling it `kind: class, status: implemented` - a row with no code behind it, in
-- a module that did not compile. Nothing caught it: a Swift module exports no symbol a dylib inventory sees, so
-- `check_registry` cannot read these rows (registry/README.md says so) and no other check reads them at all.
--
-- This is a declaration-level check, not a behavioural one: a type row must have a `class`/`struct`/`enum`/`protocol`/
-- `actor`/`typealias` declaration by that name in the two overlay source trees. Member rows are not checked here, and a row
-- that is not `implemented` is not checked, because an absent row is supposed to have no declaration.
--
-- Exit 0 when every implemented row has a declaration, 1 with the list of the ones that do not. The word test is the
-- regular expressions' \b, with ASCII letters, digits and underscore as word characters and every byte above 127 counted
-- as a word character too (Python counts only Unicode letters): a name met next to a non-ASCII symbol may therefore differ.
-- Usage: xmake l ./swiftregistry.lua   (SWIFTREGISTRY_PACKAGE names another package root, as before)

import("core.base.json")

local KINDS = { class = true, struct = true, enum = true, protocol = true, actor = true, typealias = true }
local REGISTRIES = { "RealityFoundation.json", "RealityKit.json" }
local MODULES = { "RealityFoundation", "RealityKit" }

-- Names are sorted by their bytes, as Python sorts strings: the string comparison of Lua follows the locale's collation.
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

-- The first place at or after `from` where `word` stands with a word boundary on each side, as \bword\b.
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

-- Every .swift file of the two overlay modules, as one text, the files in name order and joined by newlines.
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

-- A declaration of `name` is a declaration keyword, then whitespace, then the name at a word boundary: \b(kind)\s+NAME\b.
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

-- True when the owner's name, on its line, is followed by a colon and the provided name follows that colon - the same
-- line, or, past the whitespace after the colon, the first line that has text in it: owner[^\n]*:\s*[^\n]*\bprovided\b.
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
                    -- The row's name is qualified when the type is nested, and a declaration is spelled by the type's own
                    -- name, so the last piece is the one to look for.
                    local declared = qualified:match("[^%.]*$")
                    -- A row may name the conformance that provides its name, as `conformance-provided: OptionSet` in its
                    -- reason: Swift prints a conformance's own typealiases in the interface. The exception is only worth
                    -- anything if it is still checked, so the owning type must really declare that conformance.
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
                    -- A qualified name is a path, and every step of it has to be a type this tree declares.
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
        -- A run is reported by its verdict line and nothing else: the verdict is one line, and it is the last one.
        print(string.format("swiftregistry: FAILED - %d implemented type row(s) with no declaration, of %d checked", #failures, checked))
        os.exit(1)
    end
    print(string.format("ok   every implemented type row has a declaration (%d rows)", checked))
    print(string.format("swiftregistry: OK - %d implemented type rows, none without a declaration", checked))
end
