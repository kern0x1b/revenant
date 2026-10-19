import("core.base.json")

local CHARON = path.join(os.scriptdir(), "..", "..", "..")
local workspace = import("workspace", {rootdir = path.join(CHARON, "modules"), anonymous = true})
local probe = import("probe-exports", {rootdir = path.join(CHARON, "tests", "backports", "tools"), anonymous = true})

local function entry(api, status, kind)
    return {api = api, kind = kind or "function", introduced = "9.0", status = status or "implemented", effect = "none",
            reason = "because"}
end

local function registry(root, flat, parts)
    os.mkdir(path.join(root, "registry", "Fix"))
    if flat then
        json.savefile(path.join(root, "registry", "Fix.json"), {framework = "Fix", entries = flat})
    end
    for name, rows in pairs(parts) do
        json.savefile(path.join(root, "registry", "Fix", name), {framework = "Fix", entries = rows})
    end
end

local function read(flat, parts)
    local root = workspace.fresh("registry-files-test")
    registry(root, flat, parts)
    local said, refused, names = nil, false, nil
    try {
        function ()
            names = probe.registry_names(root)
        end,
        catch {
            function (errors)
                refused = true
                said = tostring(errors)
            end
        }
    }
    os.tryrm(root)
    return refused, said or "", names
end

local function has(text, word)
    return text:find(word, 1, true) ~= nil
end

local CASES = {
    {"probe-exports reads a registry where each name is in one file", function ()
        local refused = read({entry("fix_one")}, {["part.json"] = {entry("fix_two")}})
        return not refused
    end},
    {"probe-exports refuses a name in registry/Fix.json and registry/Fix/part.json, naming both", function ()
        local refused, said = read({entry("fix_both")}, {["part.json"] = {entry("fix_both", "absent")}})
        return refused and has(said, "fix_both") and has(said, "Fix.json") and has(said, "part.json")
    end},
    {"probe-exports refuses a name held by two files however many names each holds", function ()
        local refused, said = read({entry("fix_both"), entry("fix_other")}, {["part.json"] = {entry("fix_both")}})
        return refused and has(said, "Fix.json") and has(said, "part.json")
    end},
    {"probe-exports takes a function with and without its parentheses as one name", function ()
        local refused, said = read({entry("fix_call()")}, {["part.json"] = {entry("fix_call", "absent")}})
        return refused and has(said, "fix_call")
    end},
    {"probe-exports lists an absent constant or function with its file, and nothing else", function ()
        local refused, _, names = read({entry("fix_gone()", "absent"), entry("FixConstant", "absent", "constant"),
                                        entry("FixClass", "absent", "class"), entry("fix_kept", "implemented")}, {})
        return not refused and names.fix_gone and names.fix_gone[1] == path.join("registry", "Fix.json")
            and names.FixConstant ~= nil and names.FixClass == nil and names.fix_kept == nil
    end},
    {"probe-exports writes every name into the probe in byte order", function ()
        local text = probe.source_text({b = {}, B = {}, a = {}})
        return has(text, 'const char *names[] = {"B", "a", "b",  NULL};')
    end},
    {"probe-exports names the tree and the release in the probe's recipe", function ()
        local text = probe.recipe_text("/some/tree", "6.1")
        return has(text, 'add_repositories("charon /some/tree")') and has(text, 'set_config("apple_minimum", "6.1")')
    end},
}

function failures(opt)
    local found = {}
    for _, case in ipairs(CASES) do
        local passed = false
        local ok = try {
            function ()
                passed = case[2]()
                return true
            end,
            catch {
                function (err)
                    table.insert(found, case[1] .. ": raised " .. tostring(err))
                end
            }
        }
        if ok and not passed then
            table.insert(found, case[1])
        end
    end
    return found, #CASES
end

function main()
    local found, total = failures({})
    for _, line in ipairs(found) do
        print("registry_files_test FAIL: " .. line)
    end
    print(string.format("registry_files_test: %d checks, %d failed", total, #found))
    if #found > 0 then
        raise("registry_files_test: %d failure(s)", #found)
    end
end
