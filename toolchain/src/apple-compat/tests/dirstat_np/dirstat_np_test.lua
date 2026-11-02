local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local dir = path.absolute(os.scriptdir())
    local compat = path.absolute(path.join(dir, "..", ".."))
    local test = path.join(dir, "dirstat_np_test.c")
    local header = path.join(compat, "include", "revenant", "dirstat_np.h")
    local out = workspace.run("apple-compat-dirstat")
    local apple, ours = path.join(out, "apple"), path.join(out, "ours")
    local objects = {}
    for _, name in ipairs({"dirstat_np", "openat", "fstatat"}) do
        local object = path.join(out, name .. ".o")
        os.vrunv("xcrun", {"clang", "-O1", "-c", path.join(compat, "src", name .. ".c"), "-o", object})
        table.insert(objects, object)
    end
    os.vrunv("xcrun", table.join({"clang", "-O1", "-I", path.join(compat, "include"), "-include", header, "-o", ours, test}, objects))
    os.vrunv("xcrun", {"clang", "-O1", "-o", apple, test})
    local tree_apple, tree_ours = path.join(out, "tree-apple"), path.join(out, "tree-ours")
    os.tryrm(tree_apple)
    os.tryrm(tree_ours)
    os.mkdir(tree_apple)
    os.mkdir(tree_ours)
    local expected = os.iorunv(apple, {tree_apple})
    local actual = os.iorunv(ours, {tree_ours})
    assert(not expected:find("FAIL", 1, true), "the fixture could not be built:\n" .. expected)
    assert(actual == expected, "dirstat_np differs from the host's:\n" .. expected .. "---\n" .. actual)
end
