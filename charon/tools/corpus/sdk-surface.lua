import("core.base.json")
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local surface_impl = import("surface_impl", {rootdir = path.join(os.scriptdir(), "..", "gen"), anonymous = true})
local tsv = import("tsv", {rootdir = path.join(os.scriptdir(), "..", "gen"), anonymous = true})
local swiftinterface = import("swiftinterface", {rootdir = os.scriptdir(), anonymous = true})

AFTER = {6, 1}

local SOURCE_SUFFIXES = {".swift", ".c", ".m", ".mm", ".cpp", ".cc", ".h", ".hpp"}
local SKIPPED_DIRS = {"Tests/", "Test/", "Example", "Benchmarks/", ".github/", "docs/", "Docs/", "tests/", "samples/", "Samples/"}
local MEMBER_KINDS = {method = true, property = true, constant = true}
local REGISTRY_ORDER = {implemented = 0, inert = 1, ignored = 2, absent = 3}

ENRICHED = {"registry", "owner-registry", "demand-rank", "demand-severity", "demand-apps", "demand-telegram", "impl-lead", "impl-file-lead"}
SURFACE_HEAD = table.join({"framework", "kind", "lang", "api", "introduced", "deprecated", "obsoleted", "unavailable", "via", "getter"}, ENRICHED)
REMOVED_HEAD = table.join({"framework", "kind", "lang", "api", "introduced", "deprecated", "old-obsoleted", "state", "new-framework",
                           "new-introduced", "new-obsoleted", "new-unavailable"}, ENRICHED)

function parse_version(text)
    local parts = {}
    for part in (text .. "."):gmatch("([^.]*)%.") do
        local number = tonumber(part)
        if number == nil then
            raise("sdk-surface: %q is not a version", text)
        end
        table.insert(parts, number)
    end
    return parts
end

function compare(a, b)
    return swiftinterface.compare(a, b)
end

local function split_plain(text, separator)
    local out, start = {}, 1
    while true do
        local at = text:find(separator, start, true)
        if at == nil then
            table.insert(out, text:sub(start))
            return out
        end
        table.insert(out, text:sub(start, at - 1))
        start = at + #separator
    end
end

local function before_paren(api)
    return (api:match("^[^(]*"))
end

local function ends_with_any(name, suffixes)
    for _, suffix in ipairs(suffixes) do
        if name:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

local function remember(stems, key, name)
    if stems[key] == nil or #name < #stems[key] then
        stems[key] = name
    end
end

