local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local releases = import("releases", {anonymous = true})
local surface = import("surface", {anonymous = true})
local emit = import("emit", {anonymous = true})
local transcribe = import("transcribe", {anonymous = true})
local snapshot_pins = import("snapshot_pins", {anonymous = true})
local spec = import("spec", {anonymous = true})
local project = import("project", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})

local PROTOCOL_COLUMNS = {"protocol", "introduced", "status", "reasons", "bases", "section", "kind", "instance", "selector", "decl", "in16"}

local function without_comments(text)
    local out, pos = {}, 1
    while true do
        local line = string.find(text, "//", pos, true)
        local block = string.find(text, "/*", pos, true)
        local start = line
        if block and (start == nil or block < start) then
            start = block
        end
        if start == nil then
            break
        end
        if start == line then
            table.insert(out, string.sub(text, pos, start - 1))
            table.insert(out, " ")
            pos = string.find(text, "\n", start, true) or (#text + 1)
        else
            local close = string.find(text, "*/", start + 2, true)
            if close then
                table.insert(out, string.sub(text, pos, start - 1))
                table.insert(out, " ")
                pos = close + 2
            else
                table.insert(out, string.sub(text, pos, start + 1))
                pos = start + 2
            end
        end
    end
    table.insert(out, string.sub(text, pos))
    return table.concat(out)
end

local function defined_names(text)
    local found = {}
    local pos = 1
    while true do
        local at = string.find(text, "@protocol", pos, true)
        if at == nil then
            break
        end
        pos = at + 9
        local _, ws_end = string.find(text, "^%s+", pos)
        if ws_end then
            local name_start = ws_end + 1
            local _, name_end = string.find(text, "^[%w_]+", name_start)
            if name_end then
                local name = string.sub(text, name_start, name_end)
                local _, after = string.find(text, "^%s*", name_end + 1)
                local line_feed = string.find(string.sub(text, name_end + 1, after), "\n", 1, true) ~= nil
                local listed = false
                local open = after + 1
                if string.sub(text, open, open) == "<" then
                    local stop = string.find(text, "[;>]", open + 1)
                    if stop and string.sub(text, stop, stop) == ">" then
                        local _, tail = string.find(text, "^%s*", stop + 1)
                        listed = string.find(string.sub(text, stop + 1, tail), "\n", 1, true) ~= nil
                    end
                end
                if line_feed or listed then
                    found[name] = true
                end
                pos = name_end + 1
            end
        end
    end
    return found
end

local function header_text(sdk, fw)
    local parts = {}
    local record = sdk_modules.module_of(sdk, fw)
    assert(record ~= nil, "protocols: the SDK holds no module " .. fw)
    if record.kind == "usr" then
        for _, file in ipairs(sdk_modules.headers_of(sdk, fw) or {}) do
            table.insert(parts, files.read_text(file) or "")
        end
    else
        for _, file in ipairs(files.glob(path.join(record.root, "Headers", "*.h"))) do
            table.insert(parts, files.read_text(file) or "")
        end
    end
    return table.concat(parts, "\n")
end

local function protocol_owners(tree, fw, corpus, sdk, sdk_release)
    local classes = {}
    if os.isfile(layout.shard_path(tree, fw)) then
        for _, row in ipairs(spec.load(tree, fw)) do
            classes[row.cls] = true
        end
    end
    local introduced = {}
    for _, row in ipairs(surface.surface_rows(tree, corpus, sdk_release, fw)) do
        if (row.kind == "method" or row.kind == "property") and row.lang == "objc" then
            local owner = string.match(row.api, "^[-+]%[(%w+)") or string.match(row.api, "^(%w+)%.")
            if owner and not classes[owner] then
                if introduced[owner] == nil or releases.before(row.introduced, introduced[owner]) then
                    introduced[owner] = row.introduced
                end
            end
        end
    end
    local out = {}
    local any = false
    for _ in pairs(introduced) do
        any = true
        break
    end
    if not any then
        return out
    end
    local defined = defined_names(without_comments(header_text(sdk, fw)))
    for name, intro in pairs(introduced) do
        if defined[name] then
            out[name] = intro
        end
    end
    return out
end

local function protocol_wanted(tree, fw, corpus, sdk, sdk_release)
    local wanted = {}
    for _, row in ipairs(surface.surface_rows(tree, corpus, sdk_release, fw)) do
        if row.kind == "protocol" and row.lang == "objc" then
            wanted[row.api] = row.introduced
        end
    end
    for name, intro in pairs(protocol_owners(tree, fw, corpus, sdk, sdk_release)) do
        if wanted[name] == nil then
            wanted[name] = intro
        end
    end
    local list = {}
    for name, intro in pairs(wanted) do
        table.insert(list, {name = name, introduced = intro})
    end
    table.sort(list, function(a, b)
        return order.less(a.name, b.name)
    end)
    return list
end

local function protocols_tsv(records)
    local lines = {table.concat(PROTOCOL_COLUMNS, "\t")}
    local sorted = table.move(records, 1, #records, 1, {})
    table.sort(sorted, function(a, b)
        return order.less(a.name, b.name)
    end)
    for _, record in ipairs(sorted) do
        local bases = table.concat(record.bases or {}, ",")
        local reasons = table.concat(record.reasons or {}, "; ")
        table.insert(lines, table.concat({record.name, record.introduced, record.status, reasons, bases, "-", "-", "-", "-", "-", "-"}, "\t"))
        local in16 = nil
        if record.members16 then
            in16 = {}
            for _, name in ipairs(record.members16) do
                in16[name] = true
            end
        end
        for _, member in ipairs(record.members or {}) do
            local flag = "-"
            if in16 then
                flag = in16[member.selector] and "yes" or "no"
            end
            table.insert(lines, table.concat({record.name, record.introduced, record.status, "", bases, member.section, member.kind,
                                              member.instance and "yes" or "no", member.selector,
                                              (string.gsub(member.decl, "\t", " ")), flag}, "\t"))
        end
    end
    return table.concat(lines, "\n") .. "\n"
end

local function one(args, fw, sdk, sdk16, sdk_release)
    local snap = layout.snap_dir(args.tree, fw)
    local wanted = protocol_wanted(args.tree, fw, args.corpus, sdk, sdk_release)
    for _, stale in ipairs(files.glob(path.join(snap, "Revenant*Protocols.h"))) do
        os.rm(stale)
    end
    if #wanted == 0 then
        if os.isfile(path.join(snap, "protocols.tsv")) then
            os.rm(path.join(snap, "protocols.tsv"))
        end
        snapshot_pins.pin_record(args.tree, fw, "protocols.tsv")
        return true
    end
    local items = {}
    for _, item in ipairs(wanted) do
        table.insert(items, {name = item.name, framework = fw, introduced = item.introduced})
    end
    local result, failure = nil, nil
    try {
        function()
            result = transcribe.run({tree = args.tree, sdk26 = sdk, sdk16 = sdk16, wanted = items, clang = project.clang(args)})
        end,
        catch {
            function(e)
                failure = e
            end
        }
    }
    if failure then
        print(string.format("protocols %s: the transcriber stopped: %s", fw, tostring(failure)))
        return false
    end
    emit.file(path.join(snap, "protocols.tsv"), protocols_tsv(result.records))
    snapshot_pins.pin_record(args.tree, fw, "protocols.tsv")
    local counts = {}
    for _, record in ipairs(result.records) do
        counts[record.status] = (counts[record.status] or 0) + 1
    end
    local statuses = {}
    for status in pairs(counts) do
        table.insert(statuses, status)
    end
    table.sort(statuses, order.less)
    local parts = {}
    for _, status in ipairs(statuses) do
        table.insert(parts, string.format("%s %d", status, counts[status]))
    end
    print(string.format("protocols %s: %s", fw, table.concat(parts, ", ")))
    return true
end

function run(args)
    assert(args.corpus, "protocols needs --corpus: the corpus folder (the surface table)")
    assert(args.sdk, "protocols needs --sdk: the iPhoneOS SDK the declarations are read from")
    local sdk = args.sdk
    local sdk16 = project.sdk16(args)
    local sdk_release = sdk_info.discover(sdk).version
    local targets = args.all and surface.surface_frameworks(args.tree, args.corpus, sdk_release) or {args.framework}
    local failed = 0
    for _, fw in ipairs(targets) do
        if not one(args, fw, sdk, sdk16, sdk_release) then
            failed = failed + 1
        end
    end
    return failed > 0 and 1 or 0
end
