function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("rebasetag", out)
    local function o(file)
        return path.join(out, file)
    end

    local image = o("libtagged.dylib")
    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-O2", "-w", "-dynamiclib", "-install_name", "@rpath/libtagged.dylib", path.join(os.scriptdir(), "image.c"), "-o", image})
    io.writefile(o("passthrough.txt"), "")

    local ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--output", o("tagged.bc"), "--layout", o("tagged.layout"), "--passthrough", o("passthrough.txt"),
                                         "--state-header", o("tagged.h"), "--library", image}, o("tagged.log"))
    if not ok then
        corpus.fail("the lift of the image with a tagged rebased word failed:\n%s", log)
    end
    os.execv(path.join(e.llvmbin, "llvm-dis"), {o("tagged.bc"), "-o", o("tagged.ll")})
    local ir = io.readfile(o("tagged.ll"))
    if not ir:find("MARKER_A", 1, true) then
        corpus.fail("the lifted image does not hold the markers around the word, so the check cannot find it:\n%s", log)
    end
    if ir:find("MARKER_A.-\\00\\00\\00\\00MARKER_B") then
        corpus.fail("the rebased word lost its top byte (0x80): dyld slides the whole 64-bit word, and a Swift String literal of the image without that bit is taken for a native object")
    end
    if not ir:find("MARKER_A.-\\00\\00\\00\\80MARKER_B") then
        corpus.fail("the rebased word does not end in the top byte 0x80 of the file:\n%s", ir)
    end
    print("ok: a rebased 64-bit word keeps its top byte")
end
