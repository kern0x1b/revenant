import("core.base.json")

function main(out, opt)
    opt = type(opt) == "table" and opt or {}
    local scripts = path.join(os.scriptdir(), "..", "..", "scripts")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("classpair", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local expected = path.join(here, "expected.txt")

    os.execv("xcrun", {"clang", "-arch", "arm64", "-O0", "-w", path.join(here, "main.c"), "-lobjc", "-o", o("ClassPair-mac")})
    os.execv(o("ClassPair-mac"), {}, {stdout = o("run-mac.txt")})
    corpus.same(expected, o("run-mac.txt"), "objc4 on this Mac prints something else than expected.txt")

    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-O2", "-w", path.join(here, "main.c"), "-lobjc", "-o", o("ClassPair-arm64")})
    translate.translate(o("ClassPair-arm64"), path.join(here, "includes.h"), o("xl"))
    for _, image in ipairs(json.loadfile(o("xl/manifest.json")).images) do
        for _, class in ipairs(image.classes) do
            if class.data.name == "XLPairListedOverClsro" then
                corpus.fail("XLPairListedOverClsro (a classlist class over a clsrolist-only, all-guest ancestor) was kept at host layout")
            end
        end
    end
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    device.copy(o("xl/ClassPair"), "/var/tmp/ClassPair")
    io.writefile(o("run.txt"), device.run("chmod +x /var/tmp/ClassPair && /var/tmp/ClassPair 2>/dev/null; rm -f /var/tmp/ClassPair"))
    corpus.same(expected, o("run.txt"), "the translated program prints something else than objc4 does")
    print("ok")
end
