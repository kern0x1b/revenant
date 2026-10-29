local SYSTEMS = {
    Security = {library = "/System/Library/Frameworks/Security.framework/Security", probe = "SecTrustGetTrustResult"},
    Network = {library = "/System/Library/Frameworks/Network.framework/Network"},
}

local function emit(file, text)
    if not os.isfile(file) or io.readfile(file) ~= text then
        io.writefile(file, text)
    end
end

function names(file)
    local list = {}
    for line in io.lines(file) do
        if line ~= "" then
            table.insert(list, line)
        end
    end
    table.sort(list)
    return list
end

function rename_header(list)
    local lines = {"#ifndef REVENANT_DEFER_RENAME_H", "#define REVENANT_DEFER_RENAME_H"}
    for _, name in ipairs(list) do
        table.insert(lines, "#define " .. name .. " RevenantImpl_" .. name)
    end
    table.insert(lines, "#endif")
    return table.concat(lines, "\n") .. "\n"
end

function unexported_list(list)
    local lines = {}
    for _, name in ipairs(list) do
        table.insert(lines, "_RevenantImpl_" .. name)
    end
    return table.concat(lines, "\n") .. "\n"
end

local function asm_block(lines, tail)
    local out = {"__asm__("}
    for _, line in ipairs(lines) do
        table.insert(out, string.format('    "%s\\n"', line))
    end
    table.insert(out, string.format("    %s);", tail or '""'))
    return table.concat(out, "\n")
end

local function arm64(name)
    return asm_block({
        ".section __TEXT,__text,regular,pure_instructions",
        ".globl _" .. name,
        ".p2align 2",
        "_" .. name .. ":",
        "adrp x16, _revenant_slot_" .. name .. "@PAGE",
        "ldr x16, [x16, _revenant_slot_" .. name .. "@PAGEOFF]",
        "br x16",
    })
end

local function arm32(name)
    return asm_block({
        ".section __TEXT,__text,regular,pure_instructions",
        ".code 32",
        ".globl _" .. name,
        ".p2align 2",
        "_" .. name .. ":",
        "ldr r12, Lrevenant_" .. name .. "_literal",
        "Lrevenant_" .. name .. "_pc:",
        "add r12, pc, r12",
        "ldr r12, [r12]",
        "bx r12",
        "Lrevenant_" .. name .. "_literal:",
        ".long _revenant_slot_" .. name .. " - (Lrevenant_" .. name .. "_pc + 8)",
    }, "REVENANT_DEFER_RESTORE")
end

function trampoline_source(list, system)
    local lines = {
        "#include <dlfcn.h>",
        "#include <stddef.h>",
        "",
        "#if __has_feature(ptrauth_calls)",
        "#include <ptrauth.h>",
        "#define REVENANT_DEFER_CODE(pointer) ptrauth_strip((pointer), ptrauth_key_function_pointer)",
        "#else",
        "#define REVENANT_DEFER_CODE(pointer) (pointer)",
        "#endif",
        "",
        "#define REVENANT_DEFER_LIBRARY \"" .. system.library .. "\"",
        "",
        "static void *revenant_defer_pick(void *library, const char *name, void *backport)",
        "{",
        "    void *system = library ? dlsym(library, name) : NULL;",
        "    return REVENANT_DEFER_CODE(system ? system : backport);",
        "}",
        "",
    }
    for _, name in ipairs(list) do
        table.insert(lines, "extern void RevenantImpl_" .. name .. "(void);")
        table.insert(lines, "void *revenant_slot_" .. name .. " __attribute__((visibility(\"hidden\")));")
    end
    table.insert(lines, "")
    table.insert(lines, "#if defined(__arm64__)")
    table.insert(lines, "#define REVENANT_DEFER_RESTORE \"\"")
    for _, name in ipairs(list) do
        table.insert(lines, arm64(name))
    end
    table.insert(lines, "#elif defined(__arm__)")
    table.insert(lines, "#if defined(__thumb__)")
    table.insert(lines, "#define REVENANT_DEFER_RESTORE \".code 16\\n\"")
    table.insert(lines, "#else")
    table.insert(lines, "#define REVENANT_DEFER_RESTORE \".code 32\\n\"")
    table.insert(lines, "#endif")
    for _, name in ipairs(list) do
        table.insert(lines, arm32(name))
    end
    table.insert(lines, "#else")
    table.insert(lines, "#error \"the deferral trampolines are written for arm64 and armv7 only\"")
    table.insert(lines, "#endif")
    table.insert(lines, "")
    table.insert(lines, "__attribute__((constructor(101))) static void revenant_defer_bind(void)")
    table.insert(lines, "{")
    table.insert(lines, "    void *library = dlopen(REVENANT_DEFER_LIBRARY, RTLD_LAZY);")
    if system.probe then
        table.insert(lines, "#define REVENANT_DEFER_PROBE \"" .. system.probe .. "\"")
        table.insert(lines, "    if (library && !dlsym(library, REVENANT_DEFER_PROBE)) {")
        table.insert(lines, "        library = NULL;")
        table.insert(lines, "    }")
    end
    for _, name in ipairs(list) do
        table.insert(lines, string.format('    revenant_slot_%s = revenant_defer_pick(library, "%s", (void *)RevenantImpl_%s);', name, name, name))
    end
    table.insert(lines, "}")
    return table.concat(lines, "\n") .. "\n"
end

function generate(list, folder, system)
    os.mkdir(folder)
    local header = path.join(folder, "revenant_defer_rename.h")
    local source = path.join(folder, "revenant_defer.c")
    local unexport = path.join(folder, "revenant_defer_unexport.txt")
    emit(header, rename_header(list))
    emit(source, trampoline_source(list, system))
    emit(unexport, unexported_list(list))
    return header, source, unexport
end

function configure(target, list, folder, name)
    local header, source, unexport = generate(list, folder, SYSTEMS[name])
    target:add("files", source)
    for _, kind in ipairs({"cflags", "cxxflags", "mflags", "mxxflags"}) do
        target:add(kind, "-include", header, {force = true})
    end
    target:add("shflags", "-Wl,-unexported_symbols_list," .. unexport, {force = true})
end
