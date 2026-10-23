local generate = import("generate", {rootdir = os.scriptdir(), anonymous = true})
local implemented = import("implemented", {rootdir = os.scriptdir(), anonymous = true})
local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})
local ast = import("ast", {rootdir = os.scriptdir(), anonymous = true})
local scanner = import("demand_scan", {rootdir = os.scriptdir(), anonymous = true})
local products = import("demand_products", {rootdir = os.scriptdir(), anonymous = true})
local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})

local TARGET = "6.1.3"
local ARCHITECTURE = "armv7"
local RANK = {exact = 1, syntax = 2, text = 3}
local SWIFT_TYPE_KINDS = {Class = true, Struct = true, Enum = true, Protocol = true}
local USAGE = "usage: ./xmakew l -P . frameworks/Backports/tools/demand.lua --report DIR [--source DIR]..."
    .. " [--files LIST]... [--product PATH]... [--runtime PATH]... [--component PATH]... [--objects DIR] [--ios 6.1.3]"

local function parse(args)
    local opt = {sources = {}, products = {}, lists = {}, runtime = {}, components = {}, ios = TARGET}
    local at = 1
    while at <= #args do
        local flag, value = args[at], args[at + 1]
        if value == nil then
            raise("demand: %s has no value\n%s", flag, USAGE)
        end
        if flag == "--source" then
            table.insert(opt.sources, value)
        elseif flag == "--files" then
            table.insert(opt.lists, value)
        elseif flag == "--product" then
            table.insert(opt.products, value)
        elseif flag == "--runtime" then
            table.insert(opt.runtime, value)
        elseif flag == "--component" then
            table.insert(opt.components, value)
        elseif flag == "--report" then
            opt.report = value
        elseif flag == "--objects" then
            opt.objects = value
        elseif flag == "--ios" then
            opt.ios = value
        else
            raise("demand: unknown flag %s\n%s", flag, USAGE)
        end
        at = at + 2
    end
    if not opt.report or (#opt.sources == 0 and #opt.lists == 0 and #opt.products == 0) then
        raise(USAGE)
    end
    opt.objects = opt.objects or path.join(sdkfiles.root(), "build", ".objs")
    return opt
end

local function super_of(signature)
    return (signature or ""):match("^%s*([%w_]+)")
end

local function setter_of(name)
    return "set" .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) .. ":"
end

local function swift_module_of(symbol)
    local length, rest = (symbol or ""):match("^%$s(%d+)(.*)$")
    return length and rest:sub(1, tonumber(length)) or nil
end

local function outranks(entry, known)
    for index = 1, 3 do
        if entry.rank[index] ~= known.rank[index] then
            return entry.rank[index] > known.rank[index]
        end
    end
    return false
end

local function keep(map, key, entry)
    local known = map[key]
    if known == nil or outranks(entry, known) then
        map[key] = entry
    end
end

local function rank_of(row, intro, owned)
    return {owned and 1 or 0, row.intro ~= nil and 1 or 0, -(intro or math.huge)}
end

local function universe(state)
    local u = {classes = {}, protocols = {}, symbols = {}, members = {}, selectors = {}, swift_types = {},
        frameworks = {}}
    table.sort(state.frameworks, function (a, b)
        return scanner.bytes_less(a.name, b.name)
    end)
    for _, framework in ipairs(state.frameworks) do
        local introduced = sdkfiles.framework_introduced(framework.rows)
        u.frameworks[framework.name] = true
        for _, row in ipairs(framework.rows) do
            local intro = row.intro or introduced
            local rank = rank_of(row, intro, row.kind == "Swift declaration" and swift_module_of(row.symbol) == framework.name)
            if row.kind == "class" then
                keep(u.classes, row.name, {framework = framework.name, intro = intro, super = super_of(row.signature),
                    rank = rank})
            elseif row.kind == "protocol" then
                keep(u.protocols, row.name, {framework = framework.name, intro = intro, rank = rank})
            elseif row.kind == "C function" or row.kind == "global variable" or row.kind == "enum constant" then
                keep(u.symbols, row.name, {kind = row.kind, framework = framework.name, intro = intro, rank = rank})
            elseif row.kind == "instance method" or row.kind == "class method" then
                local tag = row.kind == "class method" and "class" or "instance"
                keep(u.members, row.container .. "|" .. tag .. "|" .. row.name, {container = row.container,
                    kind = row.kind, selector = row.name, framework = framework.name, intro = intro, rank = rank})
            elseif row.kind == "property" then
                keep(u.members, row.container .. "|instance|" .. row.name, {container = row.container,
                    kind = "instance method", selector = row.name, framework = framework.name, intro = intro, rank = rank})
                if string.find(row.signature, "^readonly ") == nil then
                    local setter = setter_of(row.name)
                    keep(u.members, row.container .. "|instance|" .. setter, {container = row.container,
                        kind = "instance method", selector = setter, framework = framework.name, intro = intro, rank = rank})
                end
            elseif row.kind == "Swift declaration" and SWIFT_TYPE_KINDS[row.signature] and row.container == ""
                and swift_module_of(row.symbol) == framework.name then
                keep(u.swift_types, row.name, {framework = framework.name, intro = intro, rank = rank})
            end
        end
    end
    local keys = {}
    for key in pairs(u.members) do
        table.insert(keys, key)
    end
    table.sort(keys, scanner.bytes_less)
    for _, key in ipairs(keys) do
        local entry = u.members[key]
        u.selectors[entry.selector] = u.selectors[entry.selector] or {}
        table.insert(u.selectors[entry.selector], entry)
    end
    return u
