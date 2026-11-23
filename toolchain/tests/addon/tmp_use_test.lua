local PATTERNS = {"os%.tmp" .. "dir", "os%.tmp" .. "file", "getenv%(\"TMP" .. "DIR\"%)"}

local SCANNED = {
    "toolchain/tests/*.lua",
    "toolchain/tests/addon/*.lua",
    "toolchain/modules/debian.lua",
    "toolchain/modules/apple/img3.lua",
    "frameworks/ReactNative/tests/host_install_test.lua",
    "frameworks/ReactNative/tests/isolate_test.lua",
    "frameworks/ReactNative/tests/overlay_test.lua",
    "frameworks/Backports/tests/export_baseline_test.lua",
    "tools/analysis_cache.lua",
    "tools/budget.lua",
    "tools/dyld_caches.lua",
    "tools/prepush.lua",
}

local GUARDS = {["tmp_use_test.lua"] = true, ["light_suites.lua"] = true}

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

function failures(opt)
    local root = path.join(opt.modules, "..", "..")
    local light = import("light_suites", {rootdir = path.join(opt.modules, "..", "tests"), anonymous = true})
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
    local restore = light.forbid_system_tmp("probe_test")
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
    return found
end
