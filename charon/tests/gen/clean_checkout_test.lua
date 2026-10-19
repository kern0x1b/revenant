-- The clean-checkout check (review F2, and the v-gen2 ruling): the tree is extracted into a folder under .agent-work/runs of this
-- checkout (`git archive HEAD` when the checkout is a git work tree, so only committed files; the tree's own files, without its
-- derived folders, when it is not one: a tree that came from git archive has no .git), and `gen --all` and `check --all` run from that
-- folder with no derived file present. It fails when
-- any file outside packages/a/apple-backports/.gen appears or changes (gen may write only that folder), when gen or check exits
-- non-zero, or when the Python oracle runs: gen and check run with a python3 on the PATH that writes a marker and fails, and the marker
-- must not exist afterwards (the build path reads the committed products and runs no generator). In a git work tree it checks HEAD, the last
-- commit: git archive reads committed files only, so an uncommitted change is not tested until it is committed. The archive, the python3
-- stand-in and the marker are removed at the end. Run: xmake l tests/gen/clean_checkout_test.lua (from any folder)

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local GEN_PREFIX = "packages/a/apple-backports/.gen/"
-- The SDK folder the generator reads its release from: the committed release-26.2 fixture (SDKSettings only; gen and check read no framework from it).
local SDK_FIXTURE = path.absolute(path.join(os.scriptdir(), "sdk_fixture", "release-26.2"))
-- The folders of a tree that are not its sources: the agent work area, the build products, xmake's state and the generator's output.
local DERIVED = {".git", ".agent-work", "build", ".xmake", "packages/a/apple-backports/.gen"}

-- Every file under dir, keyed by its path relative to dir, with its size and modification time.
local function listing(dir)
    local out = {}
    for _, filepath in ipairs(os.files(path.join(dir, "**"))) do
        out[path.relative(filepath, dir)] = {size = os.filesize(filepath), mtime = os.mtime(filepath)}
    end
    return out
end

-- The sorted names of a listing.
local function names_of(list)
    local out = {}
    for name in pairs(list) do
        table.insert(out, name)
    end
    table.sort(out)
    return out
end

-- Whether ROOT is the top of a git work tree (and not a folder inside another repository, which `git archive` would then take the
-- folder's own path of, and find empty).
local function is_work_tree_top()
    local top = false
    try {
        function ()
            local prefix = os.iorunv("git", {"-C", ROOT, "rev-parse", "--show-prefix"})
            top = prefix:gsub("%s+", "") == ""
        end,
        catch {
            function () top = false end
        }
    }
    return top
end

-- Extracts the tree under test into dir. Returns the exit status of the extraction (0 on success).
local function extract(dir)
    if is_work_tree_top() then
        return os.execv("sh", {"-c", 'git -C "$1" archive --format=tar HEAD | tar -x -C "$2"', "sh", ROOT, dir}, {try = true})
    end
    local argv = {"-c", "-f", "-"}
    for _, name in ipairs(DERIVED) do
        table.insert(argv, "--exclude")
        table.insert(argv, "./" .. name)
    end
    table.insert(argv, "-C")
    table.insert(argv, ROOT)
    table.insert(argv, ".")
    return os.execv("sh", {"-c", 'tar "$@" | tar -x -C "$0"', dir, table.unpack(argv)}, {try = true})
end

-- The exit status of `xmake l tools/gen.lua <args>` run from dir with the given PATH, or nil when it could not start.
local function run_gen(dir, args, search_path)
    local argv = {"l", "tools/gen.lua"}
    for _, arg in ipairs(args) do
        table.insert(argv, arg)
    end
    return (os.execv(os.programfile(), argv, {try = true, curdir = dir, envs = {PATH = search_path}}))
end

function main()
    local failures = 0
    local function fail(label)
        failures = failures + 1
        print("FAIL " .. label)
    end
    local stamp = tostring(os.time()) .. "-" .. tostring(math.random(1000000))
    local dir = path.join(ROOT, ".agent-work", "runs", "clean-checkout-" .. stamp)
    local shim_dir = path.join(ROOT, ".agent-work", "runs", "clean-checkout-python-" .. stamp)
    local marker = path.join(shim_dir, "python3-was-run")
    os.mkdir(dir)
    os.mkdir(shim_dir)
    -- a python3 that records that it ran and fails, first on the PATH of the generator's runs
    io.writefile(path.join(shim_dir, "python3"), "#!/bin/sh\ntouch '" .. marker .. "'\nexit 99\n")
    os.execv("chmod", {"755", path.join(shim_dir, "python3")})
    local search_path = shim_dir .. ":" .. (os.getenv("PATH") or "")
    -- the stand-in must catch a call, or the "never ran" result below proves nothing
    os.execv("sh", {"-c", "python3"}, {try = true, envs = {PATH = search_path}})
    local caught = os.isfile(marker)
    if caught then
        os.rm(marker)
    else
        fail("the python3 stand-in does not catch a call, so the no-python result would prove nothing")
    end
    local extracted = extract(dir)
    if extracted ~= 0 then
        fail("the tree could not be extracted (status " .. tostring(extracted) .. ")")
    elseif not os.isfile(path.join(dir, "tools", "gen.lua")) then
        fail("the extracted tree holds no tools/gen.lua: the extraction is not the tree under test")
    else
        local before = listing(dir)
        local started = os.mclock()
        local gen_status = run_gen(dir, {"gen", "--tree", dir, "--all", "--sdk", SDK_FIXTURE}, search_path)
        local gen_ms = os.mclock() - started
        started = os.mclock()
        local check_status = run_gen(dir, {"check", "--tree", dir, "--all", "--sdk", SDK_FIXTURE}, search_path)
        local check_ms = os.mclock() - started
        local after = listing(dir)
        if gen_status ~= 0 then
            fail("gen --all from the clean checkout exits " .. tostring(gen_status))
        end
        if check_status ~= 0 then
            fail("check --all from the clean checkout exits " .. tostring(check_status))
        end
        if os.isfile(marker) then
            fail("the Python oracle ran from the clean checkout (python3 was called by gen or check)")
        end
        local derived, outside = 0, 0
        for _, name in ipairs(names_of(after)) do
            local was = before[name]
            if string.sub(name, 1, #GEN_PREFIX) == GEN_PREFIX then
                derived = derived + 1
            elseif was == nil then
                outside = outside + 1
                fail("added outside .gen: " .. name)
            elseif was.size ~= after[name].size or was.mtime ~= after[name].mtime then
                outside = outside + 1
                fail("changed outside .gen: " .. name)
            end
        end
        for _, name in ipairs(names_of(before)) do
            if after[name] == nil and string.sub(name, 1, #GEN_PREFIX) ~= GEN_PREFIX then
                outside = outside + 1
                fail("removed outside .gen: " .. name)
            end
        end
        if derived == 0 then
            fail("gen wrote nothing under " .. GEN_PREFIX)
        end
        print(string.format("clean checkout: %d files in the archive before, %d after, %d under .gen, %d outside .gen changed",
            #names_of(before), #names_of(after), derived, outside))
        print(string.format("clean checkout: gen --all exit %s in %d ms, check --all exit %s in %d ms, python3 run: %s",
            tostring(gen_status), gen_ms, tostring(check_status), check_ms, tostring(os.isfile(marker))))
    end
    os.rm(dir)
    os.rm(shim_dir)
    print("clean checkout test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