end

local function find_member(u, container, tag, selector)
    local name, hops = container, 0
    while name and hops < 64 do
        local entry = u.members[name .. "|" .. tag .. "|" .. selector]
        if entry then
            return entry
        end
        local class = u.classes[name]
        name = class and class.super or nil
        hops = hops + 1
    end
    return nil
end

local function backed_index(keys, classes, protocols)
    local set, selectors, folders = {}, {}, {}
    for folder, list in pairs(keys) do
        folders[folder] = true
        for key in pairs(list) do
            local kind, container, name = key:match("^(.-)|(.-)|(.*)$")
            if container:startswith("Revenant") and classes[container:sub(9)] then
                container = container:sub(9)
                key = kind .. "|" .. container .. "|" .. name
            end
            set[key] = true
            if kind == "instance method" or kind == "class method" then
                selectors[name] = true
            end
        end
    end
    return {keys = set, selectors = selectors, folders = folders, protocols = protocols}
end

local function cache_of(ios)
    local source = dyld.held_source(path.join(dyld.root(), ios), ARCHITECTURE)
    if not source then
        raise("demand: no %s dyld cache under %s; the iOS %s system is needed to classify", ARCHITECTURE,
            path.join(dyld.root(), ios), ios)
    end
    return dyld.load(source), source
end

local function presence(ctx)
    local cache, target, u = ctx.cache, ctx.target, ctx.u
    local function exported(symbol)
        return cache.exports[symbol] ~= nil
    end
    local function annotated(intro)
        return intro == nil or intro <= target
    end
    local function class_present(name)
        return exported("_OBJC_CLASS_$_" .. name)
    end
    local function member_present(entry)
        if not annotated(entry.intro) then
            return false
        end
        if u.classes[entry.container] then
            return class_present(entry.container)
        end
        return true
    end
    ctx.exported = exported
    ctx.annotated = annotated
    ctx.class_present = class_present
    ctx.member_present = member_present
end

local function status_of(item)
    if item.present then
        return "present", "iOS 6.1.3"
    elseif item.backed then
        return "backported", "Backports"
    elseif item.component then
        return "backported", "component"
    elseif item.runtime then
        return "runtime", "runtime"
    elseif item.app then
        return "app", "application"
    end
    return "missing", ""
end

local function new_item(fields)
    fields.status, fields.via = status_of(fields)
    fields.files = {}
    fields.file_count = 0
    fields.count = 0
    return fields
end

local function add(ledger, key, item, file, level)
    local known = ledger.items[key]
    if not known then
        known = item
        known.key = key
        known.level = level
        ledger.items[key] = known
        table.insert(ledger.order, key)
    elseif RANK[level] < RANK[known.level] then
        known.level = level
    end
    known.count = known.count + 1
    ledger.refs = ledger.refs + 1
    if not known.files[file] then
        known.files[file] = true
        known.file_count = known.file_count + 1
        if known.status == "missing" then
            table.insert(ledger.missing_pairs, {file = file, key = key})
        end
    end
    return known
end

