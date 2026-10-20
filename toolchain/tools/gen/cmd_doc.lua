local snapshot = import("spec", {anonymous = true})
local surface = import("surface", {anonymous = true})
local headers = import("headers", {anonymous = true})
local objc = import("objc", {anonymous = true})
local protocols = import("protocols", {anonymous = true})
local swift = import("swift", {anonymous = true})
local gen = import("cmd_gen", {anonymous = true})
local trace_files = import("trace_files", {anonymous = true})
local emit = import("emit", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local pages = import("pages", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local project = import("project", {anonymous = true})
local behaviour = import("behaviour", {anonymous = true})

local objc_each = objc.each

local LEDGER_6_1_3 = surface.ledger_6_1_3()
local LEDGER_4_3 = surface.ledger_4_3()
local NO_VALUE = "-"
local FIXED_PAGES = {"index.md", "Constants.md", "Swift.md"}
local MEMBER_KINDS = {method = true, property = true}
local COMMENTS_NOT_DERIVED = "- not derived: the extractor does not run for this framework"
local DECL_NOT_DERIVED = "not derived: decl (ruling D8)"
local NOT_IN_ROWS = "not derived: not in the doc rows"
local function behaviour_note(release)
    return "Not part of this page. `xmake l tools/gen.lua behaviour --framework <framework> --coordination <corpus> "
                       .. "--ipsw-cache <cache>` writes the summary of the methods it is run on (the calls in the order the code makes "
                       .. "them, the register branches, the strings, constants and error domains its comments name; REFERENCE ONLY) "
                       .. "to `behaviour/<Class>.md` beside this page. It reads the on-disk iOS " .. release .. " cache one method at a time through "
                       .. "coordination/heavy.sh (--limit and --selector choose the methods). No command produces implementation "
                       .. "pseudocode yet."
end
local NO_COMMENT = "no comment in the doc rows"
local doc_text = import("doc_text", {anonymous = true})
local ORACLE_ROWS_SHOWN = 60
local CELL_LIMIT = 400
local SECTION_INSTANCE = "instance"
local SECTION_CLASS = "class"
local DEFAULT_SUPERCLASS = "NSObject"
local REGENERATE_COMMAND = "tools/gen.lua doc"

local function swift_overlay_needs(release)
    return {
        "Declarations with types: the " .. release .. " .swiftinterface text of each module (241 files in the SDK). No table in v-cache26 carries types.",
        "A Swift compiler that targets armv7 for iOS 6.1.3: the local swiftc (6.4) rejects `armv7-apple-ios6.1.3` (minimum iOS 7.0).",
        "The Swift runtime on iOS 6.1.3 (libswiftCore and the rest): none of the 574 armv7 images of the 6.1.3 cache read is a Swift image.",
        "A mapping from each Swift name to its mangled symbol: swift-" .. release .. ".tsv has names, kinds and members, not symbols.",
        "Signatures of generic, async, throwing, protocol-constrained and property-wrapper rows: no table carries them.",
        "Whether an armv7 Swift module or runtime loads on iOS 6.1.3: only a device run can show it.",
    }
end

function use_objc(source)
    objc_each = source or objc.each
end

local function present(value)
    return value ~= nil and value ~= ""
end

local function either(value, fallback)
    if present(value) then
        return value
    end
    return fallback
end

local function md_cell(value)
    local text = value == nil and "None" or tostring(value)
    text = string.gsub(text, "|", "\\|")
    text = string.gsub(text, "\n", " ")
    return string.sub(text, 1, CELL_LIMIT)
end

local function sequence_at(text, i)
    local lead = string.byte(text, i)
    local count, code
    if lead >= 0xC2 and lead <= 0xDF then
        count, code = 2, lead & 0x1F
    elseif lead >= 0xE0 and lead <= 0xEF then
        count, code = 3, lead & 0x0F
    elseif lead >= 0xF0 and lead <= 0xF4 then
        count, code = 4, lead & 0x07
    else
        return nil
    end
    if i + count - 1 > #text then
        return nil
    end
    for k = i + 1, i + count - 1 do
        local byte = string.byte(text, k)
        if byte < 0x80 or byte > 0xBF then
            return nil
        end
        code = (code << 6) | (byte & 0x3F)
    end
    return count, code
end

local function ascii_text(text)
    return (string.gsub(text, "[\128-\255]+", function(run)
        local out, i = {}, 1
        while i <= #run do
            local count, code = sequence_at(run, i)
            if count then
                table.insert(out, string.format("\\u{%x}", code))
                i = i + count
            else
                table.insert(out, string.format("\\x%02x", string.byte(run, i)))
                i = i + 1
            end
        end
        return table.concat(out)
    end))
end

local function decl_text(text)
    return (string.gsub(ascii_text(text), "|", "\\|"))
end

local function fence_of(text)
    local longest = 0
    for run in string.gmatch(text, "`+") do
        longest = math.max(longest, #run)
    end
    return string.rep("`", math.max(3, longest + 1))
end

local function code_span(text)
    local longest = 0
    for run in string.gmatch(text, "`+") do
        longest = math.max(longest, #run)
    end
    if longest == 0 then
        return "`" .. text .. "`"
    end
    local delimiter = string.rep("`", longest + 1)
    return delimiter .. " " .. text .. " " .. delimiter
end

local function decl_cell(docs, kind, api)
    if docs == nil then
        return code_span(DECL_NOT_DERIVED)
    end
    local row = docs[kind .. " " .. api]
    if row == nil then
        return code_span(NOT_IN_ROWS)
    end
    return code_span(decl_text(row.decl))
end

local function comments_section(docs, entries)
    local page = {"## Header comments", ""}
    if docs == nil then
        page[#page + 1] = COMMENTS_NOT_DERIVED
        return page
    end
    local blocks, bullets = {}, {}
    for _, entry in ipairs(entries) do
        local row = docs[entry.kind .. " " .. entry.api]
        if row == nil then
            table.insert(bullets, string.format("- `%s`: %s", entry.api, NOT_IN_ROWS))
        elseif row.comment == "" then
            table.insert(bullets, string.format("- `%s`: %s", entry.api, NO_COMMENT))
        else
            local text = ascii_text(row.comment)
            local fence = fence_of(text)
            local block = {"### `" .. entry.api .. "`", "", fence}
            for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
                table.insert(block, line)
            end
            table.insert(block, fence)
            table.insert(blocks, block)
        end
    end
    local body = {}
    for _, block in ipairs(blocks) do
        if #body > 0 then
            table.insert(body, "")
        end
        for _, line in ipairs(block) do
            table.insert(body, line)
        end
    end
    if #bullets > 0 then
        if #body > 0 then
            table.insert(body, "")
        end
        for _, line in ipairs(bullets) do
            table.insert(body, line)
        end
    end
    for _, line in ipairs(body) do
        page[#page + 1] = line
    end
    return page
end

local function strip_brackets(api)
    return (string.gsub(api, "%]+$", ""))
end

local function selector_of(api)
    local text = strip_brackets(api)
    local space = string.find(text, " ", 1, true)
    return space and string.sub(text, space + 1) or ""
end

local function name_of(api)
    return string.match(strip_brackets(api), "([^ ]*)$")
end

local function row_of(map, kind, api)
    return map[surface.key(kind, api)]
end

local function sorted_stable(list, before)
    local indexed = {}
    for i, item in ipairs(list) do
        indexed[i] = {item = item, at = i}
    end
    table.sort(indexed, function(a, b)
        if before(a.item, b.item) then
            return true
        end
        if before(b.item, a.item) then
            return false
        end
        return a.at < b.at
    end)
    local out = {}
    for i, entry in ipairs(indexed) do
        out[i] = entry.item
    end
    return out
end

local function by_fields(names)
    return function(a, b)
        for _, name in ipairs(names) do
            if a[name] ~= b[name] then
                return order.less(a[name], b[name])
            end
        end
        return false
    end
end

local function relative_to(tree, filepath)
    local prefix = tree .. "/"
    if string.sub(filepath, 1, #prefix) == prefix then
        return string.sub(filepath, #prefix + 1)
    end
    return filepath
end

local function needs_of(tree, fw)
    local need = {keys = {}, owners = {}}
    for _, r in ipairs(snapshot.load(tree, fw)) do
        if MEMBER_KINDS[r.kind] then
            need.owners[r.cls] = true
            local key
            if r.kind == "method" then
                local section = string.sub(r.api, 1, 1) == "-" and SECTION_INSTANCE or SECTION_CLASS
                key = objc.key_of({entity = "method", owner = r.cls, section = section, name = selector_of(r.api)})
            else
                key = objc.key_of({entity = "property", owner = r.cls, section = SECTION_INSTANCE, name = name_of(r.api)})
            end
            need.keys[key] = true
        end
    end
    return need
end

local function read_objc(corpus, sdk_release, needs)
    local frameworks, state = {}, {}
    for fw, need in pairs(needs) do
        frameworks[fw] = true
        state[fw] = {keys = need.keys, owners = need.owners, index = {}, meta = {}, classes_seen = {}}
    end
    objc_each(corpus, sdk_release, frameworks, function(fw, row)
        local s = state[fw]
        local key = objc.key_of(row)
        if row.entity == "class" then
            if s.owners[row.owner] and not s.classes_seen[key] then
                s.classes_seen[key] = true
                s.meta[row.owner] = row
            end
        elseif s.keys[key] and s.index[key] == nil then
            s.index[key] = row
        end
    end)
    return state
end

local function class_page(parsed, fw, cls, members, ctx)
    local led, led43, surf, regs, pins = ctx.led, ctx.led43, ctx.surf, ctx.regs, ctx.pins
    local stubs_skipped, oracle, meta_of, objc_index = ctx.stubs_skipped, ctx.oracle, ctx.meta_of, ctx.objc_index
    local page = {"# " .. cls .. " (" .. fw .. ")", "",
                  "Superclass: " .. either(parsed.superclasses[cls], NO_VALUE) .. ". Status at 6.1.3 and 4.3 is per member below.", "",
                  "| kind | declaration (" .. ctx.sdk_release .. " header, normalised) | availability | 6.1.3 | 4.3 | demand | impl-lead | ours (registry, pin) | stub |",
                  "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"}
    local sorted = sorted_stable(members, by_fields({"kind", "api"}))
    for _, r in ipairs(sorted) do
        local s6 = either(row_of(led, r.kind, r.api), ctx.unchecked)
        local s43 = either(row_of(led43, r.kind, r.api), surface.not_checked_state("4.3"))
        local srow = row_of(surf, r.kind, r.api) or {}
        local demand = NO_VALUE
        if present(srow["demand-rank"]) then
            demand = string.format("rank %s, %s, %s apps", either(srow["demand-rank"], NO_VALUE),
                                   either(srow["demand-severity"], NO_VALUE), either(srow["demand-apps"], NO_VALUE))
        end
        local ours = NO_VALUE
        local registered = regs[r.api]
        if registered then
            local pin = pins[r.api]
            ours = string.format("%s: %s%s", registered.entry.status == nil and "?" or registered.entry.status,
                                 registered.registry, pin and (", pin " .. tostring(pin["pinned-by"])) or "")
        end
        local stub
        if registered then
            stub = "hand/override"
        elseif stubs_skipped[r.api] then
            stub = "not stubbed: " .. stubs_skipped[r.api]
        else
            stub = "stub"
        end
        page[#page + 1] = string.format("| %s | %s | %s | %s | %s | %s | %s | %s | %s |", r.kind, decl_cell(ctx.docs, r.kind, r.api),
                                        md_cell(r.availability ~= NO_VALUE and r.availability or NO_VALUE), s6, s43, demand,
                                        md_cell(either(srow["impl-lead"], NO_VALUE)), md_cell(ours), md_cell(stub))
    end
    page[#page + 1] = ""
    local entries = {}
    for _, r in ipairs(sorted) do
        entries[#entries + 1] = {kind = r.kind, api = r.api}
    end
    for _, line in ipairs(comments_section(ctx.docs, entries)) do
        page[#page + 1] = line
    end
    if oracle[cls] then
        page[#page + 1] = ""
        page[#page + 1] = "## Host oracle (macOS, class state and defaults; v-cache26 capture)"
        page[#page + 1] = ""
        page[#page + 1] = "| item | kind | value | build |"
        page[#page + 1] = "| --- | --- | --- | --- |"
        for i = 1, math.min(#oracle[cls], ORACLE_ROWS_SHOWN) do
            local row = oracle[cls][i]
            page[#page + 1] = string.format("| %s | %s | %s | %s |", md_cell(row[1]), md_cell(row[2]), md_cell(row[3]), md_cell(row[4]))
        end
    end
    page[#page + 1] = ""
    page[#page + 1] = "## Runtime metadata (" .. ctx.sdk_release .. " binary, v-cache26 ObjC table; REFERENCE ONLY: the encodings give the binary's argument"
    page[#page + 1] = "and return types, not what a method does)"
    page[#page + 1] = ""
    local meta = meta_of[cls]
    if meta then
        page[#page + 1] = string.format("Superclass in the binary: %s. Protocols: %s.", either(meta.superclass, NO_VALUE),
                                        either(meta.protocols, NO_VALUE))
    else
        page[#page + 1] = "No class row for this class in the binary's ObjC table."
    end
    page[#page + 1] = ""
    page[#page + 1] = "| member | binary type encoding | binary address |"
    page[#page + 1] = "| --- | --- | --- |"
    for _, r in ipairs(sorted) do
        local row
        if r.kind == "method" then
            row = objc_index[objc.key_of({entity = "method", owner = cls,
                                          section = string.sub(r.api, 1, 1) == "-" and SECTION_INSTANCE or SECTION_CLASS,
                                          name = selector_of(r.api)})]
        else
            row = objc_index[objc.key_of({entity = "property", owner = cls, section = SECTION_INSTANCE, name = name_of(r.api)})]
        end
        page[#page + 1] = string.format("| `%s` | %s | %s |", md_cell(r.api),
                                        row and md_cell(row.types) or "not in the table", row and row.address or NO_VALUE)
    end
    page[#page + 1] = ""
    page[#page + 1] = "## Behaviour summary"
    page[#page + 1] = ""
    page[#page + 1] = behaviour_note(ctx.sdk_release)
    page[#page + 1] = ""
    return page
end

local function protocol_page(fw, name, record, ctx)
    local led, surf, regs = ctx.led, ctx.surf, ctx.regs
    local page = {"# " .. name .. " (" .. fw .. ", protocol)", "",
                  "Status in the transcriber's facts: " .. record.status .. ". Introduced " .. record.introduced .. ". Bases: "
                  .. either(record.bases, DEFAULT_SUPERCLASS) .. ".", "",
                  "Reasons from the transcriber: " .. either(record.reasons, "none") .. ".", "",
                  "A protocol member has no stub: its implementation is the conforming class's, and a class row of the surface is"
                  .. " stubbed where the release lacks it. The declaration is the transcriber's rendering of the " .. ctx.sdk_release .. " AST.", "",
                  "| section | kind | declaration (" .. ctx.sdk_release .. " AST, transcriber rendering) | in " .. ctx.compile .. " body | 6.1.3 | demand | ours |",
                  "| --- | --- | --- | --- | --- | --- | --- |"}
    local sorted = sorted_stable(record.members, by_fields({"section", "kind", "selector"}))
    local entries = {}
    for _, member in ipairs(sorted) do
        local api = "-[" .. name .. " " .. member.selector .. "]"
        local srow = surf[surface.key(member.kind, api)] or {}
        local demand = NO_VALUE
        if present(srow["demand-rank"]) then
            demand = string.format("rank %s, %s apps", srow["demand-rank"], either(srow["demand-apps"], NO_VALUE))
        end
        local ours = regs[api] and "hand/registry" or NO_VALUE
        local doc_api = (member.instance and "-" or "+") .. "[" .. name .. " " .. member.selector .. "]"
        entries[#entries + 1] = {kind = member.kind, api = doc_api}
        page[#page + 1] = string.format("| %s | %s | %s | %s | %s | %s | %s |", member.section, member.kind,
                                        decl_cell(ctx.docs, member.kind, doc_api), member.in16,
                                        either(row_of(led, member.kind, api), ctx.unchecked), demand, ours)
    end
    page[#page + 1] = ""
    for _, line in ipairs(comments_section(ctx.docs, entries)) do
        page[#page + 1] = line
    end
    page[#page + 1] = ""
    page[#page + 1] = "## Behaviour summary"
    page[#page + 1] = ""
    page[#page + 1] = behaviour_note(ctx.sdk_release)
    return page
end

local function write_framework(ctx, fw, objc_state)
    local tree, corpus, sdk_release = ctx.tree, ctx.corpus, ctx.sdk_release
    local spec = snapshot.load(tree, fw)
    local parsed = headers.shard_facts(tree, fw)
    local members_by_class, class_names, constant_rows = {}, {}, {}
    for _, r in ipairs(spec) do
        if MEMBER_KINDS[r.kind] then
            if members_by_class[r.cls] == nil then
                members_by_class[r.cls] = {}
                table.insert(class_names, r.cls)
            end
            table.insert(members_by_class[r.cls], r)
        elseif r.kind == "constant" then
            table.insert(constant_rows, r)
        end
    end
    local classes = order.strings(class_names)
    local member_count = 0
    for _, cls in ipairs(classes) do
        member_count = member_count + #members_by_class[cls]
    end
    local skipped = trace_files.load_skip_reasons(tree, fw)
    local pins = {}
    for _, pin in ipairs(snapshot.pins(tree, fw)) do
        pins[pin.api] = pin
    end
    local doc, why = doc_text.rows(tree, fw, ctx.sdk)
    if doc == nil then
        print(string.format("doc %s: no doc rows (%s): its comments and declarations keep the marked text", fw, why))
    end
    local ctx_fw = {
        sdk_release = ctx.sdk_release, compile = ctx.compile,
        led = surface.ledger_status(corpus, fw, LEDGER_6_1_3),
        unchecked = surface.unlisted_state(tree, fw),
        led43 = surface.ledger_status(corpus, fw, LEDGER_4_3),
        surf = surface.by_key(surface.surface_rows(tree, corpus, sdk_release, fw)),
        regs = surface.registry_entries(tree, fw),
        pins = pins,
        oracle = surface.oracle_defaults(corpus, sdk_release, fw),
        stubs_skipped = skipped,
        meta_of = objc_state.meta,
        objc_index = objc_state.index,
        docs = doc and doc.api,
    }
    local protos = protocols.records(tree, fw)
    local proto_names = {}
    for name in pairs(protos) do
        table.insert(proto_names, name)
    end
    proto_names = order.strings(proto_names)
    local entries = {}
    for _, cls in ipairs(classes) do
        table.insert(entries, {kind = "class", name = cls})
    end
    for _, name in ipairs(proto_names) do
        table.insert(entries, {kind = "protocol", name = name})
    end
    local page_files = pages.names(entries, FIXED_PAGES)

    local out = path.join(ctx.out_root, fw)
    local index = {"# " .. fw .. ": worker page set", "",
                   "Regenerated by `" .. REGENERATE_COMMAND .. " " .. fw .. "` from the committed snapshot, the ledgers and the surface table. Do not edit: regenerate.", "",
                   string.format("- Spec: the " .. ctx.sdk_release .. " header of %s, as recorded in `spec/%s/` (%d method and property rows, %d constant rows).",
                                 fw, fw, member_count, #constant_rows),
                   "- Status at 6.1.3: " .. LEDGER_6_1_3 .. ". A member the ledger does not list is not checked in that release, or absent from it when the framework is (its state says which). Status at 4.3: " .. LEDGER_4_3 .. ".",
                   string.format("- Demand and impl-lead: " .. sdk_info.names(ctx.sdk_release).surface .. ". Overrides and pins: `registry/%s/` and `overrides/hashes/%s.tsv`.", fw, fw),
                   "- Behaviour summaries (what a method calls, its strings, constants and error domains) and implementation pseudocode: not part of these pages; the Behaviour summary section of a class page says what produces them.",
                   "- REFERENCE ONLY: nothing here is Apple binary, disassembly or pseudocode, and none of it is sent to an external service.", "",
                   string.format("## Classes (%d)", #classes), "",
                   "| class | superclass | members | overridden | stub | page |", "| --- | --- | --- | --- | --- | --- |"}
    for _, cls in ipairs(classes) do
        local members = members_by_class[cls]
        local overridden, stubbed = 0, 0
        for _, r in ipairs(members) do
            if ctx_fw.regs[r.api] then
                overridden = overridden + 1
            elseif not skipped[r.api] then
                stubbed = stubbed + 1
            end
        end
        local file = page_files[pages.key("class", cls)]
        index[#index + 1] = string.format("| %s | %s | %d | %d | %d | [%s](%s) |", cls, either(parsed.superclasses[cls], NO_VALUE),
                                          #members, overridden, stubbed, file, file)
    end
    if #proto_names > 0 then
        index[#index + 1] = ""
        index[#index + 1] = string.format("## Protocols (%d)", #proto_names)
        index[#index + 1] = ""
        index[#index + 1] = "| protocol | status | members | page |"
        index[#index + 1] = "| --- | --- | --- | --- |"
        for _, name in ipairs(proto_names) do
            local file = page_files[pages.key("protocol", name)]
            index[#index + 1] = string.format("| %s | %s | %d | [%s](%s) |", name, protos[name].status, #protos[name].members, file, file)
        end
    end
    index[#index + 1] = ""
    index[#index + 1] = string.format("Constants: [Constants.md](Constants.md) (%d rows).", #constant_rows)
    index[#index + 1] = ""
    emit.file(path.join(out, "index.md"), table.concat(index, "\n") .. "\n")

    for _, cls in ipairs(classes) do
        local page = class_page(parsed, fw, cls, members_by_class[cls], ctx_fw)
        emit.file(path.join(out, page_files[pages.key("class", cls)]), table.concat(page, "\n") .. "\n")
    end
    for _, name in ipairs(proto_names) do
        local page = protocol_page(fw, name, protos[name], ctx_fw)
        emit.file(path.join(out, page_files[pages.key("protocol", name)]), table.concat(page, "\n") .. "\n")
    end

    local constants = {"# " .. fw .. " constants", "", "| name | declaration | iOS " .. ctx.sdk_release .. " value | host value | 6.1.3 | 4.3 | ours |",
                       "| --- | --- | --- | --- | --- | --- | --- |"}
    for _, r in ipairs(sorted_stable(constant_rows, by_fields({"api"}))) do
        local s6 = either(row_of(ctx_fw.led, "constant", r.api), ctx_fw.unchecked)
        local s43 = either(row_of(ctx_fw.led43, "constant", r.api), surface.not_checked_state("4.3"))
        local value = r.value_status == "found" and r.value or r.value_status
        local owned = r.owned ~= NO_VALUE and r.owned or (r.value_status == "found" and "generated" or r.value_status)
        constants[#constants + 1] = string.format("| %s | `%s` | %s | %s | %s | %s | %s |", r.api, DECL_NOT_DERIVED, md_cell(value),
                                                  md_cell(r.host_value), s6, s43, md_cell(owned))
    end
    emit.file(path.join(out, "Constants.md"), table.concat(constants, "\n") .. "\n")

    local swift_rows = swift.read_bucket(tree)[fw] or {}
    if #swift_rows > 0 then
        local page = {string.format("# %s: Swift rows (%d)", fw, #swift_rows), "",
                      "Rows of the surface in Swift, which the ObjC headers do not describe. The table describes name, kind and availability;"
                      .. " it has no types, so no signature is shown. Overlay needs: see the list at the end.", "",
                      "| kind | Swift name | introduced | unavailable | table match | 6.1.3 ledger | demand | impl-lead |",
                      "| --- | --- | --- | --- | --- | --- | --- | --- |"}
        for _, row in ipairs(sorted_stable(swift_rows, by_fields({"kind", "api"}))) do
            page[#page + 1] = string.format("| %s | `%s` | %s | %s | %s | %s | %s | %s |", row.kind, md_cell(row.api), row.introduced,
                                            md_cell(row.unavailable), row.table_match, md_cell(row.ledger_6_1_3),
                                            md_cell(row.demand_rank), md_cell(row.impl_lead))
        end
        page[#page + 1] = ""
        page[#page + 1] = "## What a Swift overlay build needs that the project does not have"
        page[#page + 1] = ""
        for _, need in ipairs(swift_overlay_needs(ctx.sdk_release)) do
            page[#page + 1] = "- " .. need
        end
        emit.file(path.join(out, "Swift.md"), table.concat(page, "\n") .. "\n")
    end
    print(string.format("doc %s: %d class pages, constants page, index -> %s", fw, #classes, relative_to(tree, out)))
    return #classes
end

function run(args)
    assert(args.coordination, "doc needs --coordination: the corpus folder")
    assert(args.sdk, "doc needs --sdk: the iOS SDK directory")
    local tree = args.tree
    assert(files.read_text(swift.bucket_path(tree)) ~= nil,
           "doc needs the Swift bucket " .. swift.bucket_path(tree) .. ": run the swift command first")
    local targets = args.all and gen.frameworks(tree) or {args.framework}
    local out_root = args.out or behaviour.doc_root()
    local needs = {}
    for _, fw in ipairs(targets) do
        needs[fw] = needs_of(tree, fw)
    end
    local sdk_release = sdk_info.discover(args.sdk).version
    local compile = sdk_info.discover(project.sdk16(args)).version
    local objc_states = read_objc(args.coordination, sdk_release, needs)
    local ctx = {tree = tree, corpus = args.coordination, sdk = args.sdk, sdk_release = sdk_release, compile = compile, out_root = out_root}
    for _, fw in ipairs(targets) do
        write_framework(ctx, fw, objc_states[fw])
    end
    return 0
end
