local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local SWIFT_CODE = {Func = true, Constructor = true, Accessor = true, Subscript = true}

local HEADER = [==[
#ifndef REVENANT_BACKPORTS_SKELETON_H
#define REVENANT_BACKPORTS_SKELETON_H

#include <objc/objc.h>

struct revenant_backports_class {
    const char *name;
    const char *super;
};

struct revenant_backports_method {
    const char *cls;
    const char *selector;
    int class_method;
    IMP implementation;
};

void revenant_backports_fail(const char *name) __attribute__((noreturn, visibility("hidden")));
void revenant_backports_register(const struct revenant_backports_class *classes, unsigned count,
                                 const struct revenant_backports_method *methods, unsigned method_count) __attribute__((visibility("hidden")));

#endif
]==]

local REGISTRAR = [==[
#include "revenant_backports.h"
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>

void revenant_backports_fail(const char *name)
{
    fprintf(stderr, "not implemented: %s\n", name);
    abort();
}

void revenant_backports_register(const struct revenant_backports_class *classes, unsigned count,
                                 const struct revenant_backports_method *methods, unsigned method_count)
{
    int progress = 1;
    while (progress) {
        progress = 0;
        for (unsigned index = 0; index < count; index++) {
            if (objc_getClass(classes[index].name))
                continue;
            Class parent = objc_getClass(classes[index].super);
            if (!parent)
                continue;
            Class cls = objc_allocateClassPair(parent, classes[index].name, 0);
            if (cls) {
                objc_registerClassPair(cls);
                progress++;
            }
        }
    }
    for (unsigned index = 0; index < method_count; index++) {
        Class cls = objc_getClass(methods[index].cls);
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

local function objc_model(rows)
    local classes, methods, seen = {}, {}, {}
    local function method(container, selector, class_method, label)
        local key = container .. "|" .. selector .. "|" .. (class_method and "+" or "-")
        if seen[key] == nil then
            seen[key] = true
            table.insert(methods, {cls = container, selector = selector, class_method = class_method, label = label})
        end
    end
    for _, row in ipairs(rows) do
        if row.kind == "class" and row.signature ~= "" then
            table.insert(classes, {name = row.name, super = row.signature})
        elseif row.kind == "instance method" or row.kind == "class method" then
            local class_method = row.kind == "class method"
            method(row.container, row.name, class_method, (class_method and "+" or "-") .. "[" .. row.container .. " " .. row.name .. "]")
        elseif row.kind == "property" then
            local label = "-[" .. row.container .. " " .. row.name .. "]"
            method(row.container, row.name, false, label)
            if string.find(row.signature, "^readonly ") == nil then
                method(row.container, setter(row.name), false, "-[" .. row.container .. " " .. setter(row.name) .. "]")
            end
        end
    end
    return classes, methods
end

local function write_objc(file, classes, methods)
    local lines = {'#include "revenant_backports.h"', ""}
    for index, method in ipairs(methods) do
        table.insert(lines, string.format("static void revenant_stub_%d(void)", index))
        table.insert(lines, string.format("{ revenant_backports_fail(%s); }", quoted(method.label)))
    end
    table.insert(lines, "")
    if #classes > 0 then
        local entries = {}
        for _, class in ipairs(classes) do
            table.insert(entries, string.format("{%s, %s}", quoted(class.name), quoted(class.super)))
        end
        table.insert(lines, "static const struct revenant_backports_class revenant_classes[] = {" .. table.concat(entries, ", ") .. "};")
    end
    if #methods > 0 then
        local entries = {}
        for index, method in ipairs(methods) do
            table.insert(entries, string.format("{%s, %s, %d, (IMP)revenant_stub_%d}", quoted(method.cls), quoted(method.selector),
                method.class_method and 1 or 0, index))
        end
        table.insert(lines, "static const struct revenant_backports_method revenant_methods[] = {" .. table.concat(entries, ", ") .. "};")
    end
    table.insert(lines, "__attribute__((constructor)) static void revenant_backports_load(void)")
    table.insert(lines, "{")
    table.insert(lines, string.format("    revenant_backports_register(%s, %d, %s, %d);",
        #classes > 0 and "revenant_classes" or "NULL", #classes, #methods > 0 and "revenant_methods" or "NULL", #methods))
    table.insert(lines, "}")
    io.writefile(file, table.concat(lines, "\n") .. "\n")
end

local function write_c(file, functions, swift)
    local lines = {'#include "revenant_backports.h"', ""}
    for index, entry in ipairs(functions) do
        table.insert(lines, string.format("__attribute__((weak, visibility(\"default\"))) void revenant_c_%d(void) __asm__(%s);", index, quoted("_" .. entry.symbol)))
        table.insert(lines, string.format("__attribute__((weak, visibility(\"default\"))) void revenant_c_%d(void) { revenant_backports_fail(%s); }", index, quoted(entry.label)))
    end
    for index, entry in ipairs(swift) do
        table.insert(lines, string.format("__attribute__((weak, visibility(\"default\"))) void revenant_swift_%d(void) __asm__(%s);", index, quoted("_" .. entry.symbol)))
        table.insert(lines, string.format("__attribute__((weak, visibility(\"default\"))) void revenant_swift_%d(void) { revenant_backports_fail(%s); }", index, quoted(entry.label)))
    end
    io.writefile(file, table.concat(lines, "\n") .. "\n")
end

function write(skeleton, frameworks)
    os.mkdir(skeleton)
    io.writefile(path.join(skeleton, "revenant_backports.h"), HEADER)
    io.writefile(path.join(skeleton, "registrar.m"), REGISTRAR)
    local totals = {objc = 0, c = 0, swift = 0}
    for _, framework in ipairs(frameworks) do
        local functions, swift = {}, {}
        local classes, methods = objc_model(framework.rows)
        for _, row in ipairs(framework.rows) do
            if row.kind == "C function" then
                table.insert(functions, {symbol = row.symbol, label = framework.name .. "." .. row.name})
            elseif row.kind == "Swift declaration" and SWIFT_CODE[row.signature] then
                table.insert(swift, {symbol = row.symbol, label = framework.name .. "." .. (row.container ~= "" and (row.container .. ".") or "") .. row.name})
            end
        end
        totals.objc = totals.objc + #methods
        totals.c = totals.c + #functions
        totals.swift = totals.swift + #swift
        os.tryrm(path.join(skeleton, framework.name .. ".m"))
        os.tryrm(path.join(skeleton, framework.name .. ".c"))
        if #classes > 0 or #methods > 0 then
            write_objc(path.join(skeleton, framework.name .. ".m"), classes, methods)
        end
        if #functions > 0 or #swift > 0 then
            write_c(path.join(skeleton, framework.name .. ".c"), functions, swift)
        end
    end
    return totals
end