local function class_item(ctx, ledger, name, level, file)
    local class = ctx.u.classes[name]
    if not class then
        return nil
    end
    local key = "class||" .. name
    local known = ledger.items[key]
    if known then
        return add(ledger, key, known, file, level)
    end
    local present = ctx.class_present(name)
    if present and class.intro and class.intro > ctx.target then
        ledger.contradictions = ledger.contradictions + 1
    end
    local item = new_item({kind = "class", container = "", name = name, framework = class.framework, intro = class.intro,
        present = present, backed = ctx.backed.keys[key] == true, component = ctx.component.classes[name] == true,
        runtime = ctx.runtime.classes[name] == true})
    return add(ledger, key, item, file, level)
end

local function symbol_item(ctx, ledger, name, level, file)
    local symbol = ctx.u.symbols[name]
    if not symbol then
        return nil
    end
    local key = symbol.kind .. "||" .. name
    local known = ledger.items[key]
    if known then
        return add(ledger, key, known, file, level)
    end
    local present
    if symbol.kind == "enum constant" then
        present = ctx.annotated(symbol.intro)
    else
        present = ctx.exported("_" .. name)
    end
    local item = new_item({kind = symbol.kind, container = "", name = name, framework = symbol.framework,
        intro = symbol.intro, present = present, backed = ctx.backed.keys[key] == true,
        component = ctx.component.symbols[name] == true, runtime = ctx.runtime.symbols[name] == true})
    return add(ledger, key, item, file, level)
end

local function protocol_item(ctx, ledger, name, level, file)
    local protocol = ctx.u.protocols[name]
    if not protocol then
        return nil
    end
    local key = "protocol||" .. name
    local known = ledger.items[key]
    if known then
        return add(ledger, key, known, file, level)
    end
    local item = new_item({kind = "protocol", container = "", name = name, framework = protocol.framework,
        intro = protocol.intro, present = ctx.annotated(protocol.intro), backed = ctx.backed.protocols[name] == true,
        component = ctx.component.protocols[name] == true, runtime = ctx.runtime.protocols[name] == true})
    return add(ledger, key, item, file, level)
end

local function swift_type_item(ctx, ledger, name, level, file)
    local swift = ctx.u.swift_types[name]
    if not swift then
        return nil
    end
    local key = "swift type||" .. name
    local known = ledger.items[key]
    if known then
        return add(ledger, key, known, file, level)
    end
    local bridge = "NS" .. name
    local bridged = ctx.u.classes[bridge] ~= nil and ctx.class_present(bridge)
    local provided = swift.framework .. "." .. name
    local item = new_item({kind = "swift type", container = "", name = name, framework = swift.framework,
        intro = swift.intro, present = ctx.annotated(swift.intro), backed = false, bridge = bridged and bridge or "",
        component = ctx.component.swift_types[provided] == true, runtime = ctx.runtime.swift_types[provided] == true})
    return add(ledger, key, item, file, level)
end

local function member_item(ctx, ledger, container, class_method, selector, level, file)
    local entry = find_member(ctx.u, container, class_method and "class" or "instance", selector)
    if not entry then
        return nil
    end
    local key = entry.kind .. "|" .. entry.container .. "|" .. selector
    local known = ledger.items[key]
    if known then
        return add(ledger, key, known, file, level)
    end
    if entry.intro == nil then
        ledger.unannotated = ledger.unannotated + 1
    end
    local item = new_item({kind = entry.kind, container = entry.container, name = selector, framework = entry.framework,
        intro = entry.intro, present = ctx.member_present(entry), backed = ctx.backed.keys[key] == true,
        component = ctx.component.classes[entry.container] == true, runtime = ctx.runtime.classes[entry.container] == true})
    return add(ledger, key, item, file, level)
end

local function selector_item(ctx, ledger, selector, level, file)
    local entries = ctx.u.selectors[selector]
    if not entries then
        if not ledger.unmatched[selector] then
            ledger.unmatched[selector] = true
            ledger.unmatched_count = ledger.unmatched_count + 1
        end
        return nil
    end
    local key = "selector||" .. selector
    local known = ledger.items[key]
    if known then
        return add(ledger, key, known, file, level)
    end
    local present, lowest, framework = false, nil, entries[1].framework
    for _, entry in ipairs(entries) do
        if ctx.member_present(entry) then
            present = true
        end
        if entry.intro and (lowest == nil or entry.intro < lowest) then
            lowest, framework = entry.intro, entry.framework
        end
    end
    local item = new_item({kind = "selector", container = "", name = selector, framework = framework, intro = lowest,
        present = present, backed = ctx.backed.selectors[selector] == true, app = ctx.app_selectors[selector] == true})
    return add(ledger, key, item, file, level)
