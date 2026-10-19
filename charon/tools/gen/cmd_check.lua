-- `check`: regenerates a framework in memory from its committed inputs (the shard, the overrides, the pins and the constant record) and
-- compares the result with the build directory .gen. A drift of the build directory, a stale pin (a pinned member whose declaration
-- differs from its pin), a protocol-set record that names a protocol a registry row implements, or a constants object the generator
-- no longer emits fails the check. A build directory not yet written is a warning, so a fresh checkout checks with no derived file
-- present; a removed override (a registry override the spec no longer holds) is a warning too, and not a failure: the backports exist
-- for exactly the APIs that 26.2 has removed or deprecated but 6.1.3 carries, so the spec does not hold them by design. Each framework's
-- count is on its summary line, and the total is a ceiling the light guard holds (tests/gen/removed_ceiling_test.lua reads
-- tests/gen/removed-overrides.tsv: a total that grows is a failure). A run that finds no framework to check fails: a check that checked
-- nothing is not a pass (review r4 G11; coordinator ruling G11). The registry's targets are checked against their shards too
-- (targets.problems): an umbrella's entries through its nested targets (no-shard.tsv), a product's members through their shards
-- (products.tsv). The gate's half, that the built dylibs export them, is check_registry and needs those dylibs. A constants.tsv that
-- holds no rows fails (input writes none for a framework with no constant), and the snapshots protocols.tsv and functions.tsv are held
-- to their pins in spec/snapshots.tsv (snapshot_pins), so a clean checkout checks them with no build directory.

local layout = import("layout", {anonymous = true})
local snapshot = import("spec", {anonymous = true})
local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local order = import("order", {anonymous = true})
local surface = import("surface", {anonymous = true})
local protocols = import("protocols", {anonymous = true})
local target_checks = import("targets", {anonymous = true})
local gen = import("cmd_gen", {anonymous = true})
local snapshot_pins = import("snapshot_pins", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})

-- The data lines of a table's text: every line after the header that is not empty.
local function data_lines(text)
    local out = {}
    local all = tsv.lines(text)
    for i = 2, #all do
        if all[i] ~= "" then
            table.insert(out, all[i])
        end
    end
    return out
end

-- The problem of a constant record that holds no rows, or nil. input writes no record for a framework with no constant, so a file of
-- that kind is stale (Round 14, decision 1).
function constant_record_problem(tree, fw)
    local text = files.read_text(layout.constant_record_path(tree, fw))
    if text ~= nil and #data_lines(text) == 0 then
        return "constants.tsv holds no rows: input writes no record for a framework with no constant (remove the file)"
    end
    return nil
end

-- The protocols the protocol-set record of a framework names that a registry row implements, sorted. The rule (protocols.rule_set)
-- names only protocols no registry row implements, so such a record is a contradiction; this check needs no corpus (review r4 F16).
function record_conflicts(tree, fw)
    local registry = surface.registry_entries(tree, fw)
    local out = {}
    for name in pairs(protocols.recorded_set(tree, fw)) do
        if registry[name] ~= nil then
            table.insert(out, name)
        end
    end
    table.sort(out, order.less)
    return out
end

-- The problems and warnings of one framework, in the order the report prints them.
local function diagnose(tree, fw, corpus, sdk_release)
    local emitted = gen.derived(tree, fw, corpus, sdk_release)
    local base = layout.gen_dir(tree, fw)
    local names = order.keys(emitted)
    local problems, warnings = {}, {}
    for _, name in ipairs(names) do
        local text = files.read_text(path.join(base, name))
        if text == nil then
            table.insert(warnings, "not in the build directory yet: " .. name .. " (run gen)")
        elseif text ~= emitted[name] then
            table.insert(problems, "build directory differs from the generator: " .. name)
        end
    end
    for _, name in ipairs(gen.stale_constants(base, fw, emitted)) do
        table.insert(problems, "build directory holds a constants object the generator no longer emits: " .. name)
    end
    local defined = {}
    for key in string.gmatch(emitted["spec.h"], "CHARON_SPEC_HASH_([%w_]+)") do
        defined[key] = true
    end
    for _, r in ipairs(snapshot.load(tree, fw)) do
        if not defined[r.key] then
            table.insert(problems, "spec member without a hash define: " .. r.api)
        end
    end
    for _, name in ipairs(record_conflicts(tree, fw)) do
        table.insert(problems, "protocol-set record names a protocol a registry row implements: " .. name)
    end
    local rows_problem = constant_record_problem(tree, fw)
    if rows_problem ~= nil then
        table.insert(problems, rows_problem)
    end
    local stale = data_lines(emitted["stale.tsv"])
    local removed = data_lines(emitted["removed.tsv"])
    local new = data_lines(emitted["new.tsv"])
    for _, line in ipairs(stale) do
        table.insert(problems, "stale pin: " .. string.gsub(line, "\t", "  "))
    end
    for _, line in ipairs(removed) do
        table.insert(warnings, "removed override: " .. string.gsub(line, "\t", "  "))
    end
    return problems, warnings, #removed, #new
end

-- The removed-override count of each framework that has one (framework -> count), and their total, with no output: the numbers the
-- light guard holds to the committed ceiling.
function removed_counts(tree, sdk_release)
    snapshot.forget()
    local counts, total = {}, 0
    for _, fw in ipairs(snapshot.frameworks(tree)) do
        local _, _, removed = diagnose(tree, fw, nil, sdk_release)
        if removed > 0 then
            counts[fw] = removed
            total = total + removed
        end
    end
    return counts, total
end

-- Returns the exit status: 1 when any framework has a problem, or when there is no framework to check.
function run(args)
    assert(args.sdk, "check needs --sdk: the iPhoneOS SDK whose release names the spec file")
    local sdk_release = sdk_info.discover(args.sdk).version
    snapshot.forget()
    local targets = args.all and snapshot.frameworks(args.tree) or {args.framework}
    if #targets == 0 then
        print("CHECK: no framework to check in " .. args.tree)
        return 1
    end
    local failed, removed_total, removed_in = 0, 0, 0
    for _, fw in ipairs(targets) do
        local problems, warnings, removed, new = diagnose(args.tree, fw, args.coordination, sdk_release)
        for _, line in ipairs(problems) do
            print("CHECK " .. fw .. ": " .. line)
        end
        for _, line in ipairs(warnings) do
            print("WARN " .. fw .. ": " .. line)
        end
        print(string.format("check %s: problems %d, removed overrides (warned) %d, members without an override (new) %d",
            fw, #problems, removed, new))
        removed_total = removed_total + removed
        if removed > 0 then
            removed_in = removed_in + 1
        end
        if #problems > 0 then
            failed = failed + 1
        end
    end
    print(string.format("check: removed overrides (warned) %d in %d frameworks (the ceiling is tests/gen/removed-overrides.tsv)",
        removed_total, removed_in))
    local target_problems = target_checks.problems(args.tree)
    for _, line in ipairs(target_problems) do
        print("CHECK targets: " .. line)
    end
    local snapshot_problems = snapshot_pins.pin_problems(args.tree)
    for _, line in ipairs(snapshot_problems) do
        print("CHECK snapshots: " .. line)
    end
    return (failed > 0 or #target_problems > 0 or #snapshot_problems > 0) and 1 or 0
end
