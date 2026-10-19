function failures(opt)
    local checks = import("checks", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local files = {"src/App/AppDelegate.m", "src/App/AppDelegate.h", "scripts/lint.py", "README.md", "tests/support/shim.m"}
    for _, case in ipairs({
            {{"src/**.m"}, {"src/App/AppDelegate.m"}},
            {{"**/*.m"}, {"src/App/AppDelegate.m", "tests/support/shim.m"}},
            {{"*.md"}, {"README.md"}},
            {{"scripts/*.py", "src/**/*.h"}, {"src/App/AppDelegate.h", "scripts/lint.py"}},
            {{"src/*.m"}, {}}}) do
        local got = checks.matching(files, case[1])
        if table.concat(got, ",") ~= table.concat(case[2], ",") then
            table.insert(found, string.format("%s selects %s, not %s", table.concat(case[1], " "), table.concat(got, ","), table.concat(case[2], ",")))
        end
    end
    return found
end