end

local function framework_item(ctx, ledger, name, level, file)
    local key = "framework||" .. name
    local known = ledger.items[key]
    if known then
        return add(ledger, key, known, file, level)
    end
    local present = ctx.cache.libraries["/System/Library/Frameworks/" .. name .. ".framework/" .. name] ~= nil
    local item = new_item({kind = "framework", container = "", name = name, framework = name, present = present,
        backed = ctx.backed.folders[name] == true, component = ctx.component.modules[name] == true,
        runtime = ctx.runtime.modules[name] == true})
    return add(ledger, key, item, file, level)
end

local function settle_frameworks(ledger)
    local members = {}
    for _, key in ipairs(ledger.order) do
        local item = ledger.items[key]
        if item.kind ~= "framework" and item.framework then
            members[item.framework] = members[item.framework] or {}
            table.insert(members[item.framework], item)
        end
    end
    for _, key in ipairs(ledger.order) do
        local item = ledger.items[key]
        local list = item.kind == "framework" and item.status == "missing" and members[item.name]
        if list and #list > 0 then
            local complete, all_present, provided = true, true, 0
            for _, member in ipairs(list) do
                if member.status == "missing" then
                    complete = false
                end
                if member.status ~= "present" then
                    all_present = false
                end
                if member.status == "backported" then
                    provided = provided + 1
                end
            end
            if complete and all_present then
                item.present = true
            elseif complete and provided > 0 then
                item.backed = true
            end
            item.status, item.via = status_of(item)
        end
    end
end

local function compact_of(u, record, global_types)
    local hits, call_hits, member_hits, own = {}, {}, {}, {}
    for _, name in ipairs(record.declared_members) do
        own[name] = true
    end
    for _, word in ipairs(record.words) do
        if u.classes[word] or u.protocols[word] or u.swift_types[word] or u.symbols[word] then
            table.insert(hits, word)
        end
    end
    for _, word in ipairs(record.calls) do
        local symbol = u.symbols[word]
        if symbol and symbol.kind == "C function" then
            table.insert(call_hits, word)
        end
    end
    for _, word in ipairs(record.members) do
        if u.selectors[word] and not own[word] then
            table.insert(member_hits, word)
        end
    end
    local methods = {}
    for _, name in ipairs(record.method_declarations) do
        methods[name] = true
    end
    local messages = {}
    for _, message in ipairs(record.messages) do
        if not (message.own and methods[message.selector]) then
            if message.class == nil and message.receiver and not message.own then
                local typed = record.var_types[message.receiver] or global_types[message.receiver] or nil
                if typed then
                    message = {selector = message.selector, class = typed, class_method = false, own = false}
                end
            end
            table.insert(messages, message)
        end
    end
    return {file = record.file, imports = record.imports, messages = messages, selectors = record.selectors,
        hits = hits, call_hits = call_hits, member_hits = member_hits}
end

local function use_record(ctx, ledger, record)
    local file, u = record.file, ctx.u
    for _, name in ipairs(record.imports) do
        if u.frameworks[name] then
            framework_item(ctx, ledger, name, "exact", file)
        end
    end
    for _, message in ipairs(record.messages) do
        if message.class == nil then
            selector_item(ctx, ledger, message.selector, "syntax", file)
        elseif u.classes[message.class] and not ctx.declared[message.class] then
            class_item(ctx, ledger, message.class, "syntax", file)
            member_item(ctx, ledger, message.class, message.class_method, message.selector, "syntax", file)
        end
    end
    for _, selector in ipairs(record.selectors) do
        selector_item(ctx, ledger, selector, "syntax", file)
    end
    local imported = {}
    for _, name in ipairs(record.imports) do
        imported[name] = true
    end
    for _, word in ipairs(record.hits) do
        if not ctx.declared[word] then
            local class = u.classes[word]
            local swift = u.swift_types[word]
            local swift_here = swift and imported[swift.framework] and class and not imported[class.framework]
            if class and not swift_here then
                class_item(ctx, ledger, word, "text", file)
            end
            if u.protocols[word] then
                protocol_item(ctx, ledger, word, "text", file)
            end
            if swift and (not class or swift_here) then
                swift_type_item(ctx, ledger, word, "text", file)
            end
            local symbol = u.symbols[word]
            if symbol and symbol.kind ~= "C function" then
                symbol_item(ctx, ledger, word, "text", file)
            end
        end
    end
    for _, word in ipairs(record.call_hits) do
        if not ctx.declared[word] then
            symbol_item(ctx, ledger, word, "text", file)
        end
    end
    for _, word in ipairs(record.member_hits) do
        if not ctx.declared[word] then
            local candidate = ledger.candidates[word]
            if not candidate then
                candidate = {name = word, files = {}, file_count = 0, count = 0}
                ledger.candidates[word] = candidate
                table.insert(ledger.candidate_order, candidate)
            end
            candidate.count = candidate.count + 1
            if not candidate.files[file] then
                candidate.files[file] = true
                candidate.file_count = candidate.file_count + 1
            end
        end
    end
