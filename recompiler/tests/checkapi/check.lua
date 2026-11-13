-- Every check script reaches the recompiler's tool modules (corpus, translate, env) through a local alias
-- (`local corpus = import("corpus", {rootdir = <tools>})`). A call `corpus.name(` to a function the module does not define
-- fails only when that script runs, and some scripts run only on a phone (the device group), so a rename in a module can leave a
-- caller broken for weeks. This check reads the scripts and the modules and compares the names, with no phone and no build.

local function defined(module)
    local names = {}
    for _, line in ipairs(io.readfile(module):split("\n", {plain = true})) do
        local name = line:match("^function ([%w_]+)%s*%(")
        if name then
            names[name] = true
        end
    end
    return names
end

function main()
    local tools = path.join(os.scriptdir(), "..", "..", "tools")
    local tests = path.join(os.scriptdir(), "..")
    local modules, errors, checked = {}, {}, 0
    for _, script in ipairs(os.files(path.join(tests, "*", "check.lua"))) do
        local text = io.readfile(script)
        for alias, module in text:gmatch('local ([%w_]+) = import%("([%w_]+)", {rootdir = path%.join%(os%.scriptdir%(%), "%.%.", "%.%.", "tools"%)') do
            local file = path.join(tools, module .. ".lua")
            if not os.isfile(file) then
                table.insert(errors, string.format("%s imports %s, which is not in %s", path.relative(script, tests), module, path.relative(tools, tests)))
            else
                modules[module] = modules[module] or defined(file)
                for call in text:gmatch(alias:gsub("%p", "%%%0") .. "%.([%w_]+)%(") do
                    checked = checked + 1
                    if not modules[module][call] then
                        table.insert(errors, string.format("%s calls %s.%s, which %s.lua does not define", path.relative(script, tests), alias, call, module))
                    end
                end
            end
        end
    end
    if checked == 0 then
        raise("checkapi found no call of a tool module in the check scripts: the pattern that reads them no longer matches")
    end
    if #errors > 0 then
        table.sort(errors)
        raise("%d dangling call(s) from check scripts to the tool modules:\n  %s", #errors, table.concat(errors, "\n  "))
    end
    print("ok: %d calls from the check scripts to the tool modules all name a function the module defines", checked)
end
