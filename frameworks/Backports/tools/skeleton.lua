local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local SWIFT_FUNCTION = {Func = true, Constructor = true, Accessor = true, Subscript = true}
local SWIFT_METADATA = {Struct = true, Class = true, Enum = true}

function src_only_image(images, name, folder, framework_exists)
    if images[name] ~= nil then
        return images[name]
    end
    assert(framework_exists, name .. " is implemented in src/" .. folder .. ", but no SDK image exports it and src/" .. folder .. " is not an SDK framework")
    return sdkfiles.framework_image(folder)
end

function owns_module(module, symbol)
    local prefix = string.format("$s%d%s", #module, module)
    return string.sub(symbol, 1, #prefix) == prefix
end

function swift_stub(row)
    local kind = row.signature
    if SWIFT_FUNCTION[kind] then
        return "function", row.symbol
    elseif SWIFT_METADATA[kind] then
        return "function", row.symbol .. "Ma"
    elseif kind == "Protocol" then
        return "data", row.symbol .. "Mp"
    elseif kind == "Var" and string.sub(row.symbol, -2) == "vp" then
        return "function", string.sub(row.symbol, 1, -3) .. "vg"
    end
    return nil
end

local HEADER = [==[
#ifndef REVENANT_BACKPORTS_SKELETON_H
#define REVENANT_BACKPORTS_SKELETON_H

#include <objc/objc.h>
#include <stddef.h>

struct revenant_backports_method {
    const char *cls;
    const char *selector;
    int class_method;
    IMP implementation;
};

struct revenant_backports_tramp {
    void **slot;
    const char *image;
    const char *name;
    void *fallback;
    void *fail;
};

void revenant_backports_fail(const char *name) __attribute__((noreturn, visibility("hidden")));
void revenant_backports_register(const struct revenant_backports_method *methods, unsigned method_count) __attribute__((visibility("hidden")));
void revenant_backports_global(void *storage, size_t size, const char *encoding, const char *name, const char *image, void *fallback) __attribute__((visibility("hidden")));
void *revenant_backports_c_target(void **slot, const char *image, const char *name) __attribute__((visibility("hidden")));
void *revenant_backports_lookup(const char *image, const char *name) __attribute__((visibility("hidden")));

#endif
]==]

local REGISTRAR = [==[
#include "revenant_backports.h"
#include <dlfcn.h>
#include <pthread.h>
#include <objc/NSObject.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char revenant_backports_absent = 0;

void revenant_backports_fail(const char *name)
{
    fprintf(stderr, "not implemented: %s\n", name);
    abort();
}

#define REVENANT_HANDLES 64
static pthread_mutex_t revenant_backports_lock = PTHREAD_MUTEX_INITIALIZER;
static const char *revenant_handle_image[REVENANT_HANDLES];
static void *revenant_handle_value[REVENANT_HANDLES];
static unsigned revenant_handle_count;

static void *revenant_backports_handle(const char *image)
{
    void *handle = NULL;
    pthread_mutex_lock(&revenant_backports_lock);
    for (unsigned index = 0; index < revenant_handle_count; index++) {
        if (strcmp(revenant_handle_image[index], image) == 0) {
            handle = revenant_handle_value[index];
            break;
        }
    }
    if (handle == NULL) {
        handle = dlopen(image, RTLD_LAZY);
        if (handle != NULL && revenant_handle_count < REVENANT_HANDLES) {
            revenant_handle_image[revenant_handle_count] = image;
            revenant_handle_value[revenant_handle_count] = handle;
            revenant_handle_count++;
        }
    }
    pthread_mutex_unlock(&revenant_backports_lock);
    return handle;
}

static void *revenant_backports_symbol(const char *image, const char *name)
{
    void *handle = revenant_backports_handle(image);
    return handle != NULL ? dlsym(handle, name) : NULL;
}

void *revenant_backports_lookup(const char *image, const char *name)
{
    return revenant_backports_symbol(image, name);
}

void *revenant_backports_c_target(void **slot, const char *image, const char *name)
{
    if (*slot == NULL) {
        void *found = revenant_backports_symbol(image, name);
        *slot = found != NULL ? found : (void *)&revenant_backports_absent;
    }
    return *slot == (void *)&revenant_backports_absent ? NULL : *slot;
}

static void revenant_missing_unrecognized(id self, SEL selector, SEL unrecognized)
{
    const char *name = NULL;
    Ivar ivar = class_getInstanceVariable(object_getClass(self), "name");
    if (ivar)
        name = *(const char **)((char *)(__bridge void *)self + ivar_getOffset(ivar));
    revenant_backports_fail(name);
}

static Class revenant_missing_class(void)
{
    Class cls = objc_getClass("RevenantMissingValue");
    if (cls)
        return cls;
    cls = objc_allocateClassPair(objc_getClass("NSObject"), "RevenantMissingValue", 0);
    class_addIvar(cls, "name", sizeof(const char *), (uint8_t)__builtin_ctz(__alignof__(const char *)), "*");
    class_addMethod(cls, sel_registerName("doesNotRecognizeSelector:"), (IMP)revenant_missing_unrecognized, "v@::");
    objc_registerClassPair(cls);
    return cls;
}

void revenant_backports_global(void *storage, size_t size, const char *encoding, const char *name, const char *image, void *fallback)
{
    if (size > 0) {
        void *system = revenant_backports_symbol(image, name);
        if (system != NULL) {
            memcpy(storage, system, size);
            return;
        }
        if (fallback != NULL) {
            memcpy(storage, fallback, size);
            return;
        }
    }
    if (encoding[0] != '@' || *(void **)storage != NULL)
        return;
    id value = [[revenant_missing_class() alloc] init];
    Ivar ivar = class_getInstanceVariable(object_getClass(value), "name");
    *(const char **)((char *)(__bridge void *)value + ivar_getOffset(ivar)) = name;
    *(void **)storage = (__bridge_retained void *)value;
}

void revenant_backports_register(const struct revenant_backports_method *methods, unsigned method_count)
{
    for (unsigned index = 0; index < method_count; index++) {
        Class cls = objc_getClass(methods[index].cls);
        if (!cls) {
            char alias[256];
            snprintf(alias, sizeof alias, "Revenant%s", methods[index].cls);
            cls = objc_getClass(alias);
        }
        if (!cls)
            continue;
        Class target = methods[index].class_method ? object_getClass((id)cls) : cls;
        SEL selector = sel_registerName(methods[index].selector);
        if (class_respondsToSelector(target, selector))
            continue;
        class_addMethod(target, selector, methods[index].implementation, "");
    }
}
]==]

local function quoted(text)
    return '"' .. string.gsub(string.gsub(text, "\\", "\\\\"), '"', '\\"') .. '"'
end

local function setter(name)
    return "set" .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) .. ":"
end

local function trim(text)
    return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

local MACRO_MARKS = {"_AVAILABLE", "AVAILABLE_", "_PROHIBITED", "_UNAVAILABLE", "_DEPRECATED", "_OBSOLETED",
    "_REFINED_FOR_SWIFT", "_SWIFT_NAME", "_SWIFT_UI_ACTOR", "_RETURNS_RETAINED", "_APPEARANCE_SELECTOR",
    "_NOESCAPE", "_RELEASES_ARGUMENT"}

local function is_macro(word)
    if not string.find(string.gsub(word, "^_+", ""), "^%u") then
        return false
    end
    for _, mark in ipairs(MACRO_MARKS) do
        if string.find(word, mark, 1, true) then
            return true
        end
    end
    return false
end

local function plain(text)
    local out = string.gsub(text, "%f[%w_]API_%u+%s*%b()", "")
    out = string.gsub(out, "%f[%w_]API_%u+%f[^%w_]", "")
    out = string.gsub(out, "%f[%w_]__attribute__%s*%b()", "")
    out = string.gsub(out, "%f[%w_]([%u%d_]+)%s*(%b())", function (word, args)
        if is_macro(word) then
            return ""
        end
        return nil
    end)
    out = string.gsub(out, "%f[%w_]([%u%d_]+)%f[^%w_]", function (word)
        if is_macro(word) then
            return ""
        end
        return nil
    end)
    return trim(string.gsub(out, "%s+", " "))
end

local function storage_type(text)
    local last_star = 0
    local position = string.find(text, "*", 1, true)
    while position ~= nil do
        last_star = position
        position = string.find(text, "*", position + 1, true)
    end
    local out = string.gsub(text, "()%f[%w_]const%f[^%w_]", function (at)
        if at > last_star then
            return ""
        end
        return "const"
    end)
    return plain(out)
end

local function group_close(text, open)
    local depth = 0
    for index = open, #text do
        local c = string.sub(text, index, index)
        if c == "(" then
            depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
            if depth == 0 then
                return index
            end
        end
    end
    return nil
end

local function declarator(text, name)
    local open = string.find(text, "(^", 1, true) or string.find(text, "(*", 1, true)
    local close = open and group_close(text, open)
    if close then
        return string.sub(text, 1, close - 1) .. " " .. name .. string.sub(text, close)
    end
    local array = string.find(text, "[", 1, true)
    if array then
        return string.sub(text, 1, array - 1) .. " " .. name .. string.sub(text, array)
    end
    return text .. " " .. name
end

local function split_top(text)
    local parts, depth, start = {}, 0, 1
    for index = 1, #text do
        local c = string.sub(text, index, index)
        if c == "(" or c == "<" or c == "[" then
            depth = depth + 1
        elseif c == ")" or c == ">" or c == "]" then
            depth = depth - 1
        elseif c == "," and depth == 0 then
            table.insert(parts, trim(string.sub(text, start, index - 1)))
            start = index + 1
        end
    end
    table.insert(parts, trim(string.sub(text, start)))
    return parts
end

function parse_function(signature)
    local text = plain(signature)
    if string.sub(text, -1) ~= ")" then
        return nil, "signature"
    end
    local depth, open = 0, nil
    for index = #text, 1, -1 do
        local c = string.sub(text, index, index)
        if c == ")" then
            depth = depth + 1
        elseif c == "(" then
            depth = depth - 1
            if depth == 0 then
                open = index
                break
            end
        end
    end
    if open == nil then
        return nil, "signature"
    end
    local ret = trim(string.sub(text, 1, open - 1))
    if ret == "" or string.find(ret, "(", 1, true) then
        return nil, "signature"
    end
    local inner = trim(string.sub(text, open + 1, -2))
    local params = {}
    if inner ~= "" and inner ~= "void" then
        for _, part in ipairs(split_top(inner)) do
            if part == "..." or string.find(part, "...", 1, true) then
                return nil, "variadic"
            end
            if part == "" then
                return nil, "signature"
            end
            table.insert(params, part)
        end
    end
    return {ret = ret, params = params}
end

local function objc_model(rows, implemented, unavailable)
    local classes, methods, seen = {}, {}, {}
    local function method(container, selector, class_method, label)
        local key = container .. "|" .. selector .. "|" .. (class_method and "+" or "-")
        if seen[key] == nil then
            seen[key] = true
            table.insert(methods, {cls = container, selector = selector, class_method = class_method, label = label})
        end
    end
    for _, row in ipairs(rows) do
        if row.kind == "class" then
            if not implemented[row.name] then
                local super = row.signature ~= "" and row.signature or "NSObject"
                table.insert(classes, {name = row.name, super = unavailable[super] and "NSObject" or super})
            end
        elseif row.kind == "instance method" or row.kind == "class method" then
            local class_method = row.kind == "class method"
            method(row.container, row.name, class_method, (class_method and "+" or "-") .. "[" .. row.container .. " " .. row.name .. "]")
        elseif row.kind == "property" then
            local class_method = string.find(" " .. (row.flags or "") .. " ", " class ", 1, true) ~= nil
            local getter = string.match(row.flags or "", "getter:(%S+)") or row.name
            local sign = class_method and "+" or "-"
            method(row.container, getter, class_method, sign .. "[" .. row.container .. " " .. getter .. "]")
            if string.find(row.signature, "^readonly ") == nil then
                method(row.container, setter(row.name), class_method, sign .. "[" .. row.container .. " " .. setter(row.name) .. "]")
            end
        end
    end
    return classes, methods
end

local function forwarder(index, entry)
    local types, decls, args = {}, {}, {}
    for position, ptype in ipairs(entry.params) do
        table.insert(types, ptype)
        table.insert(decls, declarator(ptype, "a" .. position))
        table.insert(args, "a" .. position)
    end
    local list = #types > 0 and table.concat(types, ", ") or "void"
    local params = #decls > 0 and table.concat(decls, ", ") or "void"
    local call = string.format("((revenant_fn_%d *)target)(%s)", index, table.concat(args, ", "))
    local lines = {}
    if entry.fallback then
        table.insert(lines, string.format("extern %s __revenant_fb_%s(%s);", entry.ret, entry.name, list))
    end
    table.join2(lines, {
        string.format("typedef %s revenant_fn_%d(%s);", entry.ret, index, list),
        string.format("static void *revenant_slot_%d;", index),
        string.format('__attribute__((weak, visibility("default"))) %s revenant_c_%d(%s) __asm__(%s);', entry.ret, index, params, quoted("_" .. entry.symbol)),
        string.format("%s revenant_c_%d(%s)", entry.ret, index, params),
        "{",
        string.format("    void *target = revenant_backports_c_target(&revenant_slot_%d, %s, %s);", index, quoted(entry.image), quoted(entry.symbol)),
        "    if (target != NULL) {",
    })
    if entry.ret == "void" then
        table.insert(lines, "        " .. call .. ";")
        table.insert(lines, "        return;")
    else
        table.insert(lines, "        return " .. call .. ";")
    end
    table.insert(lines, "    }")
    if entry.fallback then
        local forward = string.format("__revenant_fb_%s(%s)", entry.name, table.concat(args, ", "))
        if entry.ret == "void" then
            table.insert(lines, "    " .. forward .. ";")
            table.insert(lines, "    return;")
        else
            table.insert(lines, "    return " .. forward .. ";")
        end
    else
        table.insert(lines, string.format("    revenant_backports_fail(%s);", quoted(entry.label)))
    end
    table.insert(lines, "}")
    return lines
end

local function asm_text(text)
    return '"' .. (string.gsub(text, "%%%%", "%%")) .. '\\n"'
end

local function trampoline_asm(prefix, entries)
    local shared = "Lrevenant_" .. prefix .. "_shared"
    local resolve = "_revenant_" .. prefix .. "_tramp_resolve"
    local function labels(index, entry)
        return "_" .. entry.symbol, "_revenant_" .. prefix .. "_tramp_slot_" .. index,
            "Lrevenant_" .. prefix .. "_pool_" .. index, "Lrevenant_" .. prefix .. "_pc_" .. index,
            "Lrevenant_" .. prefix .. "_slow_" .. index
    end
    local function block(guard, per_entry, shared_lines, width)
        local lines = {guard, "__asm__(", asm_text(".pushsection __TEXT,__text,regular,pure_instructions")}
        for index, entry in ipairs(entries) do
            for _, text in ipairs(per_entry(index, entry)) do
                table.insert(lines, asm_text(text))
            end
            local slot = "_revenant_" .. prefix .. "_tramp_slot_" .. index
            for _, text in ipairs({".pushsection __DATA,__data", ".p2align " .. width, ".private_extern " .. slot, slot .. ":",
                width == 3 and "    .quad 0" or "    .long 0", ".popsection"}) do
                table.insert(lines, asm_text(text))
            end
        end
        for _, text in ipairs(shared_lines) do
            table.insert(lines, asm_text(text))
        end
        table.insert(lines, asm_text(".popsection"))
        table.insert(lines, ");")
        return lines
    end
    local function arm_entry(thumb)
        return function (index, entry)
            local public, slot, pool, here, slow = labels(index, entry)
            local out = {".globl " .. public, ".weak_definition " .. public}
            if thumb then
                table.insert(out, ".thumb_func " .. public)
            end
            table.insert(out, public .. ":")
            table.insert(out, "    ldr r12, " .. pool)
            table.insert(out, here .. ":")
            table.insert(out, thumb and "    add r12, pc" or "    add r12, pc, r12")
            table.insert(out, "    ldr r12, [r12]")
            table.insert(out, "    cmp r12, #0")
            table.insert(out, "    beq " .. slow)
            table.insert(out, "    bx r12")
            table.insert(out, slow .. ":")
            table.insert(out, "    movw r12, #" .. (index - 1))
            table.insert(out, "    b " .. shared)
            table.insert(out, ".p2align 2")
            table.insert(out, pool .. ":")
            table.insert(out, "    .long " .. slot .. "-(" .. here .. (thumb and "+4)" or "+8)"))
            return out
        end
    end
    local arm_shared = {shared .. ":", "    push {r0, r1, r2, r3, r4, lr}", "    vpush {d0, d1, d2, d3, d4, d5, d6, d7}", "    mov r0, r12",
        "    bl " .. resolve, "    mov r12, r0", "    vpop {d0, d1, d2, d3, d4, d5, d6, d7}", "    pop {r0, r1, r2, r3, r4, lr}", "    bx r12"}
    local function arm64_entry(index, entry)
        local public, slot, _, _, slow = labels(index, entry)
        return {".globl " .. public, ".weak_definition " .. public, ".p2align 2", public .. ":",
            "    adrp x16, " .. slot .. "@PAGE", "    ldr x17, [x16, " .. slot .. "@PAGEOFF]", "    cbz x17, " .. slow,
            "    br x17", slow .. ":", "    mov x17, #" .. (index - 1), "    b " .. shared}
    end
    local arm64_shared = {shared .. ":", "    sub sp, sp, #288", "    stp x0, x1, [sp, #0]", "    stp x2, x3, [sp, #16]",
        "    stp x4, x5, [sp, #32]", "    stp x6, x7, [sp, #48]", "    stp x8, x30, [sp, #64]", "    stp q0, q1, [sp, #80]",
        "    stp q2, q3, [sp, #112]", "    stp q4, q5, [sp, #144]", "    stp q6, q7, [sp, #176]", "    mov x0, x17",
        "    bl " .. resolve, "    mov x16, x0", "    ldp x0, x1, [sp, #0]", "    ldp x2, x3, [sp, #16]", "    ldp x4, x5, [sp, #32]",
        "    ldp x6, x7, [sp, #48]", "    ldp x8, x30, [sp, #64]", "    ldp q0, q1, [sp, #80]", "    ldp q2, q3, [sp, #112]",
        "    ldp q4, q5, [sp, #144]", "    ldp q6, q7, [sp, #176]", "    add sp, sp, #288", "    br x16"}
    local function x86_entry(index, entry)
        local public, slot, _, _, slow = labels(index, entry)
        return {".globl " .. public, ".weak_definition " .. public, public .. ":", "    cmpq $0, " .. slot .. "(%%rip)",
            "    je " .. slow, "    jmpq *" .. slot .. "(%%rip)", slow .. ":", "    movl $" .. (index - 1) .. ", %%r11d", "    jmp " .. shared}
    end
    local x86_shared = {shared .. ":", "    pushq %%rbp", "    movq %%rsp, %%rbp", "    pushq %%rdi", "    pushq %%rsi",
        "    pushq %%rdx", "    pushq %%rcx", "    pushq %%r8", "    pushq %%r9", "    pushq %%rax", "    subq $136, %%rsp"}
    for register = 0, 7 do
        table.insert(x86_shared, string.format("    movdqu %%%%xmm%d, %d(%%%%rsp)", register, 16 * register))
    end
    table.insert(x86_shared, "    movl %%r11d, %%edi")
    table.insert(x86_shared, "    callq " .. resolve)
    table.insert(x86_shared, "    movq %%rax, %%r11")
    for register = 0, 7 do
        table.insert(x86_shared, string.format("    movdqu %d(%%%%rsp), %%%%xmm%d", 16 * register, register))
    end
    for _, text in ipairs({"    addq $136, %%rsp", "    popq %%rax", "    popq %%r9", "    popq %%r8", "    popq %%rcx",
        "    popq %%rdx", "    popq %%rsi", "    popq %%rdi", "    popq %%rbp", "    jmpq *%%r11"}) do
        table.insert(x86_shared, text)
    end
    local lines = {}
    table.join2(lines, block("#if defined(__arm__) && defined(__thumb__)", arm_entry(true), arm_shared, 2))
    table.join2(lines, block("#elif defined(__arm__)", arm_entry(false), arm_shared, 2))
    table.join2(lines, block("#elif defined(__arm64__) || defined(__aarch64__)", arm64_entry, arm64_shared, 3))
    table.join2(lines, block("#elif defined(__x86_64__)", x86_entry, x86_shared, 3))
    table.insert(lines, "#else")
    table.insert(lines, '#error "backports: no trampoline for this architecture"')
    table.insert(lines, "#endif")
    return lines
end

local function trampoline_lines(prefix, entries)
    if #entries == 0 then
        return {}
    end
    local lines = {}
    for index, entry in ipairs(entries) do
        table.insert(lines, string.format('extern void *revenant_%s_tramp_slot_%d __asm__("_revenant_%s_tramp_slot_%d") __attribute__((visibility("hidden")));',
            prefix, index, prefix, index))
        table.insert(lines, string.format("static void revenant_%s_tramp_fail_%d(void)", prefix, index))
        table.insert(lines, string.format("{ revenant_backports_fail(%s); }", quoted(entry.label)))
        if entry.fallback then
            table.insert(lines, string.format("extern char revenant_%s_tramp_fb_%d __asm__(%s);", prefix, index, quoted("___revenant_fb_" .. entry.name)))
        end
    end
    table.join2(lines, trampoline_asm(prefix, entries))
    table.insert(lines, string.format("static const struct revenant_backports_tramp revenant_%s_tramps[] = {", prefix))
    for index, entry in ipairs(entries) do
        local fallback = entry.fallback and string.format("(void *)&revenant_%s_tramp_fb_%d", prefix, index) or "NULL"
        table.insert(lines, string.format("    {&revenant_%s_tramp_slot_%d, %s, %s, %s, (void *)revenant_%s_tramp_fail_%d},",
            prefix, index, quoted(entry.image), quoted(entry.symbol), fallback, prefix, index))
    end
    table.insert(lines, "};")
    table.insert(lines, string.format('__attribute__((visibility("hidden"), used)) void *revenant_%s_tramp_resolve(unsigned index)', prefix))
    table.insert(lines, "{")
    table.insert(lines, string.format("    const struct revenant_backports_tramp *entry = &revenant_%s_tramps[index];", prefix))
    table.insert(lines, "    void *target = revenant_backports_lookup(entry->image, entry->name);")
    table.insert(lines, "    if (target == NULL)")
    table.insert(lines, "        target = entry->fallback != NULL ? entry->fallback : entry->fail;")
    table.insert(lines, "    __atomic_store_n(entry->slot, target, __ATOMIC_RELAXED);")
    table.insert(lines, "    return target;")
    table.insert(lines, "}")
    return lines
end

local function swift_lines(swift, data)
    local lines = {}
    for index, entry in ipairs(swift) do
        table.insert(lines, string.format('__attribute__((weak, visibility("default"))) void revenant_swift_%d(void) __asm__(%s);', index, quoted("_" .. entry.symbol)))
        table.insert(lines, string.format('__attribute__((weak, visibility("default"))) void revenant_swift_%d(void) { revenant_backports_fail(%s); }', index, quoted(entry.label)))
    end
    for index, entry in ipairs(data) do
        table.insert(lines, string.format('__attribute__((weak, visibility("default"))) char revenant_swift_data_%d[16] __asm__(%s) = {0};', index, quoted("_" .. entry.symbol)))
    end
    return lines
end

local function objc_source(model, umbrella, alias)
    local lines = {'#include "revenant_backports.h"', string.format('#include "%s"', alias), umbrella, ""}
    for _, class in ipairs(model.classes) do
        table.insert(lines, string.format("REVENANT_ALIAS_OF(%s, %s)", class.name, class.super))
    end
    table.insert(lines, "")
    if #model.protocols > 0 then
        table.insert(lines, string.format("static Protocol *revenant_protocols[%d] __attribute__((used));", #model.protocols))
    end
    for _, global in ipairs(model.globals) do
        table.insert(lines, string.format('__attribute__((weak, visibility("default"))) %s __asm__(%s) = {0};',
            declarator(storage_type(global.type), "revenant_global_" .. global.name), quoted("_" .. global.name)))
        if global.fallback then
            table.insert(lines, string.format("extern %s;", declarator(storage_type(global.type), "__revenant_fb_" .. global.name)))
        end
    end
    for index, method in ipairs(model.methods) do
        table.insert(lines, string.format("static void revenant_stub_%d(void)", index))
        table.insert(lines, string.format("{ revenant_backports_fail(%s); }", quoted(method.label)))
    end
    table.insert(lines, "")
    if #model.methods > 0 then
        local entries = {}
        for index, method in ipairs(model.methods) do
            table.insert(entries, string.format("{%s, %s, %d, (IMP)revenant_stub_%d}", quoted(method.cls), quoted(method.selector),
                method.class_method and 1 or 0, index))
        end
        table.insert(lines, "static const struct revenant_backports_method revenant_methods[] = {" .. table.concat(entries, ", ") .. "};")
    end
    for index, entry in ipairs(model.functions) do
        table.join2(lines, forwarder(index, entry))
    end
    table.join2(lines, trampoline_lines(model.prefix, model.trampolines))
    table.join2(lines, swift_lines(model.swift, model.data))
    table.insert(lines, "__attribute__((constructor)) static void revenant_backports_load(void)")
    table.insert(lines, "{")
    for index, name in ipairs(model.protocols) do
        table.insert(lines, string.format("    revenant_protocols[%d] = @protocol(%s);", index - 1, name))
    end
    for _, global in ipairs(model.globals) do
        local size = global.array and "0" or string.format("sizeof(revenant_global_%s)", global.name)
        local fallback = global.fallback and string.format("(void *)&__revenant_fb_%s", global.name) or "NULL"
        table.insert(lines, string.format("    revenant_backports_global(&revenant_global_%s, %s, @encode(__typeof__(revenant_global_%s)), %s, %s, %s);",
            global.name, size, global.name, quoted(global.name), quoted(global.image), fallback))
    end
    table.insert(lines, string.format("    revenant_backports_register(%s, %d);", #model.methods > 0 and "revenant_methods" or "NULL", #model.methods))
    table.insert(lines, "}")
    return table.concat(lines, "\n") .. "\n"
end

local function emit(file, text)
    if not os.isfile(file) or io.readfile(file) ~= text then
        io.writefile(file, text)
    end
end

function write(skeleton, frameworks, implemented, images, markers, definitions)
    definitions = definitions or {}
    os.mkdir(skeleton)
    emit(path.join(skeleton, "revenant_backports.h"), HEADER)
    emit(path.join(skeleton, "registrar.m"), REGISTRAR)
    local alias = path.join(sdkfiles.src_root(), "revenant_alias.h")
    local totals = {objc = 0, classes = 0, protocols = 0, globals = 0, globals_uncopied = 0, c = 0, trampolines = 0, c_in_src = 0, src_only = 0, swift = 0}
    local outputs, seen_c, seen_global, imports_of = {}, {}, {}, {}
    local function output(name)
        if outputs[name] == nil then
            outputs[name] = {classes = {}, methods = {}, protocols = {}, functions = {}, trampolines = {}, globals = {}, swift = {}, data = {},
                imports = {}, import_seen = {}}
        end
        return outputs[name]
    end
    local function import_of(out, text)
        if text ~= "" and not out.import_seen[text] then
            out.import_seen[text] = true
            table.insert(out.imports, text)
        end
    end
    for _, framework in ipairs(frameworks) do
        local own = output(framework.name)
        import_of(own, framework.import or "")
        imports_of[framework.name] = framework.import or ""
        local classes, methods = objc_model(framework.rows, implemented, framework.unavailable)
        table.join2(own.classes, classes)
        table.join2(own.methods, methods)
        local function image_of(name)
            return images[name] or sdkfiles.framework_image(framework.name)
        end
        for _, row in ipairs(framework.rows) do
            local marked = markers[row.name] ~= nil
            if row.kind == "C function" and not seen_c[row.name] then
                seen_c[row.name] = true
                local signature = parse_function(row.signature)
                local out = output(marked and markers[row.name] or framework.name)
                import_of(out, framework.import or "")
                if signature == nil then
                    table.insert(out.trampolines, {name = row.name, symbol = row.symbol, label = framework.name .. "." .. row.name,
                        image = image_of(row.name), fallback = marked})
                    totals.trampolines = totals.trampolines + 1
                else
                    table.insert(out.functions, {name = row.name, symbol = row.symbol, label = framework.name .. "." .. row.name,
                        image = image_of(row.name), ret = signature.ret, params = signature.params, fallback = marked})
                    totals.c = totals.c + 1
                end
                if marked then
                    totals.c_in_src = totals.c_in_src + 1
                end
            elseif row.kind == "global variable" and not seen_global[row.name] then
                seen_global[row.name] = true
                local array = string.find(row.signature, "[", 1, true) ~= nil
                assert(not (marked and array), row.name .. " is implemented in src as an array, which has no copy")
                local out = output(marked and markers[row.name] or framework.name)
                import_of(out, framework.import or "")
                table.insert(out.globals, {name = row.name, type = row.signature, image = image_of(row.name), array = array,
                    fallback = marked})
                totals.globals = totals.globals + 1
                if array then
                    totals.globals_uncopied = totals.globals_uncopied + 1
                end
            elseif row.kind == "protocol" and not string.find(" " .. (row.flags or "") .. " ", " nonruntime ", 1, true) then
                table.insert(own.protocols, row.name)
            elseif row.kind == "Swift declaration" then
                local kind, symbol = swift_stub(row)
                if kind and owns_module(framework.name, row.symbol) then
                    local entry = {symbol = symbol, label = framework.name .. "." .. (row.container ~= "" and (row.container .. ".") or "") .. row.name}
                    table.insert(kind == "function" and own.swift or own.data, entry)
                end
            end
        end
        totals.objc = totals.objc + #methods
        totals.classes = totals.classes + #classes
        totals.protocols = totals.protocols + #own.protocols
        totals.swift = totals.swift + #own.swift + #own.data
    end
    local gap = {}
    for name in pairs(markers) do
        if not seen_c[name] and not seen_global[name] then
            table.insert(gap, name)
        end
    end
    table.sort(gap)
    for _, name in ipairs(gap) do
        local folder = markers[name]
        local definition = definitions[name]
        assert(definition ~= nil, name .. " is implemented in src, but no definition of it was found")
        local framework_exists = os.isdir(sdkfiles.framework_root(sdkfiles.sdk_folder(), folder))
        local image = src_only_image(images, name, folder, framework_exists)
        local out = output(folder)
        import_of(out, imports_of[folder] or "")
        if definition.kind == "function" then
            table.insert(out.trampolines, {name = name, symbol = name, label = folder .. "." .. name, image = image, fallback = true})
            totals.trampolines = totals.trampolines + 1
        elseif definition.kind == "global" then
            assert(definition.type ~= nil and definition.type ~= "", name .. " is implemented in src, but its declaration has no type")
            assert(not definition.array, name .. " is implemented in src as an array, which has no copy")
            table.insert(out.globals, {name = name, type = definition.type, image = image, array = false, fallback = true})
            totals.globals = totals.globals + 1
        else
            raise("%s is implemented in src, but is neither a function nor a global", name)
        end
        totals.src_only = totals.src_only + 1
    end
    local names = {}
    for name in pairs(outputs) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local out = outputs[name]
        local file = path.join(skeleton, name .. ".m")
        os.tryrm(path.join(skeleton, name .. ".c"))
        if #out.classes > 0 or #out.methods > 0 or #out.protocols > 0 or #out.globals > 0 or #out.functions > 0 or #out.trampolines > 0 or #out.swift > 0 or #out.data > 0 then
            emit(file, objc_source({classes = out.classes, methods = out.methods, protocols = out.protocols, globals = out.globals,
                functions = out.functions, trampolines = out.trampolines, prefix = (string.gsub(name, "[^%w_]", "_")),
                swift = out.swift, data = out.data}, table.concat(out.imports, "\n"), alias))
        else
            os.tryrm(file)
        end
    end
    return totals
end
