-- `diff`: the host differential of the constants (tools/gen.py@52253c0650 cmd_diff). For each constant the spec holds as found, owned by
-- nobody and exported on iOS, the value macOS holds is read by a reference program built against the host framework, and the
-- value the generated constants objects hold is read by the oracle from the constants dylib and compared with it. Where macOS
-- differs from the iOS 26.2 cache, the cache's value is the expectation (iOS wins). Prints one line per difference and a summary;
-- returns the exit status: 1 when a name differs, a host program does not build or the reference program fails, 0 otherwise.

local layout = import("layout", {anonymous = true})
local snapshot = import("spec", {anonymous = true})
local host = import("host", {anonymous = true})
local strings = import("strings", {anonymous = true})
local probes = import("probe", {anonymous = true})
local files = import("files", {anonymous = true})
local render = import("render", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local sdk_imports = import("sdk_imports", {anonymous = true})

-- Python's repr of a text of ASCII and UTF-8 bytes: quoted with ' unless it holds ' and no ", the backslash and the quote escaped,
-- tab, newline and carriage return as escapes, other control characters as \xNN.
function repr(text)
    local quote = "'"
    if string.find(text, "'", 1, true) and not string.find(text, '"', 1, true) then
        quote = '"'
    end
    local out = {quote}
    for i = 1, #text do
        local ch = string.sub(text, i, i)
        local byte = string.byte(ch)
        if ch == "\\" then
            table.insert(out, "\\\\")
        elseif ch == quote then
            table.insert(out, "\\" .. ch)
        elseif byte == 9 then
            table.insert(out, "\\t")
        elseif byte == 10 then
            table.insert(out, "\\n")
        elseif byte == 13 then
            table.insert(out, "\\r")
        elseif byte < 32 or byte == 127 then
            table.insert(out, string.format("\\x%02x", byte))
        else
            table.insert(out, ch)
        end
    end
    table.insert(out, quote)
    return table.concat(out)
end

-- The reference program for the names: each declared with the type the spec declares it with (CFStringRef or NSString, the qualifiers
-- where the declaration has them), and printed as name, a tab, and the UTF-8 text of its value, one line per name.
local function reference_source(names, shape, types, imports)
    local body = {}
    for _, line in ipairs(imports) do
        table.insert(body, line)
    end
    table.insert(body, "#import <stdio.h>")
    for _, name in ipairs(names) do
        if shape[name] == "cf" then
            table.insert(body, "extern const CFStringRef " .. name .. ";")
        else
            table.insert(body, "extern " .. render.ns_type(types[name] or "-") .. " " .. name .. ";")
        end
    end
    table.insert(body, "int main(void) {")
    table.insert(body, "@autoreleasepool {")
    for _, name in ipairs(names) do
        local cast = shape[name] == "cf" and "(__bridge NSString *)" or ""
        table.insert(body, 'printf("' .. name .. '\\t%s\\n", [' .. cast .. name .. ' UTF8String]);')
    end
    table.insert(body, "}")
    table.insert(body, "return 0;")
    table.insert(body, "}")
    return table.concat(body, "\n") .. "\n"
end

-- The number of keys of a table.
local function count_of(map)
    local n = 0
    for _ in pairs(map) do
        n = n + 1
    end
    return n
end

-- Returns the exit status.
function run(args)
    assert(args.sdk, "diff needs --sdk: the iPhoneOS SDK whose release names the iOS cache value source")
    local fw = args.framework
    local tree = path.absolute(args.tree)
    local release = sdk_info.discover(args.sdk).version
    local ios_source = sdk_info.names(release).ios_value
    local _, carried = host.framework_binary(fw)
    if not carried then
        print("differential " .. fw .. ": not on macOS, so no host differential; the iOS " .. release .. " cache is the only expectation")
        return 0
    end
    local spec = snapshot.load(tree, fw)
    local shape, types, ios_value = {}, {}, {}
    for _, r in ipairs(spec) do
        shape[r.api] = r.shape
        types[r.api] = r.type
        if r.value_source == ios_source then
            ios_value[r.api] = r.value
        end
    end
    local names = {}
    for _, r in ipairs(spec) do
        if r.kind == "constant" and r.value_status == "found" and r.owned == "-" and r.tbd == "exported" then
            table.insert(names, r.api)
        end
    end

    local gen = layout.gen_dir(tree, fw)
    host.configure(fw, gen)

    -- A name macOS does not export cannot be read on the host: it is named, not compared, and the link is retried without it.
    local absent = {}
    local imports = sdk_imports.umbrella_imports(args.sdk, fw, true)
    while true do
        local _, changed = host.write_generated("reference.m", reference_source(names, shape, types, imports))
        local built, err = host.build("reference", changed)
        if built then
            break
        end
        local missing = {}
        for name in string.gmatch(err, '"_([%w_]+)", referenced from') do
            missing[name] = true
        end
        local hits = {}
        for _, name in ipairs(names) do
            if missing[name] then
                table.insert(hits, name)
            end
        end
        if count_of(missing) == 0 or #hits == 0 then
            print("reference does not link against macOS " .. fw .. ": " .. host.tail(err, 200))
            return 1
        end
        table.sort(hits)
        for _, name in ipairs(hits) do
            table.insert(absent, name)
        end
        local kept = {}
        for _, name in ipairs(names) do
            if not missing[name] then
                table.insert(kept, name)
            end
        end
        names = kept
    end
    for _, name in ipairs(absent) do
        print("NOT ON MACOS " .. name .. ": not compared")
    end

    local ran, out, err, exit = host.run(host.product("reference"))
    if not ran then
        -- A reference that exits with an error (a crash included) has no values: the run fails, and says why.
        print("reference crashed (exit status " .. tostring(exit) .. ")" .. (err ~= "" and (": " .. host.tail(err, 300)) or ""))
        return 1
    end
    local reference = {}
    for _, line in ipairs(strings.lines(out)) do
        local tab = string.find(line, "\t", 1, true)
        if tab then
            reference[string.sub(line, 1, tab - 1)] = string.sub(line, tab + 1)
        end
    end

    local sources = files.glob(path.join(gen, fw .. "Constants*.m"))
    if #sources == 0 or #names == 0 then
        print("differential " .. fw .. ": no constant objects to compare")
        return 0
    end

    -- xmake compares whole-second mtimes: a source written in the second its dylib was built is not seen as newer. A source
    -- whose mtime is not older than the dylib's forces the rebuild (the same rule the reference uses).
    local product_path = host.product("constants")
    local force = not os.isfile(product_path)
    for _, source in ipairs(sources) do
        if not force and os.mtime(source) >= os.mtime(product_path) then
            force = true
        end
    end
    local built, err = host.build("constants", force)
    if not built then
        print("gen sources do not build as a host dylib: " .. host.tail(err, 300))
        return 1
    end
    local port = probes.values(host.product("constants"), names)

    local equal, ios_wins, differ = 0, 0, {}
    for _, name in ipairs(names) do
        local entry = port[name]
        local status, value = "missing", nil
        if entry ~= nil then
            -- probe-crashed: the oracle failed for this name, which is not the same as a name the constants do not hold
            status, value = entry[1], entry[2]
        end
        local ref = reference[name]
        if status ~= "found" or ref == nil then
            table.insert(differ, {name, "port " .. status .. ", reference " .. (ref ~= nil and "present" or "missing")})
        else
            local expected = string.gsub(ref, "\n+$", "")
            if value == expected then
                equal = equal + 1
            elseif ios_value[name] ~= nil and value == ios_value[name] then
                -- The iOS 26.2 cache is the expectation (iOS wins): a macOS value the port does not carry is expected, and listed.
                ios_wins = ios_wins + 1
            else
                table.insert(differ, {name, "port " .. repr(value) .. ", reference " .. repr(ref)})
            end
        end
    end
    for _, d in ipairs(differ) do
        print("DIFFERS " .. d[1] .. ": " .. d[2])
    end
    print(string.format("differential %s: %d names, %d equal to macOS, %d equal to the iOS " .. release .. " cache where macOS differs (iOS wins), %d differ, %d not on macOS",
        fw, #names, equal, ios_wins, #differ, #absent))
    return #differ > 0 and 1 or 0
end