end

local function use_product(ctx, ledger, product)
    local file, u = product.file, ctx.u
    for _, name in ipairs(product.undefined) do
        local found
        if name:startswith("_OBJC_CLASS_$_") then
            found = class_item(ctx, ledger, name:sub(#"_OBJC_CLASS_$_" + 1), "exact", file)
        elseif name:startswith("_") and not name:startswith("_OBJC_") and not name:startswith("_$s") then
            found = symbol_item(ctx, ledger, name:sub(2), "exact", file)
        end
        if not found and not name:startswith("_OBJC_METACLASS_") then
            ledger.outside = ledger.outside + 1
        end
    end
    for _, selector in ipairs(product.selectors) do
        if u.selectors[selector] then
            selector_item(ctx, ledger, selector, "text", file)
        end
    end
end

local function framework_totals(ctx, ledger)
    local totals = {}
    for _, key in ipairs(ledger.order) do
        local item = ledger.items[key]
        local name = item.framework or "(none)"
        totals[name] = totals[name] or {referenced = 0, present = 0, backported = 0, runtime = 0, missing = 0, app = 0,
            exact = 0, syntax = 0, text = 0}
        local row = totals[name]
        row.referenced = row.referenced + 1
        row[item.status] = row[item.status] + 1
        row[item.level] = row[item.level] + 1
    end
    return totals
end

local function ranked(ledger, status)
    local out = {}
    for _, key in ipairs(ledger.order) do
        local item = ledger.items[key]
        if item.status == status then
            table.insert(out, item)
        end
    end
    table.sort(out, function (a, b)
        if a.file_count ~= b.file_count then
            return a.file_count > b.file_count
        end
        return scanner.bytes_less(a.key, b.key)
    end)
    return out
end

local function row_of(item)
    return string.format("%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\t%s", item.key, item.framework or "",
        item.intro and tostring(item.intro) or "", item.status, item.level, item.kind, item.file_count, item.count,
        item.bridge or "", item.via)
end

local function write_report(opt, ctx, ledger, meta)
    os.mkdir(opt.report)
    local totals = framework_totals(ctx, ledger)
    local frameworks = {}
    for name in pairs(totals) do
        table.insert(frameworks, name)
    end
    table.sort(frameworks, scanner.bytes_less)
    local table_rows = {"framework\treferenced\tpresent\tbackported\truntime\tmissing\texact\tsyntax\ttext"}
    for _, name in ipairs(frameworks) do
        local row = totals[name]
        table.insert(table_rows, string.format("%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d", name, row.referenced, row.present,
            row.backported, row.runtime, row.missing, row.exact, row.syntax, row.text))
    end
    io.writefile(path.join(opt.report, "frameworks.tsv"), table.concat(table_rows, "\n") .. "\n")

    local header = "key\tframework\tintro\tstatus\tlevel\tkind\tfiles\trefs\tbridge\tvia"
    local items = {header}
    for _, key in ipairs(ledger.order) do
        table.insert(items, row_of(ledger.items[key]))
    end
    io.writefile(path.join(opt.report, "items.tsv"), table.concat(items, "\n") .. "\n")

    local missing = ranked(ledger, "missing")
    local missing_rows = {header}
    for _, item in ipairs(missing) do
        table.insert(missing_rows, row_of(item))
    end
    io.writefile(path.join(opt.report, "missing.tsv"), table.concat(missing_rows, "\n") .. "\n")

    local pair_rows = {}
    for _, pair in ipairs(ledger.missing_pairs) do
        table.insert(pair_rows, pair.file .. "\t" .. pair.key)
    end
    table.sort(pair_rows, scanner.bytes_less)
    io.writefile(path.join(opt.report, "missing_files.tsv"), table.concat(pair_rows, "\n") .. "\n")

    local item_file_rows = {}
    for _, key in ipairs(ledger.order) do
        for file in pairs(ledger.items[key].files) do
            table.insert(item_file_rows, key .. "\t" .. file)
        end
    end
    table.sort(item_file_rows, scanner.bytes_less)
    io.writefile(path.join(opt.report, "item_files.tsv"), table.concat(item_file_rows, "\n") .. "\n")

    local candidates = {}
    for _, candidate in ipairs(ledger.candidate_order) do
        local present = false
        for _, entry in ipairs(ctx.u.selectors[candidate.name] or {}) do
            if ctx.member_present(entry) then
                present = true
            end
        end
        local status = present and "present" or (ctx.backed.selectors[candidate.name] and "backported" or "missing")
        table.insert(candidates, {name = candidate.name, file_count = candidate.file_count, count = candidate.count,
            status = status})
    end
    table.sort(candidates, function (a, b)
        if a.file_count ~= b.file_count then
            return a.file_count > b.file_count
        end
        return scanner.bytes_less(a.name, b.name)
    end)
    local candidate_rows = {"name\tfiles\trefs\tstatus"}
    for _, candidate in ipairs(candidates) do
        table.insert(candidate_rows, string.format("%s\t%d\t%d\t%s", candidate.name, candidate.file_count, candidate.count,
            candidate.status))
    end
    io.writefile(path.join(opt.report, "candidates.tsv"), table.concat(candidate_rows, "\n") .. "\n")

    local lines = {}
    local function say(text)
        table.insert(lines, text)
    end
    local by_level, by_status = meta.by_level, meta.by_status
    say(string.format("iOS %s system: %s", opt.ios, ctx.source))
    say(string.format("SDK: %s (version %s)", ctx.sdk, ctx.sdk_version))
    say(string.format("backported objects: %s (%d folders)", opt.objects, meta.folders))
    say(string.format("sources scanned: %d files; products read: %d", meta.files, meta.products))
    say("")
    say(string.format("referenced items: %d (exact %d, syntax %d, text %d)", #ledger.order, by_level.exact or 0,
        by_level.syntax or 0, by_level.text or 0))
    say(string.format("present on iOS %s: %d", opt.ios, by_status.present or 0))
    say(string.format("backported and not present on iOS %s: %d (Backports objects %d, revenant components %d)", opt.ios,
        by_status.backported or 0, meta.by_via.Backports or 0, meta.by_via.component or 0))
    say(string.format("provided by the revenant Swift runtime and not on iOS %s: %d", opt.ios, by_status.runtime or 0))
    say(string.format("missing: %d", by_status.missing or 0))
    say(string.format("resolved by the application's own declarations, not counted as missing: %d", by_status.app or 0))
    local by_kind = {}
    for _, item in ipairs(missing) do
        by_kind[item.kind] = (by_kind[item.kind] or 0) + 1
    end
    local kinds = {}
    for kind in pairs(by_kind) do
        table.insert(kinds, kind)
    end
    table.sort(kinds, scanner.bytes_less)
    for _, kind in ipairs(kinds) do
        say(string.format("  missing %-18s %d", kind, by_kind[kind]))
    end
    local bridged = 0
    for _, item in ipairs(missing) do
        if item.bridge ~= nil and item.bridge ~= "" then
            bridged = bridged + 1
        end
    end
    say(string.format("  of the missing Swift types, %d have a present NS bridge class (the bridge column)", bridged))
    say(string.format("selectors not in the SDK (app or private): %d", meta.unmatched))
    say(string.format("product symbols outside the SDK: %d", ledger.outside))
    say(string.format("members with no availability annotation (counted present): %d", ledger.unannotated))
    say(string.format("classes annotated after iOS %s that the cache exports: %d", opt.ios, ledger.contradictions))
    say(string.format("member-name candidates (text only, not counted): %d", #candidates))
    say("")
    say("framework referenced present backported runtime missing exact syntax text")
    for _, name in ipairs(frameworks) do
        local row = totals[name]
        say(string.format("  %-28s %5d %5d %5d %5d %5d %5d %5d %5d", name, row.referenced, row.present, row.backported,
            row.runtime, row.missing, row.exact, row.syntax, row.text))
    end
    say("")
    say("top 50 missing, by files that use them")
    for index = 1, math.min(50, #missing) do
        local item = missing[index]
        say(string.format("  %3d %-16s %-48s files %d (%s)", index, item.kind, item.key, item.file_count, item.level))
    end
    io.writefile(path.join(opt.report, "summary.txt"), table.concat(lines, "\n") .. "\n")
    for _, line in ipairs(lines) do
        print(line)
    end
end

local function source_files(roots, lists)
    local files = {}
    for _, root in ipairs(roots) do
        for _, file in ipairs(os.files(path.join(root, "**"))) do
            if scanner.language_of(file) and not file:find("/%.git/") then
                table.insert(files, file)
            end
        end
    end
    for _, list in ipairs(lists) do
        for line in io.lines(list) do
            if line ~= "" and scanner.language_of(line) then
                table.insert(files, line)
            end
        end
    end
    table.sort(files, scanner.bytes_less)
    return files
end

function main(...)
    local opt = parse({...})
    local started = os.mclock()
    local function phase(label)
        print(string.format("phase %s %.1f s", label, (os.mclock() - started) / 1000))
        started = os.mclock()
    end

    local state = generate.prepare()
    local u = universe(state)
    phase("sdk facts")
    local cache, source = cache_of(opt.ios)
    phase("cache " .. source)
    local keys = implemented.from_objects(opt.objects)
    local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
    local status = lowered.protocol_status(path.join(os.scriptdir(), "..", "src"), sdkfiles.sdk_folder())
    local uncalled = {}
    for name in pairs(status.uncalled) do
        table.insert(uncalled, name)
    end
    table.sort(uncalled)
    io.writefile(path.join(opt.report, "protocols-uncalled.txt"), table.concat(uncalled, "\n") .. "\n")
    local backed = backed_index(keys, u.classes, status.backed)
    local folders = 0
    for _ in pairs(backed.folders) do
        folders = folders + 1
    end
    phase("backported objects")

    local files = source_files(opt.sources, opt.lists)
    local records, declared, app_selectors = {}, {}, {}
    for _, file in ipairs(files) do
        local record = scanner.scan(file)
        for _, name in ipairs(record.declared) do
            declared[name] = true
        end
        for _, name in ipairs(record.method_declarations) do
            app_selectors[name] = true
        end
        for _, name in ipairs(record.declared_members) do
            app_selectors[name] = true
        end
        table.insert(records, record)
    end
    local global_types = {}
    for _, record in ipairs(records) do
        for _, name in ipairs(record.var_names) do
            local type = record.var_types[name]
            if global_types[name] == nil then
                global_types[name] = type
            elseif global_types[name] ~= type then
                global_types[name] = false
            end
        end
    end
    local compact = {}
    for _, record in ipairs(records) do
        table.insert(compact, compact_of(u, record, global_types))
    end
    phase("scan " .. #files .. " files")

    local product_files = {}
    for _, root in ipairs(opt.products) do
        for _, file in ipairs(products.files_under(root)) do
            table.insert(product_files, file)
        end
    end

    local ctx = {u = u, cache = cache, target = ast.version_of(opt.ios), backed = backed,
        declared = declared, app_selectors = app_selectors, source = source, sdk = state.sdk, sdk_version = state.version,
        runtime = products.provider(opt.runtime), component = products.provider(opt.components)}
    presence(ctx)
    local ledger = {items = {}, order = {}, missing_pairs = {}, candidates = {}, candidate_order = {}, unmatched = {},
        unmatched_count = 0, outside = 0, contradictions = 0, unannotated = 0, refs = 0}
    for _, record in ipairs(compact) do
        use_record(ctx, ledger, record)
    end
    for _, file in ipairs(product_files) do
        use_product(ctx, ledger, products.read(file))
    end
    settle_frameworks(ledger)
    phase("classify")

    local by_level, by_status, by_via = {}, {}, {}
    for _, key in ipairs(ledger.order) do
        local item = ledger.items[key]
        by_level[item.level] = (by_level[item.level] or 0) + 1
        by_status[item.status] = (by_status[item.status] or 0) + 1
        if item.via ~= "" then
            by_via[item.via] = (by_via[item.via] or 0) + 1
        end
    end
    write_report(opt, ctx, ledger, {folders = folders, files = #files, products = #product_files, by_level = by_level,
        by_status = by_status, by_via = by_via, unmatched = ledger.unmatched_count})
    phase("report " .. opt.report)
end
