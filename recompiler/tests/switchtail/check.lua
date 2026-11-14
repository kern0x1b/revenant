local function lifted_size(e, bitcode)
    local functions, lines = 0, 0
    local inside = false
    for line in os.iorunv(path.join(e.llvmbin, "llvm-dis"), {bitcode, "-o", "-"}):gmatch("[^\n]+") do
        if line:match("^define .-@sub_%x+%(") then
            inside = true
            functions = functions + 1
        end
        if inside then
            lines = lines + 1
            if line == "}" then
                inside = false
            end
        end
    end
    return functions, lines
end

local MOST_FUNCTIONS, MOST_LINES = 80, 12000

function main(out, ...)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local opt = corpus.options(...)
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("switchtail", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local source = path.join(here, "main.c")

    os.execv("xcrun", {"clang", "-arch", "arm64", "-O2", "-w", source, "-o", o("switchtail-mac")})
    os.execv(o("switchtail-mac"), {}, {stdout = o("run-mac.txt")})

    corpus.ios(e, {"-O2", "-w", source, "-o", o("switchtail-arm64")})
    translate.translate(o("switchtail-arm64"), path.join(here, "includes.h"), o("xl"), {}, {})
    local functions, lines = lifted_size(e, o("xl/lifted.bc"))
    if functions > MOST_FUNCTIONS then
        corpus.fail("%d functions are lifted, at most %d are expected: the targets of the jump table are functions of their own again", functions, MOST_FUNCTIONS)
    end
    if lines > MOST_LINES then
        corpus.fail("the lifted functions are %d lines of IR, at most %d are expected: the code that the cases share is copied again", lines, MOST_LINES)
    end
    print("ok: %d lifted functions and %d lines of IR for a switch of 24 cases that share a tail", functions, lines)
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    device.copy(o("xl/switchtail"), "/var/tmp/switchtail")
    io.writefile(o("run.txt"), device.run("chmod +x /var/tmp/switchtail && /var/tmp/switchtail 2>/dev/null; rm -f /var/tmp/switchtail"))
    corpus.same(o("run-mac.txt"), o("run.txt"), "the translated program prints something else than the Mac does")
    print("ok")
end
