local function refused(action)
    local message
    try {
        action,
        catch {
            function (errors)
                message = tostring(errors)
            end
        }
    }
    return message
end

local function with_env(name, value, action)
    local saved = os.getenv(name)
    os.setenv(name, value)
    local result
    local message = refused(function () result = action() end)
    os.setenv(name, saved or "")
    if message then
        raise(message)
    end
    return result
end

function failures(opt)
    local workspace = import("workspace", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local revenant = path.directory(path.absolute(opt.modules))
    local cache = path.join(os.getenv("HOME"), ".revenant", "cache")

    if workspace.root() ~= revenant then
        table.insert(found, "root() is the checkout the module sits in: " .. workspace.root() .. " against " .. revenant)
    end

    local task = "revenant-workspace-test-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000000))
    local folder = with_env("REVENANT_TASK", task, function () return workspace.run("one", "two") end)
    if folder ~= path.join(cache, task, "one", "two") or not os.isdir(folder) then
        table.insert(found, "run() makes $HOME/.revenant/cache/<REVENANT_TASK>/<path>: " .. tostring(folder))
    end
    local first = with_env("REVENANT_TASK", task, function () return workspace.fresh("scratch") end)
    local second = with_env("REVENANT_TASK", task, function () return workspace.fresh("scratch") end)
    if first == second or not os.isdir(first) or not os.isdir(second) or path.directory(first) ~= path.join(cache, task) then
        table.insert(found, "fresh() makes a new folder under the task each call: " .. tostring(first) .. " " .. tostring(second))
    end
    os.tryrm(path.join(cache, task))

    local unnamed = with_env("REVENANT_TASK", "", function () return workspace.task() end)
    if not unnamed or unnamed == "" or unnamed:find("/", 1, true) then
        table.insert(found, "with no REVENANT_TASK the task is the checkout's folder name: " .. tostring(unnamed))
    end
    if revenant:startswith(path.join(cache, unnamed)) then
        table.insert(found, "run output is never inside the checkout")
    end

    local nowhere = path.join(cache, task .. "-missing")
    local message = refused(function () with_env("REVENANT_CORPUS_ROOT", nowhere, function () return workspace.corpus() end) end)
    if not message or not message:find(nowhere, 1, true) or not message:find("REVENANT_CORPUS_ROOT", 1, true) then
        table.insert(found, "a missing corpus is refused naming the folder and the variable: " .. tostring(message))
    end

    local fake = path.join(cache, task .. "-corpus")
    os.mkdir(path.join(fake, "corpus"))
    io.writefile(path.join(fake, "corpus", "rows.tsv"), "")
    local rows = with_env("REVENANT_CORPUS_ROOT", fake, function () return workspace.corpus("rows.tsv") end)
    if rows ~= path.join(fake, "corpus", "rows.tsv") then
        table.insert(found, "corpus(<file>) is the file under REVENANT_CORPUS_ROOT/corpus: " .. tostring(rows))
    end
    message = refused(function () with_env("REVENANT_CORPUS_ROOT", fake, function () return workspace.corpus("absent.tsv") end) end)
    if not message or not message:find("absent.tsv", 1, true) then
        table.insert(found, "a corpus file that is not there is refused by name: " .. tostring(message))
    end
    os.tryrm(fake)

    message = refused(function () with_env("REVENANT_GEN_SDK", nowhere, function () return workspace.sdk() end) end)
    if not message or not message:find("REVENANT_GEN_SDK", 1, true) or not message:find(nowhere, 1, true) then
        table.insert(found, "an SDK setting that names no SDK is refused naming it: " .. tostring(message))
    end
    local sdk = path.join(cache, task .. "-sdk", "iPhoneOS26.2.sdk")
    io.writefile(path.join(sdk, "SDKSettings.json"), "{}")
    local named = with_env("REVENANT_GEN_SDK", sdk, function () return workspace.sdk() end)
    if named ~= sdk then
        table.insert(found, "REVENANT_GEN_SDK names the SDK when it is set: " .. tostring(named))
    end
    os.tryrm(path.directory(sdk))
    return found
end
