local json = import("core.base.json")
local emit = import("emit", {anonymous = true})
local surface_impl = import("surface_impl", {anonymous = true})

local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local function blobs(tree)
    local out = {}
    for _, item in ipairs(tree.tree or {}) do
        if item.type == "blob" then
            table.insert(out, item.path)
        end
    end
    return out
end

function run(args)
    local corpus = args.corpus or workspace.corpus()
    local trees = path.join(corpus, "impl-source-trees")
    os.mkdir(trees)
    for _, entry in ipairs(surface_impl.repositories()) do
        local text = os.iorunv("gh", {"api", "repos/" .. entry.repo .. "/git/trees/" .. entry.branch .. "?recursive=1"})
        local tree = json.decode(text)
        if tree == nil or tree.sha == nil then
            raise("impl-index: %s did not answer with a tree", entry.repo)
        end
        if tree.truncated then
            raise("impl-index: %s: the tree is truncated by GitHub, the file list is incomplete", entry.repo)
        end
        local files = blobs(tree)
        if #files == 0 then
            json.mark_as_array(files)
        end
        local listing = {repo = entry.repo, branch = entry.branch, sha = tree.sha, files = files}
        emit.file(path.join(trees, string.gsub(entry.repo, "/", "_") .. ".json"), json.encode(listing) .. "\n")
        print(string.format("%s@%s: %d files", entry.repo, string.sub(tree.sha, 1, 10), #files))
    end
    return 0
end
