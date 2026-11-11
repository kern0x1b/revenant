local TOOLS = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local SRC = path.absolute(path.join(os.scriptdir(), "..", "src"))
local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local LIBRARIES = os.getenv("REVENANT_BACKPORT_LIBRARIES") or path.join(ROOT, "build", "iphoneos", "armv7", "release")

local NAMES = {
    "AVVideoColorPrimariesKey",
    "AVVideoColorPrimaries_ITU_R_709_2",
    "AVVideoColorPrimaries_SMPTE_C",
    "AVVideoColorPropertiesKey",
    "AVVideoTransferFunctionKey",
    "AVVideoTransferFunction_ITU_R_709_2",
    "AVVideoYCbCrMatrixKey",
    "AVVideoYCbCrMatrix_ITU_R_601_4",
    "AVVideoYCbCrMatrix_ITU_R_709_2",
    "CTRadioAccessTechnologyCDMA1x",
    "CTRadioAccessTechnologyCDMAEVDORev0",
    "CTRadioAccessTechnologyCDMAEVDORevA",
    "CTRadioAccessTechnologyCDMAEVDORevB",
    "CTRadioAccessTechnologyDidChangeNotification",
    "CTRadioAccessTechnologyEdge",
    "CTRadioAccessTechnologyGPRS",
    "CTRadioAccessTechnologyHSDPA",
    "CTRadioAccessTechnologyHSUPA",
    "CTRadioAccessTechnologyLTE",
    "CTRadioAccessTechnologyeHRPD",
    "MPMediaPlaylistPropertySeedItems",
    "NSProgressFileCompletedCountKey",
    "NSProgressFileOperationKindCopying",
    "NSProgressFileOperationKindDecompressingAfterDownloading",
    "NSProgressFileOperationKindDownloading",
    "NSProgressFileOperationKindKey",
    "NSProgressFileTotalCountKey",
    "NSProgressFileURLKey",
    "NSProgressKindFile",
    "NSProgressThroughputKey",
    "UITableViewAutomaticDimension",
    "kSecAttrSynchronizable",
}

local function device_table()
    local set = {}
    for line in io.lines(path.join(TOOLS, "device-globals.txt")) do
        if string.sub(line, 1, 1) ~= "#" and line ~= "" then
            local name, install = string.match(line, "^([^\t]+)\t([^\t]+)$")
            assert(name, "a malformed row in tools/device-globals.txt: " .. line)
            set[name] = install
        end
    end
    return set
end

local function framework_of(install)
    return string.match(install, "/([^/]+)%.framework/")
end

local function source_files()
    local files = {}
    for _, pattern in ipairs({"**.m", "**.mm", "**.c", "**.h"}) do
        for _, file in ipairs(os.files(path.join(SRC, pattern))) do
            table.insert(files, file)
        end
    end
    table.sort(files)
    return files
end

local function without_macro(line, name)
    local code = string.gsub(line, "BACKPORT_IMPL%(" .. name .. "%)", "")
    return (string.gsub(code, '"[^"]*"', '""'))
end

local function scan()
    local macro_count, definitions, illegal, reads = {}, {}, {}, {}
    for _, name in ipairs(NAMES) do
        macro_count[name], definitions[name], reads[name] = 0, 0, {}
    end
    for _, file in ipairs(source_files()) do
        local folder = string.match(file, "/src/([^/]+)/")
        local text = io.readfile(file)
        for _, name in ipairs(NAMES) do
            if string.find(text, name, 1, true) then
                local number = 0
                for line in (text .. "\n"):gmatch("(.-)\n") do
                    number = number + 1
                    if string.find(line, name, 1, true) then
                        local macro = string.find(line, "BACKPORT_IMPL(" .. name .. ")", 1, true) ~= nil
                        if macro then
                            macro_count[name] = macro_count[name] + 1
                            if string.match(line, "^%S.-BACKPORT_IMPL%(" .. name .. "%)%s*=") then
                                definitions[name] = definitions[name] + 1
                            else
                                table.insert(illegal, string.format("%s:%d %s", file, number, string.sub(line, 1, 120)))
                            end
                        end
                        if string.find(without_macro(line, name), "%f[%w_]" .. name .. "%f[^%w_]") then
                            reads[name][folder] = true
                        end
                    end
                end
            end
        end
    end
    return macro_count, definitions, illegal, reads
