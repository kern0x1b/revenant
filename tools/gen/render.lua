-- The generated outputs of a framework, built in memory from the snapshot: text in, files out. Nothing here writes a file; the
-- commands hand the result to emit.

local layout = import("layout", {anonymous = true})
local snapshot = import("spec", {anonymous = true})
local releases = import("releases", {anonymous = true})
local sources = import("sources", {anonymous = true})
local protocols = import("protocols", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local order = import("order", {anonymous = true})
local surface = import("surface", {anonymous = true})
local sdk = import("sdk", {anonymous = true})
local measured = import("measured", {anonymous = true})
local headers = import("headers", {anonymous = true})
local bands = import("bands", {anonymous = true})
local property_map = import("property_map", {anonymous = true})
local filter_builders = import("filter_builders", {anonymous = true})
local protocol_headers = import("protocol_headers", {anonymous = true})
local mio_objects = import("mio_objects", {anonymous = true})

local function sorted_by_key(list, field)
    local tagged = {}
    for i, item in ipairs(list) do
        table.insert(tagged, {item = item, at = i})
    end
    table.sort(tagged, function(a, b)
        if a.item[field] ~= b.item[field] then
            return order.less(a.item[field], b.item[field])
        end
        return a.at < b.at
    end)
    local out = {}
    for _, t in ipairs(tagged) do
        table.insert(out, t.item)
    end
    return out
end

-- The release a constant is placed and registered at: the first release the held caches export it in (measured), else the
-- header's introduced release where no held cache exports it (`none`).
function release_of(r)
    local measured = r.measured
    if measured ~= "-" and measured ~= "none" and measured ~= "" then
        return measured
    end
    return r.introduced
end

-- The constants a framework's constant files hold, grouped by the release each is placed at (release_of, the same key release-split
-- checks a file's symbols by), and the sorted list of those releases. `named` holds the constants the registry names in any
-- status (surface.registry_constants).
function constant_groups(spec, named)
    local by_release, release_list = {}, {}
    for _, r in ipairs(spec) do
        if r.kind == "constant" and r.value_status == "found" and r.owned == "-" and r.tbd == "exported" and not named[r.api] then
            local release = release_of(r)
            if by_release[release] == nil then
                by_release[release] = {}
                table.insert(release_list, release)
            end
            table.insert(by_release[release], r)
        end
    end
    return by_release, releases.sorted(release_list)
end

-- The first identifier of a declaration, skipping const and volatile: the type of the constant.
function constant_base(decl)
    for word in string.gmatch(decl, "[%a_][%w_]*") do
        if word ~= "const" and word ~= "volatile" then
            return word
        end
    end
    return "NSString"
end

-- Whether a declaration's words hold const.
local function has_const(text)
    return string.find(text, "%f[%w_]const%f[^%w_]") ~= nil
end

-- The two const qualifiers of a declared type, read from where the const stands relative to the pointer's star (the last one): a
-- const before it qualifies the string (`const NSString *`, the SDK's `NSString const *`), a const after it qualifies the variable
-- (`NSString *const`). A type with no star is a typedef of a pointer (`NSErrorDomain const`), so its const is the variable's.
function constant_qualifiers(decl)
    local before, after = string.match(decl, "^(.*)%*(.*)$")
    if before == nil then
        return false, has_const(decl)
    end
    return has_const(before), has_const(after)
end

-- The type of an NSString constant as its declaration spells it: NSString *, with the string's const in front of it and the
-- variable's after the star (constant_qualifiers). `NSString const *` is `const NSString *`, the same type to the compiler.
function ns_type(decl)
    local pointee, variable = constant_qualifiers(decl)
    return (pointee and "const " or "") .. "NSString *" .. (variable and "const" or "")
end

-- The definition of one constant, in the canonical type of its shape: the qualifiers are the declaration's. A typedef of NSString
-- defines as NSString *, which is the same type to the compiler and needs no SDK typedef that a build SDK may lack; a CFStringRef
-- typedef defines as CFStringRef through a bridging cast from the literal, and its pointee const is already in the typedef, so only
-- the variable's const is written.
function constant_definition(r)
    local literal = '@"' .. r.value .. '"'
    if r.shape == "cf" then
        local _, variable = constant_qualifiers(r.type or "-")
        return string.format("%sCFStringRef %s = (__bridge CFStringRef)%s;", variable and "const " or "", r.api, literal)
    end
    return string.format("%s %s = %s;", ns_type(r.type or "-"), r.api, literal)
end

-- The README of a framework's build directory: what the generated files are, their counts, and the sources the generator reads.
local function readme(fw, spec, pins, stale, removed, new, by_release, release_list, sdk_release)
    local sdk_id = sdk.names(sdk_release).sdk_id
    local counts, kinds = {}, {}
    for _, r in ipairs(spec) do
        if counts[r.kind] == nil then
            counts[r.kind] = 0
            table.insert(kinds, r.kind)
        end
        counts[r.kind] = counts[r.kind] + 1
    end
    table.sort(kinds, order.less)
    local count_text = {}
    for _, k in ipairs(kinds) do
        table.insert(count_text, string.format("%s %d", k, counts[k]))
    end
    local constants = 0
    for _, release in ipairs(release_list) do
        constants = constants + #by_release[release]
    end
    local out = {
        "<!-- GENERATED by tools/gen.lua version " .. layout.constants().VERSION .. ". Do not edit. -->",
        "# gen/" .. fw,
        "",
        string.format("Spec: `spec.%s.tsv` (%s). Contract layer: `spec.h` (one hash per member), %d constant definitions in %d objects"
            .. " (%s), `verify.c` (one assertion per pinned override).", sdk_id, table.concat(count_text, ", "), constants,
            #release_list, table.concat(release_list, ", ")),
        string.format("Overrides: %d pins in `overrides/hashes/%s.tsv`; stale %d; removed %d; members without an override %d (new.tsv).",
            #pins, fw, #stale, #removed, #new),
        "",
        "Rules: gen/ is never edited by hand; `xmake l tools/gen.lua check` fails on any drift from what the generator emits and on a"
            .. " stale pin; a removed override is reported, never deleted.",
        "",
        "## Sources (the SOURCES table of tools/gen/sources.lua)",
        "",
        "| source | kind | licence | loader | status | adds |",
        "| --- | --- | --- | --- | --- | --- |",
    }
    for _, row in ipairs(sources.sources(sdk_release)) do
        table.insert(out, "| " .. table.concat(row, " | ") .. " |")
    end
    table.insert(out, "")
    table.insert(out, "## Open-source leads (licence and use, owner rule 2026-10-09)")
    table.insert(out, "")
    table.insert(out, "| lead | library | licence | use | status |")
    table.insert(out, "| --- | --- | --- | --- | --- |")
    for _, row in ipairs(sources.oss_leads()) do
        table.insert(out, "| " .. table.concat(row, " | ") .. " |")
    end
    table.insert(out, "")
    table.insert(out, "## References")
    table.insert(out, "")
    table.insert(out, "Libraries read as a reference for behaviour while writing a row, and the files consulted. None for this framework: the"
        .. " constants' values come from the macOS framework of this host and their declarations from the " .. sdk_release .. " headers.")
    table.insert(out, "")
    return table.concat(out, "\n")
end

-- The release list without its dots, as a file name carries it: 16.4 -> 164.
local function release_tag(release)
    return (string.gsub(release, "%.", ""))
end

-- Whether the spec holds an api: its own row, or, for a class's member, the same property of a protocol the class conforms to (a class
-- does not repeat a property its protocol declares, so the protocol's declaration is the one held). conformances maps a class or
-- protocol to the protocols it conforms to, followed transitively; protocol_members is the set of Protocol.property names.
function held(api, index, conformances, protocol_members)
    if index[api] ~= nil then
        return true
    end
    local class, member = string.match(api, "^([^.]+)%.(.+)$")
    if class == nil then
        return false
    end
    local seen = {}
    local function through(name)
        for _, protocol in ipairs(conformances[name] or {}) do
            if not seen[protocol] then
                seen[protocol] = true
                local key = protocol .. "." .. member
                if index[key] ~= nil or protocol_members[key] or through(protocol) then
                    return true
                end
            end
        end
        return false
    end
    return through(class)
end

-- The files the generator emits for a framework: name -> text. corpus is the coordination corpus when the command has it (nil in the
-- build): the protocol set is then checked against the rule (protocols.generation_set).
function render(tree, fw, corpus, sdk_release)
    local sdk_id = sdk.names(sdk_release).sdk_id
    local spec = snapshot.load(tree, fw)
    local index = snapshot.index(spec)
    local facts = headers.shard_facts(tree, fw)
    local pins = snapshot.pins(tree, fw)
    local overrides, override_order = snapshot.overrides(tree, fw)
    -- a constant the registry names, in any status, is defined by hand or refused by the registry check: the generator emits no
    -- definition or row for it (the registry row is the fact; the hand-written file is the definition)
    local named = surface.registry_constants(tree, fw)
    local files = {}

    local lines = {layout.constants().MARK, "// Framework: " .. fw .. ". Spec: " .. sdk_id .. ".",
                   "#ifndef CHARON_" .. string.upper(fw) .. "_SPEC_H", "#define CHARON_" .. string.upper(fw) .. "_SPEC_H"}
    for _, r in ipairs(spec) do
        table.insert(lines, "#define CHARON_SPEC_HASH_" .. r.key .. " 0x" .. r.hash .. "ULL")
    end
    table.insert(lines, "#endif")
    files["spec.h"] = table.concat(lines, "\n") .. "\n"

    local by_release, release_list = constant_groups(spec, named)
    for _, release in ipairs(release_list) do
        local body = {layout.constants().MARK, "#import <" .. fw .. "/" .. fw .. ".h>", ""}
        for _, r in ipairs(by_release[release]) do
            table.insert(body, constant_definition(r))
        end
        files[fw .. "Constants" .. release_tag(release) .. ".m"] = table.concat(body, "\n") .. "\n"
    end

    local verify = {layout.constants().MARK, '#include "spec.h"', "#define CHARON_IMPLEMENTS(key, pinned, name) \\",
                    '  _Static_assert(CHARON_SPEC_HASH_##key == (pinned), name " was written against another declaration: the ' .. sdk_release .. ' spec changed, review the override and re-pin it")'}
    local stale, removed = {}, {}
    local by_key = {}
    for _, r in ipairs(spec) do
        if by_key[r.key] == nil then
            by_key[r.key] = r
        end
    end
    local pinned_keys = {}
    for _, p in ipairs(sorted_by_key(pins, "key")) do
        pinned_keys[p.key] = true
        local target = by_key[p.key]
        if target == nil then
            table.insert(removed, {p.api, "pin without a spec member: the override stays, reported", p.registry})
        else
            if target.hash ~= p["pinned"] then
                table.insert(stale, {p.api, p.key, p["pinned"], target.hash, p.registry})
            end
            table.insert(verify, string.format('CHARON_IMPLEMENTS(%s, 0x%sULL, "%s");', p.key, p["pinned"], p.api))
        end
    end
    local api_names = table.move(override_order, 1, #override_order, 1, {})
    table.sort(api_names, order.less)
    for _, api in ipairs(api_names) do
        local found = overrides[api]
        if not held(api, index, facts.conformances, facts.protocol_members) and found.entry.kind ~= "class"
           and string.sub(api, 1, 2) ~= "-[" then
            table.insert(removed, {api, "registry override the " .. sdk_release .. " spec does not hold", found.registry})
        end
    end
    files["verify.c"] = table.concat(verify, "\n") .. "\n"

    local new = {}
    for _, r in ipairs(spec) do
        if (r.kind == "method" or r.kind == "property") and not pinned_keys[r.key] and overrides[r.api] == nil then
            table.insert(new, {r.cls, r.kind, r.api, r.hash})
        end
    end
    files["new.tsv"] = tsv.table_text({"class", "kind", "api", "hash"}, new)
    files["stale.tsv"] = tsv.table_text({"api", "key", "pinned", "spec", "registry"}, stale)
    files["removed.tsv"] = tsv.table_text({"api", "reason", "registry"}, removed)
    files["README.md"] = readme(fw, spec, pins, stale, removed, new, by_release, release_list, sdk_release)

    -- The per-row index the registry check reads (registry() in modules/apple/backports.lua): the fields of a registry row.
    -- Paths are relative to the package root, where registry/ and gen/ both live.
    local index_rows = {}
    for _, release in ipairs(release_list) do
        local source = ".gen/" .. fw .. "/" .. fw .. "Constants" .. release_tag(release) .. ".m"
        for _, r in ipairs(by_release[release]) do
            table.insert(index_rows, {fw, "constant", r.api, release, "6.0", release, "implemented", "",
                                      ".gen/" .. fw .. "/README.md", source, "generated", r.hash})
        end
    end
    files["rows.tsv"] = tsv.table_text({"framework", "kind", "api", "introduced", "minimum", "maximum", "status", "effect", "facts",
                                        "source", "owner", "declhash"}, index_rows)

    for name, text in pairs(protocols.protocol_files(tree, fw, corpus, sdk_release)) do
        files[name] = text
    end
    -- the protocol header of the framework (Charon<F>Protocols.h), declared from the snapshot and the declaration table
    -- (tools/gen/protocol_headers.lua): the generated sources and the folder's own sources import it from .gen/<F>/
    for name, text in pairs(protocol_headers.protocol_header_files(tree, fw)) do
        assert(files[name] == nil, name .. " is also emitted from the spec of " .. fw)
        files[name] = text
    end
    -- the objects of the measured tables (tools/gen/measured.lua): the release objects of the UIKit table and the constant objects of the
    -- constants table (tools/corpus/cfconst.tsv), written in place of the committed files. Their names are the framework's own, so a name
    -- the spec already emits is a collision and not an overwrite
    for name, text in pairs(measured.objects(tree, fw)) do
        assert(files[name] == nil, "measured object " .. name .. " is also emitted from the spec of " .. fw)
        files[name] = text
    end
    -- the band objects of the framework's committed spec (tools/gen/bands.lua): one object per band tag, named by the spec's own tags
    for name, text in pairs(bands.objects(tree, fw)) do
        assert(files[name] == nil, "band object " .. name .. " is also emitted from the spec of " .. fw)
        files[name] = text
    end
    -- the property table of ImageIO's CGImageMetadata (tools/gen/property_map.lua): the rows of its measured table in its object's text
    for name, text in pairs(property_map.objects(tree, fw)) do
        assert(files[name] == nil, "property object " .. name .. " is also emitted from the spec of " .. fw)
        files[name] = text
    end
    -- the CIFilter convenience constructors of CoreImage (tools/gen/filter_builders.lua): one object per band of the measured table
    for name, text in pairs(filter_builders.objects(tree, fw)) do
        assert(files[name] == nil, "constructor object " .. name .. " is also emitted from the spec of " .. fw)
        files[name] = text
    end
    -- the ModelIO band objects (tools/gen/mio_objects.lua): one object per release band of the SDK's surface rows, which are the
    -- framework's committed input and not the SDK's headers, so the rows' release names the file
    for name, text in pairs(mio_objects.objects(tree, fw, sdk_release)) do
        assert(files[name] == nil, "ModelIO object " .. name .. " is also emitted from the spec of " .. fw)
        files[name] = text
    end
    return files
end
