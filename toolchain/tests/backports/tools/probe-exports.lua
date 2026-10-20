import("core.base.json")
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "modules"), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "modules"), anonymous = true})

local PROGRAM = "exportprobe"

local SOURCE = [==[#import <Foundation/Foundation.h>
#include <dlfcn.h>

int main(void)
{
    NSArray *folders = @[@"/System/Library/Frameworks", @"/System/Library/PrivateFrameworks"];
    int opened = 0;
    for (NSString *folder in folders) {
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL]) {
            if (![name hasSuffix:@".framework"])
                continue;
            NSString *path = [NSString stringWithFormat:@"%@/%@/%@", folder, name, [name stringByDeletingPathExtension]];
            if (dlopen([path UTF8String], RTLD_LAZY))
                opened++;
        }
    }
    printf("opened %d\n", opened);
    const char *names[] = {@NAMES@ NULL};
    for (int i = 0; names[i]; i++)
        if (dlsym(RTLD_DEFAULT, names[i]))
            printf("exported %s\n", names[i]);
    printf("done\n");
    return 0;
}
]==]

local RECIPE = [[set_project("exportprobe")
set_version("0.1.0")
add_repositories("revenant @REVENANT@")
add_addons("revenant latest")
set_config("apple_minimum", "@RELEASE@")
includes("@addon/revenant/apple-ios")
includes("@addon/revenant/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
target("exportprobe")
    add_rules("@addon/revenant/daemon")
    add_files("probe.m")
    add_frameworks("Foundation")
    set_values("revenant.control", "packaging/control")
]]

local CONTROL = [[Package: org.revenant.exportprobe
Name: Revenant export probe
Architecture: iphoneos-arm
Description: asks the release which names it exports
Maintainer: revenant
Author: revenant
Section: Development
]]

local USAGE = "usage: xmake l tests/backports/tools/probe-exports.lua (--registry | --names <file>) --workdir <folder> "
              .. "[--release 6.0] [--revenant <tree>]"

local function replace(text, marker, value)
    return (text:gsub(marker:gsub("%p", "%%%0"), (value:gsub("%%", "%%%%"))))
end

local function entries_of(held, file)
    if type(held) ~= "table" then
        raise("%s holds no registry entries", file)
    end
    if held.entries ~= nil then
        return held.entries
    end
    if #held == 0 and next(held) ~= nil then
        raise("%s holds an object with no entries", file)
    end
    return held
end

function registry_names(root)
    local files = {}
    table.join2(files, os.files(path.join(root, "registry", "*.json")))
    table.join2(files, os.files(path.join(root, "registry", "*", "*.json")))
    byteorder.sort(files)
    local names, told = {}, {}
    for _, file in ipairs(files) do
        local relative = path.relative(file, root)
        for _, entry in ipairs(entries_of(json.decode(io.readfile(file)), file)) do
            local name = entry.api:gsub("%(%)$", "")
            if told[name] then
                raise("%s is named by both %s and %s", entry.api, told[name], relative)
            end
            told[name] = relative
            if entry.status == "absent" and (entry.kind == "constant" or entry.kind == "function") then
                names[name] = names[name] or {}
                table.insert(names[name], relative)
            end
        end
    end
    return names
end

function source_text(listed)
    local sorted = table.keys(listed)
    byteorder.sort(sorted)
    local literal = {}
    for _, name in ipairs(sorted) do
        table.insert(literal, '"' .. name .. '", ')
    end
    return replace(SOURCE, "@NAMES@", table.concat(literal))
end

function recipe_text(revenant, release)
    return replace(replace(RECIPE, "@REVENANT@", revenant), "@RELEASE@", release)
end

function control_text()
    return CONTROL
end

local function parse(argv)
    local options = {release = "6.0", revenant = workspace.root()}
    local i = 1
    while i <= #argv do
        local name = argv[i]
        if name == "--registry" then
            options.registry = true
            i = i + 1
        elseif name == "--names" or name == "--release" or name == "--revenant" or name == "--workdir" then
            local value = argv[i + 1]
            if value == nil then
                raise("%s needs a value\n%s", name, USAGE)
            end
            options[name:sub(3)] = value
            i = i + 2
        else
            raise("unknown argument %s\n%s", name, USAGE)
        end
    end
    if options.workdir == nil then
        raise("--workdir is required\n%s", USAGE)
    end
    return options
end

local function run(argv, workdir)
    local log = path.join(workdir, "probe-step.log")
    local out = io.open(log, "w")
    local status = os.execv(os.programfile(), argv, {curdir = workdir, stdout = out, stderr = out, try = true})
    out:close()
    local text = io.readfile(log)
    os.rm(log)
    return status, text
end

function main(...)
    local options = parse({...})
    local root = path.join(options.revenant, "packages", "frameworks", "apple-backports")
    local listed
    if options.registry then
        listed = registry_names(root)
    elseif options.names then
        listed = {}
        for line in io.lines(options.names) do
            local name = line:match("^%s*(.-)%s*$")
            if name ~= "" then
                listed[name] = {}
            end
        end
    else
        raise("name the names with --names or --registry\n%s", USAGE)
    end
    if table.empty(listed) then
        raise("there are no names to ask about")
    end
    local workdir = path.absolute(options.workdir)
    os.tryrm(workdir)
    os.mkdir(path.join(workdir, "packaging"))
    io.writefile(path.join(workdir, "probe.m"), source_text(listed))
    io.writefile(path.join(workdir, "xmake.lua"), recipe_text(options.revenant, options.release))
    io.writefile(path.join(workdir, "packaging", "control"), control_text())
    for _, argv in ipairs({{"f", "-y", "-c"}, {"-y"}, {"emulate", "install"}}) do
        local status, text = run(argv, workdir)
        if status ~= 0 then
            raise("xmake %s failed:\n%s", table.concat(argv, " "), text)
        end
    end
    local _, text = run({"emulate", "run", "/usr/libexec/" .. PROGRAM}, workdir)
    local exported = {}
    for line in text:gmatch("[^\n]+") do
        if line:sub(1, 9) == "exported " then
            table.insert(exported, line:match("^exported%s+(%S+)"))
        end
    end
    byteorder.sort(exported)
    if not text:find("done", 1, true) then
        raise("the probe did not finish:\n%s", text)
    end
    local count = 0
    for _ in pairs(listed) do
        count = count + 1
    end
    print(string.format("%d of %d names are exported by iOS %s", #exported, count, options.release))
    for _, name in ipairs(exported) do
        print(string.format("exported %s %s", name, table.concat(listed[name] or {}, " ")))
    end
    if options.registry and #exported > 0 then
        os.exit(1)
    end
end
