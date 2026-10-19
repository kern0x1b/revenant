local layout = import("layout", {anonymous = true})
local surface = import("surface", {anonymous = true})
local order = import("order", {anonymous = true})
local strings = import("strings", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local sdk = import("sdk", {anonymous = true})

local LEDGER_RELEASE = surface.ledger_6_1_3()
local BUCKET_FILE = "swift/bucket.tsv"
local SWIFT_LANG = "swift"
local HEADER_OK = "header-ok"
local BUCKET_STATE = "swift: needs the Swift interface source"
local NO_VALUE = "-"
local BUCKET_KINDS = {method = true, property = true, constant = true}
local COLUMNS = {"framework", "kind", "api", "introduced", "unavailable", "via", "table_match", "table_kind", "table_introduced",
                 "table_unavailable", "demand_rank", "demand_apps", "impl_lead", "ledger_6_1_3", "state"}

local function index_of(header)
    local out = {}
    for i, name in ipairs(header) do
        out[name] = i
    end
    return out
end

local function dash(value)
    if value == nil or value == "" then
        return NO_VALUE
    end
    return value
end

local function bucket_candidates(tree, corpus, release)
    local out = {}
    for _, fw in ipairs(order.strings(surface.surface_frameworks(tree, corpus, release))) do
        local led6 = surface.ledger_status(corpus, fw, LEDGER_RELEASE)
        local registry = nil
        for _, row in ipairs(surface.surface_rows(tree, corpus, release, fw)) do
            if BUCKET_KINDS[row.kind] and row.lang == SWIFT_LANG then
                local status = led6[surface.key(row.kind, row.api)] or surface.unlisted_state(tree, fw)
                if status ~= HEADER_OK then
                    if registry == nil then
                        registry = surface.registry_entries(tree, fw)
                    end
                    if registry[row.api] == nil then
                        table.insert(out, {row = row, status = status})
                    end
                end
            end
        end
    end
    return out
end

local function table_matches(corpus, release, wanted)
    local matched = {}
    local index = nil
    for line in io.lines(path.join(corpus, sdk.names(release).swift_interface)) do
        if line ~= "" then
            local cells = tsv.fields(line)
            if index == nil then
                index = index_of(cells)
            else
                local k = cells[index.module] .. "\t" .. cells[index.api]
                if wanted[k] and matched[k] == nil then
                    matched[k] = {kind = cells[index.kind], introduced = cells[index.introduced],
                                  unavailable = cells[index.unavailable]}
                end
            end
        end
    end
    return matched
end

function bucket(tree, corpus, release)
    local candidates = bucket_candidates(tree, corpus, release)
    local wanted = {}
    for _, candidate in ipairs(candidates) do
        local row = candidate.row
        wanted[row.framework .. "\t" .. row.api] = true
    end
    local matched = table_matches(corpus, release, wanted)
    local rows, matches, frameworks = {}, 0, {}
    for _, candidate in ipairs(candidates) do
        local row = candidate.row
        local match = matched[row.framework .. "\t" .. row.api]
        if match then
            matches = matches + 1
        end
        frameworks[row.framework] = true
        table.insert(rows, {row.framework, row.kind, row.api, row.introduced, dash(row.unavailable), row.via,
                            match and "yes" or "no", match and match.kind or NO_VALUE,
                            match and match.introduced or NO_VALUE,
                            match and dash(match.unavailable) or NO_VALUE, dash(row["demand-rank"]),
                            dash(row["demand-apps"]), dash(row["impl-lead"]), candidate.status, BUCKET_STATE})
    end
    local count = 0
    for _ in pairs(frameworks) do
        count = count + 1
    end
    return rows, matches, count
end

function bucket_text(rows)
    return strings.backslash_replace(tsv.table_text(COLUMNS, rows))
end

function bucket_path(tree)
    return path.join(tree, layout.constants().OUT_ROOT, BUCKET_FILE)
end

function read_bucket(tree)
    local out = {}
    local text = files.read_text(bucket_path(tree))
    if text == nil then
        return out
    end
    for _, row in ipairs(tsv.records(text)) do
        out[row.framework] = out[row.framework] or {}
        table.insert(out[row.framework], row)
    end
    return out
end
