local workspace = import("@addon.revenant.workspace", {anonymous = true})
local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})

local TOOLS = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local SRC = path.absolute(path.join(os.scriptdir(), "..", "src"))
local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local SKELETON = path.join(ROOT, "build", "generated", "backports", "skeleton")
local RELEASE = "6.1.3"
local PRIVATE = "^/System/Library/PrivateFrameworks/"
local SOURCE_PATTERNS = {"**.m", "**.mm", "**.c"}
local REFERENCE_PATTERNS = {"**.m", "**.mm", "**.c", "**.h", "**.swift"}
local SHADOW_SETS = os.getenv("REVENANT_SHADOW_SETS")

local skeleton = import("skeleton", {rootdir = TOOLS, anonymous = true})

local function trim(text)
    return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

local function lines_of(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function plain_text(text)
    return (string.gsub(text, "BACKPORT_IMPL%(([%w_]+)%)", "__revenant_fb_%1"))
end

local function mentioned(text, known)
    local found = {}
    for name in string.gmatch(text, "[%a_][%w_]*") do
        if known[name] then
            found[name] = true
        end
    end
    return found
end

local function called(text, known)
    local found = {}
    for name in string.gmatch(text, "([%a_][%w_]*)%s*%(") do
        if known[name] then
            found[name] = true
        end
    end
    return found
end

local function sources_of(root, patterns)
    local files = {}
    for _, pattern in ipairs(patterns) do
        for _, file in ipairs(os.files(path.join(root, pattern))) do
            table.insert(files, file)
        end
    end
    table.sort(files)
    return files
end

local function table_of(file)
    local full = path.join(TOOLS, file)
    assert(os.isfile(full), file .. " is missing from tools: run ./xmakew l -P . frameworks/Backports/tools/generate.lua device-globals")
    local set, count = {}, 0
    for line in io.lines(full) do
        if string.sub(line, 1, 1) ~= "#" and line ~= "" then
            local name, install = string.match(line, "^([^\t]+)\t([^\t]+)$")
            assert(name, "a malformed row in tools/" .. file .. ": " .. line)
            set[name] = install
            count = count + 1
        end
    end
    return set, count
end

local function device_table()
    return table_of("device-globals.txt")
end

local function unlisted_table()
    return table_of("device-unlisted.txt")
end

local function synthetic()
    local scratch = path.join(workspace.scratch(), "device_globals_test")
    os.tryrm(scratch)
    local frameworks = {{name = "SampleKit", import = "", unavailable = {}, rows = {
        {kind = "global variable", container = "", name = "SampleKitDevice", symbol = "SampleKitDevice", signature = "NSString *const", intro = 4000, flags = ""},
        {kind = "global variable", container = "", name = "SampleKitLib", symbol = "SampleKitLib", signature = "NSString *const", intro = 4000, flags = ""},
        {kind = "global variable", container = "", name = "SampleKitLater", symbol = "SampleKitLater", signature = "NSString *const", intro = 9000, flags = ""},
        {kind = "global variable", container = "", name = "SampleKitUnlisted", symbol = "SampleKitUnlisted", signature = "NSString *const", intro = 4000, flags = ""},
    }}}
    local device = {SampleKitDevice = "/System/Library/Frameworks/SampleKit.framework/SampleKit", SampleKitLib = "/usr/lib/libSampleKit.dylib"}
    local images = {SampleKitDevice = "/System/Library/Frameworks/OtherKit.framework/OtherKit", SampleKitLib = "/usr/lib/libSampleKit.dylib"}
    local references = {SampleKit = {SampleKitDevice = true, SampleKitLib = true}}
    local totals = skeleton.write(scratch, frameworks, {}, images, {}, {}, device, references)
    assert(totals.device_bound == 2, "two globals the device exports must be bound to their image, not copied")
    local source = io.readfile(path.join(scratch, "SampleKit.m"))
    assert(not string.find(source, "revenant_global_SampleKitDevice", 1, true), "a global the device exports still has a skeleton definition, which in-library code binds to instead of the device image")
    assert(not string.find(source, "revenant_global_SampleKitLib", 1, true), "a global the device exports from a library still has a skeleton definition")
    assert(string.find(source, 'revenant_global_SampleKitLater __asm__("_SampleKitLater")', 1, true), "a global the device lacks must keep its skeleton definition")
    assert(string.find(source, 'revenant_global_SampleKitUnlisted __asm__("_SampleKitUnlisted")', 1, true), "a global the device exports from an image the SDK lists nowhere must keep its skeleton definition and export")
    local flags = io.readfile(path.join(scratch, "SampleKit.weak"))
    for _, flag in ipairs({"-Wl,-weak_framework,SampleKit", "-Wl,-weak_library,/usr/lib/libSampleKit.dylib", "-Wl,-U,_SampleKitDevice"}) do
        assert(string.find(flags, flag, 1, true), flag .. " is missing from SampleKit.weak")
    end
    assert(not string.find(flags, "-Wl,-U,_SampleKitLib", 1, true), "a name the SDK lists in the device image needs no -U")
    os.tryrm(scratch)
    print("device_globals: a device-exported global is bound, not copied, and the link names its image")
end

local function generated_storage()
    assert(os.isdir(SKELETON), "the generated skeleton is absent at " .. SKELETON .. ": build the Backports before this test")
    local stored = {}
    for _, file in ipairs(os.files(path.join(SKELETON, "*.m"))) do
        for name in string.gmatch(io.readfile(file), "revenant_global_([%w_]+) __asm__%(") do
            stored[name] = path.filename(file)
        end
    end
    return stored
end

local function device_storage(stored, device)
    local found = {}
    for name, file in pairs(stored) do
        if device[name] then
            table.insert(found, name .. " in " .. file)
        end
    end
    table.sort(found)
    assert(#found == 0, "the skeleton defines a global the device exports, so in-library references read that definition, not the image: " .. table.concat(found, "; "))
end

local function references_have_links(device)
    local problems, count = {}, 0
    for _, dir in ipairs(os.dirs(path.join(SRC, "*"))) do
        local folder = path.filename(dir)
        local links = {}
        local weak = path.join(SKELETON, folder .. ".weak")
        if os.isfile(weak) then
            for line in io.lines(weak) do
                links[line] = true
            end
        end
        local set = {}
        for _, file in ipairs(sources_of(dir, REFERENCE_PATTERNS)) do
            for name in pairs(mentioned(plain_text(io.readfile(file)), device)) do
                set[name] = true
            end
        end
        for name in pairs(set) do
            count = count + 1
            local flag = skeleton.weak_flag(device[name])
            if not links[flag] then
                table.insert(problems, folder .. " references " .. name .. " without " .. flag)
            end
        end
    end
    table.sort(problems)
    assert(#problems == 0, "a library references a device global without a link to the image that exports it: " .. table.concat(problems, "; "))
    print(string.format("device_globals: %d references from src to device globals each have a link to their image", count))
end

local function cache_file()
    return path.join(dyld.root(), RELEASE, "dyld_shared_cache_armv7")
end

local function check_exported(rows, cache, file)
    local missing, count = {}, 0
    for name, install in pairs(rows) do
        count = count + 1
        local library = cache.libraries[install]
        if library == nil or library.exports["_" .. name] == nil then
            table.insert(missing, name .. " in " .. install)
        end
    end
    table.sort(missing)
    assert(#missing == 0, "the iOS " .. RELEASE .. " cache does not export these globals at their image, so " .. file .. " is stale: " .. table.concat(missing, "; "))
    return count
end

local function exporters_of(cache, names)
    local found = {}
    for install, library in pairs(cache.libraries) do
        for symbol in pairs(library.exports) do
            local name = string.sub(symbol, 2)
            if names[name] and not found[name] then
                found[name] = install
            end
        end
    end
    return found
end

local function check_copied(stored, cache, unlisted)
    local exported = exporters_of(cache, stored)
    local private = {}
    local extra, copied_unlisted = {}, 0
    for name, install in pairs(exported) do
        if string.find(install, PRIVATE) then
            table.insert(private, name)
        elseif unlisted[name] == nil then
            table.insert(extra, name .. " from " .. install)
        else
            copied_unlisted = copied_unlisted + 1
        end
    end
    table.sort(extra)
    table.sort(private)
    assert(#extra == 0, "the skeleton copies globals an SDK framework exports and the SDK lists, so in-library references read the copy, not the image: " .. table.concat(extra, "; "))
    return exported, private, copied_unlisted
end

local function oracle(stored, device, exported, unlisted)
    if SHADOW_SETS == nil then
        print("device_globals: REVENANT_SHADOW_SETS is unset, so Telegram's shadow-set oracle is not checked")
        return
    end
    assert(os.isdir(SHADOW_SETS), "REVENANT_SHADOW_SETS is not a directory: " .. SHADOW_SETS)
    local names = {}
    for _, file in ipairs(os.files(path.join(SHADOW_SETS, "*.data.txt"))) do
        for line in io.lines(file) do
            local name = trim(line)
            if name ~= "" then
                names[(string.gsub(name, "^_", "", 1))] = true
            end
        end
    end
    local count, bound, copied, neither = 0, 0, {}, {}
    for name in pairs(names) do
        count = count + 1
        if device[name] then
            bound = bound + 1
        elseif stored[name] then
            table.insert(copied, name)
        else
            table.insert(neither, name)
        end
    end
    table.sort(copied)
    table.sort(neither)
    if exported ~= nil then
        local public = {}
        for _, name in ipairs(copied) do
            if (exported[name] == nil or not string.find(exported[name], PRIVATE)) and unlisted[name] == nil then
                table.insert(public, name)
            end
        end
        assert(#public == 0, "Telegram's oracle lists names the skeleton copies from an SDK framework, so in-library references read the copy: " .. table.concat(public, " "))
    end
    print(string.format("device_globals: Telegram's oracle lists %d names: %d bound to the device image, %d copied from a private framework, %d neither: %s",
        count, bound, #copied, #neither, #neither > 0 and table.concat(neither, " ") or "none"))
end

local function without_blocks(text)
    local out, i = {}, 1
    while i <= #text do
        local _, open = text:find("^%^%s*%b()%s*{", i)
        if not open then
            _, open = text:find("^%^%s*{", i)
        end
        if open then
            local depth, j = 0, open
            repeat
                local c = text:sub(j, j)
                if c == "{" then
                    depth = depth + 1
                elseif c == "}" then
                    depth = depth - 1
                end
                j = j + 1
            until depth == 0 or j > #text
            i = j
        else
            table.insert(out, text:sub(i, i))
            i = i + 1
        end
    end
    return table.concat(out)
end

local function code_of(text)
    local clean = plain_text(text)
    clean = string.gsub(clean, "/%*.-%*/", "")
    clean = string.gsub(clean, "//[^\n]*", "")
    clean = string.gsub(clean, '"[^"\n]*"', '""')
    return without_blocks(clean)
end

local function functions_of(lines)
    local found = {}
    local i = 1
    while i <= #lines do
        local header = lines[i]
        local open = nil
        if string.match(header, "^[%+%-%a_]") and not string.find(header, ";%s*$") and string.find(header, "%)") then
            if string.find(header, "{%s*$") then
                open = i
            elseif string.match(lines[i + 1] or "", "^{%s*$") then
                open = i + 1
            end
        end
        if open then
            local body, j = {}, open + 1
            while j <= #lines and lines[j] ~= "}" do
                table.insert(body, lines[j])
                j = j + 1
            end
            local name = string.match(header, "^[%+%-]%s*%([^)]*%)%s*([%a_][%w_]*)")
            for call in string.gmatch(header, "([%a_][%w_]*)%s*%(") do
                name = call
            end
            local prev = i > 1 and lines[i - 1] or ""
            table.insert(found, {
                header = trim(header),
                name = name,
                method = string.match(header, "^[%+%-]") ~= nil,
                early = string.find(header, "^%+ ?%(void%)load%f[^%w_]") ~= nil or string.find(prev .. " " .. header, "constructor", 1, true) ~= nil,
                body = table.concat(body, "\n"),
            })
            i = j
        end
        i = i + 1
    end
    return found
end

local function early_reads(stored)
    local problems, roots, files = {}, 0, sources_of(SRC, SOURCE_PATTERNS)
    for _, file in ipairs(files) do
        local functions = functions_of(lines_of(io.readfile(file)))
        local functions_by, methods_by = {}, {}
        for _, fn in ipairs(functions) do
            fn.code = code_of(fn.body)
            if fn.name then
                local index = fn.method and methods_by or functions_by
                index[fn.name] = index[fn.name] or {}
                table.insert(index[fn.name], fn)
            end
        end
        local queue, seen = {}, {}
        for _, fn in ipairs(functions) do
            if fn.early then
                roots = roots + 1
                seen[fn] = true
                table.insert(queue, fn)
            end
        end
        while #queue > 0 do
            local fn = table.remove(queue)
            for name in pairs(mentioned(fn.code, stored)) do
                table.insert(problems, string.format("%s: %s reads %s, which the skeleton copies in %s", path.relative(file, ROOT), fn.header, name, stored[name]))
            end
            for name in pairs(called(fn.code, functions_by)) do
                for _, callee in ipairs(functions_by[name]) do
                    if not seen[callee] then
                        seen[callee] = true
                        table.insert(queue, callee)
                    end
                end
            end
            for name in pairs(mentioned(fn.code, methods_by)) do
                for _, callee in ipairs(methods_by[name]) do
                    if not seen[callee] then
                        seen[callee] = true
                        table.insert(queue, callee)
                    end
                end
            end
        end
    end
    table.sort(problems)
    assert(#problems == 0, "a +load or constructor reads a copied global, which is zero until the library's constructor runs: " .. table.concat(problems, "; "))
    print(string.format("device_globals: %d +load and constructor bodies in %d sources read no copied global", roots, #files))
end

local function copied_references(stored)
    local per_library, total, folders = {}, 0, {}
    for _, dir in ipairs(os.dirs(path.join(SRC, "*"))) do
        local folder = path.filename(dir)
        local names = {}
        for _, file in ipairs(sources_of(dir, REFERENCE_PATTERNS)) do
            for name in pairs(mentioned(plain_text(io.readfile(file)), stored)) do
                names[name] = true
            end
        end
        local list = {}
        for name in pairs(names) do
            table.insert(list, name)
        end
        table.sort(list)
        if #list > 0 then
            per_library[folder] = list
            total = total + #list
            table.insert(folders, folder)
        end
    end
    table.sort(folders)
    for _, folder in ipairs(folders) do
        print(string.format("device_globals: %s references %d copied globals, none read in +load or a constructor: %s",
            folder, #per_library[folder], table.concat(per_library[folder], " ")))
    end
    print(string.format("device_globals: %d copied-global references across %d libraries", total, #folders))
end

synthetic()
local device, device_count = device_table()
local unlisted, unlisted_count = unlisted_table()
for name in pairs(unlisted) do
    assert(device[name] == nil, name .. " is in both device-globals.txt and device-unlisted.txt")
end
local stored = generated_storage()
device_storage(stored, device)
references_have_links(device)
local exported = nil
local cachefile = cache_file()
if os.isfile(cachefile) then
    local cache = dyld.load(cachefile)
    local listed = check_exported(device, cache, "device-globals.txt")
    local unlisted_listed = check_exported(unlisted, cache, "device-unlisted.txt")
    local private, copied_unlisted
    exported, private, copied_unlisted = check_copied(stored, cache, unlisted)
    print(string.format("device_globals: the iOS %s cache exports all %d device-globals.txt rows at their listed images and all %d device-unlisted.txt rows at theirs; %d of %d SDK-unlisted globals are copied and exported; %d copied globals are exported only by private frameworks, which the SDK has no stub for: %s",
        RELEASE, listed, unlisted_listed, copied_unlisted, unlisted_count, #private, table.concat(private, " ")))
else
    print(string.format("device_globals: no iOS %s dyld cache at %s, so the inventory and copied-global checks against it are skipped (%d rows and %d unlisted rows checked for format only)",
        RELEASE, cachefile, device_count, unlisted_count))
end
oracle(stored, device, exported, unlisted)
early_reads(stored)
copied_references(stored)
