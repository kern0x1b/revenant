-- The VFS overlay the headers command writes for a port (tools/gen/cmd_headers.lua overlay_text) is read by clang: an overlay with no
-- entries must be a valid one. clang takes roots as an array, and json.encode writes an empty table as an object, so the empty overlay
-- is checked by the compiler itself: clang -ivfsoverlay accepts the array form, and rejects the object form the writer used to give.
-- Run:
--   xmake l tests/gen/vfs_overlay_test.lua
-- The fixtures live under build/ in the tree and are removed when the test ends.

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "vfs-overlay-test")

-- clang -fsyntax-only over an empty source, with the overlay: the status is 0 when clang reads the overlay and accepts the source.
local function clang_accepts(overlay_file, source)
    local status = os.execv("xcrun", {"--sdk", "macosx", "clang", "-fsyntax-only", "-ivfsoverlay", overlay_file, source},
                            {try = true})
    return status == 0
end

local function run()
    local cmd = import("gen.cmd_headers", {rootdir = TOOLS, anonymous = true})
    local json = import("core.base.json")
    local failures = 0
    local function check(ok, what)
        if not ok then
            failures = failures + 1
            print("FAIL " .. what)
        end
    end

    os.rm(SCRATCH)
    os.mkdir(SCRATCH)
    local source = path.join(SCRATCH, "empty.c")
    io.writefile(source, "int fixture_value;\n")

    -- the writer's empty overlay: roots is an array, and the text says so
    local empty = cmd.overlay_text({})
    check(string.find(empty, '"roots":[]', 1, true) ~= nil, "the empty overlay writes roots as an array")
    check(json.decode(empty).roots ~= nil, "the empty overlay parses as JSON")
    local empty_file = path.join(SCRATCH, "empty-vfs.yaml")
    io.writefile(empty_file, empty)
    check(clang_accepts(empty_file, source), "clang -ivfsoverlay accepts the empty overlay")

    -- the form the writer gave before: roots as an object, which clang must refuse (the test measures the cause)
    local object_form = path.join(SCRATCH, "object-vfs.yaml")
    io.writefile(object_form, '{"case-sensitive":"false","version":0,"roots":{}}')
    check(not clang_accepts(object_form, source), "clang refuses the object form of roots, the defect this test pins")

    -- one entry: a directory of one file, mapped to the port's file, is accepted as well
    local mapped = path.join(SCRATCH, "Fixture.h")
    io.writefile(mapped, "/* fixture */\n")
    local one = cmd.overlay_text({[path.join(SCRATCH, "Fixture.framework", "Headers")] = {{name = "Fixture.h", external = path.absolute(mapped)}}})
    local one_file = path.join(SCRATCH, "one-vfs.yaml")
    io.writefile(one_file, one)
    check(clang_accepts(one_file, source), "clang -ivfsoverlay accepts an overlay with one mapped file")

    os.rm(SCRATCH)
    print("vfs overlay test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

run()
