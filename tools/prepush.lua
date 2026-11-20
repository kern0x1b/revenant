local bytes = import("core.base.bytes")

local root = path.absolute(path.directory(os.scriptdir()))

local CODE = {m = true, mm = true, c = true, cpp = true}

local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

local byteorder = import("@addon.revenant.byteorder", {anonymous = true})

local function digest(text)
    return hash.sha256(bytes(text))
end

local function git(folder, args)
    return os.iorunv("git", table.join({"-C", folder}, args))
end

local function tracked(pattern)
    local files = {}
    for file in git(root, {"ls-files", "--", pattern}):gmatch("[^\n]+") do
        table.insert(files, file)
    end
    return files
end

local GATE_JOBS = 6
local GATE_LINES = 30
local GATE_EXCLUDES = {"/.git", "/.xmake", "/build", "/.cache", "/.cache-private", "/.cache-boot", "/.claude/worktrees"}

local function budgeted(command, opt)
    opt = opt or {}
    local args = table.join({"l", "-P", root, path.join(root, "tools", "budget.lua"), "run", "--class", "critical", "--jobs", tostring(opt.jobs or 2), "--"}, command)
    return os.execv(os.programfile(), args, {try = true, curdir = opt.curdir or root, envs = opt.envs, stdout = opt.output, stderr = opt.output}) == 0
end

local function gate_folder()
    return path.join(root, "build", "backports-gate")
end

local function gate_tree(folder)
    return path.join(folder, "tree")
end

local function gate_environment()
    return {
        REVENANT_PREBUILT = os.getenv("REVENANT_PREBUILT") or "kern0x1b/revenant",
        REVENANT_PREBUILT_ONLY = os.getenv("REVENANT_PREBUILT_ONLY") or "llvm,swift,ld64",
    }
end

local function gate_ignored(folder)
    local lines = {}
    for entry in git(folder, {"ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z"}):gmatch("[^\0]+") do
        table.insert(lines, "/" .. entry:gsub("([%*%?%[\\])", "\\%1"))
    end
    return table.concat(lines, "\n") .. "\n"
end

local function gate_sync_arguments(tree, ignored)
    local args = {"-a", "--delete"}
    for _, pattern in ipairs(GATE_EXCLUDES) do
        table.insert(args, "--exclude=" .. pattern)
    end
    if ignored then
        table.insert(args, "--exclude-from=" .. ignored)
    end
    table.insert(args, root .. "/")
    table.insert(args, tree .. "/")
    return args
end

local function gate_commands(tree)
    return {
        {os.programfile(), "f", "-P", tree, "-p", "iphoneos", "-a", "armv7", "--component=Backports", "-y"},
        {os.programfile(), "build", "-P", tree, "-y"},
    }
end

