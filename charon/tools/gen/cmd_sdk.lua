local function heavy_folder_of(coordination)
    return path.directory(coordination)
end

local function steps(args)
    local out = {}
    table.insert(out, {name = "ir", run = function(step_args)
        os.mkdir(path.join(args.out, "ir"))
        os.execv("xmake", {"l", path.join(step_args.tree, "tools", "found", "ir.lua")},
                 {envs = {IR_SDK = step_args.sdk, IR_FULL = path.join(args.out, "ir", "full.tsv")}})
        return 0
    end})
    table.insert(out, {name = "portvalues", run = function(step_args)
        os.execv("xmake", {"l", path.join(step_args.tree, "tools", "found", "port_values.lua")},
                 {envs = {IR_SDK = step_args.sdk, IR_PORT_VALUES = path.join(args.out, "ir", "port-values.tsv")}})
        return 0
    end})
    table.insert(out, {name = "swiftshard", run = function(step_args)
        return import("cmd_swiftshard", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "input", run = function(step_args)
        return import("cmd_input", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "functions", run = function(step_args)
        return import("cmd_functions", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "protocols", run = function(step_args)
        return import("cmd_protocols", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "gen", run = function(step_args)
        return import("cmd_gen", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "trace", run = function(step_args)
        return import("cmd_trace", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "swift", run = function(step_args)
        return import("cmd_swift", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "swiftcode", run = function(step_args)
        step_args.out = path.join(args.out, "swift")
        step_args.coordination = heavy_folder_of(step_args.coordination)
        return import("cmd_swiftcode", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "scope", run = function(step_args)
        step_args.out = path.join(args.out, "scope")
        step_args.swift_rendered = path.join(args.out, "swift")
        return import("cmd_scope", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "headers", run = function(step_args)
        step_args.ir = path.join(args.out, "ir", "full.tsv")
        step_args.port_values = path.join(args.out, "ir", "port-values.tsv")
        step_args.out = path.join(args.out, "headers")
        return import("cmd_headers", {anonymous = true}).run(step_args)
    end})
    table.insert(out, {name = "worklist", run = function(step_args)
        step_args.out = path.join(args.out, "worklist")
        step_args.scope = path.join(args.out, "scope", "v-gen-scope.tsv")
        step_args.swift_rendered = path.join(args.out, "swift")
        return import("worklist", {anonymous = true}).run(step_args)
    end})
    if args.verify then
        table.insert(out, {name = "verify", run = function(step_args)
            step_args.ir = path.join(args.out, "ir", "full.tsv")
            step_args.headers = path.join(args.out, "headers")
            step_args.out = path.join(args.out, "verify")
            step_args.coordination = heavy_folder_of(step_args.coordination)
            return import("verify", {anonymous = true}).run(step_args)
        end})
    end
    if args.doc then
        table.insert(out, {name = "doc", run = function(step_args)
            step_args.out = path.join(args.out, "doc")
            return import("cmd_doc", {anonymous = true}).run(step_args)
        end})
    end
    return out
end

local injected = nil

function use(list)
    injected = list
end

function plan(args)
    return injected or steps(args)
end

local function step_args_of(args)
    local out = {}
    for key, value in pairs(args) do
        out[key] = value
    end
    out.all = true
    out.framework = nil
    return out
end

function run(args)
    assert(args.sdk, "sdk needs --sdk: the iPhoneOS SDK the pipeline reads")
    assert(args.coordination, "sdk needs --coordination: the corpus folder (the surface table, the ledgers and the iOS constants)")
    assert(args.out, "sdk needs --out: the folder scope (and doc, with --doc) write to")
    args.sdk = path.absolute(args.sdk)
    args.tree = path.absolute(args.tree)
    local list = plan(args)
    local total_started = os.mclock()
    for _, step in ipairs(list) do
        local started = os.mclock()
        local status, detail, failure = 1, nil, nil
        try {
            function()
                status, detail = step.run(step_args_of(args))
            end,
            catch {
                function(e)
                    failure = e
                end
            }
        }
        local seconds = (os.mclock() - started) / 1000
        if failure ~= nil then
            print(string.format("sdk: %s failed after %.1fs: %s", step.name, seconds, tostring(failure)))
            return 1
        end
        if status ~= 0 then
            print(string.format("sdk: %s failed after %.1fs: exit status %s%s", step.name, seconds, tostring(status),
                                detail and (": " .. detail) or ""))
            return 1
        end
        print(string.format("sdk: %s %.1fs%s", step.name, seconds, detail and (": " .. detail) or ""))
    end
    print(string.format("sdk: %d steps in %.1fs", #list, (os.mclock() - total_started) / 1000))
    return 0
end