function index_repo(entry, tree)
    local stems, directories = {}, {}
    for _, name in ipairs(tree.files) do
        if name:sub(1, #entry.under) == entry.under and ends_with_any(name, SOURCE_SUFFIXES) then
            local skipped = false
            for _, dir in ipairs(SKIPPED_DIRS) do
                if ("/" .. name):find("/" .. dir, 1, true) then
                    skipped = true
                    break
                end
            end
            if not skipped then
                local parts = split_plain(name, "/")
                local directory = (entry.directory and #parts > 2) and parts[2]:lower() or nil
                if not (entry.directory and directory == nil) then
                    if directory then
                        directories[directory] = true
                    end
                    local stem = parts[#parts]:match("^(.*)%.[^.]*$") or parts[#parts]
                    local prefix = directory and (directory .. "\t") or "\t"
                    remember(stems, prefix .. stem, name)
                    if stem:find("+", 1, true) then
                        remember(stems, prefix .. split_plain(stem, "+")[1], name)
                    end
                end
            end
        end
    end
    return {entry = entry, stems = stems, directories = directories, sha = tree.sha}
end

function repositories()
    return surface_impl.repositories()
end

function load_impl(corpus)
    local repos = {}
    for _, entry in ipairs(repositories()) do
        local file = path.join(corpus, "impl-source-trees", (entry.repo:gsub("/", "_")) .. ".json")
        if not os.isfile(file) then
            raise("no file list for %s at %s: run `xmake l tools/gen.lua impl-index` first", entry.repo, file)
        end
        table.insert(repos, index_repo(entry, json.decode(io.readfile(file))))
    end
    return repos
end

local function applies(repo, framework)
    if repo.entry.frameworks ~= nil then
        return repo.entry.frameworks[framework] == true
    end
    return repo.directories[framework:lower()] == true
end

function candidates(entry, name, loose)
    local base = before_paren(name)
    local found = {base}
    local strip = entry.strip
    if strip and base:sub(1, #strip) == strip and #base > #strip then
        table.insert(found, base:sub(#strip + 1))
    end
    if entry.prefix and loose then
        local root = base:match("^k[A-Z]") and base:sub(2) or base
        for i = #root - 1, 4, -1 do
            local char = root:sub(i + 1, i + 1)
            if char:match("^[A-Z]$") or char == "_" then
                table.insert(found, (root:sub(1, i):gsub("_+$", "")))
            end
        end
    end
    return found
end

function owners(kind, lang, api)
    local owner = api:match("^[-+]%[([%w_]+) ")
    if owner then
        return {owner}
    end
    if not MEMBER_KINDS[kind] then
        return {}
    end
    local base = before_paren(api)
    if not base:find(".", 1, true) then
        return {}
    end
    local parts = split_plain(base, ".")
    table.remove(parts)
    if lang == "objc" then
        return {parts[1]}
    end
    local out = {}
    for n = #parts, 1, -1 do
        table.insert(out, table.concat(parts, ".", 1, n))
    end
    return out
end

function lookup(repos, framework, kind, api, owner_names)
    local member = #owner_names > 0 and MEMBER_KINDS[kind] == true
    local names = member and owner_names or {api}
    local loose = (kind == "function" or kind == "constant") and not member
    local hits = {}
    for _, repo in ipairs(repos) do
        if applies(repo, framework) then
            local prefix = repo.entry.directory and (framework:lower() .. "\t") or "\t"
            local found = nil
            for _, name in ipairs(names) do
                for _, candidate in ipairs(candidates(repo.entry, name, loose)) do
                    found = repo.stems[prefix .. candidate]
                    if found then
                        break
                    end
                end
                if found then
                    break
                end
            end
            if found then
                table.insert(hits, {source = repo.entry.source, file = repo.entry.repo .. ":" .. found})
            end
        end
    end
    return hits
end

local function records(file)
    local text = io.readfile(file)
    if text == nil then
        raise("sdk-surface: cannot read %s", file)
    end
    return tsv.records(text)
end

function load_registry(file)
    return registry_from(records(file))
end

function registry_from(list)
    local rows, count = {}, 0
    for _, row in ipairs(list) do
        local status = row.status
        local api = row.api
        local have = rows[api]
        if have == nil then
            count = count + 1
        end
        if have == nil or (REGISTRY_ORDER[status] or 9) < (REGISTRY_ORDER[have] or 9) then
            rows[api] = status
        end
    end
    return rows, count
end

function registry_status(registry, kind, api)
    local status = registry[api]
    if status ~= nil then
        return status
    end
    local owner, selector = api:match("^[-+]%[([%w_]+) (.+)%]$")
    if owner then
        return registry[owner .. "." .. selector]
    end
    if kind == "property" and api:find(".", 1, true) then
        local dot = api:find(".", 1, true)
        local name_owner, name = api:sub(1, dot - 1), api:sub(dot + 1)
        for _, candidate in ipairs({"-[" .. name_owner .. " " .. name .. "]",
                                    "-[" .. name_owner .. " set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":]"}) do
            if registry[candidate] ~= nil then
                return registry[candidate]
            end
        end
    end
    return nil
end

function show_registry(status)
    if status == nil or status == "" then
        return "none"
    end
    return status == "implemented" and "carried" or status
end

function load_demand(file)
    return demand_from(records(file))
end

function demand_from(list)
    local rows, count = {}, 0
    for _, row in ipairs(list) do
        if row.api ~= nil and rows[row.api] == nil then
            rows[row.api] = row
            count = count + 1
        end
    end
    return rows, count
end

function demand_for(demand, kind, api)
    local row = demand[api]
    if row == nil and (kind == "constant" or kind == "function") then
        row = demand["_" .. before_paren(api)]
    end
    return row
end

function enrich(row, registry, demand, repos)
    local api, kind, lang, framework = row.api, row.kind, row.lang, row.framework
    local own = registry_status(registry, kind, api)
    local owner_names = owners(kind, lang, api)
    local owner_status = ""
    if own == nil and #owner_names > 0 then
        owner_status = show_registry(registry[owner_names[1]])
        if owner_status == "none" then
            owner_status = ""
        end
    end
    local found = demand_for(demand, kind, api)
    local telegram = ""
    if found then
        for _, caller in ipairs(split_plain(found.crash_callers, ",")) do
            if caller == "telegram" then
                telegram = "yes"
            end
        end
    end
    local sources, seen, files = {}, {}, {}
    for _, hit in ipairs(lookup(repos, framework, kind, api, owner_names)) do
        if not seen[hit.source] then
            seen[hit.source] = true
            table.insert(sources, hit.source)
        end
        table.insert(files, hit.file)
    end
    return {show_registry(own), owner_status, found and found.rank or "", found and found.severity or "", found and found.apps or "", telegram,
            table.concat(sources, ","), table.concat(files, ";")}
end

local function newest(corpus, prefix, suffix)
    local best, best_time = nil, nil
    for _, file in ipairs(os.files(path.join(corpus, prefix .. "*" .. suffix))) do
        local time = os.mtime(file)
        if best == nil or time > best_time then
            best, best_time = file, time
        end
    end
    if best == nil then
        raise("no %s*%s in %s", prefix, suffix, corpus)
    end
    return best
end

function walks(corpus, new, old)
    local files = os.files(path.join(corpus, "sdk-*-declared.json"))
    if #files == 0 then
        raise("no sdk-<version>-declared.json in %s: run sdk-introduced --sdk <iPhoneOS SDK> first", corpus)
    end
    local function version(file)
        local name = path.filename(file)
        local at = 1
        while true do
            local start = name:find("sdk-", at, true)
            if start == nil then
                return {0}
            end
            local text = name:sub(start + 4):match("^(%d+[%.%d]*)%-declared%.json$")
            if text and not text:find("..", 1, true) and text:sub(-1) ~= "." then
                return parse_version(text)
            end
            at = start + 1
        end
    end
    local newest_file, oldest_file = files[1], files[1]
    for i = 2, #files do
        if compare(version(files[i]), version(newest_file)) > 0 then
            newest_file = files[i]
        end
        if compare(version(files[i]), version(oldest_file)) < 0 then
            oldest_file = files[i]
        end
    end
    return new or newest_file, old or oldest_file
end

local function cell(value)
    return (tostring(value):gsub("[\t\n]", " "))
end

local function write_tsv(file, head, rows)
    local out = io.open(file, "wb")
    if out == nil then
        raise("sdk-surface: cannot write %s", file)
    end
    out:write(table.concat(head, "\t") .. "\n")
    local chunk = {}
    for _, row in ipairs(rows) do
        local cells = {}
        for i, value in ipairs(row) do
            cells[i] = cell(value)
        end
        table.insert(chunk, table.concat(cells, "\t"))
        if #chunk >= 4096 then
            out:write(table.concat(chunk, "\n") .. "\n")
            chunk = {}
        end
    end
    if #chunk > 0 then
        out:write(table.concat(chunk, "\n") .. "\n")
    end
    out:close()
end

function is_live(row, sdk_version)
    if row.unavailable ~= nil and row.unavailable ~= "" then
        return false
    end
    return not (row.obsoleted ~= nil and row.obsoleted ~= "" and compare(parse_version(row.obsoleted), sdk_version) <= 0)
end

local function introduced_after(row)
    return row.introduced ~= "" and compare(parse_version(row.introduced), AFTER) > 0
end

local function stable_sort(list, less)
    for i, item in ipairs(list) do
        item.position = i
    end
    table.sort(list, function (a, b)
        local verdict = less(a, b)
        if verdict ~= nil then
            return verdict
        end
        return a.position < b.position
    end)
end

local function order_strings(a, b)
    if a == b then
        return nil
    end
    return byteorder.less(a, b)
end

function surface_rows(rows)
    local surface, unannotated, before = {}, {}, {}
    for _, row in ipairs(rows) do
        if row.introduced == "" then
            local key = row.lang .. "\t" .. row.framework
            unannotated[key] = (unannotated[key] or 0) + 1
        elseif not introduced_after(row) then
            local key = row.lang .. "\t" .. (row.via == "own" and "own" or "floor")
            before[key] = (before[key] or 0) + 1
        else
            table.insert(surface, {row = row, version = parse_version(row.introduced)})
        end
    end
    stable_sort(surface, function (a, b)
        local by_version = compare(a.version, b.version)
        if by_version ~= 0 then
            return by_version < 0
        end
        for _, field in ipairs({"framework", "lang", "kind", "api"}) do
            local verdict = order_strings(a.row[field], b.row[field])
            if verdict ~= nil then
                return verdict
            end
        end
        return nil
    end)
    local out = {}
    for _, item in ipairs(surface) do
        table.insert(out, item.row)
    end
    return out, unannotated, before
end

function removed_rows(new_rows, old_rows, new_version, old_version)
    local present = {}
    for _, row in ipairs(new_rows) do
        local key = row.lang .. "\t" .. row.api
        if present[key] == nil or (not is_live(present[key], new_version) and is_live(row, new_version)) then
            present[key] = row
        end
    end
    local old_live = {}
    for _, row in ipairs(old_rows) do
        if is_live(row, old_version) then
            old_live[row.lang .. "\t" .. row.api] = true
        end
    end
    local relabelled = {}
    for _, row in ipairs(new_rows) do
        if row.lang == "swift" and row.api:find("(", 1, true) and is_live(row, new_version) and not old_live[row.lang .. "\t" .. row.api] then
            local key = row.kind .. "\t" .. before_paren(row.api)
            if relabelled[key] == nil then
                relabelled[key] = row
            end
        end
    end
    local removed = {}
    for _, row in ipairs(old_rows) do
        if is_live(row, old_version) then
            local current = present[row.lang .. "\t" .. row.api]
            local state = nil
            if current == nil and row.lang == "swift" and row.api:find("(", 1, true) then
                current = relabelled[row.kind .. "\t" .. before_paren(row.api)]
                state = current and "changed" or "removed"
            elseif current == nil then
                state = "removed"
            elseif current.unavailable ~= "" then
                state = "unavailable"
            elseif not is_live(current, new_version) then
                state = "obsoleted"
            end
            if state then
                table.insert(removed, {row = row, state = state, current = current})
            end
        end
    end
    stable_sort(removed, function (a, b)
        for _, pair in ipairs({{a.state, b.state}, {a.row.framework, b.row.framework}, {a.row.lang, b.row.lang}, {a.row.kind, b.row.kind},
                               {a.row.api, b.row.api}}) do
            local verdict = order_strings(pair[1], pair[2])
            if verdict ~= nil then
                return verdict
            end
        end
        return nil
    end)
    return removed
end

local function md_table(head, rows)
    local dashes = {}
    for i = 1, #head do
        dashes[i] = "---"
    end
    local lines = {"| " .. table.concat(head, " | ") .. " |", "|" .. table.concat(dashes, "|") .. "|"}
    for _, row in ipairs(rows) do
        local cells = {}
        for i, value in ipairs(row) do
            cells[i] = tostring(value)
        end
        table.insert(lines, "| " .. table.concat(cells, " | ") .. " |")
    end
    return table.concat(lines, "\n")
end

local function named(names)
    if #names == 0 then
        return "none"
    end
    local quoted = {}
    for i, name in ipairs(names) do
        quoted[i] = "`" .. name .. "`"
    end
    return table.concat(quoted, ", ")
end

function object_keys(text, key)
    local marker = "\"" .. key .. "\": {"
    local at, last = 1, nil
    while true do
        local found = text:find(marker, at, true)
        if found == nil then
            break
        end
        last, at = found, found + 1
    end
    if last == nil then
        raise("sdk-surface: no %q object in the walk", key)
    end
    local keys, i, expect_key = {}, last + #marker, true
    while i <= #text do
        local c = text:sub(i, i)
        if c == "}" then
            return keys
        elseif c == "\"" then
            local j = i + 1
            while text:sub(j, j) ~= "\"" do
                j = j + (text:sub(j, j) == "\\" and 2 or 1)
            end
            if expect_key then
                table.insert(keys, json.decode("[" .. text:sub(i, j) .. "]")[1])
            end
            expect_key = false
            i = j + 1
        else
            if c == "," then
                expect_key = true
            end
            i = i + 1
        end
    end
    raise("sdk-surface: the %q object of the walk does not close", key)
end

local function int(value)
    return string.format("%d", value or 0)
end

local function not_in_surface(new, new_path, no_row_keys, unannotated, before, floor_in_table)
    local dropped = new.dropped
    local unversioned = {objc = 0, swift = 0}
    for key, value in pairs(unannotated) do
        local lang = key:match("^([^\t]*)")
        if unversioned[lang] then
            unversioned[lang] = unversioned[lang] + value
        end
    end
    local forward, anonymous, no_row = dropped["forward-declaration"], dropped.anonymous, dropped["no-row"]
    local failed = {}
    for i = 1, math.min(40, #new.failed) do
        table.insert(failed, "\n  - " .. new.failed[i])
    end
    local no_row_items, tbd = {}, {}
    for _, name in ipairs(no_row_keys) do
        table.insert(no_row_items, "`" .. name .. "` (" .. no_row[name] .. ")")
        if no_row[name]:find(".tbd", 1, true) then
            table.insert(tbd, name)
        end
    end
    return {"## Not in the surface", "",
            "Everything the walk of `" .. path.filename(new_path) .. "` sees and does not put in the table, counted; what it cannot see at all is the last item.", "",
            string.format("- Introduced at or before iOS 6.1 (in the walk, not in the table): %s Objective-C / C and %s Swift rows with a version of their own; "
                          .. "%s Objective-C / C and %s Swift rows more whose version at or before 6.1 is only a floor taken from their class, protocol, category "
                          .. "or enum (`via=container` or `class-floor`), so any of them may have arrived after 6.1 and is not shown as such.",
                          int(before["objc\town"]), int(before["swift\town"]), int(before["objc\tfloor"]), int(before["swift\tfloor"])),
            string.format("- No iOS version at all (%s Objective-C / C and %s Swift rows): API from before the availability annotations, or Swift API "
                          .. "whose module states no version. In the walk, not in the table. Objective-C members of a category with no annotation of its own take "
                          .. "their class's or protocol's version as a floor (`via=class-floor`) and are not among these (a Swift extension member with no @available keeps `none`): %s rows took one, "
                          .. "%s of them are in the table (the others took a version at or before 6.1).",
                          int(unversioned.objc), int(unversioned.swift), int(dropped["class-floor"]), int(floor_in_table)),
            string.format("- Forward declarations (`@class CIImage;`, `@protocol MTLTexture;`) in another framework's header, a row with no version "
                          .. "beside the real one: %s Objective-C and %s Swift rows removed from the walk.", int(forward.objc), int(forward.swift)),
            string.format("- Enums and structs with no name of their own, which have no row (a `typedef struct {...} X` is one; the cases of an anonymous enum "
                          .. "do have theirs): %s enums and %s structs.", int(anonymous.enum), int(anonymous.struct)),
            string.format("- Headers clang rejects, named with the first error (%d):", #new.failed) .. table.concat(failed),
            string.format("- %s frameworks with headers were walked and %s libraries under `usr/include` (`include/<directory>`, `include` for the loose "
                          .. "top-level headers; the C++ standard library `c++`, the Darwin module's `_modules` shims and the `secure` wrappers are not walked, "
                          .. "each is an `#error` or C++ when read alone). The C API of libSystem (`os_unfair_lock_*`, `dispatch_*`, `xpc_*`, `os_log_*`, `mach_*`) "
                          .. "is in these.", int(dropped["frameworks-walked"]), int(dropped["libraries-walked"])),
            string.format("- Frameworks, libraries and Swift modules that give no row at all (%d): ", #no_row_keys) .. table.concat(no_row_items, "; ") .. ".",
            string.format("- Frameworks with headers that give no Objective-C / C row (%d; those of them named above give no row at all, the rest have Swift rows): ",
                          #dropped["no-objc-row"]) .. named(dropped["no-objc-row"]) .. ".",
            string.format("- Swift modules: %s found, %s with rows; without rows: ", int(dropped["swift-modules-found"]),
                          int(dropped["swift-modules-found"] - #dropped["swift-modules-without-rows"])) .. named(dropped["swift-modules-without-rows"]) .. ".",
            "- What neither clang nor a swiftinterface shows: macros (`#define` constants), typedefs and struct fields, conformances "
                .. "(`extension X: P`), SPI, private headers; frameworks that ship only a `.tbd` (" .. named(tbd) .. ").", ""}
end

local function counter_add(counter, key, by)
    counter[key] = (counter[key] or 0) + (by or 1)
end

local function major(introduced)
    return tonumber(introduced:match("^[^.]*"))
end

function summary_text(inputs, rows, removed)
    local new, old = inputs.new, inputs.old
    local at = {}
    for i, name in ipairs(SURFACE_HEAD) do
        at[name] = i
    end
    local total = #rows
    local carried, with_impl, demanded, telegram, objc, swift = 0, 0, 0, 0, 0, 0
    local by_registry, by_owner, by_via, per_source = {}, {}, {}, {}
    local majors_set, frameworks, framework_order = {}, {}, {}
    for _, r in ipairs(rows) do
        if r[at.registry] == "carried" then
            carried = carried + 1
        end
        if r[at["impl-lead"]] ~= "" then
            with_impl = with_impl + 1
        end
        counter_add(by_registry, r[at.registry])
        if r[at.registry] == "none" then
            counter_add(by_owner, r[at["owner-registry"]])
        end
        if r[at["demand-rank"]] ~= "" then
            demanded = demanded + 1
        end
        if r[at["demand-telegram"]] ~= "" then
            telegram = telegram + 1
        end
        if r[at.lang] == "objc" then
            objc = objc + 1
        elseif r[at.lang] == "swift" then
            swift = swift + 1
        end
        local m = major(r[at.introduced])
        majors_set[m] = true
        local fw = r[at.framework]
        if frameworks[fw] == nil then
            frameworks[fw] = {total = 0, carried = 0, impl = 0, majors = {}}
            table.insert(framework_order, fw)
        end
        frameworks[fw].total = frameworks[fw].total + 1
        counter_add(frameworks[fw].majors, m)
        if r[at.registry] == "carried" then
            frameworks[fw].carried = frameworks[fw].carried + 1
        end
        if r[at["impl-lead"]] ~= "" then
            frameworks[fw].impl = frameworks[fw].impl + 1
        end
        for _, source in ipairs(split_plain(r[at["impl-lead"]], ",")) do
            if source ~= "" then
                counter_add(per_source, source)
            end
        end
        counter_add(by_via, r[at.via])
    end
    local majors = {}
    for m in pairs(majors_set) do
        table.insert(majors, m)
    end
    table.sort(majors)
    local dropped_total = 0
    for _, r in ipairs(removed) do
        if r[8] ~= "changed" then
            dropped_total = dropped_total + 1
        end
    end
    local other_owner = 0
    for key, value in pairs(by_owner) do
        if key ~= "" and key ~= "carried" and key ~= "absent" then
            other_owner = other_owner + value
        end
    end
    local shas = {}
    for _, repo in ipairs(inputs.repos) do
        table.insert(shas, repo.entry.repo .. "@" .. repo.sha:sub(1, 8))
    end
    local sources = {}
    for _, source in ipairs(byteorder.keys(per_source)) do
        table.insert(sources, source .. " " .. per_source[source])
    end
    local by_major = {}
    for _, m in ipairs(majors) do
        local count, mo, ms, floor, mc, mi = 0, 0, 0, 0, 0, 0
        for _, r in ipairs(rows) do
            if major(r[at.introduced]) == m then
                count = count + 1
                if r[at.lang] == "objc" then
                    mo = mo + 1
                end
                if r[at.lang] == "swift" then
                    ms = ms + 1
                end
                if r[at.via] == "container" or r[at.via] == "class-floor" then
                    floor = floor + 1
                end
                if r[at.registry] == "carried" then
                    mc = mc + 1
                end
                if r[at["impl-lead"]] ~= "" then
                    mi = mi + 1
                end
            end
        end
        table.insert(by_major, {m, count, mo, ms, floor, mc, mi})
    end
    local ordered = {}
    for i, fw in ipairs(framework_order) do
        ordered[i] = {name = fw, index = i}
    end
    table.sort(ordered, function (a, b)
        local ta, tb = frameworks[a.name].total, frameworks[b.name].total
        if ta ~= tb then
            return ta > tb
        end
        return a.index < b.index
    end)
    local by_framework = {}
    for _, item in ipairs(ordered) do
        local counts = frameworks[item.name]
        local line = {item.name, counts.total, counts.carried, counts.impl}
        for _, m in ipairs(majors) do
            table.insert(line, counts.majors[m] or "")
        end
        table.insert(by_framework, line)
    end
    local major_head = {"framework", "rows", "carried", "impl"}
    for _, m in ipairs(majors) do
        table.insert(major_head, tostring(m))
    end
    local by_state = {}
    for _, state in ipairs({"removed", "unavailable", "obsoleted", "changed"}) do
        local count, so, ss, sc, sd = 0, 0, 0, 0, 0
        for _, r in ipairs(removed) do
            if r[8] == state then
                count = count + 1
                if r[3] == "objc" then
                    so = so + 1
                end
                if r[3] == "swift" then
                    ss = ss + 1
                end
                if r[13] == "carried" then
                    sc = sc + 1
                end
                if r[15] ~= "" then
                    sd = sd + 1
                end
            end
        end
        table.insert(by_state, {state, count, so, ss, sc, sd})
    end
    local lines = {string.format("# SDK %s surface after iOS %d.%d", new.version, AFTER[1], AFTER[2]), "",
                   "Two things to read before using a number below:", "",
                   "- **`impl-lead` is a lead by file name, not a fact of implementation.** A row has one when a reference "
                       .. "implementation (WinObjC, swift-foundation, ...) has a *file* named after the type it belongs to (`UIView.mm` for "
                       .. "`UIView.safeAreaInsets`). Nothing checks that the file implements that member, or that the repository's snapshot is "
                       .. "as new as the API (WinObjC is years older than most of these rows).",
                   "- **`via=container` and `via=class-floor` versions are a floor, not the arrival.** The member came in that iOS version "
                       .. "*or later*: it took the version of the class, protocol, category or enum it sits in "
                       .. "(`MTLGPUFamilyApple8` says 13.0 through its enum and came with iOS 16). Only `via=own` is the declaration's own "
                       .. "`@available`.", "",
                   "Generated by `tools/corpus/sdk-surface.lua build`. Inputs: `" .. path.filename(inputs.new_path) .. "` (" .. new.sdk .. ", target "
                       .. new.target .. "), `" .. path.filename(inputs.old_path) .. "`, registry `" .. path.filename(inputs.registry_path)
                       .. "`, demand `" .. path.filename(inputs.demand_path) .. "`, implementation file lists `impl-source-trees/` ("
                       .. table.concat(shas, ", ") .. ").", "",
                   "## Totals", "",
                   md_table({"", "rows"}, {
                       {"declared after iOS 6.1 (`sdk-" .. new.version .. "-surface.tsv`)", total},
                       {"of them Objective-C / C (clang)", objc},
                       {"of them Swift-only (`.swiftinterface`)", swift},
                       {"registry: carried", carried},
                       {"registry: absent", by_registry.absent or 0},
                       {"registry: inert / ignored", string.format("%d / %d", by_registry.inert or 0, by_registry.ignored or 0)},
                       {"registry: no row", by_registry.none or 0},
                       {"  of those, the owning class or protocol has a row: carried / absent / other",
                        string.format("%d / %d / %d", by_owner.carried or 0, by_owner.absent or 0, other_owner)},
                       {"in the demand corpus", demanded},
                       {"  of those called by Telegram", telegram},
                       {"  `via` own / container / class-floor", string.format("%d / %d / %d", by_via.own or 0, by_via.container or 0,
                                                                                by_via["class-floor"] or 0)},
                       {"with an `impl-lead` (a file name match, not an implementation, see above)", with_impl},
                       {"dropped since " .. old.version .. ": removed / unavailable / obsoleted (`removed-since-" .. old.version .. ".tsv`)", dropped_total},
                       {"  and signature `changed` (same Swift name, other labels; in the same file, not counted above)", #removed - dropped_total}}), "",
                   "`impl-lead` by repository (a row may have several): " .. table.concat(sources, ", "), "",
                   "## By introduced iOS version", "",
                   md_table({"iOS", "rows", "objc", "swift", "of them a floor", "carried", "with impl-lead"}, by_major), "",
                   "## By framework and version", "",
                   "Rows per framework and the major iOS version they arrived in; `carried` and `impl` (an `impl-lead`) are the two counts the task asked for.", "",
                   md_table(major_head, by_framework), "",
                   "## Dropped since " .. old.version, "",
                   "What " .. old.sdk .. " declares and " .. new.sdk .. " does not, or declares unavailable, or obsoleted at or below its version. A Swift name that "
                       .. "is gone under its labels but declared again under others (`withCheckedContinuation(function:_:)` -> "
                       .. "`withCheckedContinuation(isolation:function:_:)`) is `changed`, not removed: its signature moved, the name did not. "
                       .. "Rows are matched by name and labels, so the `changed` and `removed` counts are a split of one comparison, and "
                       .. "`changed` is not in the dropped total.", "",
                   md_table({"state", "rows", "objc", "swift", "carried in the registry", "demanded"}, by_state), ""}
    table.join2(lines, not_in_surface(new, inputs.new_path, inputs.no_row_keys, inputs.unannotated, inputs.before, by_via["class-floor"] or 0))
    return table.concat(lines, "\n")
end

function build(options)
    local corpus = workspace.corpus()
    local new_path, old_path = walks(corpus, options.new, options.old)
    local new_text = io.readfile(new_path)
    local new = json.decode(new_text)
    local old = json.decode(io.readfile(old_path))
    local registry_path = options.registry or newest(corpus, "carried-registry-", ".tsv")
    local demand_path = options.demand or path.join(corpus, "crash-demand-top.tsv")
    local registry, registry_count = load_registry(registry_path)
    local demand, demand_count = load_demand(demand_path)
    local repos = load_impl(corpus)
    local new_version, old_version = parse_version(new.version), parse_version(old.version)
    local stem = "sdk-" .. new.version
    local out = options.out or corpus
    os.mkdir(out)
    print(string.format("new %s (%d rows), old %s (%d rows), registry %s (%d rows), demand %s (%d rows)", path.filename(new_path), #new.rows,
                        path.filename(old_path), #old.rows, path.filename(registry_path), registry_count, path.filename(demand_path), demand_count))
    local surface, unannotated, before = surface_rows(new.rows)
    local enriched = {}
    for _, row in ipairs(surface) do
        local line = {row.framework, row.kind, row.lang, row.api, row.introduced, row.deprecated, row.obsoleted, row.unavailable, row.via,
                      row.getter or ""}
        table.join2(line, enrich(row, registry, demand, repos))
        table.insert(enriched, line)
    end
    write_tsv(path.join(out, stem .. "-surface.tsv"), SURFACE_HEAD, enriched)
    local removed = {}
    for _, item in ipairs(removed_rows(new.rows, old.rows, new_version, old_version)) do
        local row, current = item.row, item.current
        local line = {row.framework, row.kind, row.lang, row.api, row.introduced, row.deprecated, row.obsoleted, item.state,
                      current and current.framework or "", current and current.introduced or "", current and current.obsoleted or "",
                      current and current.unavailable or ""}
        table.join2(line, enrich(row, registry, demand, repos))
        table.insert(removed, line)
    end
    local old_stem = "sdk-" .. new.version .. "-removed-since-" .. old.version .. ".tsv"
    write_tsv(path.join(out, old_stem), REMOVED_HEAD, removed)
    local inputs = {new = new, old = old, new_path = new_path, old_path = old_path, registry_path = registry_path, demand_path = demand_path,
                    repos = repos, unannotated = unannotated, before = before, no_row_keys = object_keys(new_text, "no-row")}
    io.writefile(path.join(out, stem .. "-surface.md"), summary_text(inputs, enriched, removed))
    print(string.format("wrote %s-surface.tsv (%d rows), %s (%d rows), %s-surface.md", stem, #enriched, old_stem, #removed, stem))
end

local OPTIONS = {new = true, old = true, registry = true, demand = true, out = true}

function main(command, ...)
    local arguments = {...}
    if command ~= "build" then
        raise("usage: xmake l tools/corpus/sdk-surface.lua build [--new F] [--old F] [--registry F] [--demand F] [--out DIR]")
    end
    local options = {}
    local i = 1
    while i <= #arguments do
        local name, value = arguments[i]:match("^%-%-([%w]+)=(.*)$")
        if name == nil then
            name = arguments[i]:match("^%-%-([%w]+)$")
            value = arguments[i + 1]
            i = i + 1
        end
        if name == nil or not OPTIONS[name] or value == nil then
            raise("sdk-surface: unknown or incomplete argument %s", arguments[i] or arguments[i - 1])
        end
        options[name] = path.absolute(value)
        i = i + 1
    end
    build(options)
end