local function failure_lines(text)
    local report = import("ci.log", {rootdir = os.scriptdir()}).report(text)
    local lines = {}
    for _, found in ipairs(report.modules) do
        table.insert(lines, "swiftc failed for " .. found.module)
        table.join2(lines, found.diagnostics)
    end
    for _, name in ipairs(report.failed) do
        table.insert(lines, "failed: " .. name)
    end
    table.join2(lines, report.errors)
    if #lines == 0 then
        local tail = {}
        for line in text:gmatch("[^\n]+") do
            table.insert(tail, line)
        end
        for index = math.max(1, #tail - GATE_LINES + 1), #tail do
            table.insert(lines, tail[index])
        end
    end
    return lines
end

local function explain_failure(logfile)
    local lines = failure_lines(io.readfile(logfile))
    for index = 1, math.min(#lines, GATE_LINES) do
        print("%s", lines[index])
    end
    if #lines > GATE_LINES then
        print("... %d more", #lines - GATE_LINES)
    end
    print("the Backports build failed; the whole log is %s", logfile)
end

local function backports_build()
    local folder = gate_folder()
    local tree = gate_tree(folder)
    local logfile = path.join(folder, "prepush.log")
    os.mkdir(tree)
    local output = io.open(logfile, "w")
    local ignored = path.join(folder, "ignored.txt")
    io.writefile(ignored, gate_ignored(root))
    local ok = os.execv("rsync", gate_sync_arguments(tree, ignored), {try = true, stdout = output, stderr = output}) == 0
    if ok then
        for _, command in ipairs(gate_commands(tree)) do
            if not budgeted(command, {jobs = GATE_JOBS, curdir = tree, envs = gate_environment(), output = output}) then
                ok = false
                break
            end
        end
    end
    output:close()
    if not ok then
        explain_failure(logfile)
    end
    return ok
end

local function lua(script, ...)
    return budgeted(table.join({os.programfile(), "l", "-P", root, path.join(root, script)}, {...}))
end

local function declared(xmake, name)
    return xmake:find("[%s{,]" .. name .. " = {") ~= nil
end

local function backports_negative()
    local xmake = io.readfile(path.join(root, "frameworks", "Backports", "xmake.lua"))
    local files = {}
    for _, file in ipairs(tracked("frameworks/Backports/tests")) do
        local stem, extension = file:match("([%w_]+)_test%.(%w+)$")
        if stem and CODE[extension] and declared(xmake, stem) then
            table.insert(files, file)
        end
    end
    return files
end

local function emulator_negative(xmake)
    local files = {}
    for block in xmake:gmatch("target%(.-target_end%(%)") do
        if block:find('add_tests("negative"', 1, true) then
            for file in block:gmatch('add_files%("([^"]+)"%)') do
                table.insert(files, path.join("emulator", file))
            end
        end
    end
    return files
end

local function shape(file, text)
    local errors = {}
    if not text:find("revenant_read_arguments(", 1, true) and not text:find('"--negative"', 1, true) then
        table.insert(errors, file .. " never reads --negative, so its negative run is its positive run")
    end
    if text:find('"check.h"', 1, true) and not text:find("return revenant_finish()", 1, true) then
        table.insert(errors, file .. " uses check.h but does not return revenant_finish(), so a failed check exits 0")
    end
    return errors
end

local function negative_errors()
    local emulator = io.readfile(path.join(root, "emulator", "xmake.lua"))
    local errors = {}
    for _, file in ipairs(table.join(backports_negative(), emulator_negative(emulator))) do
        for _, message in ipairs(shape(file, io.readfile(path.join(root, file)))) do
            table.insert(errors, message)
        end
    end
    return errors
end

local function negative_shape()
    local errors = negative_errors()
    for _, message in ipairs(errors) do
        print(message)
    end
    return #errors == 0
end

local MEMO_VERSION = "prepush memo 3"
local MEMO_KEEP = 40
local TOOLS = {"toolchain/modules/", "toolchain/addon.lua", "xmake.lua"}
local UNBUILT = {"docs/**", "**/*.md", ".agents/**", "agent-skills/**"}
local PREBUILT_ENV = {"REVENANT_PREBUILT", "REVENANT_PREBUILT_ONLY"}
local ALWAYS = {"tools/prepush.lua", "tools/budget.lua"}
local AMBIENT_SKIPS = {REVENANT_CACHE = true, REVENANT_BUDGET_POOL = true, REVENANT_BUDGET_PATIENCE = true, REVENANT_BUDGET_HELD = true, REVENANT_BUDGET_DISK_GB = true, REVENANT_LIGHT_SUITES_VERDICT = true}
local STORE_PACKAGES = {"llvm", "swift", "swift-bootstrap", "swift-runtime", "libcxx", "apple-compat", "iphoneos-sdk", "ld64", "ldid"}
local TOOL_NAMES = {"git", "rsync", "cmake", "ninja", "xcrun", "clang", "cc", "make", "sh"}

local function call(script, ...)
    local arguments = table.pack(...)
    local ok = true
    try {
        function ()
            import(path.basename(script), {rootdir = path.join(root, path.directory(script)), anonymous = true}).main(table.unpack(arguments, 1, arguments.n))
        end,
        catch {
            function (errors)
                print("%s", tostring(errors))
                ok = false
            end
        }
    }
    return ok
end

local function digests_stable(runner)
    if not runner("toolchain/tools/recipe_digests.lua") then
        return false
    end
    local stable = true
    for line in git(root, {"status", "--porcelain", "--untracked-files=no", "--", "packages"}):gmatch("[^\n]+") do
        if line:find("/port/digest.lua$") then
            print("regenerated digest differs from the committed one: %s", line:sub(4))
            stable = false
        end
    end
    return stable
end

local function digest_reads()
    local reads = {"toolchain/tools/recipe_digests.lua", "packages/*/*/port/digest.lua"}
    table.join2(reads, TOOLS)
    for _, recipe in ipairs(import("@addon.revenant.digest", {anonymous = true}).recipes()) do
        table.join2(reads, recipe.inputs)
    end
    return reads
end

local facts_text

local function toolchain_facts()
    if not facts_text then
        local facts = {}
        for _, probe in ipairs({{"xcode-select", {"-p"}}, {"xcodebuild", {"-version"}}, {"xcrun", {"--show-sdk-path"}}, {"xcrun", {"--show-sdk-version"}}}) do
            table.insert(facts, try { function () return (os.iorunv(probe[1], probe[2]):gsub("%s+", " ")) end } or "none")
        end
        facts_text = table.concat(facts, "\n")
    end
    return facts_text
end

local function sorted(lines)
    byteorder.sort(lines)
    return lines
end

local function ambient_environment()
    local lines = {}
    for name, value in pairs(os.getenvs()) do
        if (name:find("^REVENANT_") or name == "XMAKE_GLOBALDIR") and not AMBIENT_SKIPS[name] and value ~= "" then
            table.insert(lines, name .. "=" .. value)
        end
    end
    return table.concat(sorted(lines), "\n")
end

local function attributes_facts(folder)
    local locations = {path.join(folder, (git(folder, {"rev-parse", "--git-path", "info/attributes"}):trim()))}
    local configured = try { function () return git(folder, {"config", "--get", "core.attributesFile"}):trim() end }
    if configured and configured ~= "" then
        table.insert(locations, (configured:gsub("^~/", (os.getenv("HOME") or "") .. "/")))
    else
        table.insert(locations, path.join(os.getenv("XDG_CONFIG_HOME") or path.join(os.getenv("HOME") or "", ".config"), "git", "attributes"))
    end
    local lines = {}
    for index, file in ipairs(locations) do
        table.insert(lines, (index == 1 and "local " or "global ") .. (os.isfile(file) and hash.sha256(file) or "none"))
    end
    return table.concat(lines, "\n")
end

local function packages_folder()
    return path.join(cache().store(), "xmake-global", ".xmake", "packages")
end

local function store_installs()
    local lines = {}
    local packages = packages_folder()
    for _, name in ipairs(STORE_PACKAGES) do
        for _, install in ipairs(os.filedirs(path.join(packages, name:sub(1, 1), name, "*", "*"))) do
            local line = path.relative(install, packages)
            if os.islink(install) then
                line = line .. " -> " .. path.filename(os.readlink(install))
            end
            local manifest = path.join(install, "manifest.txt")
            table.insert(lines, line .. " " .. (os.isfile(manifest) and hash.sha256(manifest) or "no manifest"))
        end
    end
    return table.concat(sorted(lines), "\n")
end

local function sdk_content()
    local sdk = import("sdk", {rootdir = path.join(root, "frameworks", "Backports", "tools"), anonymous = true})
    local pattern = path.join(packages_folder(), "i", "iphoneos-sdk", "*", "*", "Developer.app", "Contents", "Developer", "Platforms",
                              "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk")
    local seen, lines = {}, {}
    for _, folder in ipairs(os.dirs(pattern)) do
        local real = os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
        if not seen[real] then
            seen[real] = true
            table.insert(lines, try { function () return sdk.cache_key(real) end } or "unreadable")
        end
    end
    return table.concat(sorted(lines), "\n")
end

local function resolved_tools()
    local lines = {}
    for _, name in ipairs(TOOL_NAMES) do
        local found = try { function () return os.iorunv("sh", {"-c", "command -v " .. name}):trim() end } or "none"
        local version = try { function () return os.iorunv("sh", {"-c", name .. " --version 2>&1 | head -n 1"}):trim() end } or ""
        table.insert(lines, name .. "=" .. found .. " " .. version)
    end
    return table.concat(lines, "\n")
end

local installed_text

local function installed_facts()
    if not installed_text then
        installed_text = table.concat({toolchain_facts(), resolved_tools(), store_installs(), sdk_content()}, "\n--\n")
    end
    return installed_text
end

local function dirty_entries(folder)
    local tokens, entries = {}, {}
    for token in git(folder, {"status", "--porcelain=v1", "--untracked-files=all", "-z"}):gmatch("[^\0]+") do
        table.insert(tokens, token)
    end
    local index = 1
    while index <= #tokens do
        local status = tokens[index]:sub(1, 2)
        table.insert(entries, {status = status, file = tokens[index]:sub(4)})
        if status:find("[RC]") then
            index = index + 1
        end
        index = index + 1
    end
    return entries
end

local function manifest(folder)
    local current = {}
    for line in git(folder, {"ls-files", "-s"}):gmatch("[^\n]+") do
        local mode, sha, file = line:match("^(%d+) (%x+) %d\t(.+)$")
        current[file] = mode .. " " .. sha
    end
    local pending = {}
    for _, entry in ipairs(dirty_entries(folder)) do
        local full = path.join(folder, entry.file)
        if os.islink(full) then
            current[entry.file] = "link " .. os.readlink(full)
        elseif os.isfile(full) then
            table.insert(pending, entry.file)
        else
            current[entry.file] = "deleted"
        end
    end
    if #pending > 0 then
        local digests = {}
        for line in git(folder, table.join({"hash-object", "--"}, pending)):gmatch("[^\n]+") do
            table.insert(digests, line)
        end
        for index, file in ipairs(pending) do
            current[file] = "file " .. digests[index]
        end
    end
    return current
end

local compiled = {}

local function pattern_of(glob)
    local found = compiled[glob]
    if not found then
        local escaped = glob:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0")
        if escaped:endswith("/") then
            found = "^" .. escaped .. ".*$"
        else
            local wide = escaped:gsub("%*%*/", "\1"):gsub("%*%*", "\1"):gsub("%*", "[^/]*")
            found = "^" .. wide:gsub("\1", ".*") .. "$"
        end
        compiled[glob] = found
    end
    return found
end

local function matches(file, globs)
    for _, glob in ipairs(globs) do
        if file:match(pattern_of(glob)) then
            return true
        end
    end
    return false
end

local function reads_of(step)
    local reads = step.reads
    if type(reads) == "function" then
        reads = reads()
    end
    return reads or {"**"}
end

local function selected(files, step)
    local reads = reads_of(step)
    local lines = {}
    for file, value in pairs(files) do
        if (matches(file, reads) and not matches(file, step.skips or {})) or matches(file, ALWAYS) then
            table.insert(lines, file .. " " .. value)
        end
    end
    return sorted(lines)
end

local function environment_of(step)
    local values = {}
    for _, name in ipairs(step.env or {}) do
        table.insert(values, name .. "=" .. (os.getenv(name) or ""))
    end
    return table.concat(values, "\n")
end

local function inputs(folder)
    return {
        files = manifest(folder),
        tool = digest(os.iorunv(os.programfile(), {"--version"})),
        host = os.host() .. "/" .. os.arch(),
    }
end

local function key_of(input, step)
    local facts = step.facts and step.facts() or ""
    return digest(table.concat({MEMO_VERSION, step.name, step.version or "1", input.tool, input.host, ambient_environment(), environment_of(step), facts,
                                table.concat(selected(input.files, step), "\n")}, "\n"))
end

local function slug(step)
    return (step.name:gsub("%s+", "-"))
end

local function recalled(store, step, key)
    local file = path.join(store, slug(step), key)
    if not os.isfile(file) then
        return nil
    end
    local record = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        local name, value = line:match("^(%S+) (.*)$")
        if name then
            record[name] = value
        end
    end
    return record.verdict == "ok" and record or nil
end

local function remembered(store, step, key, record)
    local folder = path.join(store, slug(step))
    os.mkdir(folder)
    local lines = {"verdict ok"}
    for _, name in ipairs({"seconds", "worktree", "head", "at"}) do
        table.insert(lines, name .. " " .. tostring(record[name]))
    end
    local temporary = path.join(folder, key .. ".tmp." .. hash.uuid())
    io.writefile(temporary, table.concat(lines, "\n") .. "\n")
    os.mv(temporary, path.join(folder, key))
    local kept = {}
    for _, file in ipairs(os.files(path.join(folder, "*"))) do
        if not file:find(".tmp.", 1, true) then
            table.insert(kept, {file = file, at = os.mtime(file)})
        end
    end
    table.sort(kept, function (a, b) return a.at > b.at end)
    for index = MEMO_KEEP + 1, #kept do
        os.tryrm(kept[index].file)
    end
end

local function age_of(at)
    local seconds = os.time() - (tonumber(at) or os.time())
    if seconds < 90 then
        return string.format("%d s ago", seconds)
    elseif seconds < 5400 then
        return string.format("%d min ago", seconds // 60)
    end
    return string.format("%.1f h ago", seconds / 3600)
end

local function provenance(record)
    return string.format("ran %s s in %s at %s, %s", record.seconds, record.worktree, (record.head or ""):sub(1, 9), age_of(record.at))
end

local function recall_line(store, step, key)
    local record = recalled(store, step, key)
    if record then
        return string.format("recalled %s memo (%s)", step.name, provenance(record))
    end
end

local function recall_report(store, step, key)
    local line = recall_line(store, step, key)
    if line then
        return line .. "\nkey " .. key
    end
end

local function batch(steps, keep_going)
    local results = {}
    for _, step in ipairs(steps) do
        local started = os.time()
        local ok = step.inline()
        print("%s %s %ds", ok and "ok" or "FAIL", step.name, os.time() - started)
        table.insert(results, {name = step.name, ok = ok, seconds = os.time() - started})
        if not ok and not keep_going then
            break
        end
    end
    return results
end

local function run_steps(steps, opt)
    local failed = {}
    local keys, hits, misses = {}, {}, {}
    for _, step in ipairs(steps) do
        keys[step.name] = opt.key and opt.key(step) or nil
        local record = keys[step.name] and not opt.fresh and recalled(opt.store, step, keys[step.name])
        if record then
            hits[step.name] = record
        else
            table.insert(misses, step)
        end
    end
    local record_of = function (step, seconds)
        if keys[step.name] then
            remembered(opt.store, step, keys[step.name], {seconds = seconds, worktree = opt.worktree or "", head = opt.head or "", at = os.time()})
        end
    end
    local grouped = {}
    for _, step in ipairs(misses) do
        if step.inline then
            table.insert(grouped, step)
        end
    end
    local verdicts = {}
    local stopped = false
    for _, step in ipairs(steps) do
        local hit = hits[step.name]
        if stopped then
            break
        elseif hit then
            print("ok %s memo (%s)", step.name, provenance(hit))
        elseif step.inline then
            if not verdicts[step.name] then
                for _, result in ipairs((opt.batch or batch)(grouped, opt.keep_going)) do
                    verdicts[result.name] = result
                end
            end
            local result = verdicts[step.name]
            if result and result.ok then
                record_of(step, result.seconds)
            else
                if not result then
                    print("FAIL %s: the process that runs the checks left no verdict for it", step.name)
                end
                table.insert(failed, step.name)
                stopped = not opt.keep_going
            end
        else
            local started = os.time()
            local ok = step.run()
            local seconds = os.time() - started
            if ok then
                record_of(step, seconds)
            end
            print("%s %s %ds", ok and "ok" or "FAIL", step.name, seconds)
            if not ok then
                table.insert(failed, step.name)
                stopped = not opt.keep_going
            end
        end
    end
    return failed
end

local STEPS = {
    {name = "comments", facts = function () return attributes_facts(root) end, inline = function () return call("tools/comments.lua", "check") end},
    {name = "comments test", reads = {"tools/comments.lua", "tools/comments/"}, inline = function () return call("tools/comments.lua", "test") end},
    {name = "private cache test", reads = table.join({"tools/private_cache.lua"}, TOOLS), inline = function () return call("tools/private_cache.lua", "test") end},
    {name = "layout", env = {"LC_COLLATE"}, inline = function () return call("tools/layout.lua") end},
    {name = "docs_commands", inline = function () return call("tools/docs_commands.lua") end},
    {name = "open_gaps", inline = function () return call("tools/open_gaps.lua") end},
    {name = "credentials", reads = {"agent-skills/tests/"}, inline = function () return call("agent-skills/tests/credentials.lua", "test") end},
    {name = "copied_text", reads = {"agent-skills/tests/"}, inline = function () return call("agent-skills/tests/copied_text.lua", "test") end},
    {name = "recipe digests", reads = digest_reads, facts = installed_facts, inline = function () return digests_stable(call) end},
    {name = "negative shape", reads = {"frameworks/Backports/xmake.lua", "frameworks/Backports/tests/", "emulator/"}, inline = negative_shape},
    {name = "ci errors test", reads = table.join({"tools/ci_errors.lua", "tools/ci/"}, TOOLS), inline = function () return call("tools/ci_errors.lua", "test") end},
    {name = "ci replay test", reads = table.join({"tools/ci_swiftc_replay.lua", "tools/ci/"}, TOOLS), inline = function () return call("tools/ci_swiftc_replay.lua", "test") end},
    {name = "host install test", run = function () return lua("frameworks/ReactNative/tests/host_install_test.lua") end},
    {name = "isolate test", run = function () return lua("frameworks/ReactNative/tests/isolate_test.lua") end},
    {name = "lowered members", heavy = true, skips = UNBUILT, env = PREBUILT_ENV, facts = installed_facts, run = function () return lua("frameworks/Backports/tests/lowered_members_test.lua") end},
    {name = "lowered exports", heavy = true, skips = UNBUILT, env = PREBUILT_ENV, facts = installed_facts, run = function () return lua("frameworks/Backports/tests/lowered_exports_test.lua") end},
    {name = "light suites", heavy = true, env = PREBUILT_ENV, facts = installed_facts, run = function () return lua("toolchain/tests/light_suites.lua") end},
    {name = "backports build", heavy = true, env = PREBUILT_ENV, facts = installed_facts, run = backports_build},
}

local function test_suite()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end

    check("a program that ignores the flag is reported", #shape("a_test.m", "int main(void) { assert(1); return 0; }"), 1)
    check("a program that reads the flag itself is clean", #shape("b_test.c", 'int main(int argc, char **argv) { return argc > 1 && strcmp(argv[1], "--negative") == 0; }'), 0)
    check("a check.h program that returns its failures is clean", #shape("c_test.m", '#import "check.h"\nint main(int argc, char **argv) { revenant_read_arguments(argc, argv); return revenant_finish(); }'), 0)
    check("a check.h program that drops its failures is reported", #shape("d_test.m", '#import "check.h"\nint main(int argc, char **argv) { revenant_read_arguments(argc, argv); return 0; }'), 1)
    check("a stem that a host test table names is declared", declared('host_tests("Foundation", {progress = {"A.m"}})', "progress"), true)
    check("a stem no table names is not declared", declared("local x = {}", "json_sorted_keys"), false)

    local emulator = 'target("a")\n    add_files("tests/unit/a_test.cpp")\n    add_tests("default")\ntarget_end()\n'
        .. 'target("b")\n    add_files("tests/unit/b_test.cpp")\n    add_tests("negative", {runargs = {"--negative"}, expect_failure = true})\ntarget_end()\n'
    check("only a target that declares a negative run is a negative source", table.concat(emulator_negative(emulator), ","), "emulator/tests/unit/b_test.cpp")

    local environment = gate_environment()
    check("the gate names the prebuilt toolchain it may install, so it never builds llvm from source", #environment.REVENANT_PREBUILT_ONLY > 0 and #environment.REVENANT_PREBUILT > 0, true)
    local sync = gate_sync_arguments("/g/tree")
    check("the gate copies the checkout into its own tree and deletes what the checkout dropped", table.concat(sync, " ", 1, 2), "-a --delete")
    check("the gate copies from the checkout's folder to its tree", table.concat(sync, " ", #sync - 1), root .. "/ /g/tree/")
    check("the gate leaves out git, the configuration, the build and the caches", table.concat(sync, " "):find("--exclude=/.git --exclude=/.xmake --exclude=/build --exclude=/.cache ", 1, true) ~= nil, true)
    local ignoring = gate_sync_arguments("/g/tree", "/g/ignored.txt")
    check("the gate leaves out what git ignores, so that it builds what the key covers", table.concat(ignoring, " "):find("--exclude-from=/g/ignored.txt", 1, true) ~= nil, true)
    check("the gate's source and tree stay last", table.concat(ignoring, " ", #ignoring - 1), root .. "/ /g/tree/")
    local commands = gate_commands("/g/tree")
    check("the gate configures the armv7 device build of the Backports component in its own tree",
          table.concat(commands[1], " ", 2), "f -P /g/tree -p iphoneos -a armv7 --component=Backports -y")
    check("the gate builds every target of that configuration", table.concat(commands[2], " ", 2), "build -P /g/tree -y")
    local compiled = "\27[0mframeworks/Backports/src/PDFKit/PDFView11.m:68:17: error: auto property synthesis is not allowed [-Werror,-Wobjc-missing-property-synthesis]\n"
        .. "   68 | @implementation RevenantPDFPageRender\n      |                 ^\n"
    check("the gate reports the compiler's error and not its source lines", table.concat(failure_lines(compiled), "|"),
          "frameworks/Backports/src/PDFKit/PDFView11.m:68:17: error: auto property synthesis is not allowed [-Werror,-Wobjc-missing-property-synthesis]")
    check("a failure without a compiler error reports the end of the log", table.concat(failure_lines("one\ntwo\nthree\n"), "|"), "one|two|three")

    print("prepush: %d tests passed", count)
end

local function test_cache()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("prepush cache test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local function commit(folder, message)
        git(folder, {"-c", "user.name=prepush", "-c", "user.email=prepush@localhost", "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", message})
    end

    check("a directory glob takes what is under it", matches("docs/a/b.md", {"docs/**"}), true)
    check("a trailing slash takes what is under the directory", matches("tools/ci/log.lua", {"tools/"}), true)
    check("a directory name is not a prefix of another directory", matches("toolsx/y", {"tools/"}), false)
    check("**/*.md takes a file at the top", matches("README.md", {"**/*.md"}), true)
    check("**/*.md takes a file at any depth", matches("a/b/c.md", {"**/*.md"}), true)
    check("**/*.md leaves a longer extension", matches("a.mdx", {"**/*.md"}), false)
    check("* stays inside one directory", matches("src/b/a.c", {"src/*"}), false)
    check("* takes a file of the directory", matches("src/a.c", {"src/*"}), true)
    check("a plain name is that file", matches("xmake.lua", {"xmake.lua"}), true)
    check("a plain name is not a longer name", matches("xmake.luax", {"xmake.lua"}), false)

    local base = os.iorunv("mktemp", {"-d"}):trim()
    local repo = path.join(base, "repo")
    local store = path.join(base, "store")
    os.mkdir(path.join(repo, "docs"))
    os.mkdir(path.join(repo, "tools"))
    git(repo, {"init", "-q"})
    io.writefile(path.join(repo, "tools", "prepush.lua"), "one\n")
    io.writefile(path.join(repo, "tools", "budget.lua"), "one\n")
    io.writefile(path.join(repo, "a.txt"), "one\n")
    io.writefile(path.join(repo, "docs", "d.md"), "doc\n")
    io.writefile(path.join(repo, "b.txt"), "other\n")
    git(repo, {"add", "-A"})
    commit(repo, "one")
    os.setenv("PREPUSH_TEST_KEY", "0")

    local everything = {name = "everything"}
    local code = {name = "code", skips = {"docs/**", "**/*.md"}}
    local narrow = {name = "narrow", reads = {"a.txt"}}
    local with_env = {name = "with env", reads = {"a.txt"}, env = {"PREPUSH_TEST_KEY"}}
    local function key(step, folder)
        return key_of(inputs(folder or repo), step)
    end
    local base_keys = {everything = key(everything), code = key(code), narrow = key(narrow), with_env = key(with_env)}
    check("the same inputs give the same key", key(everything), base_keys.everything)
    check("the step's name is part of the key", key({name = "other"}) ~= base_keys.everything, true)
    check("the step's version is part of the key", key({name = "everything", version = "2"}) ~= base_keys.everything, true)

    io.writefile(path.join(repo, "tools", "prepush.lua"), "two\n")
    check("the code of prepush is part of the key of a step that reads one file", key(narrow) ~= base_keys.narrow, true)
    check("the code of prepush is part of the key of a step that skips documents", key(code) ~= base_keys.code, true)
    io.writefile(path.join(repo, "tools", "prepush.lua"), "one\n")
    io.writefile(path.join(repo, "tools", "budget.lua"), "two\n")
    check("the code of the budget is part of every key", key(narrow) ~= base_keys.narrow, true)
    io.writefile(path.join(repo, "tools", "budget.lua"), "one\n")
    check("restoring the code restores the keys", key(narrow), base_keys.narrow)

    local saved_catalogue = os.getenv("REVENANT_TEST_ASSET_CATALOGUE")
    os.setenv("REVENANT_TEST_ASSET_CATALOGUE", "elsewhere")
    check("a REVENANT_ variable that nothing declares changes every key", key(narrow) ~= base_keys.narrow, true)
    os.setenv("REVENANT_TEST_ASSET_CATALOGUE", saved_catalogue or "")
    check("a REVENANT_ variable that is emptied is as good as unset", key(narrow), base_keys.narrow)
    local saved_cache, saved_held = os.getenv("REVENANT_CACHE"), os.getenv("REVENANT_BUDGET_HELD")
    os.setenv("REVENANT_CACHE", "/another/worktree/.cache")
    os.setenv("REVENANT_BUDGET_HELD", "1")
    check("the cache folder of a worktree and the budget's own variables change no key", key(narrow), base_keys.narrow)
    os.setenv("REVENANT_CACHE", saved_cache or "")
    os.setenv("REVENANT_BUDGET_HELD", saved_held or "")
    local saved_verdict = os.getenv("REVENANT_LIGHT_SUITES_VERDICT")
    os.setenv("REVENANT_LIGHT_SUITES_VERDICT", "0123456789abcdef@/a/run/light-suites.verdict")
    check("the hand-off of a verdict from ci_local to its tests is not an input of the verdict", key(narrow), base_keys.narrow)
    os.setenv("REVENANT_LIGHT_SUITES_VERDICT", saved_verdict or "")
    check("a tool is keyed by its version and not only by where it resolves", resolved_tools():find("git=%S*git git version") ~= nil, true)
    local saved_global = os.getenv("XMAKE_GLOBALDIR")
    os.setenv("XMAKE_GLOBALDIR", "/another/store")
    check("the package store xmake reads changes every key", key(narrow) ~= base_keys.narrow, true)
    os.setenv("XMAKE_GLOBALDIR", saved_global or "")

    io.writefile(path.join(repo, "docs", "d.md"), "changed\n")
    check("a changed document changes the key of a step that reads everything", key(everything) ~= base_keys.everything, true)
    check("a changed document leaves the key of a step that skips documents", key(code), base_keys.code)
    check("a changed document leaves the key of a step that reads one file", key(narrow), base_keys.narrow)
    io.writefile(path.join(repo, "docs", "d.md"), "doc\n")
    check("the same content again gives the same key", key(everything), base_keys.everything)

    io.writefile(path.join(repo, "b.txt"), "changed\n")
    check("a file outside what a step reads leaves its key", key(narrow), base_keys.narrow)
    check("a file a step skips documents is read by the code step", key(code) ~= base_keys.code, true)
    io.writefile(path.join(repo, "b.txt"), "other\n")

    io.writefile(path.join(repo, "a.txt"), "two\n")
    check("a changed file that a step reads changes its key", key(narrow) ~= base_keys.narrow, true)
    io.writefile(path.join(repo, "a.txt"), "one\n")
    check("restoring the file restores the key", key(narrow), base_keys.narrow)
    io.writefile(path.join(repo, "c.txt"), "new\n")
    check("an untracked file changes the key of a step that reads everything", key(everything) ~= base_keys.everything, true)
    os.rm(path.join(repo, "c.txt"))
    check("removing the untracked file restores the key", key(everything), base_keys.everything)
    os.rm(path.join(repo, "a.txt"))
    check("a deleted tracked file changes the key of a step that reads it", key(narrow) ~= base_keys.narrow, true)
    io.writefile(path.join(repo, "a.txt"), "one\n")
    check("restoring the deleted file restores the key", key(narrow), base_keys.narrow)

    os.setenv("PREPUSH_TEST_KEY", "1")
    check("a variable a step names changes its key", key(with_env) ~= base_keys.with_env, true)
    check("a variable no step names changes no key", key(everything), base_keys.everything)
    os.setenv("PREPUSH_TEST_KEY", "0")
    check("restoring the variable restores the key", key(with_env), base_keys.with_env)

    commit(repo, "empty")
    check("a new commit with the same content leaves the key", key(everything), base_keys.everything)
    local copy = path.join(base, "copy")
    os.cp(repo, copy)
    check("another folder with the same content has the same key", key(everything, copy), base_keys.everything)

    local fixture_store = path.join(base, "fixture-store")
    local packages = path.join(fixture_store, "xmake-global", ".xmake", "packages")
    local install = path.join(packages, "l", "llvm", "1.0", "abc")
    os.mkdir(install)
    io.writefile(path.join(install, "manifest.txt"), "one\n")
    local function installs()
        local saved = os.getenv("REVENANT_STORE")
        os.setenv("REVENANT_STORE", fixture_store)
        local text = store_installs()
        os.setenv("REVENANT_STORE", saved or "")
        return text
    end
    local installed = installs()
    check("an install of a package the checks run against is listed with its manifest", installed:find("l/llvm/1.0/abc ", 1, true) ~= nil, true)
    io.writefile(path.join(install, "manifest.txt"), "two\n")
    check("an install that is made again under the same name changes the digest", installs() ~= installed, true)
    os.mkdir(path.join(packages, "o", "other", "1.0", "x"))
    check("a package the checks do not run against changes nothing", installs():find("other", 1, true), nil)

    local attributes = attributes_facts(repo)
    io.writefile(path.join(repo, ".git", "info", "attributes"), "*.m comments=upstream\n")
    check("a local attribute file changes what the comments check is keyed on", attributes_facts(repo) ~= attributes, true)
    os.rm(path.join(repo, ".git", "info", "attributes"))
    check("removing the local attribute file restores it", attributes_facts(repo), attributes)

    local runs = {a = 0, b = 0, c = 0, d = 0, e = 0}
    local batches = 0
    local steps = {
        {name = "a", inline = function () runs.a = runs.a + 1; return true end},
        {name = "b", inline = function () runs.b = runs.b + 1; return false end},
        {name = "c", run = function () runs.c = runs.c + 1; return true end},
        {name = "d", reads = {"b.txt"}, inline = function () runs.d = runs.d + 1; return true end},
        {name = "e", reads = {"a.txt"}, inline = function () runs.e = runs.e + 1; return true end},
    }
    local function counting(grouped, keep_going)
        batches = batches + 1
        return batch(grouped, keep_going)
    end
    local function pass(folder, extra)
        local input = inputs(folder or repo)
        return run_steps(steps, table.join({keep_going = true, store = store, worktree = "w", head = "h", batch = counting,
                                            key = function (step) return key_of(input, step) end}, extra or {}))
    end
    check("a failing step is reported", table.concat(pass(), ","), "b")
    check("the steps that can run in one process run in one batch", batches, 1)
    check("a step that passed ran once", runs.a + runs.c + runs.d + runs.e, 4)
    check("a failing step is not remembered", recalled(store, steps[2], key(steps[2])), nil)
    check("a passing step is remembered with where it ran", recalled(store, steps[1], key(steps[1])).worktree, "w")
    local reader = import("@addon.revenant.recalled", {anonymous = true})
    check("the reader that ci_local's tests use agrees that a passed step is remembered", reader.holds(store, steps[1].name, key(steps[1])), true)
    check("the reader agrees that a failed step is not", reader.holds(store, steps[2].name, key(steps[2])), false)
    check("the reader agrees that another key is not", reader.holds(store, steps[1].name, "0000"), false)
    check("a recall says where the verdict came from", (recall_line(store, steps[1], key(steps[1])) or ""):find("^recalled a memo %(ran %d+ s in w at h, ") ~= nil, true)
    check("a step that failed has no recall", recall_line(store, steps[2], key(steps[2])), nil)
    check("a recall asks for the inputs it is given", recall_line(store, steps[1], "0000"), nil)
    local report = recall_report(store, steps[1], key(steps[1])) or ""
    check("a recall report is the line and then the key it was found under", report:find("^recalled a memo %(.-%)\nkey " .. key(steps[1]) .. "$") ~= nil, true)
    check("a step that failed has no recall report", recall_report(store, steps[2], key(steps[2])), nil)
    pass()
    check("a passing step is not run again on unchanged inputs", runs.a, 1)
    check("a spawned step is not run again on unchanged inputs", runs.c, 1)
    check("a failing step is run again, since it is not remembered", runs.b, 2)
    check("the failing step alone goes to the second batch", batches, 2)
    pass(copy)
    check("another folder with the same content takes the verdict from the store", runs.a, 1)
    pass(nil, {fresh = true})
    check("a fresh run ignores the memo", runs.a, 2)
    check("a fresh run runs every step again", runs.a + runs.c + runs.d + runs.e, 8)
    io.writefile(path.join(repo, "b.txt"), "changed\n")
    pass()
    check("a changed file runs the steps that read it", runs.d, 3)
    check("a changed file runs the steps that read everything", runs.a, 3)
    check("a changed file leaves the steps that read other files", runs.e, 2)

    local silent = {{name = "p", inline = function () return true end}, {name = "q", inline = function () return true end}}
    local lost_store = path.join(base, "lost-store")
    local function by_name(step) return step.name end
    local lost = run_steps(silent, {keep_going = true, store = lost_store, key = by_name, batch = function () return {} end})
    check("checks that run in one process and leave no verdict are failures", table.concat(lost, ","), "p,q")
    check("a check that left no verdict is not remembered", recalled(lost_store, silent[1], "p"), nil)
    local partial = run_steps(silent, {keep_going = true, store = lost_store, key = by_name, batch = function () return {{name = "p", ok = true, seconds = 0}} end})
    check("a check missing from the verdicts fails and the one present passes", table.concat(partial, ","), "q")
    local stopped = run_steps(silent, {keep_going = false, store = path.join(base, "stop-store"), key = by_name, batch = function () return {} end})
    check("a lost verdict stops the run like a failure", table.concat(stopped, ","), "p")

    local gate
    for _, step in ipairs(STEPS) do
        if step.name == "backports build" then
            gate = step
        end
    end
    check("the Backports gate skips no file, since its tree is a copy of the checkout", #(gate.skips or {}), 0)

    io.writefile(path.join(repo, ".gitignore"), "scratch/\n*.o\n")
    io.writefile(path.join(repo, "junk.o"), "x\n")
    os.mkdir(path.join(repo, "scratch"))
    io.writefile(path.join(repo, "scratch", "x"), "x\n")
    local ignored = gate_ignored(repo)
    check("what git ignores is listed for the gate, anchored at the root", ignored:find("/junk.o", 1, true) ~= nil and ignored:find("/scratch/", 1, true) ~= nil, true)
    check("what git tracks is not listed", ignored:find("a.txt", 1, true), nil)

    local record = {seconds = "12", worktree = "w", head = "0123456789abcdef", at = os.time() - 120}
    check("a verdict names where and when it was made", provenance(record), "ran 12 s in w at 012345678, 2 min ago")

    os.rm(base)
    print("prepush cache: %d tests passed", count)
end

local function parse_arguments(arguments)
    local parsed = {keep_going = false, list = false, only = nil, fresh = false, inline = nil, results = nil, recall = nil}
    local function names(argument, value)
        assert(value, argument .. " needs a comma-separated list of check names; --list prints them")
        local found = {}
        for name in value:gmatch("[^,]+") do
            table.insert(found, name)
        end
        return found
    end
    local index = 1
    while index <= #arguments do
        local argument = arguments[index]
        if argument == "--keep-going" then
            parsed.keep_going = true
        elseif argument == "--list" then
            parsed.list = true
        elseif argument == "--fresh" then
            parsed.fresh = true
        elseif argument == "--only" then
            index = index + 1
            parsed.only = names(argument, arguments[index])
        elseif argument == "--inline" then
            index = index + 1
            parsed.inline = names(argument, arguments[index])
        elseif argument == "--recall" then
            index = index + 1
            parsed.recall = arguments[index]
            assert(parsed.recall, "--recall needs the name of one check; --list prints them")
        elseif argument == "--results" then
            index = index + 1
            parsed.results = arguments[index]
            assert(parsed.results, "--results needs the file the verdicts are written to")
        else
            raise("unknown argument %s; the arguments are test, --list, --only <check,...>, --recall <check>, --keep-going and --fresh", argument)
        end
        index = index + 1
    end
    return parsed
end

local function select_steps(steps, only)
    if not only then
        return steps
    end
    local wanted = {}
    for _, name in ipairs(only) do
        wanted[name] = true
    end
    local selected = {}
    for _, step in ipairs(steps) do
        if wanted[step.name] then
            table.insert(selected, step)
            wanted[step.name] = nil
        end
    end
    local unknown = table.keys(wanted)
    table.sort(unknown)
    assert(#unknown == 0, "no such check: " .. table.concat(unknown, ", ") .. "; --list prints the names")
    return selected
end

local function test_arguments()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("prepush arguments test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local function raises(arguments)
        return try {function () parse_arguments(arguments); return true end} == nil
    end
    check("no argument stops at the first failure", parse_arguments({}).keep_going, false)
    check("--keep-going keeps going", parse_arguments({"--keep-going"}).keep_going, true)
    check("--list lists", parse_arguments({"--list"}).list, true)
    check("--fresh ignores the memo", parse_arguments({"--fresh"}).fresh, true)
    check("a run without --fresh reads the memo", parse_arguments({}).fresh, false)
    check("--inline names the checks one process runs", table.concat(parse_arguments({"--inline", "layout,comments"}).inline, "|"), "layout|comments")
    check("--results names the file of the verdicts", parse_arguments({"--inline", "layout", "--results", "/tmp/v"}).results, "/tmp/v")
    check("--inline without a value is an error", raises({"--inline"}), true)
    check("--results without a value is an error", raises({"--results"}), true)
    check("--only splits on commas and keeps the spaces of a name", table.concat(parse_arguments({"--only", "layout,light suites"}).only, "|"), "layout|light suites")
    check("--only without a value is an error", raises({"--only"}), true)
    check("--recall names one check", parse_arguments({"--recall", "light suites"}).recall, "light suites")
    check("--recall without a value is an error", raises({"--recall"}), true)
    check("an unknown argument is an error", raises({"--fast"}), true)

    local steps = {{name = "a"}, {name = "b"}, {name = "c"}}
    check("no selection keeps every check", #select_steps(steps, nil), 3)
    check("a selection keeps the checks in their own order", select_steps(steps, {"c", "a"})[2].name, "c")
    check("an unknown check name is an error", try {function () select_steps(steps, {"a", "z"}); return true end} == nil, true)

    local ordered = {}
    local seen_heavy = false
    for _, step in ipairs(STEPS) do
        if step.heavy then
            seen_heavy = true
        elseif seen_heavy then
            table.insert(ordered, step.name)
        end
    end
    check("every heavy check comes after every cheap one: " .. table.concat(ordered, ","), #ordered, 0)

    local runs = {}
    local function recording(name, ok)
        return {name = name, cache = false, run = function () table.insert(runs, name); return ok end}
    end
    local plan = {recording("cheap", false), recording("heavy", true)}
    local failed = run_steps(plan, {keep_going = false})
    check("a failed check stops the run before the next one", table.concat(runs, ",") .. "/" .. table.concat(failed, ","), "cheap/cheap")
    runs = {}
    failed = run_steps(plan, {keep_going = true})
    check("--keep-going runs the next check after a failure", table.concat(runs, ",") .. "/" .. table.concat(failed, ","), "cheap,heavy/cheap")
    print("prepush arguments: %d tests passed", count)
end

local function spawned_batch(steps, keep_going)
    local names = {}
    for _, step in ipairs(steps) do
        table.insert(names, step.name)
    end
    local results = os.tmpfile() .. ".verdicts"
    local command = {os.programfile(), "l", "-P", root, path.join(root, "tools", "prepush.lua"), "--inline", table.concat(names, ","), "--results", results}
    if keep_going then
        table.insert(command, "--keep-going")
    end
    budgeted(command)
    local verdicts = {}
    if os.isfile(results) then
        for line in io.readfile(results):gmatch("[^\n]+") do
            local name, status, seconds = line:match("^(.-)\t(%a+)\t(%d+)$")
            if name then
                table.insert(verdicts, {name = name, ok = status == "ok", seconds = tonumber(seconds)})
            end
        end
        os.tryrm(results)
    end
    return verdicts
end

function main(command, ...)
    if command == "test" then
        test_suite()
        test_cache()
        test_arguments()
        return
    end
    local arguments = command and table.join({command}, {...}) or {}
    local parsed = parse_arguments(arguments)
    if parsed.list then
        for _, step in ipairs(STEPS) do
            print("%s%s", step.name, step.heavy and " (heavy)" or "")
        end
        return
    end
    if parsed.recall then
        local step = select_steps(STEPS, {parsed.recall})[1]
        local report = recall_report(path.join(cache().store(), "memo"), step, key_of(inputs(root), step))
        if not report then
            raise("no verdict of %s is remembered for these inputs", step.name)
        end
        print("%s", report)
        return
    end
    if parsed.inline then
        local results = batch(select_steps(STEPS, parsed.inline), parsed.keep_going)
        local lines, failed = {}, {}
        for _, result in ipairs(results) do
            table.insert(lines, string.format("%s\t%s\t%d", result.name, result.ok and "ok" or "FAIL", result.seconds))
            if not result.ok then
                table.insert(failed, result.name)
            end
        end
        if parsed.results then
            io.writefile(parsed.results, table.concat(lines, "\n") .. "\n")
        end
        if #failed > 0 then
            raise("%d of %d checks failed: %s", #failed, #results, table.concat(failed, ", "))
        end
        return
    end
    local steps = select_steps(STEPS, parsed.only)
    local input = inputs(root)
    local failed = run_steps(steps, {
        keep_going = parsed.keep_going,
        fresh = parsed.fresh,
        store = path.join(cache().store(), "memo"),
        worktree = path.filename(root),
        head = git(root, {"rev-parse", "HEAD"}):trim(),
        key = function (step) return key_of(input, step) end,
        batch = spawned_batch,
    })
    if #failed > 0 then
        raise("%d of %d checks failed: %s", #failed, #steps, table.concat(failed, ", "))
    end
    if parsed.only then
        print("prepush: %d of %d checks passed (--only); a push needs all of them", #steps, #STEPS)
    else
        print("prepush: %d checks passed", #steps)
    end
end
