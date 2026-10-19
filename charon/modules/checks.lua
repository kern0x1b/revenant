function pattern(glob)
    local escaped = glob:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0")
    escaped = escaped:gsub("%*%*/", "\001"):gsub("%*%*", "\002"):gsub("%*", "[^/]*"):gsub("%?", "[^/]")
    escaped = escaped:gsub("\001", ".-/?"):gsub("\002", ".*")
    return "^" .. escaped .. "$"
end

function matching(files, globs)
    local found = {}
    for _, file in ipairs(files) do
        for _, glob in ipairs(globs) do
            if file:match(pattern(glob)) then
                table.insert(found, file)
                break
            end
        end
    end
    return found
end

local interpreters = {[".py"] = {"python3"}, [".sh"] = {"bash"}, [".rb"] = {"ruby"}, [".pl"] = {"perl"}, [".js"] = {"node"}}

function command(target)
    local script = table.wrap(target:values("check.script"))
    if #script > 0 then
        local interpreter = interpreters[path.extension(script[1])]
        if not interpreter then
            raise("target(%s): check.script %s has no interpreter Charon knows by its extension; use check.command", target:name(), script[1])
        end
        return table.join(interpreter, script)
    end
    local declared = table.wrap(target:values("check.command"))
    if #declared == 0 then
        raise("target(%s) is a check without check.script or check.command", target:name())
    end
    return declared
end

function tracked()
    local files = {}
    for line in os.iorunv("git", {"-C", os.projectdir(), "ls-files"}):gmatch("[^\n]+") do
        table.insert(files, line)
    end
    return files
end

function changed(opt)
    local argv = opt.staged and {"diff", "--cached", "--name-only", "--diff-filter=ACMR"} or {"diff", "--name-only", "--diff-filter=ACMR", "HEAD"}
    local listed = os.iorunv("git", table.join({"-C", os.projectdir()}, argv))
    local files = {}
    for line in listed:gmatch("[^\n]+") do
        table.insert(files, line)
    end
    return files
end

function run(targets, opt)
    opt = opt or {}
    local scoped = opt.staged or opt.changed
    local files = opt.files or (scoped and changed(opt) or tracked())
    local failed, ran = {}, 0
    for _, target in ipairs(targets) do
        local argv0 = command(target)
        local globs = table.wrap(target:values("check.files"))
        local selected = #globs > 0 and matching(files, globs) or files
        local needed = #selected > 0 or (not scoped and not target:values("check.needs-files"))
        if needed then
            local argv = table.slice(argv0, 2)
            if target:values("check.pass-files") then
                table.join2(argv, selected)
            end
            ran = ran + 1
            local ok = try { function ()
                os.execv(argv0[1], argv, {curdir = os.projectdir()})
                return true
            end }
            if ok then
                cprint("${bright green}check${clear} %s", target:name())
            else
                cprint("${bright red}check${clear} %s failed", target:name())
                table.insert(failed, target:name())
            end
        end
    end
    return ran, failed
end
