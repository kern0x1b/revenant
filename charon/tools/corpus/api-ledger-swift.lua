import("core.base.json")

local common = import("values_common", {rootdir = os.scriptdir(), anonymous = true})
local swift = import("values_swift", {rootdir = os.scriptdir(), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local OPTIONS = {
    {name = "out", required = true},
    {name = "sdk"},
    {name = "vfs", required = true},
    {name = "module-dirs", required = true},
    {name = "digester"},
    {name = "shims-modulemap"},
    {name = "cache-dir"},
    {name = "search-dirs", default = ""},
    {name = "include-dirs-for", default = ""},
    {name = "module-maps-for", default = ""},
    {name = "extra-module-maps", default = ""},
    {name = "reference-dirs", default = ""},
}

local function tool_digest()
    local text = io.readfile(path.join(os.scriptdir(), "api-ledger-swift.lua")) .. io.readfile(path.join(os.scriptdir(), "values_swift.lua"))
    return swift.string_hash(text):sub(1, 8)
end

local function real_list(text)
    local out = {}
    for _, item in ipairs(common.split(text, ",")) do
        if common.strip(item) ~= "" then
            table.insert(out, common.realpath(item))
        end
    end
    return out
end

local function owner_lists(text)
    local out = {}
    for _, pair in ipairs(common.split(text, ",")) do
        if pair:find("=", 1, true) then
            local owner, _, items = common.partition(pair, "=")
            out[owner] = swift.list(real_list(items))
        end
    end
    return out
end

local function joined(items)
    return table.concat(items or {}, " ")
end

local function source_of(binary, owner, directory, module)
    local found = swift.package_of(binary)
    local dylib = path.join(directory, "libswift" .. module .. ".dylib")
    found.owner = owner
    found.module = binary
    found.dylib = dylib
    found.dylib_there = os.exists(dylib)
    return found
end

local function interface_facts(file, targets, compilers)
    local handle = io.open(file, "r")
    if not handle then
        return
    end
    for _ = 1, 12 do
        local line = handle:read("L")
        if not line then
            break
        end
        if line:sub(1, #"// swift-module-flags:") == "// swift-module-flags:" then
            local flags = common.words(line)
            for index, flag in ipairs(flags) do
                if flag == "-target" and index + 1 <= #flags then
                    targets[flags[index + 1]] = true
                elseif flag:sub(1, 8) == "-target=" then
                    targets[flag:sub(9)] = true
                end
            end
        elseif line:sub(1, #"// swift-compiler-version:") == "// swift-compiler-version:" then
            local _, _, rest = common.partition(line, ":")
            compilers[common.strip(rest)] = true
        end
    end
    handle:close()
end

local function sorted_keys(set)
    local out = byteorder.keys(set)
    return swift.list(out)
end

local function references_of(text)
    local references = {}
    for _, pair in ipairs(common.split(text, ",")) do
        if common.strip(pair) ~= "" then
            if not pair:find("=", 1, true) then
                raise("api-ledger-swift.lua: --reference-dirs wants <name>=<dir>, got '%s'", pair)
            end
            local name, _, directory = common.partition(pair, "=")
            directory = common.realpath(directory)
            local found = {}
            if os.isdir(directory) then
                found = os.files(path.join(directory, "**.swiftinterface"))
            elseif os.isfile(directory) then
                found = {directory}
            end
            local targets, compilers = {}, {}
            for _, file in ipairs(found) do
                interface_facts(file, targets, compilers)
            end
            byteorder.sort(found)
            local target_list, compiler_list = sorted_keys(targets), sorted_keys(compilers)
            references[name] = {path = directory, files = swift.list(found), built = false, targets = target_list, compilers = compiler_list}
            common.note(string.format("  reference %s: %d text interfaces, target %s, %s -- recorded, not measured", name, #found,
                                      #target_list > 0 and table.concat(target_list, ", ") or "unknown",
                                      #compiler_list > 0 and table.concat(compiler_list, ", ") or "unknown compiler"))
        end
    end
    return references
end

function main(...)
    local args = common.parse_args("api-ledger-swift.lua", OPTIONS, {...})
    local started = os.mclock()
    local sdk = args.sdk or workspace.sdk()
    local digester = args.digester or swift.find_digester()
    os.mkdir(args.out)
    local cache_dir = args["cache-dir"] or path.join(args.out, "swift-module-cache")
    os.mkdir(cache_dir)
    local workdir = path.join(cache_dir, "digests")
    os.mkdir(workdir)
    common.note("digester: " .. digester)

    local digest = tool_digest()
    local search = real_list(args["search-dirs"])
    local extra_maps = real_list(args["extra-module-maps"])
    local owner_maps = owner_lists(args["module-maps-for"])
    local owner_includes = owner_lists(args["include-dirs-for"])
    for _, file in ipairs(extra_maps) do
        if not os.exists(file) then
            common.note(string.format("module map %s does not exist, passed on anyway so the failure is the digester's and says why", file))
        end
    end
    local modules, sources, failures, all_conformances = {}, {}, swift.list(), {}
    for _, pair in ipairs(common.split(args["module-dirs"], ",")) do
        if not pair:find("=", 1, true) then
            raise("api-ledger-swift.lua: --module-dirs wants <owner>=<dir>, got '%s'", pair)
        end
        local owner, _, directory = common.partition(pair, "=")
        directory = common.realpath(directory)
        if not os.isdir(directory) then
            common.note(string.format("%s: %s is not a directory, skipped", owner, directory))
        else
            local shims = args["shims-modulemap"] or path.join(path.directory(directory), "shims", "module.modulemap")
            if not os.exists(shims) then
                shims = nil
            end
            local entries = {}
            for _, entry in ipairs(os.filedirs(path.join(directory, "*"))) do
                table.insert(entries, path.filename(entry))
            end
            byteorder.sort(entries)
            for _, entry in ipairs(entries) do
                if entry:sub(-#".swiftmodule") == ".swiftmodule" then
                    local module = entry:sub(1, -#".swiftmodule" - 1)
                    local binary = path.join(directory, entry, "armv7-apple-ios.swiftmodule")
                    if not os.exists(binary) then
                        common.note(string.format("  %s/%s: no armv7-apple-ios.swiftmodule, not this port's target", owner, module))
                    else
                        local key = swift.string_hash(table.concat({
                            binary, tostring(os.mtime(binary)), tostring(os.filesize(binary)),
                            digester, tostring(os.mtime(digester)), shims or "", args.vfs,
                            joined(search), joined(extra_maps), joined(owner_maps[owner]),
                            joined(owner_includes[owner]), digest,
                        })):sub(1, 16)
                        local cache_file = path.join(cache_dir, string.format("%s-%s-%s.json", owner, module, key))
                        local cached
                        if os.exists(cache_file) then
                            local data = json.loadfile(cache_file)
                            cached = data ~= nil and swift.read_cache_record(data) or nil
                            if cached == nil then
                                common.note(string.format("  %s/%s: the cache entry is not a record this reader wrote, read again", owner, module))
                            end
                        end
                        if cached ~= nil then
                            modules[module] = cached.names
                            for name, listed in pairs(cached.conformances) do
                                all_conformances[name] = listed
                            end
                            sources[module] = source_of(binary, owner, directory, module)
                            common.note(string.format("  %s/%s: %d declarations (from cache)", owner, module, common.count(cached.names)))
                        else
                            local maps = table.join(extra_maps, owner_maps[owner] or {})
                            local names, conformances, failure = swift.read_module(digester, directory, module, sdk, args.vfs, shims, workdir, search,
                                                                                   maps, owner_includes[owner] or {})
                            if failure then
                                table.insert(failures, string.format("%s/%s: %s", owner, module, failure))
                                common.note(string.format("  %s/%s: %s", owner, module, failure))
                            else
                                swift.write_cache_record(cache_file, names, conformances)
                                modules[module] = names
                                for name, listed in pairs(conformances) do
                                    all_conformances[name] = listed
                                end
                                sources[module] = source_of(binary, owner, directory, module)
                                common.note(string.format("  %s/%s: %d declarations", owner, module, common.count(names)))
                            end
                        end
                    end
                end
            end
        end
    end

    local references = references_of(args["reference-dirs"])
    local index = {digester = digester, target = swift.target(), sdk = sdk, vfs = args.vfs,
                   ["search-dirs"] = swift.list(search), ["extra-module-maps"] = swift.list(extra_maps),
                   ["module-maps-for"] = owner_maps, ["include-dirs-for"] = owner_includes, modules = modules,
                   conformances = swift.sorted_conformances(all_conformances),
                   sources = sources, failures = failures, references = references}
    local file = path.join(args.out, "swift-modules.json")
    io.writefile(file, swift.encode(index, 1))
    local total = 0
    for _, names in pairs(modules) do
        total = total + common.count(names)
    end
    common.note(string.format("wrote %s: %d modules, %d distinct names, %.1f minutes", file, common.count(modules), total,
                              (os.mclock() - started) / 60000.0))
end
