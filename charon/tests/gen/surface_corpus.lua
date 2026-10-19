-- The corpus files the surface reads beside a tree's shards (surface_model.lua and surface_impl.lua): the crash demand table and the
-- file list of each implementation-lead repository. A fixture test that reads the surface calls write(corpus) once: by default the
-- demand table has no rows and every repository lists no file. listed maps a repository ("owner/name") to the files it lists, and
-- demand is the table's text (its header included). Nothing else in the corpus is written.

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local REPOS = {"swiftlang/swift-foundation", "swiftlang/swift-corelibs-foundation", "apple-oss-distributions/CF",
               "apple-oss-distributions/objc4", "apple-oss-distributions/libdispatch", "OpenCombine/OpenCombine",
               "OpenSwiftUIProject/OpenSwiftUI", "microsoft/WinObjC"}
local EMPTY_DEMAND = "rank\tseverity\tapi\tkind\tframework\tapps\tcrash_callers\n"

-- Writes the demand table and the file lists under corpus.
function write(corpus, demand, listed)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    listed = listed or {}
    os.mkdir(path.join(corpus, "impl-source-trees"))
    emit.file(path.join(corpus, "crash-demand-top.tsv"), demand or EMPTY_DEMAND)
    for _, repo in ipairs(REPOS) do
        local quoted = {}
        for _, name in ipairs(listed[repo] or {}) do
            table.insert(quoted, '"' .. name .. '"')
        end
        local file = path.join(corpus, "impl-source-trees", (string.gsub(repo, "/", "_")) .. ".json")
        emit.file(file, '{"sha": "fixture", "files": [' .. table.concat(quoted, ", ") .. "]}\n")
    end
end
