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
    translate.translate(o("switchtail-arm64"), path.join(here, "includes.h"), o("entries"), {}, {XL_LIFT_TARGETS = "entries"})
    translate.translate(o("switchtail-arm64"), path.join(here, "includes.h"), o("functions"), {}, {XL_LIFT_TARGETS = "functions"})
    local shared, shared_lines = lifted_size(e, o("entries/lifted.bc"))
    local alone, alone_lines = lifted_size(e, o("functions/lifted.bc"))
    if alone - shared < 20 then
        corpus.fail("lifting the targets of the table as entries leaves %d functions, lifting them as functions %d: fewer than 20 targets became entries", shared, alone)
    end
    if shared_lines * 10 > alone_lines * 6 then
        corpus.fail("the lifted functions are %d lines of IR with the targets as entries and %d lines with the targets as functions: the code they share is still copied", shared_lines, alone_lines)
    end
    print("ok: %d targets of the table are entries of the function that holds it, the lifted functions are %d lines of IR instead of %d", alone - shared, shared_lines, alone_lines)
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    device.copy(o("entries/switchtail"), "/var/tmp/switchtail")
    io.writefile(o("run.txt"), device.run("chmod +x /var/tmp/switchtail && /var/tmp/switchtail 2>/dev/null; rm -f /var/tmp/switchtail"))
    corpus.same(o("run-mac.txt"), o("run.txt"), "the translated program prints something else than the Mac does")
    print("ok")
end
