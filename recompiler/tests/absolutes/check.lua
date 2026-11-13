local VALUE = "0x123456789"
local VALUE_BYTES = "\\89gE#\\01\\00\\00\\00"

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("absolutes", out)
    local function o(file)
        return path.join(out, file)
    end

    local definer, user = o("libdefiner.dylib"), o("libuser.dylib")
    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-dynamiclib", "-install_name", "@rpath/libdefiner.dylib", path.join(os.scriptdir(), "definer.S"), "-o", definer})
    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-O2", "-w", "-dynamiclib", "-install_name", "@rpath/libuser.dylib", path.join(os.scriptdir(), "user.c"), definer, "-o", user})
    io.writefile(o("passthrough.txt"), "")

    local symbols = os.iorunv("xcrun", {"nm", "-m", definer})
    if not symbols:find("(absolute) external _absolute_value", 1, true) then
        corpus.fail("the fixture does not export an absolute symbol:\n%s", symbols)
    end

    local function lift(name, images)
        local argv = {"--base", "0x10000000", "--output", o(name .. ".bc"), "--layout", o(name .. ".layout"), "--passthrough", o("passthrough.txt"),
                      "--state-header", o(name .. ".h"), "--library"}
        for _, image in ipairs(images) do
            table.insert(argv, image)
        end
        return corpus.run(e.xlate, argv, o(name .. ".log"))
    end

    local ok, log = lift("alone", {user})
    if ok or not log:find("data bind to unresolved symbol _absolute_value", 1, true) then
        corpus.fail("an image that binds an absolute symbol no guest image defines was not refused:\n%s", log)
    end

    ok, log = lift("both", {user, definer})
    if not ok or log:find("unresolved", 1, true) then
        corpus.fail("an absolute symbol of a guest image was not resolved:\n%s", log)
    end
    os.execv(path.join(e.llvmbin, "llvm-dis"), {o("both.bc"), "-o", o("both.ll")})
    local ir = io.readfile(o("both.ll"))
    if not ir:find(VALUE_BYTES, 1, true) then
        corpus.fail("the guest image does not hold the eight bytes of %s, the value of the absolute symbol unslid:\n%s", VALUE, log)
    end
    print("ok: a bind to an absolute symbol of a guest image takes its value, unslid")
end
