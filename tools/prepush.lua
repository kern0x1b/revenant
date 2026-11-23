local bytes = import("core.base.bytes")

local root = path.absolute(path.directory(os.scriptdir()))

local output = {}

function output.write(text)
    print("%s", text)
    io.flush()
end

local function say(format, ...)
    local values = {...}
    output.write(#values > 0 and string.format(format, ...) or format)
end

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
local GATE_EXCLUDES = {"/.git", "/.xmake", "/build", "/.cache", "/.cache-private", "/.cache-boot", "/.cache-*", "/.claude/worktrees"}

local REFUSAL_EXIT = 3
local REFUSED = {}

local function budgeted(command, opt)
    opt = opt or {}
    local args = table.join({"l", "-P", root, path.join(root, "tools", "budget.lua"), "run", "--class", "critical", "--jobs", tostring(opt.jobs or 2), "--"}, command)
    local status = os.execv(os.programfile(), args, {try = true, curdir = opt.curdir or root, envs = opt.envs, stdout = opt.output, stderr = opt.output})
    if status == REFUSAL_EXIT then
        return REFUSED
    end
    return status == 0
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

local RECORD_LIMIT = 4100

local function git_records(folder, args, what)
    local scratch = path.join(cache().root(), "scratch", "prepush-lists")
    os.mkdir(scratch)
    local file = path.join(scratch, "list-" .. path.filename(os.tmpfile()))
    local text, failure
    try {
        function ()
            local status = os.execv("git", table.join({"-C", folder}, args), {stdout = file, stderr = file .. ".errors", try = true})
            if status ~= 0 then
                failure = string.format("git exited with status %s (%s)", tostring(status), (io.readfile(file .. ".errors") or ""):trim():sub(1, 200))
            else
                local handle = io.open(file, "rb")
                text = handle:read("*all")
                handle:close()
            end
        end,
        catch {
            function (raised)
                failure = tostring(raised):sub(1, 200)
            end
        },
        finally {
            function ()
                os.tryrm(file)
                os.tryrm(file .. ".errors")
            end
        }
    }
    if failure then
        raise("prepush: %s could not be read cleanly: %s; nothing was run and no remembered verdict was used", what or "a list of git", failure)
    end
    return text
end

local function split_records(text, what)
    local records = {}
    if text == "" then
        return records
    end
    for record in text:gmatch("[^\0]+") do
        if #record > RECORD_LIMIT then
            raise("prepush: %s could not be read cleanly: a record of %d bytes is no path; nothing was run and no remembered verdict was used", what, #record)
        end
        table.insert(records, record)
    end
    local _, boundaries = text:gsub("%z", "")
    if boundaries ~= #records then
        raise("prepush: %s could not be read cleanly: the output of git is not a list of records that each end at a boundary (%d records, %d boundaries); nothing was run and no remembered verdict was used", what, #records, boundaries)
    end
    return records
end

local function gate_ignored(folder)
    local lines = {}
    local what = "the list of what git ignores"
    for _, entry in ipairs(split_records(git_records(folder, {"ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z"}, what), what)) do
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

local function gate_preflight()
    return {"true"}
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
        say("%s", lines[index])
    end
    if #lines > GATE_LINES then
        say("... %d more", #lines - GATE_LINES)
    end
    say("the Backports build failed; the whole log is %s", logfile)
end

local function backports_build()
    local folder = gate_folder()
    local tree = gate_tree(folder)
    local logfile = path.join(folder, "prepush.log")
    os.mkdir(folder)
    local output = io.open(logfile, "w")
    local ignored = path.join(folder, "ignored.txt")
    io.writefile(ignored, gate_ignored(root))
    local result = budgeted(gate_preflight(), {output = output})
    if result == REFUSED then
        output:close()
        return REFUSED
    end
    local ok = result == true
    if ok then
        os.mkdir(tree)
        ok = os.execv("rsync", gate_sync_arguments(tree, ignored), {try = true, stdout = output, stderr = output}) == 0
    end
    if ok then
        for _, command in ipairs(gate_commands(tree)) do
            result = budgeted(command, {jobs = GATE_JOBS, curdir = tree, envs = gate_environment(), output = output})
            if result == REFUSED then
                output:close()
                return REFUSED
            end
            if not result then
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

local function backports_exports()
    local built = path.join(gate_tree(gate_folder()), "build", "iphoneos", "armv7", "release")
    return lua("frameworks/Backports/tests/export_baseline_test.lua", "check", built)
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
        say("%s", message)
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
                say("%s", tostring(errors))
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
            say("regenerated digest differs from the committed one: %s", line:sub(4))
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
        local began = os.time()
        say("prepush: reading the installed toolchain (xcode, the tools on the path, the store's packages, the SDK), once")
        installed_text = table.concat({toolchain_facts(), resolved_tools(), store_installs(), sdk_content()}, "\n--\n")
        say("prepush: the installed toolchain is read, %ds", os.time() - began)
    end
    return installed_text
end

local PRIVATE_FOLDERS = {".cache*/**", "build/**", ".xmake/**", ".claude/worktrees/**"}

local function dirty_pathspec()
    local spec = {"--", "."}
    for _, folder in ipairs(PRIVATE_FOLDERS) do
        table.insert(spec, ":(exclude,glob)" .. folder)
    end
    return spec
end

local function dirty_entries(folder, reader)
    local what = "the list of uncommitted files"
    local tokens, entries = split_records((reader or git_records)(folder, table.join({"status", "--porcelain=v1", "--untracked-files=all", "-z"}, dirty_pathspec()), what), what), {}
    local index = 1
    while index <= #tokens do
        if not tokens[index]:find("^[ MTADRCU%?!][ MTADRCU%?!] ") then
            raise("prepush: %s could not be read cleanly: a record that is no status line (%d bytes, starts with %q); nothing was run and no remembered verdict was used", what, #tokens[index], tokens[index]:sub(1, 12))
        end
        local status = tokens[index]:sub(1, 2)
        table.insert(entries, {status = status, file = tokens[index]:sub(4)})
        if status:find("[RC]") then
            index = index + 1
            if index > #tokens then
                raise("prepush: %s could not be read cleanly: a rename or copy without its source; nothing was run and no remembered verdict was used", what)
            end
        end
        index = index + 1
    end
    return entries
end

local HASH_CHUNK = 1000

local function manifest(folder, reader, hasher)
    local current = {}
    for line in git(folder, {"ls-files", "-s"}):gmatch("[^\n]+") do
        local mode, sha, file = line:match("^(%d+) (%x+) %d\t(.+)$")
        current[file] = mode .. " " .. sha
    end
    local pending, dirty = {}, 0
    for _, entry in ipairs(dirty_entries(folder, reader)) do
        local full = path.join(folder, entry.file)
        dirty = dirty + 1
        if os.islink(full) then
            current[entry.file] = "link " .. os.readlink(full)
        elseif os.isfile(full) then
            table.insert(pending, entry.file)
        else
            current[entry.file] = "deleted"
        end
    end
    local digests = {}
    for from = 1, #pending, HASH_CHUNK do
        local chunk = table.slice(pending, from, math.min(from + HASH_CHUNK - 1, #pending))
        for line in (hasher or git)(folder, table.join({"hash-object", "--"}, chunk)):gmatch("[^\n]+") do
            table.insert(digests, line)
        end
    end
    if #digests ~= #pending then
        raise("prepush: the content of the uncommitted files could not be read cleanly: %d files, %d digests; nothing was run and no remembered verdict was used", #pending, #digests)
    end
    for index, file in ipairs(pending) do
        current[file] = "file " .. digests[index]
    end
    return current, dirty
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

local function inputs(folder, reader, hasher)
    local files, dirty = manifest(folder, reader, hasher)
    return {
        files = files,
        dirty = dirty,
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
        say("start %s", step.name)
        local ok = step.inline()
        say("%s %s %ds", ok and "ok" or "FAIL", step.name, os.time() - started)
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
    local keyed = os.time()
    if opt.key then
        say("prepush: computing the keys of %d checks", #steps)
    end
    for _, step in ipairs(steps) do
        keys[step.name] = opt.key and opt.key(step) or nil
        local record = keys[step.name] and not opt.fresh and recalled(opt.store, step, keys[step.name])
        if record then
            hits[step.name] = record
        else
            table.insert(misses, step)
        end
    end
    if opt.key then
        say("prepush: keys done in %ds, %d of %d checks have a remembered verdict%s", os.time() - keyed, #steps - #misses, #steps, opt.fresh and " (not used, --fresh)" or "")
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
    local heavy_started = false
    local function stop_at(name)
        stopped = not opt.keep_going
        if stopped then
            say("prepush: %s failed; the run stops here%s", name, heavy_started and "" or ", and no heavy check was started")
        end
    end
    for _, step in ipairs(steps) do
        local hit = hits[step.name]
        if stopped then
            break
        elseif hit then
            say("ok %s memo (%s)", step.name, provenance(hit))
        elseif step.inline then
            if not verdicts[step.name] then
                local produced = (opt.batch or batch)(grouped, opt.keep_going)
                if produced == REFUSED then
                    return failed, true
                end
                for _, result in ipairs(produced) do
                    verdicts[result.name] = result
                end
            end
            local result = verdicts[step.name]
            if result and result.ok then
                record_of(step, result.seconds)
            else
                if not result then
                    say("FAIL %s: the process that runs the checks left no verdict for it", step.name)
                end
                table.insert(failed, step.name)
                stop_at(step.name)
            end
        else
            if step.heavy and not heavy_started then
                heavy_started = true
                if #failed == 0 then
                    say("prepush: the light checks are green; starting the heavy ones")
                else
                    say("prepush: starting the heavy checks although %s failed (--keep-going)", table.concat(failed, ", "))
                end
            end
            local started = os.time()
            say("start %s", step.name)
            local ok = step.run()
            if ok == REFUSED then
                return failed, true
            end
            local seconds = os.time() - started
            if ok then
                record_of(step, seconds)
            end
            say("%s %s %ds", ok and "ok" or "FAIL", step.name, seconds)
            if not ok then
                table.insert(failed, step.name)
                stop_at(step.name)
            end
        end
    end
    return failed, false
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
    {name = "overlay test", reads = {"frameworks/ReactNative/tools/overlay.lua", "frameworks/ReactNative/tests/overlay_test.lua"}, run = function () return lua("frameworks/ReactNative/tests/overlay_test.lua") end},
    {name = "export baseline test", reads = {"frameworks/Backports/tests/export_baseline_test.lua", "toolchain/modules/apple/", "toolchain/modules/*.lua"}, run = function () return lua("frameworks/Backports/tests/export_baseline_test.lua", "test") end},
    {name = "lowered members", heavy = true, skips = UNBUILT, env = PREBUILT_ENV, facts = installed_facts, run = function () return lua("frameworks/Backports/tests/lowered_members_test.lua") end},
    {name = "lowered exports", heavy = true, skips = UNBUILT, env = PREBUILT_ENV, facts = installed_facts, run = function () return lua("frameworks/Backports/tests/lowered_exports_test.lua") end},
    {name = "light suites", heavy = true, env = PREBUILT_ENV, facts = installed_facts, run = function () return lua("toolchain/tests/light_suites.lua") end},
    {name = "backports build", heavy = true, env = PREBUILT_ENV, facts = installed_facts, run = backports_build},
    {name = "backports exports", heavy = true, env = PREBUILT_ENV, facts = installed_facts, run = backports_exports},
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
    check("the gate leaves out a private cache of any name that starts with .cache-, so a worktree's own cache is not copied into the tree", table.concat(sync, " "):find("--exclude=/.cache-* ", 1, true) ~= nil, true)
    check("the gate asks the budget before it creates its tree", gate_preflight()[1], "true")
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
    os.setenv("REVENANT_CACHE", path.join(base, "another-worktree", ".cache"))
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
    local failed, refused = run_steps(plan, {keep_going = false})
    check("a failed check stops the run before the next one", table.concat(runs, ",") .. "/" .. table.concat(failed, ","), "cheap/cheap")
    runs = {}
    failed = run_steps(plan, {keep_going = true})
    check("--keep-going runs the next check after a failure", table.concat(runs, ",") .. "/" .. table.concat(failed, ","), "cheap,heavy/cheap")

    runs = {}
    failed, refused = run_steps(plan, {keep_going = true})
    check("a real failure is still a failed check", table.concat(runs, ",") .. "/" .. table.concat(failed, ","), "cheap,heavy/cheap")
    check("a real failure is not a budget refusal", refused, false)

    runs = {}
    local refusing = {name = "refused", cache = false, run = function () table.insert(runs, "refused"); return REFUSED end}
    local refused_plan = {recording("cheap", true), refusing, recording("heavy", true)}
    failed, refused = run_steps(refused_plan, {keep_going = true})
    check("a budget refusal is not counted as a failed check", table.concat(failed, ","), "")
    check("a budget refusal is reported as a refusal", refused, true)
    check("a budget refusal stops before the next check", table.concat(runs, ","), "cheap,refused")

    local inline_plan = {
        {name = "a", inline = function () return true end},
        {name = "b", inline = function () return true end}
    }
    failed, refused = run_steps(inline_plan, {keep_going = true, batch = function () return REFUSED end})
    check("a refused check batch is not counted as failed checks", table.concat(failed, ","), "")
    check("a refused check batch is reported as a refusal", refused, true)
    print("prepush arguments: %d tests passed", count)
end

local function dirty_tests(base)
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("prepush dirty test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local function refusal(run)
        local message
        try { run, catch { function (raised) message = tostring(raised) end } }
        return message
    end
    local function reader_of(text)
        return function () return text end
    end
    local function repository(name)
        local folder = path.join(base, name)
        os.mkdir(folder)
        git(folder, {"init", "-q"})
        io.writefile(path.join(folder, "tracked.txt"), "one\n")
        git(folder, {"add", "-A"})
        git(folder, {"-c", "user.name=prepush", "-c", "user.email=prepush@localhost", "-c", "commit.gpgsign=false", "commit", "-q", "-m", "one"})
        return folder
    end
    local function fill(folder, subfolder, amount, extension)
        os.mkdir(path.join(folder, subfolder))
        os.vrunv("sh", {"-c", 'i=0; while [ $i -lt $1 ]; do printf "%s\\n" "$i" > "$2/file-with-a-longer-name-$i.$3"; i=$((i + 1)); done', "sh",
                        tostring(amount), path.join(folder, subfolder), extension or "txt"})
    end
    local function listed(files)
        local found = 0
        for _, value in pairs(files) do
            if value:find("^file ") then
                found = found + 1
            end
        end
        return found
    end

    check("a list that ends at a boundary splits at it", #split_records("a\0b\0", "x"), 2)
    check("an empty answer is an empty list", #split_records("", "x"), 0)
    check("an answer that does not end at a boundary is refused", (refusal(function () split_records("M  a", "x") end) or ""):find("could not be read cleanly", 1, true) ~= nil, true)
    check("an empty record is refused", (refusal(function () split_records("a\0\0b\0", "x") end) or ""):find("could not be read cleanly", 1, true) ~= nil, true)
    check("a record that is no path is refused", (refusal(function () split_records(string.rep("x", 5000) .. "\0", "x") end) or ""):find("could not be read cleanly", 1, true) ~= nil, true)
    check("a status list is read", #dirty_entries(base, reader_of(" M a.txt\0?? b.txt\0")), 2)
    check("a rename takes the record of its source with it", #dirty_entries(base, reader_of("R  new.txt\0old.txt\0 M a.txt\0")), 2)
    check("a rename without its source is refused", (refusal(function () dirty_entries(base, reader_of("R  new.txt\0")) end) or ""):find("could not be read cleanly", 1, true) ~= nil, true)
    check("a record that is no status line is refused", (refusal(function () dirty_entries(base, reader_of("no status line here\0")) end) or ""):find("no status line", 1, true) ~= nil, true)
    check("a list without its boundaries, as xmake decodes a long one, is refused", (refusal(function () dirty_entries(base, reader_of(string.rep("?? file.txt", 60))) end) or ""):find("could not be read cleanly", 1, true) ~= nil, true)
    local unreadable = refusal(function () inputs(repository("unreadable"), reader_of(string.rep("?? file.txt", 60))) end)
    check("the inputs of the checks are refused when the list could not be read, so no key and no remembered verdict follows", (unreadable or ""):find("no remembered verdict was used", 1, true) ~= nil, true)
    local short = repository("short")
    io.writefile(path.join(short, "a.txt"), "a\n")
    io.writefile(path.join(short, "b.txt"), "b\n")
    local lost = refusal(function () manifest(short, nil, function () return "0123456789012345678901234567890123456789\n" end) end)
    check("a digest missing for an uncommitted file is refused, never a key without its content", (lost or ""):find("no remembered verdict was used", 1, true) ~= nil, true)

    for _, amount in ipairs({3, 10, 1000, 30000}) do
        local folder = repository("n" .. amount)
        fill(folder, "src", amount)
        local files, dirty = manifest(folder)
        check(amount .. " untracked files are all dirty entries", dirty, amount)
        check(amount .. " untracked files each have a digest in the manifest", listed(files), amount)
        local name = "src/file-with-a-longer-name-1.txt"
        check("a digest of the manifest is git's own (" .. amount .. ")", files[name], "file " .. git(folder, {"hash-object", "--", name}):trim())
        local step = {name = "everything"}
        local before = key_of(inputs(folder), step)
        io.writefile(path.join(folder, name), "changed\n")
        check("a changed untracked file changes the key of a check that reads everything (" .. amount .. ")", key_of(inputs(folder), step) ~= before, true)
        io.writefile(path.join(folder, name), "1\n")
        check("and restoring it restores the key (" .. amount .. ")", key_of(inputs(folder), step), before)
        io.writefile(path.join(folder, "tracked.txt"), "two\n")
        check("a modified tracked file beside them changes the key (" .. amount .. ")", key_of(inputs(folder), step) ~= before, true)
        os.rm(folder)
    end

    local folder = repository("private")
    fill(folder, ".cache-x", 3000)
    fill(folder, "build", 500)
    fill(folder, ".xmake", 500)
    fill(folder, "real", 4)
    local files, dirty = manifest(folder)
    check("only the files outside the private folders are dirty entries", dirty, 4)
    check("and only those have a digest", listed(files), 4)
    local step = {name = "everything"}
    local before = key_of(inputs(folder), step)
    io.writefile(path.join(folder, ".cache-x", "file-with-a-longer-name-1.txt"), "changed\n")
    io.writefile(path.join(folder, "build", "file-with-a-longer-name-1.txt"), "changed\n")
    check("a file in a private cache or a build folder changes no key", key_of(inputs(folder), step), before)
    os.rm(folder)

    folder = repository("ignored")
    io.writefile(path.join(folder, ".gitignore"), "*.o\n")
    fill(folder, "obj", 1000, "o")
    io.writefile(path.join(folder, "obj", "keep.txt"), "kept\n")
    local excludes = 0
    for line in gate_ignored(folder):gmatch("[^\n]+") do
        if line:find("^/obj/file%-with%-a%-longer%-name%-%d+%.o$") then
            excludes = excludes + 1
        end
    end
    check("what git ignores is listed one by one for the gate's copy (1000 ignored files)", excludes, 1000)

    local broken = repository("broken")
    io.writefile(path.join(broken, "uncommitted.txt"), "uncommitted\n")
    io.writefile(path.join(broken, ".git", "index"), "this is not an index")
    local failed = refusal(function () dirty_entries(broken) end)
    check("a git that fails on the status is refused, never read as an empty tree", (failed or ""):find("could not be read cleanly: git exited with status", 1, true) ~= nil, true)
    check("and the refusal says that no remembered verdict was used", (failed or ""):find("no remembered verdict was used", 1, true) ~= nil, true)
    check("the inputs of the checks fail on it too, so no key follows", refusal(function () inputs(broken) end) ~= nil, true)
    check("a folder git cannot enter is refused the same way", (refusal(function () dirty_entries(path.join(base, "nowhere")) end) or ""):find("git exited with status", 1, true) ~= nil, true)
    check("a git that fails on the ignored list is refused too", (refusal(function () gate_ignored(path.join(base, "nowhere")) end) or ""):find("could not be read cleanly: git exited with status", 1, true) ~= nil, true)

    local real_tmpfile = os.tmpfile
    local fixed = path.join(base, "fixed-name")
    os.tmpfile = function () return fixed end
    local lists = path.join(cache().root(), "scratch", "prepush-lists")
    refusal(function () dirty_entries(broken) end)
    check("no list file stays in the scratch folder after a failed read", os.isfile(path.join(lists, "list-fixed-name")), false)
    check("no list of errors stays there either", os.isfile(path.join(lists, "list-fixed-name.errors")), false)
    dirty_entries(repository("fine"))
    check("no list file stays in the scratch folder after a good read", os.isfile(path.join(lists, "list-fixed-name")), false)
    os.tmpfile = real_tmpfile
    local saved_cache = os.getenv("REVENANT_CACHE")
    os.setenv("REVENANT_CACHE", path.join(base, "named-cache"))
    dirty_entries(repository("located"))
    os.setenv("REVENANT_CACHE", saved_cache or "")
    check("the list file is made under the scratch folder of the checkout's cache", os.isdir(path.join(base, "named-cache", "scratch", "prepush-lists")), true)

    local special = repository("special")
    local names = {
        "with space.txt",
        "new\nline.txt",
        "\208\159\209\128\208\184\208\178\208\181\209\130.txt",
        "-dash.txt",
        "quote'\"d.txt",
        "tab\there.txt",
    }
    for index, name in ipairs(names) do
        io.writefile(path.join(special, name), "content " .. index .. "\n")
    end
    git(special, {"mv", "tracked.txt", "renamed.txt"})
    io.writefile(path.join(special, "renamed.txt"), "two\n")
    local files, dirty = manifest(special)
    check("every special name and the renamed file is a dirty entry", dirty, #names + 1)
    for index, name in ipairs(names) do
        check("the manifest has the digest of " .. string.format("%q", name), files[name], "file " .. git(special, {"hash-object", "--", name}):trim())
    end
    check("a staged rename that is edited again has the digest of its new content", files["renamed.txt"], "file " .. git(special, {"hash-object", "--", "renamed.txt"}):trim())
    check("and the name it left is not in the manifest", files["tracked.txt"], nil)
    local special_step = {name = "everything"}
    local special_before = key_of(inputs(special), special_step)
    for index, name in ipairs(names) do
        io.writefile(path.join(special, name), "changed " .. index .. "\n")
        check("a changed file changes the key (" .. string.format("%q", name) .. ")", key_of(inputs(special), special_step) ~= special_before, true)
        io.writefile(path.join(special, name), "content " .. index .. "\n")
    end
    check("restoring them restores the key", key_of(inputs(special), special_step), special_before)
    print("prepush: %d dirty tests passed", count)
end

local function test_dirty()
    local base = path.join(cache().root(), "scratch", "prepush-dirty-test-" .. path.filename(os.tmpfile()))
    os.mkdir(base)
    local failure
    try {
        function () dirty_tests(base) end,
        catch { function (raised) failure = tostring(raised) end },
        finally { function () os.tryrm(base) end },
    }
    if failure then
        raise("%s", failure)
    end
end

local function test_live()
    local process = import("core.base.process")
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("prepush live test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local function captured(run, ...)
        local lines = {}
        local saved = output.write
        output.write = function (text) table.insert(lines, text) end
        local failed
        local result = try { function (...) return run(...) end, catch { function (raised) failed = raised end } }
        output.write = saved
        assert(failed == nil, tostring(failed))
        return lines, result
    end
    local function index_of(lines, text)
        for index, line in ipairs(lines) do
            if line:find(text, 1, true) then
                return index
            end
        end
    end
    local function ran_steps(red, ran)
        return {
            {name = "light green", inline = function () table.insert(ran, "light green") return true end},
            {name = "light " .. (red and "red" or "other"), inline = function () table.insert(ran, "light other") return not red end},
            {name = "light after", inline = function () table.insert(ran, "light after") return true end},
            {name = "plain", run = function () table.insert(ran, "plain") return true end},
            {name = "heavy", heavy = true, run = function () table.insert(ran, "heavy") return true end},
        }
    end

    local ran = {}
    local lines, results = captured(function () local failed, refused = run_steps(ran_steps(true, ran), {}) return {failed = failed, refused = refused} end)
    check("a red light check fails the run and is named", table.concat(results.failed, ","), "light red")
    check("it stops the light checks after it", table.concat(ran, ","), "light green,light other")
    check("so that no check that is not light starts", index_of(lines, "start plain") == nil and index_of(lines, "start heavy") == nil, true)
    check("the red check is reported at once, as a line of its own", index_of(lines, "FAIL light red") ~= nil, true)
    check("the stop is named with the check and says that no heavy check was started",
          lines[#lines], "prepush: light red failed; the run stops here, and no heavy check was started")
    check("the stop comes after the red line", index_of(lines, "FAIL light red") < index_of(lines, "run stops here"), true)

    ran = {}
    lines, results = captured(function () local failed = run_steps(ran_steps(true, ran), {keep_going = true}) return {failed = failed} end)
    check("with --keep-going the run goes on past a red light check", table.concat(ran, ","), "light green,light other,light after,plain,heavy")
    check("and says so before the first heavy check", index_of(lines, "starting the heavy checks although light red failed (--keep-going)") ~= nil
          and index_of(lines, "starting the heavy checks although") < index_of(lines, "start heavy"), true)
    check("and does not report a stop", index_of(lines, "run stops here"), nil)

    ran = {}
    lines, results = captured(function () local failed = run_steps(ran_steps(false, ran), {}) return {failed = failed} end)
    check("a green run starts every check", table.concat(ran, ","), "light green,light other,light after,plain,heavy")
    check("it says that the light checks are green before the first heavy check", index_of(lines, "the light checks are green; starting the heavy ones") ~= nil
          and index_of(lines, "the light checks are green") < index_of(lines, "start heavy"), true)
    check("each check says that it starts, then how it ended", index_of(lines, "start heavy") < index_of(lines, "ok heavy"), true)

    local failing = {{name = "light green", inline = function () return true end}, {name = "heavy red", heavy = true, run = function () return false end},
                     {name = "heavy later", heavy = true, run = function () error("must not run") end}}
    lines, results = captured(function () local failed = run_steps(failing, {}) return {failed = failed} end)
    check("a red heavy check stops the run and is named", table.concat(results.failed, ","), "heavy red")
    check("the stop line of a heavy check does not claim that no heavy check was started", lines[#lines], "prepush: heavy red failed; the run stops here")

    local memo_store = os.iorunv("mktemp", {"-d"}):trim()
    lines = captured(function ()
        return run_steps({{name = "alpha", inline = function () return true end}, {name = "beta", run = function () return true end}},
                         {store = memo_store, key = function (step) output.write("computing the key of " .. step.name) return "key-" .. step.name end})
    end)
    check("the first line of a run says that the keys are being computed", lines[1], "prepush: computing the keys of 2 checks")
    check("every key is computed after that line", index_of(lines, "computing the key of alpha") == 2 and index_of(lines, "computing the key of beta") == 3, true)
    check("a line says when the keys are done, with the number of remembered verdicts", lines[4], "prepush: keys done in 0s, 0 of 2 checks have a remembered verdict")
    check("no check starts before the keys are done", index_of(lines, "start alpha") > 4 and index_of(lines, "start beta") > 4, true)
    os.rm(memo_store)

    local flushes = 0
    local real_flush = io.flush
    io.flush = function (...) flushes = flushes + 1 return real_flush(...) end
    say("prepush test: a line is flushed as it is written")
    io.flush = real_flush
    check("every line written through say is flushed at once, not left to the buffer", flushes, 1)

    local function listing()
        return try { function () return os.iorunv("/bin/ps", {"-ax", "-o", "pid=,command="}) end } or ""
    end
    local function matching(predicate)
        local pids = {}
        for line in listing():gmatch("[^\n]+") do
            local pid, text = line:match("^%s*(%d+)%s+(.-)%s*$")
            if pid and predicate(text) then
                table.insert(pids, tonumber(pid))
            end
        end
        return pids
    end
    local function ends_with(text, suffix)
        return #text >= #suffix and text:sub(-#suffix) == suffix
    end
    local function wait_until(condition, milliseconds)
        local deadline = os.mclock() + milliseconds
        while not condition() and os.mclock() < deadline do
            os.sleep(300)
        end
        return condition()
    end
    local function kill(signal, pids)
        for _, pid in ipairs(pids) do
            try { function () os.iorunv("/bin/kill", {"-" .. signal, tostring(pid)}) end }
        end
    end
    local base = os.iorunv("mktemp", {"-d"}):trim()
    local script = path.join(root, "tools", "prepush.lua")
    local budget_script = path.join(root, "tools", "budget.lua")
    local unique = 3000 + os.getpid() % 2000

    local live_log = path.join(base, "live.log")
    local live_tag = tostring(unique)
    local live = process.openv(os.programfile(), {"l", "-P", root, script, "probe-say", live_tag}, {outpath = live_log, errpath = live_log, envs = {"REVENANT_BUDGET_HELD="}})
    local seen = wait_until(function () return (io.readfile(live_log) or ""):find("probe line", 1, true) ~= nil end, 60000)
    local still_running = #matching(function (text) return ends_with(text, "prepush.lua probe-say " .. live_tag) end)
    live:kill()
    kill("KILL", matching(function (text) return ends_with(text, "prepush.lua probe-say " .. live_tag) end))
    check("a line is in the log file while the process that wrote it still runs", seen and still_running == 1, true)

    local function hold_environment(pool, floor)
        return {"REVENANT_BUDGET_POOL=" .. pool, "REVENANT_BUDGET_HELD=", "REVENANT_BUDGET_DISK_GB=" .. floor}
    end

    local refused_seconds = tostring(unique + 1)
    local refused_pool = path.join(base, "poolRefused")
    os.mkdir(refused_pool)
    local refused_log = path.join(base, "hold-refused.log")
    local refused = process.openv(os.programfile(), {"l", "-P", root, script, "probe-hold", refused_seconds},
                                  {outpath = refused_log, errpath = refused_log, envs = hold_environment(refused_pool, "100000000")})
    local refusal_said = wait_until(function () return (io.readfile(refused_log) or ""):find("GB floor, so no heavy command starts", 1, true) ~= nil end, 90000)
    local refused_sleepers = #matching(function (text) return text == "/bin/sleep " .. refused_seconds end)
    refused:kill()
    kill("KILL", matching(function (text) return ends_with(text, "prepush.lua probe-hold " .. refused_seconds) or text == "/bin/sleep " .. refused_seconds end))
    check("a run whose disk is below the budget's floor is refused and starts no command, so the runs below pin the floor to 0", refusal_said and refused_sleepers == 0, true)

    for round, signal in ipairs({"TERM", "INT", "KILL"}) do
        local seconds = tostring(unique + round * 7)
        local sleeping = "/bin/sleep " .. seconds
        local pool = path.join(base, "pool" .. signal)
        os.mkdir(pool)
        local log = path.join(base, "hold-" .. signal .. ".log")
        local run = process.openv(os.programfile(), {"l", "-P", root, script, "probe-hold", seconds},
                                  {outpath = log, errpath = log, envs = hold_environment(pool, "0")})
        local function held_text()
            return try { function () return os.iorunv(os.programfile(), {"l", "-P", root, budget_script, "status"}, {envs = {REVENANT_BUDGET_POOL = pool, REVENANT_BUDGET_HELD = ""}}) end } or ""
        end
        local running = false
        wait_until(function ()
            running = #matching(function (text) return text == sleeping end) > 0 and held_text():find(" holds 1 token(s)", 1, true) ~= nil
            return running or (io.readfile(log) or ""):find("budget:", 1, true) ~= nil
        end, 90000)
        local mains = matching(function (text) return ends_with(text, "prepush.lua probe-hold " .. seconds) end)
        local runs = matching(function (text) return text:find("budget.lua run", 1, true) ~= nil and ends_with(text, "-- " .. sleeping) end)
        local sleepers = matching(function (text) return text == sleeping end)
        check("a run that holds its tokens has its prepush, its budget run and its command (" .. signal .. ")",
              string.format("held and listed %s, prepush %d, budget run %d, command %d, first line of its log %q", tostring(running), #mains, #runs, #sleepers, (io.readfile(log) or ""):match("[^\n]*")),
              "held and listed true, prepush 1, budget run 1, command 1, first line of its log \"\"")
        kill(signal, mains)
        local function all_gone()
            return #matching(function (text) return text == sleeping or ends_with(text, "-- " .. sleeping) or ends_with(text, "prepush.lua probe-hold " .. seconds) end) == 0
        end
        local gone = wait_until(all_gone, 30000)
        local leftovers = matching(function (text) return text == sleeping or ends_with(text, "-- " .. sleeping) end)
        local held_after = held_text()
        kill("KILL", leftovers)
        kill("KILL", mains)
        run:kill()
        check("after SIG" .. signal .. " to prepush no budget run and no command is left", #leftovers, 0)
        check("and the process that was signalled is gone", gone, true)
        check("and no token is held", held_after:find("held      0 token(s)", 1, true) ~= nil and not held_after:find(" holds ", 1, true), true)
    end

    os.rm(base)
    print("prepush: %d live tests passed", count)
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
    if budgeted(command) == REFUSED then
        os.tryrm(results)
        return REFUSED
    end
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
        test_dirty()
        test_live()
        return
    end
    if command == "probe-say" then
        say("probe line")
        os.sleep(600000)
        return
    end
    if command == "probe-hold" then
        budgeted({"/bin/sleep", ...}, {jobs = 1})
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
        say("%s", report)
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
    say("prepush: reading the state of the tree")
    local read_at = os.time()
    local input = inputs(root)
    local tracked_count = 0
    for _ in pairs(input.files) do
        tracked_count = tracked_count + 1
    end
    say("prepush: %d files, %d of them uncommitted or untracked (%ds)", tracked_count, input.dirty, os.time() - read_at)
    local failed, refused = run_steps(steps, {
        keep_going = parsed.keep_going,
        fresh = parsed.fresh,
        store = path.join(cache().store(), "memo"),
        worktree = path.filename(root),
        head = git(root, {"rev-parse", "HEAD"}):trim(),
        key = function (step) return key_of(input, step) end,
        batch = spawned_batch,
    })
    if refused then
        say("prepush: budget refused; this is not a failed check, free the space and rerun")
        os.exit(REFUSAL_EXIT)
    end
    if #failed > 0 then
        raise("%d of %d checks failed: %s", #failed, #steps, table.concat(failed, ", "))
    end
    if parsed.only then
        say("prepush: %d of %d checks passed (--only); a push needs all of them", #steps, #STEPS)
    else
        say("prepush: %d checks passed", #steps)
    end
end
