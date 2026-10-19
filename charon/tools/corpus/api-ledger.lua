import("async.runjobs")

local HERE = os.scriptdir()
local MODULES = path.join(HERE, "..", "..", "modules")
local workspace = import("workspace", {rootdir = MODULES, anonymous = true})
local byteorder = import("byteorder", {rootdir = MODULES, anonymous = true})
local surface_walk = import("surface_walk", {rootdir = HERE, anonymous = true})
local ledger_inputs = import("ledger_inputs", {rootdir = HERE, anonymous = true})
local ledger_classify = import("ledger_classify", {rootdir = HERE, anonymous = true})
local ledger_swift = import("ledger_swift", {rootdir = HERE, anonymous = true})
local ledger_headers = import("ledger_headers", {rootdir = HERE, anonymous = true})
local ledger_output = import("ledger_output", {rootdir = HERE, anonymous = true})

local USAGE = [[usage: xmake l tools/corpus/api-ledger.lua build --gate <gate dir with lib*Backports.dylib>
    --release-cache <path to dyld_shared_cache_armv7> --vfs <lift vfs.yaml> --out <output dir>
    [--surface <tsv>] [--sdk <iPhoneOS 26.2 SDK>] [--release 6.1.3] [--cache-dir <dir>] [--jobs N]
    [--refresh] [--frameworks F1,F2,...] [--registries <charon checkout>] [--swift-modules <swift-modules.json>]
--surface defaults to the corpus's sdk-26.2-surface.tsv, --sdk to the workspace's iPhoneOS 26.2 SDK,
--cache-dir to $HOME/.cache/hades/<task>/api-ledger/index.]]

local VALUED = {surface = true, gate = true, release = true, ["release-cache"] = true, sdk = true, vfs = true, ["cache-dir"] = true,
                out = true, jobs = true, frameworks = true, registries = true, ["swift-modules"] = true}

local function note(message)
    io.stderr:write(message .. "\n")
    io.stderr:flush()
end

local function parse(arguments)
    local args = {release = "6.1.3", jobs = 4}
    local index = 1
    while index <= #arguments do
        local item = arguments[index]
        local name, value = item:match("^%-%-([%w%-]+)=(.*)$")
        if not name then
            name = item:match("^%-%-([%w%-]+)$")
        end
        if name == "refresh" then
            args.refresh = true
        elseif name and VALUED[name] then
            if value == nil then
                index = index + 1
                value = arguments[index]
                if value == nil then
                    raise("api-ledger: --%s needs a value\n%s", name, USAGE)
                end
            end
            args[(name:gsub("%-", "_"))] = value
        else
            raise("api-ledger: unrecognized argument %s\n%s", item, USAGE)
        end
        index = index + 1
    end
    args.jobs = tonumber(args.jobs)
    if not args.jobs or math.type(args.jobs) ~= "integer" and args.jobs ~= math.floor(args.jobs) then
        raise("api-ledger: --jobs wants an integer\n%s", USAGE)
    end
    args.jobs = math.floor(args.jobs)
    for _, required in ipairs({"gate", "release_cache", "vfs", "out"}) do
        if not args[required] then
            raise("api-ledger: --%s is required\n%s", (required:gsub("_", "-")), USAGE)
        end
    end
    args.surface = args.surface or workspace.corpus("sdk-26.2-surface.tsv")
    args.sdk = args.sdk or workspace.sdk()
    args.cache_dir = args.cache_dir or workspace.run("api-ledger", "index")
    return args
end

local function count_keys(map)
    local count = 0
    for _ in pairs(map) do
        count = count + 1
    end
    return count
end

local function swift_registries(read)
    local out = {}
    for api, entry in pairs(read) do
        if entry[3] ~= ledger_classify.swift_only_package() then
            out[api] = {entry[1], entry[3], entry[2]}
        end
    end
    return out
end

