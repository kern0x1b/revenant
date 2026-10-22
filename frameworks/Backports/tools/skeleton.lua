local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local SWIFT_CODE = {Func = true, Constructor = true, Accessor = true, Subscript = true}

local HEADER = [==[
#ifndef REVENANT_BACKPORTS_SKELETON_H
#define REVENANT_BACKPORTS_SKELETON_H

#include <objc/objc.h>

struct revenant_backports_method {
    const char *cls;
    const char *selector;
    int class_method;
    IMP implementation;
};

void revenant_backports_fail(const char *name) __attribute__((noreturn, visibility("hidden")));
void revenant_backports_register(const struct revenant_backports_method *methods, unsigned method_count) __attribute__((visibility("hidden")));

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
            if row.flags ~= "unavailable" and not implemented[row.name] then
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

local function objc_source(model, umbrella, alias)
    local lines = {'#include "revenant_backports.h"', string.format('#include "%s"', alias), umbrella, ""}
    for _, class in ipairs(model.classes) do
        table.insert(lines, string.format("REVENANT_ALIAS_OF(%s, %s)", class.name, class.super))
    end
    table.insert(lines, "")
    if #model.protocols > 0 then
        table.insert(lines, string.format("static Protocol *revenant_protocols[%d] __attribute__((used));", #model.protocols))
    end
    for _, name in ipairs(model.globals) do
        table.insert(lines, string.format('__attribute__((weak, visibility("default"))) __typeof__(%s) %s = {0};', name, name))
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
    table.insert(lines, "__attribute__((constructor)) static void revenant_backports_load(void)")
    table.insert(lines, "{")
    for index, name in ipairs(model.protocols) do
        table.insert(lines, string.format("    revenant_protocols[%d] = @protocol(%s);", index - 1, name))
    end
    table.insert(lines, string.format("    revenant_backports_register(%s, %d);", #model.methods > 0 and "revenant_methods" or "NULL", #model.methods))
    table.insert(lines, "}")
    return table.concat(lines, "\n") .. "\n"
end

local function c_source(functions, swift)
    local lines = {'#include "revenant_backports.h"', ""}
    for index, entry in ipairs(functions) do
        table.insert(lines, string.format("__attribute__((weak, visibility(\"default\"))) void revenant_c_%d(void) __asm__(%s);", index, quoted("_" .. entry.symbol)))
        table.insert(lines, string.format("__attribute__((weak, visibility(\"default\"))) void revenant_c_%d(void) { revenant_backports_fail(%s); }", index, quoted(entry.label)))
    end
    for index, entry in ipairs(swift) do
        table.insert(lines, string.format("__attribute__((weak, visibility(\"default\"))) void revenant_swift_%d(void) __asm__(%s);", index, quoted("_" .. entry.symbol)))
        table.insert(lines, string.format("__attribute__((weak, visibility(\"default\"))) void revenant_swift_%d(void) { revenant_backports_fail(%s); }", index, quoted(entry.label)))
    end
    return table.concat(lines, "\n") .. "\n"
end

local function emit(file, text)
    if not os.isfile(file) or io.readfile(file) ~= text then
        io.writefile(file, text)
    end
end

function write(skeleton, frameworks, implemented)
    os.mkdir(skeleton)
    emit(path.join(skeleton, "revenant_backports.h"), HEADER)
    emit(path.join(skeleton, "registrar.m"), REGISTRAR)
    local alias = path.join(sdkfiles.src_root(), "revenant_alias.h")
    local totals = {objc = 0, classes = 0, protocols = 0, globals = 0, c = 0, swift = 0}
    for _, framework in ipairs(frameworks) do
        local functions, swift, protocols, globals = {}, {}, {}, {}
        local classes, methods = objc_model(framework.rows, implemented, framework.unavailable)
        for _, row in ipairs(framework.rows) do
            if row.kind == "C function" then
                table.insert(functions, {symbol = row.symbol, label = framework.name .. "." .. row.name})
            elseif row.kind == "global variable" then
                table.insert(globals, row.name)
            elseif row.kind == "protocol" and row.flags ~= "nonruntime" then
                table.insert(protocols, row.name)
            elseif row.kind == "Swift declaration" and SWIFT_CODE[row.signature] then
                table.insert(swift, {symbol = row.symbol, label = framework.name .. "." .. (row.container ~= "" and (row.container .. ".") or "") .. row.name})
            end
        end
        totals.objc = totals.objc + #methods
        totals.classes = totals.classes + #classes
        totals.protocols = totals.protocols + #protocols
        totals.globals = totals.globals + #globals
        totals.c = totals.c + #functions
        totals.swift = totals.swift + #swift
        local objc_file = path.join(skeleton, framework.name .. ".m")
        local c_file = path.join(skeleton, framework.name .. ".c")
        if #classes > 0 or #methods > 0 or #protocols > 0 or #globals > 0 then
            emit(objc_file, objc_source({classes = classes, methods = methods, protocols = protocols, globals = globals}, framework.import or "", alias))
        else
            os.tryrm(objc_file)
        end
        if #functions > 0 or #swift > 0 then
            emit(c_file, c_source(functions, swift))
        else
            os.tryrm(c_file)
        end
    end
    return totals
end
