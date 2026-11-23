import("core.base.json")

local TOOLS = os.scriptdir()
local STUB_PATTERN = '{"([^"]*)", "([^"]*)", ([01]), %(IMP%)revenant_stub_%d+}'
local CLUSTER_DEPTH = 6
local DEFAULT_INVENTORY = path.join(TOOLS, "..", "..", "..", ".cache", "dyld", "6.1.3", "classes_armv7.json")
local SNAPSHOT_FOLDER = path.join(TOOLS, "app-stubs")
local REASONS = {backlog = true, device = true}

local function lines_of(text)
    local out = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(out, line)
    end
    return out
end

function bytes_less(a, b)
    local length = math.min(#a, #b)
    for index = 1, length do
        local left, right = a:byte(index), b:byte(index)
        if left ~= right then
            return left < right
        end
    end
    return #a < #b
end

local function member_key(class_method, cls, selector)
    return (class_method and "+" or "-") .. cls .. " " .. selector
end

local function setter_of(selector)
    local base = selector:match("^is(%u.*)$") or selector
    return "set" .. base:sub(1, 1):upper() .. base:sub(2) .. ":"
end

function stubs_of(folder)
    local stubs = {}
    local files = os.files(path.join(folder, "*.m"))
    table.sort(files, bytes_less)
    for _, file in ipairs(files) do
        for cls, selector, class_method in io.readfile(file):gmatch(STUB_PATTERN) do
            table.insert(stubs, {cls = cls, selector = selector, class_method = class_method == "1"})
        end
    end
    return stubs
end

function lowered_of(file)
    local lowered = {}
    for _, line in ipairs(lines_of(io.readfile(file))) do
        local cls, sign, selector = line:match("^member (%S+) ([+-])(.+)$")
        if cls then
            lowered[sign .. cls .. " " .. selector] = true
            if not selector:find(":", 1, true) then
                lowered[sign .. cls .. " " .. setter_of(selector)] = true
            end
        end
    end
    return lowered
end

function inventory_of(file)
    local classes = json.decode(io.readfile(file)).classes
    local sets, children = {}, {}
    for cls, info in pairs(classes) do
        if info.superclass then
            children[info.superclass] = children[info.superclass] or {}
            table.insert(children[info.superclass], cls)
        end
    end
    local function set_of(cls, class_method)
        local key = cls .. (class_method and "+" or "-")
        local set = sets[key]
        if set == nil then
            set = {}
            for _, name in ipairs((class_method and classes[cls].class or classes[cls].instance) or {}) do
                set[name] = true
            end
            sets[key] = set
        end
        return set
    end
    local function chain_has(cls, selector, class_method)
        local depth = 0
        while cls and classes[cls] and depth < 64 do
            if set_of(cls, class_method)[selector] then
                return true
            end
            cls = classes[cls].superclass
            depth = depth + 1
        end
        return false
    end
    local function descendant_has(cls, selector, class_method, depth)
        for _, child in ipairs(children[cls] or {}) do
            if set_of(child, class_method)[selector] or (depth < CLUSTER_DEPTH and descendant_has(child, selector, class_method, depth + 1)) then
                return true
            end
        end
        return false
    end
    local self = {}
    function self.responds(cls, selector, class_method)
        if not classes[cls] then
            return chain_has("NSObject", selector, class_method)
        end
        if chain_has(cls, selector, class_method) then
            return true
        end
        local own = set_of(cls, true)
        if own["alloc"] or own["allocWithZone:"] then
            return descendant_has(cls, selector, class_method, 0)
        end
        return false
    end
    return self
end

function intros_of(facts)
    local intros = {}
    local function put(key, value)
        local known = intros[key]
        if value and (known == nil or value < known) then
            intros[key] = value
        end
    end
    local files = os.files(path.join(facts, "*.tsv"))
    table.sort(files, bytes_less)
    for _, file in ipairs(files) do
        if path.filename(file) ~= "constant_intros.tsv" then
            for line in io.lines(file) do
                local kind, container, name, version = line:match("^[^\t]*\t([^\t]*)\t([^\t]*)\t([^\t]*)\t[^\t]*\t[^\t]*\t([^\t]*)\t")
                if kind then
                    local value = tonumber(version)
                    if kind == "instance method" then
                        put("-" .. container .. " " .. name, value)
                    elseif kind == "class method" then
                        put("+" .. container .. " " .. name, value)
                    elseif kind == "property" then
                        put("-" .. container .. " " .. name, value)
                        put("-" .. container .. " is" .. name:sub(1, 1):upper() .. name:sub(2), value)
                        put("-" .. container .. " " .. setter_of(name), value)
                    end
                end
            end
        end
    end
    return intros
end

function references_of(binary)
    local objc = import("@addon.revenant.apple.objc", {anonymous = true})
    local found = objc.binary_selectors(binary, "armv7")
    assert(found, "not an armv7 Mach-O image: " .. binary)
    local selectors, classes = {}, {}
    for key in pairs(found.used) do
        selectors[key:sub(2)] = true
    end
    local symbols = os.iorunv("grep", {"-a", "-o", "_OBJC_CLASS_[$]_[A-Za-z0-9_]*", binary})
    for name in symbols:gmatch("_OBJC_CLASS_%$_([%w_]+)") do
        classes[name] = true
    end
    return {selectors = selectors, classes = classes}
end

function snapshot_entries(stubs, inventory, references, intros)
    local seen, entries = {}, {}
    for _, stub in ipairs(stubs) do
        local key = member_key(stub.class_method, stub.cls, stub.selector)
        if not seen[key] and not inventory.responds(stub.cls, stub.selector, stub.class_method) then
            for _, reference in ipairs(references) do
                if reference.classes[stub.cls] and reference.selectors[stub.selector] then
                    seen[key] = true
                    table.insert(entries, {key = key, intro = intros[key]})
                    break
                end
            end
        end
    end
    table.sort(entries, function (a, b)
        return bytes_less(a.key, b.key)
    end)
    return entries
end

function snapshot_text(app, minimum, entries)
    local out = {"app\t" .. app, "minimum\t" .. minimum}
    for _, entry in ipairs(entries) do
        local sign, cls, selector = entry.key:match("^([+-])(%S+) (.+)$")
        table.insert(out, table.concat({entry.intro and tostring(entry.intro) or "", sign .. cls, selector}, "\t"))
    end
    return table.concat(out, "\n") .. "\n"
end

function snapshot_read(file)
    local snapshot = {entries = {}}
    for _, line in ipairs(lines_of(io.readfile(file))) do
        local name, value = line:match("^(%a+)\t(.*)$")
        if name == "app" then
            snapshot.app = value
        elseif name == "minimum" then
            snapshot.minimum = tonumber(value)
        else
            local intro, owner, selector = line:match("^([^\t]*)\t([^\t]+)\t([^\t]+)$")
            assert(owner, "a malformed row in " .. file .. ": " .. line)
            table.insert(snapshot.entries, {key = owner .. " " .. selector, intro = tonumber(intro)})
        end
    end
    assert(snapshot.app and snapshot.minimum, "no app or minimum in " .. file)
    return snapshot
end

function allowed_read(file)
    local allowed = {}
    if not os.isfile(file) then
        return allowed
    end
    for _, line in ipairs(lines_of(io.readfile(file))) do
        local owner, selector, reason = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)$")
        assert(owner, "a malformed row in " .. file .. ": " .. line)
        assert(REASONS[reason], "an unknown reason in " .. file .. ": " .. line)
        allowed[owner .. " " .. selector] = reason
    end
    return allowed
