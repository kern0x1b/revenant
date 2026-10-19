-- The protocol objects the generator emits for a framework, from the snapshot's protocol records (protocols.tsv). The objects are
-- emitted only for the protocols the generation set names. A protocol the SDK declares ("sdk16 body") is named through the
-- framework's own umbrella header; a transcribed one has no declaration in the tree (the transcriber's header is not committed:
-- generated output), so a set that names one raises instead of emitting an object no compiler can resolve.

local layout = import("layout", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local releases = import("releases", {anonymous = true})
local surface = import("surface", {anonymous = true})
local order = import("order", {anonymous = true})

local TRANSCRIBED = "transcribed"
local GENERATED_STATUS = {["sdk16 body"] = true, [TRANSCRIBED] = true}
-- The release whose ledger says which members the 6.1.3 release lacks.
local LEDGER_RELEASE = surface.ledger_6_1_3()

-- The rule of generation_set in tools/gen.py@52253c0650: the objc protocols missing at 6.1.3 (a row the ledger lists
-- with a status other than header-ok, which the port's headers cover) and named by no registry row of the framework. It
-- reads the coordination corpus (the surface table and the ledgers), which lives outside the repository.
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

-- The reviewed set of a framework: the protocols named by its record (protocol-sets/<F>.tsv), and the empty set without a record.
-- Read by the check too (cmd_check.record_conflicts), in every clean checkout.
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

-- The objc protocols whose objects this generator emits. Without the coordination corpus (corpus nil: the build, a clean checkout)
-- the set is the reviewed record. With it, the rule is worked out from the corpus and must equal the record: a difference names the
-- protocols on each side, so a change of the rule or of the corpus is reviewed through the record, never silently emitted.
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

-- name -> the protocol's record in the snapshot (its release, status, reasons, bases, and members), or none when the framework
-- has no protocol snapshot.
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

-- The generated protocol files of a framework: name -> text. One source per release a protocol arrived in: each source names
-- every protocol of its release, so clang emits its protocol object there.
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
