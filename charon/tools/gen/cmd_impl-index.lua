-- `impl-index`: the file lists of the reference implementations that surface_impl.lua reads as implementation leads. For each
-- repository in surface_impl's REPOS it asks GitHub for the tree of the repository's branch (`gh api`, names only, nothing cloned)
-- and writes {repo, branch, sha, files} to <corpus>/impl-source-trees/<owner>_<name>.json. A tree GitHub truncates is refused: a
-- list with files missing from it would drop leads without a word. Port of the former sdk-surface.py impl-index.
--
-- usage: xmake l tools/gen.lua impl-index --tree T [--coordination <corpus folder>]
-- The corpus folder defaults to $CHARON_CORPUS_ROOT/corpus (CHARON_CORPUS_ROOT defaults to ~/Git/projects/ios/coordination).

local json = import("core.base.json")
local emit = import("emit", {anonymous = true})
local surface_impl = import("surface_impl", {anonymous = true})

local function default_corpus()
    local root = os.getenv("CHARON_CORPUS_ROOT") or path.join(os.getenv("HOME"), "Git", "projects", "ios", "coordination")
    return path.join(root, "corpus")
end

-- The blob paths of a tree listing, in the order GitHub gives them.
local function blobs(tree)
    local out = {}
    for _, item in ipairs(tree.tree or {}) do
        if item.type == "blob" then
            table.insert(out, item.path)
        end
    end
    return out
end

-- Returns the exit status: 0 when every repository's list is written.
function run(args)
    local corpus = args.coordination or default_corpus()
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
