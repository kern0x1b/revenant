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

function constant_record_problem(tree, fw)
    local text = files.read_text(layout.constant_record_path(tree, fw))
    if text ~= nil and #data_lines(text) == 0 then
        return "constants.tsv holds no rows: input writes no record for a framework with no constant (remove the file)"
    end
    return nil
end

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