end

local function symbol_lines(output, name)
    local found = {}
    for line in (output .. "\n"):gmatch("(.-)\n") do
        if string.find(line, " _" .. name .. " ", 1, true) or string.find(line, " _" .. name .. "$") then
            table.insert(found, line)
        end
    end
    return found
end

local function nm_of(file)
    return os.iorunv("nm", {"-m", file})
end

local device = device_table()
local macro_count, definitions, illegal, reads = scan()

local referenced = {}
for _, name in ipairs(NAMES) do
    assert(device[name] ~= nil, name .. " is in the test's list but not in tools/device-globals.txt")
end
for name, count in pairs(macro_count) do
    if count > 0 and device[name] then
        referenced[name] = count
    end
end
local missing, extra = {}, {}
for name in pairs(referenced) do
    local listed = false
    for _, listed_name in ipairs(NAMES) do
        if listed_name == name then
            listed = true
        end
    end
    if not listed then
        table.insert(extra, name)
    end
end
for _, name in ipairs(NAMES) do
    if referenced[name] == nil then
        table.insert(missing, name)
    end
end
table.sort(missing)
table.sort(extra)
assert(#missing == 0, "these device globals are no longer referenced through BACKPORT_IMPL, so the list is stale: " .. table.concat(missing, " "))
assert(#extra == 0, "these device globals are referenced through BACKPORT_IMPL but missing from the test's list: " .. table.concat(extra, " "))

table.sort(illegal)
assert(#illegal == 0, "a BACKPORT_IMPL use of a device global is not its file-scope fallback definition, so it reads the library's own fallback and not the OS constant: " .. table.concat(illegal, "; "))

for _, name in ipairs(NAMES) do
    assert(definitions[name] == macro_count[name], name .. " has a BACKPORT_IMPL use that is not a definition")
end

local libraries = os.files(path.join(LIBRARIES, "lib*Backports.dylib"))
assert(#libraries > 0, "no built Backports libraries under " .. LIBRARIES .. ": build the Backports before this test")
table.sort(libraries)
local outputs = {}
for _, library in ipairs(libraries) do
    outputs[library] = nm_of(library)
end

local defined = {}
for _, library in ipairs(libraries) do
    for _, name in ipairs(NAMES) do
        for _, line in ipairs(symbol_lines(outputs[library], name)) do
            if not string.find(line, "(undefined)", 1, true) then
                table.insert(defined, path.filename(library) .. ": " .. name .. " is defined locally: " .. line)
            end
        end
    end
end
table.sort(defined)
assert(#defined == 0, "a built library defines an OS constant itself, so in-library reads go to that copy and not the OS image: " .. table.concat(defined, "; "))

local bound, unbound = 0, {}
for _, name in ipairs(NAMES) do
    for folder in pairs(reads[name]) do
        local library = "lib" .. folder .. "Backports.dylib"
        local output = outputs[path.join(LIBRARIES, library)]
        local expected = "(undefined) weak external _" .. name .. " (from " .. framework_of(device[name]) .. ")"
        local ok = false
        if output ~= nil then
            for _, line in ipairs(symbol_lines(output, name)) do
                if string.find(line, expected, 1, true) then
                    ok = true
                end
            end
        end
        if ok then
            bound = bound + 1
        else
            table.insert(unbound, library .. " does not import " .. expected)
        end
    end
end
table.sort(unbound)
assert(#unbound == 0, "an in-library read of a device global is not bound to the OS image: " .. table.concat(unbound, "; "))

local read_names = 0
for _, name in ipairs(NAMES) do
    local any = false
    for _ in pairs(reads[name]) do
        any = true
    end
    if any then
        read_names = read_names + 1
    end
end
print(string.format("device_reads: %d device globals are referenced through BACKPORT_IMPL only as their file-scope fallback definition; %d of them are also read in src by their plain name, and each of those reads is imported weakly from the device image (%d imports); no built library defines any of them (%d libraries)",
    #NAMES, read_names, bound, #libraries))
