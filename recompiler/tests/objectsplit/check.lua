local FUNCTIONS = 6500
local INVOKES = 120
local MAX_OBJECT = 0x1000000

local function module(file)
    local parts = {'target triple = "armv7-apple-ios6.0"\n', "declare i32 @__gxx_personality_sj0(...)\n", "declare void @sink(i32)\n"}
    for function_index = 0, FUNCTIONS - 1 do
        table.insert(parts, string.format("define void @f%d() personality ptr @__gxx_personality_sj0 {\n", function_index))
        for call = 0, INVOKES - 1 do
            table.insert(parts, string.format("  invoke void @sink(i32 %d) to label %%b%d unwind label %%lp\nb%d:\n", call, call, call))
        end
        table.insert(parts, "  ret void\nlp:\n  %l = landingpad { ptr, i32 } cleanup\n  resume { ptr, i32 } %l\n}\n")
    end
    io.writefile(file, table.concat(parts))
end

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("objectsplit", out)
    local lifted = path.join(out, "lifted.bc")
    local host = {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk, "-O0", "-w"}
    local clang = path.join(e.llvmbin, "clang")

    module(path.join(out, "module.ll"))
    os.execv(clang, {"-target", "armv7-apple-ios6.0", "-marm", "-w", "-c", "-emit-llvm", path.join(out, "module.ll"), "-o", lifted})
    os.tryrm(path.join(out, "module.ll"))

    local whole, log = corpus.run(clang, table.join(host, {"-c", lifted, "-o", path.join(out, "whole.o")}), path.join(out, "whole.log"))
    if whole or not log:find("scattered relocation", 1, true) then
        corpus.fail("the module was meant to be too big for one object: armv7 Mach-O scattered relocations address 16 MB of a section, and one object of it compiled instead of failing:\n%s", log)
    end

    local objects = translate.compile_lifted(e, out, host)
    if #objects < 4 then
        corpus.fail("a module of %d bytes of bitcode went into %d objects, data included", os.filesize(lifted), #objects)
    end
    local defined = {}
    for _, object in ipairs(objects) do
        if os.filesize(object) >= MAX_OBJECT then
            corpus.fail("%s is %d bytes, more than the 16 MB one object can address", object, os.filesize(object))
        end
        for _, symbol in ipairs(os.iorunv("nm", {"-gjU", object}):split("\n", {plain = true})) do
            if symbol:match("^_f%d+$") then
                defined[symbol] = (defined[symbol] or 0) + 1
            end
        end
    end
    for function_index = 0, FUNCTIONS - 1 do
        if defined["_f" .. function_index] ~= 1 then
            corpus.fail("_f%d is defined %d times across the pieces", function_index, defined["_f" .. function_index] or 0)
        end
    end
    print("ok: a module of %d bytes of bitcode, too big for one object, compiles into %d objects", os.filesize(lifted), #objects)
end
