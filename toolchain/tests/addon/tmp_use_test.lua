local PATTERNS = {"os%.tmp" .. "dir", "os%.tmp" .. "file", "getenv%(\"TMP" .. "DIR\"%)"}

local SCANNED = {
    "toolchain/tests/*.lua",
    "toolchain/tests/addon/*.lua",
    "toolchain/modules/debian.lua",
    "toolchain/modules/apple/img3.lua",
    "frameworks/ReactNative/tests/host_install_test.lua",
    "frameworks/ReactNative/tests/isolate_test.lua",
    "frameworks/ReactNative/tests/overlay_test.lua",
    "frameworks/ReactNative/tools/isolate.lua",
    "frameworks/Backports/tests/device_imports_test.lua",
    "frameworks/Backports/tests/export_baseline_test.lua",
    "frameworks/Backports/tests/lowered_exports_test.lua",
    "frameworks/Backports/tests/lowered_members_test.lua",
    "tools/analysis_cache.lua",
    "tools/budget.lua",
    "tools/dyld_caches.lua",
    "tools/prepush.lua",
}

local GUARDS = {["tmp_use_test.lua"] = true, ["light_suites.lua"] = true, ["tmp_guard.lua"] = true}

local function uses_of(file)
    local found = {}
    local number = 0
    for line in io.lines(file) do
        number = number + 1
        for _, pattern in ipairs(PATTERNS) do
            if line:find(pattern) then
                table.insert(found, number)
                break
            end
        end
    end
    return found
end

local function redirected(root, folder)
    local script = path.join(folder, "probe.lua")
    io.writefile(script, "function main()\n    print(os.tmp" .. "dir())\nend\n")
    local own = path.join(folder, "own")
    os.mkdir(own)
    local text = os.iorunv(os.programfile(), {"l", "-P", root, script}, {envs = {XMAKE_TMPDIR = own, TMPDIR = own}})
    return text:trim():startswith(own), own
end

function failures(opt)
    local root = path.absolute(path.join(opt.modules, "..", ".."))
    local guard = import("tmp_guard", {rootdir = opt.modules, anonymous = true})
    local fixtures = import("fixtures", {rootdir = path.join(opt.modules, "..", "tests", "addon"), anonymous = true})
    local found = {}
    local scanned = 0
    for _, pattern in ipairs(SCANNED) do
        for _, file in ipairs(os.files(path.join(root, pattern))) do
            if not GUARDS[path.filename(file)] then
                scanned = scanned + 1
                for _, number in ipairs(uses_of(file)) do
                    table.insert(found, string.format("%s:%d takes a file or a folder of the system temporary folder; a test works in a folder of its own under the scratch of the checkout (fixtures.scratch() in a suite, workspace.fresh(name) elsewhere)",
                                                      path.relative(file, root), number))
                end
            end
        end
    end
    if scanned < 60 then
        table.insert(found, string.format("only %d files were scanned, so the patterns of SCANNED no longer find the tests", scanned))
    end

    local before_dir, before_file = os.tmpdir, os.tmpfile
    local restore = guard.forbid("probe_test")
    local refused = {}
    for name, call in pairs({["os.tmpdir"] = function () return os.tmpdir() end, ["os.tmpfile"] = function () return os.tmpfile() end}) do
        try {
            function ()
                call()
            end,
            catch {
                function (errors)
                    refused[name] = tostring(errors):find("probe_test calls " .. name .. ", which is the system temporary folder", 1, true) ~= nil
                end
            }
        }
    end
    restore()
    for _, name in ipairs({"os.tmpdir", "os.tmpfile"}) do
        if not refused[name] then
            table.insert(found, "a suite that calls " .. name .. " must be refused, naming the suite")
        end
    end
    if os.tmpdir ~= before_dir or os.tmpfile ~= before_file then
        table.insert(found, "the guard must put os.tmpdir and os.tmpfile back")
    end

    local ok = redirected(root, fixtures.scratch())
    if not ok then
        table.insert(found, "a child process given XMAKE_TMPDIR and TMPDIR must answer os.tmpdir() with a folder under it")
    end
    return found
end