function build(args)
    local started = os.mclock()
    os.mkdir(args.cache_dir)
    os.mkdir(args.out)

    local rows = ledger_inputs.load_surface(args.surface)
    if args.frameworks then
        local wanted = {}
        for name in args.frameworks:gmatch("[^,]+") do
            wanted[name] = true
        end
        if args.frameworks:sub(1, 1) == "," or args.frameworks:sub(-1) == "," or args.frameworks:find(",,", 1, true) then
            wanted[""] = true
        end
        local kept = {}
        for _, row in ipairs(rows) do
            if wanted[row.framework] then
                table.insert(kept, row)
            end
        end
        rows = kept
    end
    local seen_frameworks = {}
    for _, row in ipairs(rows) do
        seen_frameworks[row.framework] = true
    end
    note(string.format("%d rows, %d frameworks", #rows, count_keys(seen_frameworks)))
    local checkout = args.registries or ledger_inputs.default_checkout(args.surface)
    local swift = args.swift_modules and ledger_swift.load_swift_modules(args.swift_modules) or nil
    if swift then
        swift.registries = swift_registries(ledger_inputs.read_package_registries(checkout))
        local packages = {}
        for _, entry in pairs(swift.registries) do
            packages[entry[2]] = true
        end
        local names = table.keys(packages)
        byteorder.sort(names)
        note(string.format("Swift package registries: %d entries over %s", count_keys(swift.registries),
                           #names > 0 and table.concat(names, ", ") or "none"))
        note(string.format("Swift: %d modules, %d names, from %s", count_keys(swift.modules), count_keys(swift.names), swift.digester))
    end

    note(string.format("reading the built %s libraries from %s", args.release, args.gate))
    local built_classes, built_protocols, built_exports = ledger_inputs.load_built_inventories(args.gate)
    note(string.format("  %d classes, %d protocols, %d exported symbols", count_keys(built_classes), count_keys(built_protocols), count_keys(built_exports)))

    note(string.format("reading the release's own %s dyld cache %s", args.release, args.release_cache))
    local release_classes, release_protocols = ledger_inputs.objc_inventory(args.release_cache)
    local release_exports = ledger_inputs.cache_exports(args.release_cache)
    note(string.format("  %d classes, %d protocols, %d exported symbols", count_keys(release_classes), count_keys(release_protocols), count_keys(release_exports)))

    note("reading the 26.2 headers' own @interface declarations from " .. args.sdk)
    local headers = ledger_inputs.header_superclasses(args.sdk)
    local declarations = 0
    for _, declared in pairs(headers) do
        declarations = declarations + count_keys(declared)
    end
    note(string.format("  %d frameworks, %d class declarations", count_keys(headers), declarations))

    local registries = ledger_inputs.read_package_registries(checkout)
    local decided_apis = {}
    for api, entry in pairs(registries) do
        if ledger_classify.is_decided(entry[1]) then
            decided_apis[api] = true
        end
    end
    note(string.format("package registries: %d entries, of which %d record a decision", count_keys(registries), count_keys(decided_apis)))

    local results, diagnostics, deferred, matched = {}, {}, {}, {}
    for _, row in ipairs(rows) do
        local kind, lang, api = row.kind, row.lang, row.api
        local pass = ledger_classify.pass_of(kind, lang)
        if lang == "swift" then
            if swift == nil then
                table.insert(results, {row, "unmeasured", "swift-only row and no Swift pass was given (--swift-modules)", nil, "swift-pass"})
            else
                local status, reason, introduced, needs = ledger_swift.classify_swift(api, row, swift, matched)
                table.insert(results, {row, status, reason, introduced, needs})
            end
        elseif pass == "runtime" then
            local declared = headers[row.framework]
            declared = declared and {framework = row.framework, supers = declared} or nil
            local status, reason
            if kind == "class" then
                status, reason = ledger_classify.classify_class(api, built_classes, built_protocols, release_classes, release_protocols)
            elseif kind == "method" then
                status, reason = ledger_classify.classify_method(api, built_classes, release_classes, built_protocols, release_protocols,
                                                                 decided_apis, row.unavailable, declared)
            else
                status, reason = ledger_classify.classify_property(api, built_classes, release_classes, built_protocols, release_protocols,
                                                                   row.getter, nil, decided_apis, row.unavailable, declared)
            end
            local decided = status == "missing" and ledger_classify.decide(row, registries, diagnostics) or nil
            if decided then
                table.insert(results, {row, decided[1], decided[2], decided[3], decided[4]})
            else
                table.insert(results, {row, status, reason, nil, nil})
            end
        elseif pass == "symbol" then
            local status, reason = ledger_classify.classify_symbol(api, built_exports, release_exports)
            if status then
                table.insert(results, {row, status, reason, nil, nil})
            else
                table.insert(deferred, row)
            end
        elseif pass == "header" then
            table.insert(deferred, row)
        else
            table.insert(results, {row, "undecided", string.format("unhandled kind/lang %s/%s", kind, lang), nil, nil})
        end
    end
    for _, diagnostic in ipairs(diagnostics) do
        local near = {}
        for _, key in ipairs(diagnostic[2]) do
            table.insert(near, ledger_classify.repr(key))
        end
        note(string.format("decide pass: %s is in no registry; the nearest keys it holds are %s", ledger_classify.repr(diagnostic[1]),
                           #near > 0 and "[" .. table.concat(near, ", ") .. "]" or "none"))
    end
    local placed = 0
    for _, result in ipairs(results) do
        if result[2] ~= "unmeasured" then
            placed = placed + 1
        end
    end
    note(string.format("%d rows placed by the built artifacts, %d deferred to the header pass", placed, #deferred))

    local needed = {}
    for _, row in ipairs(deferred) do
        needed[row.framework] = true
    end
    local frameworks = table.keys(needed)
    byteorder.sort(frameworks)
    note(string.format("header pass: %d frameworks, %d names, %d jobs", #frameworks, #frameworks, args.jobs))
    local scratch = path.join(args.cache_dir, "generated")
    os.mkdir(scratch)
    local indexes, walked, dumped = {}, 0, 0
    local header_started = os.mclock()
    if #frameworks > 0 then
        runjobs("api-ledger header pass", function (index)
            local framework = frameworks[index]
            local found, cached
            try {
                function ()
                    found, cached = ledger_headers.framework_index(framework, args.sdk, args.vfs, args.cache_dir, scratch, args.refresh)
                end,
                catch {
                    function (errors)
                        local message = tostring(errors):gsub("%s+$", "")
                        found = {error = string.format("the header walk failed on %s: error: %s", framework, message),
                                 rows = {}, flags = {}, compiled = {}, failed = {}, headers = 0}
                        cached = true
                        note(string.format("  %s: %s", framework, message))
                    end
                }
            }
            indexes[framework] = found
            dumped = dumped + 1
            if not cached then
                walked = walked + 1
            end
            if dumped % 20 == 0 or dumped == #frameworks then
                note(string.format("  %d/%d frameworks (%d walked, %d from cache, %.0fs elapsed)", dumped, #frameworks, walked, dumped - walked,
                                   (os.mclock() - started) / 1000))
            end
        end, {total = #frameworks, comax = math.max(1, args.jobs)})
    end
    local header_seconds = (os.mclock() - header_started) / 1000
    surface_walk.cleanup()

    for _, row in ipairs(deferred) do
        local status, reason, introduced, needs = ledger_classify.classify_from_headers(row.api, row, indexes[row.framework], args.release,
                                                                                        built_exports, release_exports)
        table.insert(results, {row, status, reason, introduced, needs})
    end
    local elapsed = (os.mclock() - started) / 1000
    if swift then
        local again = ledger_swift.resolve_swift_coverage(results, swift, matched)
        note(string.format("coverage branch: %d frameworks placed a row, %d rows re-classified as measured absent", count_keys(matched), again))
    end
    local summary, written = ledger_output.write_output(results, args, elapsed, indexes, walked, header_seconds, swift)
    note(string.format("wrote %s and %d per-framework todo files in %.1f minutes", summary, written, elapsed / 60.0))
    return results, indexes
end

function main(command, ...)
    if command ~= "build" then
        raise("api-ledger: the one command is build\n%s", USAGE)
    end
    build(parse({...}))
end
