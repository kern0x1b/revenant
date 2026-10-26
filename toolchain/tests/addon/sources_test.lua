function failures(opt)
    local sources = import("apple.sources", {rootdir = opt.modules, anonymous = true})
    local root = path.join(opt.modules, "..", "tests", "data", "sources")
    local found = {}
    local cases = {
        {pattern = "src/*.cc", expect = "src/a.cc src/b.cc src/test_a.cc src/test_b.cc"},
        {pattern = "src/*.cc|test*.cc", expect = "src/a.cc src/b.cc"},
        {pattern = "src/*.cc|test*.cc|b.cc", expect = "src/a.cc"}
    }
    for _, case in ipairs(cases) do
        local names = {}
        for _, file in ipairs(sources.collect("sources", root, {case.pattern})) do
            table.insert(names, path.relative(file, root))
        end
        table.sort(names)
        if table.concat(names, " ") ~= case.expect then
            table.insert(found, string.format("%s matches %s, not %s", case.pattern, table.concat(names, " "), case.expect))
        end
    end
    for _, pattern in ipairs({"src/*.mm", "src/*.cc|*.cc"}) do
        local raised = false
        try {
            function ()
                sources.collect("sources", root, {pattern})
            end,
            catch {
                function ()
                    raised = true
                end
            }
        }
        if not raised then
            table.insert(found, pattern .. " must raise when it matches no file")
        end
    end
    return found
end
