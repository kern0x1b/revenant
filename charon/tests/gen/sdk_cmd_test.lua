local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local cmd = import("gen.cmd_sdk", {rootdir = TOOLS, anonymous = true})
    local args = {sdk = path.join(ROOT, "tests", "gen", "sdk_fixture", "release-26.2"), tree = ROOT, coordination = ROOT, out = ROOT}

    cmd.use(nil)
    local names = {}
    for _, step in ipairs(cmd.plan(args)) do
        table.insert(names, step.name)
    end
    check(table.concat(names, ",") == "ir,portvalues,swiftshard,input,functions,protocols,gen,trace,swift,swiftcode,scope,headers,worklist",
          "the pipeline's steps in order: " .. table.concat(names, ","))
    args.doc = true
    names = {}
    for _, step in ipairs(cmd.plan(args)) do
        table.insert(names, step.name)
    end
    check(names[#names] == "doc" and #names == 14, "--doc adds doc last: " .. table.concat(names, ","))
    args.doc = nil
    args.verify = true
    names = {}
    for _, step in ipairs(cmd.plan(args)) do
        table.insert(names, step.name)
    end
    check(#names == 14 and names[13] == "worklist" and names[14] == "verify",
          "--verify adds verify after the work list: " .. table.concat(names, ","))
    args.verify = nil
    for _, module in ipairs({"worklist", "verify"}) do
        local loaded = import("gen." .. module, {rootdir = TOOLS, anonymous = true})
        check(type(loaded.run) == "function", module .. " loads and has run")
    end

    local ran = {}
    local function recording(name, status)
        return {name = name, run = function()
            table.insert(ran, name)
            return status
        end}
    end
    cmd.use({recording("a", 0), recording("b", 0)})
    check(cmd.run(args) == 0 and table.concat(ran, ",") == "a,b", "every step runs and the run is 0")

    ran = {}
    cmd.use({recording("a", 0), recording("b", 3), recording("c", 0)})
    check(cmd.run(args) == 1, "a failing step makes the run 1")
    check(table.concat(ran, ",") == "a,b", "the run stops at the failing step: " .. table.concat(ran, ","))

    ran = {}
    local raising = {name = "b", run = function()
        table.insert(ran, "b")
        raise("the step broke")
    end}
    cmd.use({recording("a", 0), raising, recording("c", 0)})
    check(cmd.run(args) == 1, "a raising step makes the run 1")
    check(table.concat(ran, ",") == "a,b", "the run stops at the raising step: " .. table.concat(ran, ","))

    cmd.use(nil)
    local message = nil
    try {
        function()
            cmd.run({sdk = args.sdk, tree = ROOT, coordination = ROOT})
        end,
        catch {
            function(errors)
                message = tostring(errors)
            end
        }
    }
    check(message ~= nil and string.find(message, "sdk needs --out", 1, true) ~= nil, "a run without --out fails naming it: " .. tostring(message))

    print("sdk command test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)) .. " (" .. count .. " checks)")
    if failures > 0 then
        os.exit(1)
    end
end
