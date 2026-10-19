-- The implementation leads of a surface row: where a reference implementation might be read, by file name (its Impl, read
-- from the file lists `impl-index` wrote under corpus/impl-source-trees). A lead is a file of the name the row's type, function or
-- constant has, in a repository that stands for the framework; it is a lead, not a fact of implementation. Nothing is cloned or read
-- but the file lists.

local files = import("files", {anonymous = true})
local json = import("core.base.json")

-- The repositories the leads come from: `frameworks` names the frameworks a repository stands for (nil:
-- by directory, in `directory` repositories), `under` the folder its sources sit in, `strip` a prefix the repository's names drop,
-- `prefix` a function's or a constant's name that is a prefix of the file's, and `directory` the frameworks' own folders.
-- `branch` is the branch `impl-index` (tools/gen/cmd_impl-index.lua) lists.
local REPOS = {
    {source = "swift-foundation", repo = "swiftlang/swift-foundation", branch = "main", frameworks = {Foundation = true},
     under = "Sources/"},
    {source = "swift-corelibs-foundation", repo = "swiftlang/swift-corelibs-foundation", branch = "main",
     frameworks = {Foundation = true}, under = "Sources/", strip = "NS"},
    {source = "apple-oss", repo = "apple-oss-distributions/CF", branch = "main", frameworks = {CoreFoundation = true},
     under = "", prefix = true},
    {source = "apple-oss", repo = "apple-oss-distributions/objc4", branch = "main", frameworks = {ObjectiveC = true},
     under = "runtime/"},
    {source = "apple-oss", repo = "apple-oss-distributions/libdispatch", branch = "main", frameworks = {Dispatch = true},
     under = "src/swift/", strip = "Dispatch"},
    {source = "OpenCombine", repo = "OpenCombine/OpenCombine", branch = "master", frameworks = {Combine = true}, under = "Sources/"},
    {source = "OpenSwiftUI", repo = "OpenSwiftUIProject/OpenSwiftUI", branch = "main", frameworks = {SwiftUI = true, SwiftUICore = true},
     under = "Sources/"},
    {source = "WinObjC", repo = "microsoft/WinObjC", branch = "develop", under = "Frameworks/", prefix = true, directory = true},
}

-- The repositories, for the command that lists their files.
function repositories()
    return REPOS
end
local SOURCE_SUFFIXES = {".swift", ".c", ".m", ".mm", ".cpp", ".cc", ".h", ".hpp"}
local SKIPPED_DIRS = {"Tests/", "Test/", "Example", "Benchmarks/", ".github/", "docs/", "Docs/", "tests/", "samples/", "Samples/"}
local MEMBER_KINDS = {method = true, property = true, constant = true}

