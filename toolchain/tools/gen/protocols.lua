local layout = import("layout", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local releases = import("releases", {anonymous = true})
local surface = import("surface", {anonymous = true})
local order = import("order", {anonymous = true})

local TRANSCRIBED = "transcribed"
local GENERATED_STATUS = {["sdk16 body"] = true, [TRANSCRIBED] = true}
local LEDGER_RELEASE = surface.ledger_6_1_3()

function rule_set(tree, fw, corpus, sdk_release)
    local led6 = surface.ledger_status(corpus, fw, LEDGER_RELEASE)
    local registry = surface.registry_entries(tree, fw)
    local out = {}
    for _, row in ipairs(surface.surface_rows(tree, corpus, sdk_release, fw)) do
        if row.kind == "protocol" and row.lang == "objc" and registry[surface.canonical_member(row.api, "protocol")] == nil then
            local status = led6[surface.key("protocol", row.api)]
            if status ~= nil and status ~= "header-ok" then
                out[row.api] = true
            end
        end
    end
    return out
end

function recorded_set(tree, fw)
    local out = {}
    local text = files.read_text(layout.protocol_set_path(tree, fw))
    if text then
        for _, row in ipairs(tsv.records(text)) do
            out[row.protocol] = true
        end
    end
    return out
end

function generation_set(tree, fw, corpus, sdk_release)
    local recorded = recorded_set(tree, fw)
    if corpus == nil then
        return recorded
    end
    local computed = rule_set(tree, fw, corpus, sdk_release)
    local only_rule, only_record = {}, {}
    for name in pairs(computed) do
        if not recorded[name] then table.insert(only_rule, name) end
    end
    for name in pairs(recorded) do
        if not computed[name] then table.insert(only_record, name) end
    end
    if #only_rule > 0 or #only_record > 0 then
        table.sort(only_rule, order.less)
        table.sort(only_record, order.less)
        raise(string.format("the protocol set of %s differs from its record: the rule gives [%s], the record has [%s]; review the record",
            fw, table.concat(only_rule, ","), table.concat(only_record, ",")))
    end
    return computed
end

function records(tree, fw)
    local out = {}
    local text = files.read_text(path.join(layout.snap_dir(tree, fw), "protocols.tsv"))
    if not text then
        return out
    end
    for _, row in ipairs(tsv.records(text)) do
        local record = out[row.protocol]
        if record == nil then
            record = {introduced = row.introduced, status = row.status, reasons = row.reasons, bases = row.bases, members = {}}
            out[row.protocol] = record
        end
        if row.section ~= "-" then
            table.insert(record.members, {section = row.section, kind = row.kind, instance = row.instance == "yes",
                                          selector = row.selector, decl = row.decl, in16 = row.in16})
        end
    end
    return out
end

function protocol_files(tree, fw, corpus, sdk_release)
    local protocols = records(tree, fw)
    local wanted = generation_set(tree, fw, corpus, sdk_release)
    local generated, by_release, release_list = {}, {}, {}
    for name, record in pairs(protocols) do
        if GENERATED_STATUS[record.status] and wanted[name] then
            if record.status == TRANSCRIBED then
                raise(string.format("%s: the protocol %s is transcribed and its declaration is not in the tree: the generation set cannot "
                    .. "name it until the transcriber is ported", fw, name))
            end
            generated[name] = record
            local release = record.introduced
            if by_release[release] == nil then
                by_release[release] = {}
                table.insert(release_list, release)
            end
            table.insert(by_release[release], name)
        end
    end
    local out = {}
    for _, release in ipairs(releases.sorted(release_list)) do
        local names = table.move(by_release[release], 1, #by_release[release], 1, {})
        table.sort(names, order.less)
        local tag = string.gsub(release, "%.", "")
        local body = {layout.constants().MARK}
        local sdk16 = false
        for _, name in ipairs(names) do
            if generated[name].status == "sdk16 body" then
                sdk16 = true
            end
        end
        if sdk16 then
            table.insert(body, "#import <" .. fw .. "/" .. fw .. ".h>")
        end
        table.insert(body, "")
        table.insert(body, "__attribute__((used)) Protocol *const charon_" .. fw .. "_protocols" .. tag .. "[] = {")
        for _, name in ipairs(names) do
            table.insert(body, "    @protocol(" .. name .. "),")
        end
        table.insert(body, "};")
        out[fw .. "Protocols" .. tag .. ".m"] = table.concat(body, "\n") .. "\n"
    end
    return out
end