end

local function version_text(intro)
    if intro == nil then
        return "unknown"
    end
    return string.format("%d.%d", intro // 1000, intro % 1000)
end

function judge(snapshots, lowered, allowed)
    local violations, named = {}, {}
    for _, snapshot in ipairs(snapshots) do
        local limit = (snapshot.minimum + 1) * 1000
        for _, entry in ipairs(snapshot.entries) do
            if not lowered[entry.key] and (entry.intro == nil or entry.intro < limit) then
                named[entry.key] = true
                if not allowed[entry.key] then
                    table.insert(violations, string.format("%s (SDK iOS %s) is named by %s, absent from iOS 6.1.3 and implemented by no Backports source",
                        entry.key, version_text(entry.intro), snapshot.app))
                end
            end
        end
    end
    local stale = {}
    for key, reason in pairs(allowed) do
        if not named[key] then
            table.insert(stale, string.format("%s is listed as %s, but no snapshot names it as a stub any more", key, reason))
        end
    end
    table.sort(violations, bytes_less)
    table.sort(stale, bytes_less)
    return violations, stale
end

local function read_snapshots(files)
    local snapshots = {}
    for _, file in ipairs(files) do
        table.insert(snapshots, snapshot_read(file))
    end
    return snapshots
end

local function option_values(args, name)
    local values = {}
    local index = 1
    while index <= #args do
        if args[index] == name then
            table.insert(values, args[index + 1])
            index = index + 2
        else
            index = index + 1
        end
    end
    return values
end

local function option(args, name, default)
    local values = option_values(args, name)
    return values[#values] or default
end

local function command_check(args)
    local files = option_values(args, "--snapshot")
    if #files == 0 then
        files = os.files(path.join(SNAPSHOT_FOLDER, "*.snapshot"))
        table.sort(files, bytes_less)
    end
    local lowered = lowered_of(option(args, "--lowered", path.join(TOOLS, "lowered-members.txt")))
    local allowed = allowed_read(option(args, "--allowed", path.join(SNAPSHOT_FOLDER, "allowed.txt")))
    local snapshots = read_snapshots(files)
    local violations, stale = judge(snapshots, lowered, allowed)
    for _, line in ipairs(violations) do
        print("dangerous stub: " .. line)
    end
    for _, line in ipairs(stale) do
        print("stale entry: " .. line)
    end
    if #violations > 0 or #stale > 0 then
        raise(string.format("%d dangerous stubs and %d stale entries; implement each dangerous stub, or list it in %s with the reason backlog or device, and delete each stale entry",
            #violations, #stale, path.join("frameworks", "Backports", "tools", "app-stubs", "allowed.txt")))
    end
    local count, listed = 0, 0
    for _, snapshot in ipairs(snapshots) do
        count = count + #snapshot.entries
    end
    for _ in pairs(allowed) do
        listed = listed + 1
    end
    print("stubs: %d snapshots name %d stubs that iOS 6.1.3 lacks; none is dangerous beyond the %d allowed ones", #snapshots, count, listed)
end

local function command_snapshot(args)
    local app = option(args, "--app")
    local out = option(args, "--out")
    local binaries = option_values(args, "--binary")
    assert(app and out and #binaries > 0, "usage: stubs.lua snapshot --app NAME --out FILE --binary IMAGE [--binary IMAGE...] [--skeleton DIR] [--inventory FILE] [--facts DIR] [--minimum MAJOR]")
    local sdkfiles = import("sdk", {rootdir = TOOLS, anonymous = true})
    local skeleton = option(args, "--skeleton", path.join(sdkfiles.build_root(), "skeleton"))
    local inventory = inventory_of(option(args, "--inventory", DEFAULT_INVENTORY))
    local facts = option(args, "--facts", sdkfiles.cache_folder(sdkfiles.sdk_folder()))
    local minimum = tonumber(option(args, "--minimum", "15"))
    local references = {}
    for _, binary in ipairs(binaries) do
        table.insert(references, references_of(binary))
    end
    local entries = snapshot_entries(stubs_of(skeleton), inventory, references, intros_of(facts))
    io.writefile(out, snapshot_text(app, minimum, entries))
    print("stubs: %d stubs named by %s are absent from iOS 6.1.3, written to %s", #entries, app, out)
end

function main(command, ...)
    local args = {...}
    if command == "check" then
        command_check(args)
    elseif command == "snapshot" then
        command_snapshot(args)
    else
        raise("usage: stubs.lua check | snapshot")
    end
end
