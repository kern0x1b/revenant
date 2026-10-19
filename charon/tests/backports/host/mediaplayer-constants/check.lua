import("core.base.json")

local DEFINE = "^NSString%s*%*%s*const%s+([%w_%.]+)%s*="
local DECLARE = "^extern%s+NSString%s*%*%s*const%s+([%w_%.]+)%s*;"

local function sorted_keys(set)
    local keys = {}
    for key in pairs(set) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local function rows_of(registry_dir)
    local found = {}
    local files = os.files(path.join(registry_dir, "*.json"))
    for _, path_ in ipairs(files) do
        local data = json.decode(io.readfile(path_))
        for _, entry in ipairs(data.entries or {}) do
            if entry.kind == "constant" and entry.status == "implemented" then
                found[entry.api] = found[entry.api] or {}
                table.insert(found[entry.api], path.filename(path_))
            end
        end
    end
    return found, #files
end

local function definitions(objects_dir)
    local defined, declared, objects = {}, {}, 0
    for _, path_ in ipairs(os.files(path.join(objects_dir, "*.m"))) do
        objects = objects + 1
        for line in io.lines(path_) do
            local define = string.match(line, DEFINE)
            if define then
                defined[define] = defined[define] or path.filename(path_)
            end
            local declare = string.match(line, DECLARE)
            if declare then
                declared[declare] = true
            end
        end
    end
    local count = 0
    for _ in pairs(defined) do
        count = count + 1
    end
    return defined, declared, objects, count
end

local function rows_vs_objects(registry_dir, objects_dir)
    local rows, files = rows_of(registry_dir)
    local defined, declared, objects, definitions_count = definitions(objects_dir)
    local row_count = 0
    for _ in pairs(rows) do
        row_count = row_count + 1
    end
    if row_count == 0 then
        print("rows-vs-objects: NO implemented constant row was examined, so nothing was proved")
        return 2
    end
    print(string.format("  rows-vs-objects: %d implemented constant rows over %d registry files, %d objects, %d definitions",
        row_count, files, objects, definitions_count))
    local bad = false
    for _, name in ipairs(sorted_keys(rows)) do
        if defined[name] == nil then
            print(string.format("  UNBACKED  %s is implemented in %s and NO object defines it", name, table.concat(rows[name], ", ")))
            bad = true
        end
    end
    for _, name in ipairs(sorted_keys(defined)) do
        if rows[name] == nil then
            print(string.format("  UNROWED   %s is defined by %s and has no implemented constant row", name, defined[name]))
            bad = true
        end
    end
    for _, name in ipairs(sorted_keys(defined)) do
        if not declared[name] then
            print(string.format("  UNDECLARED %s is defined by %s but no file declares it extern", name, defined[name]))
            bad = true
        end
    end
    if bad then
        return 1
    end
    print("  rows-vs-objects: every implemented constant row has an object, and every object has a row")
    return 0
end

local function probe(names_file, out_file)
    local names = {}
    for line in io.lines(names_file) do
        local name = string.match(line, "^%s*(.-)%s*$")
        if name ~= "" then
            table.insert(names, name)
        end
    end
    local src = {
        "#import <Foundation/Foundation.h>",
        "#import <dlfcn.h>",
        "#include <stdio.h>",
        "int main(void){@autoreleasepool{",
        'void *h=dlopen("/System/Library/Frameworks/MediaPlayer.framework/MediaPlayer",RTLD_LAZY);',
        'if(!h){fprintf(stderr,"no framework\\n");return 2;}',
        "const char *n[]={",
    }
    for _, name in ipairs(names) do
        table.insert(src, '  "' .. name .. '",')
    end
    table.insert(src, "  0};")
    table.insert(src, 'for(int k=0;n[k];k++){ if(dlsym(h,n[k])) printf("H %s\\n", n[k]); }')
    table.insert(src, "return 0;}}")
    io.writefile(out_file, table.concat(src, "\n") .. "\n")
    return 0
end

function main(command, a, b)
    local status = 2
    if command == "probe" then
        assert(a and b, "usage: check.lua probe <names file> <probe.m>")
        status = probe(a, b)
    elseif command == "rows-vs-objects" then
        assert(a and b, "usage: check.lua rows-vs-objects <registry dir> <objects dir>")
        status = rows_vs_objects(a, b)
    else
        print("usage: check.lua probe <names file> <probe.m> | check.lua rows-vs-objects <registry dir> <objects dir>")
    end
    os.exit(status)
end
