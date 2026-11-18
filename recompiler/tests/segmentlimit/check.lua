local REFUSAL = "dyld's bind and rebase opcodes name a segment with 4 bits"

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("segmentlimit", out)
    local function o(file)
        return path.join(out, file)
    end

    local images = {}
    for index = 0, 6 do
        local image = o(string.format("libimage%d.dylib", index))
        corpus.ios(e, {"-fuse-ld=" .. e.ld, "-O2", "-w", "-dynamiclib", "-install_name", string.format("@rpath/libimage%d.dylib", index),
                       string.format("-DINDEX=%d", index), path.join(os.scriptdir(), "image.c"), "-o", image})
        table.insert(images, image)
    end
    io.writefile(o("passthrough.txt"), "")

    local function lift(name, count, library, base)
        local argv = {"--base", base or "0x10000000", "--output", o(name .. ".bc"), "--layout", o(name .. ".layout"), "--passthrough", o("passthrough.txt"),
                      "--state-header", o(name .. ".h")}
        if library then
            table.insert(argv, "--library")
        end
        for index = 1, count do
            table.insert(argv, images[index])
        end
        return corpus.run(e.xlate, argv, o(name .. ".log"))
    end

    local ok, log = lift("seven", 7)
    if ok then
        corpus.fail("an executable of seven guest images was translated: its seventh image's data segment is segment 16, which no bind or rebase opcode can name")
    end
    for _, phrase in ipairs({REFUSAL, "at most 6 guest images", "--library", "7 images"}) do
        if not log:find(phrase, 1, true) then
            corpus.fail("the refusal of seven images does not say %q:\n%s", phrase, log)
        end
    end

    ok, log = lift("six", 6)
    if log:find(REFUSAL, 1, true) then
        corpus.fail("six guest images fit the executable's 16 segment indices and were refused:\n%s", log)
    end

    ok, log = lift("library", 7, true)
    if log:find(REFUSAL, 1, true) then
        corpus.fail("a library has no guest segments of its own, and seven images were refused:\n%s", log)
    end
    local CEILING = "ends above 0x2fc00000"
    ok, log = lift("ceiling", 1, true, "0x2fbfc000")
    if ok or not log:find(CEILING, 1, true) or not log:find("lower --base by at least 0x", 1, true) then
        corpus.fail("a library whose guest image reaches the main stack's zone was translated, or the refusal does not say %q and by how much to lower the base:\n%s", CEILING, log)
    end
    ok, log = lift("under", 1, true, "0x2e000000")
    if log:find(CEILING, 1, true) or not log:find("xlate: guest image 0x2e000000-0x", 1, true) then
        corpus.fail("a library whose guest image is under the main stack was refused, or its guest image was not written:\n%s", log)
    end
    print("ok: seven guest images are refused for an executable, six are not, a library takes seven, and a library's guest image ends under the main stack or is refused")
end