-- The index of one repository: its file stems, by (directory, stem), each to the shortest file name of that stem; and the directories
-- its files sit in (a `directory` repository only).
local function index_of(corpus, entry)
    local text = files.read_text(path.join(corpus, "impl-source-trees", string.gsub(entry.repo, "/", "_") .. ".json"))
    assert(text, "no file list for " .. entry.repo .. ": run tools/gen.lua impl-index first")
    local stems, directories = {}, {}
    local function remember(directory, stem, name)
        local key = (directory or "") .. "\t" .. stem
        if stems[key] == nil or #name < #stems[key] then
            stems[key] = name
        end
    end
    for _, name in ipairs(json.decode(text).files) do
        local under_ok = string.sub(name, 1, #entry.under) == entry.under
        local suffix_ok = false
        for _, suffix in ipairs(SOURCE_SUFFIXES) do
            if string.sub(name, -#suffix) == suffix then
                suffix_ok = true
            end
        end
        local skipped = false
        for _, dir in ipairs(SKIPPED_DIRS) do
            if string.find("/" .. name, "/" .. dir, 1, true) then
                skipped = true
            end
        end
        if under_ok and suffix_ok and not skipped then
            local parts = {}
            for part in string.gmatch(name, "[^/]+") do
                table.insert(parts, part)
            end
            local directory = nil
            if entry.directory and #parts > 2 then
                directory = string.lower(parts[2])
            end
            if not (entry.directory and directory == nil) then
                if directory then
                    directories[directory] = true
                end
                local stem = string.match(parts[#parts], "^(.*)%.[^.]*$") or parts[#parts]
                remember(directory, stem, name)
                if string.find(stem, "+", 1, true) then
                    remember(directory, string.match(stem, "^([^+]*)"), name)
                end
            end
        end
    end
    return {stems = stems, directories = directories}
end

-- The candidate stems of a name in one repository: the name itself (its part before the parentheses), its alias without the prefix
-- the repository's `strip` names, and, for a function or a constant (`loose`) in a `prefix` repository, every prefix that ends where a
-- capital letter or an underscore begins, longest first.
local function candidates(entry, name, loose)
    local base = string.match(name, "^([^(]*)")
    local found = {base}
    if entry.strip and string.sub(base, 1, #entry.strip) == entry.strip and #base > #entry.strip then
        table.insert(found, string.sub(base, #entry.strip + 1))
    end
    if entry.prefix and loose then
        local root = string.match(base, "^k%u") and string.sub(base, 2) or base
        for position = #root - 1, 4, -1 do
            local ch = string.sub(root, position + 1, position + 1)
            if string.match(ch, "%u") or ch == "_" then
                table.insert(found, (string.gsub(string.sub(root, 1, position), "_+$", "")))
            end
        end
    end
    return found
end

-- The owners a row's name belongs to, nearest first: its class for an ObjC member, and for a Swift member its type and the types that
-- enclose it. Only members, constants and the like have owners; a type or a function has none.
local function owners(kind, lang, api)
    local objc_owner = string.match(api, "^[-+]%[([%w_]+) ")
    if objc_owner then
        return {objc_owner}
    end
    if not MEMBER_KINDS[kind] then
        return {}
    end
    local base = string.match(api, "^([^(]*)")
    if not string.find(base, ".", 1, true) then
        return {}
    end
    local parts = {}
    for part in string.gmatch(base, "[^.]+") do
        table.insert(parts, part)
    end
    table.remove(parts)
    if lang == "objc" then
        return {parts[1]}
    end
    local out = {}
    for n = #parts, 1, -1 do
        table.insert(out, table.concat(parts, ".", 1, n))
    end
    return out
end

-- The index of every repository, read once per corpus: a list of {entry, index}.
local memo = {}
local function indexes(corpus)
    if memo[corpus] == nil then
        local out = {}
        for _, entry in ipairs(REPOS) do
            table.insert(out, {entry = entry, index = index_of(corpus, entry)})
        end
        memo[corpus] = out
    end
    return memo[corpus]
end

-- The leads of one surface row: {source = ..., file = "repo:path"} in the repositories' order, one per repository. A row in a
-- framework no repository stands for has none.
function leads(corpus, framework, kind, lang, api)
    local owner_names = owners(kind, lang, api)
    local member = #owner_names > 0 and MEMBER_KINDS[kind] ~= nil
    local names = member and owner_names or {api}
    local loose = (kind == "function" or kind == "constant") and not member
    local out = {}
    for _, item in ipairs(indexes(corpus)) do
        local entry, index = item.entry, item.index
        local applies
        if entry.frameworks ~= nil then
            applies = entry.frameworks[framework] == true
        else
            applies = index.directories[string.lower(framework)] == true
        end
        if applies then
            local directory = entry.directory and string.lower(framework) or nil
            local found = nil
            for _, name in ipairs(names) do
                for _, candidate in ipairs(candidates(entry, name, loose)) do
                    local hit = index.stems[(directory or "") .. "\t" .. candidate]
                    if found == nil and hit ~= nil then
                        found = hit
                    end
                end
            end
            if found then
                table.insert(out, {source = entry.source, file = entry.repo .. ":" .. found})
            end
        end
    end
    return out
end
