local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local implemented = import("implemented", {rootdir = tools, anonymous = true})

function main()
    local scratch = path.join(sdkfiles.build_root(), "stale_objects_test")
    if os.isdir(scratch) then
        os.rmdir(scratch)
    end
    local srcdir = path.join(scratch, "frameworks", "Backports", "src", "Foundation")
    local objdir = path.join(scratch, "build", ".objs", "FoundationBackports", "iphoneos", "armv7", "release", "frameworks", "Backports", "src", "Foundation")
    os.mkdir(srcdir)
    os.mkdir(objdir)
    local clang = sdkfiles.tool("clang")
    local live = path.join(srcdir, "Live.c")
    local gone = path.join(srcdir, "Gone.c")
    io.writefile(live, "int revenant_stale_live = 1;\n")
    io.writefile(gone, "int revenant_stale_gone = 1;\n")
    os.vrunv(clang, {"-c", live, "-o", path.join(objdir, "Live.c.o")})
    os.vrunv(clang, {"-c", gone, "-o", path.join(objdir, "Gone.c.o")})
    os.rm(gone)
    local keys = implemented.from_objects(path.join(scratch, "build", ".objs"))
    assert(keys.Foundation and keys.Foundation["global variable||revenant_stale_live"],
        "an object whose source exists must contribute its members")
    assert(keys.Foundation == nil or keys.Foundation["global variable||revenant_stale_gone"] == nil,
        "an orphan object whose source was removed must not contribute members")
    os.rmdir(scratch)
end
