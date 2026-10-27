local picture = import("lib.picture", {rootdir = os.scriptdir(), anonymous = true})
local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})

function main()
    local snapshots = tree.root("tests", "data", "snapshots")
    local styles_tree = path.join(snapshots, "styles.txt")
    local typography_tree = path.join(snapshots, "typography.txt")
    assert(picture.tree_difference(styles_tree, styles_tree) == 0, "a text tree must match itself")
    assert(picture.tree_difference(styles_tree, typography_tree) > 0, "a text tree of another scenario must differ")
    print("tree: all checks passed")
    local models = os.dirs(path.join(tree.workspace().home(), "device-baselines", "*"))
    assert(#models > 0, "no phone has a baseline: run --live --accept --calibrate=N on a phone first")
    for _, dir in ipairs(models) do
        local name = path.filename(dir)
        local height = picture.read_screen(path.join(dir, "screen.txt"))
        local tolerance = picture.read_tolerances(path.join(dir, "tolerance.txt")).styles
        local styles = path.join(dir, "styles.png")
        local typography = path.join(dir, "typography.png")
        assert(height and tolerance and os.isfile(styles) and os.isfile(typography),
               name .. " lacks its screen, tolerance or the styles and typography references")
        assert(picture.judge(styles, styles, height, tolerance), name .. ": a picture must match itself")
        assert(not picture.judge(styles, typography, height, tolerance), name .. ": a picture of another scenario must fail")
        print("picture: all checks passed for %s", name)
    end
end
