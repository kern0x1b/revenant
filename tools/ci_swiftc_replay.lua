local workspace = import("@addon.revenant.workspace", {anonymous = true})
local log = import("ci.log", {rootdir = os.scriptdir()})

local RUNNER = "/Users/runner/work/revenant/revenant"

local function replace_all(text, from, to)
    local out, at = {}, 1
    while true do
        local first, last = text:find(from, at, true)
        if not first then
            break
        end
        table.insert(out, text:sub(at, first - 1))
        table.insert(out, to)
        at = last + 1
    end
    table.insert(out, text:sub(at))
    return table.concat(out)
end

local function relocate(text, mapping)
    return replace_all(replace_all(text, RUNNER .. "/.cache", mapping.cache), RUNNER, mapping.root)
end

local function find_argv(text, module)
    for line in text:gmatch("[^\n]+") do
        local found, argv = log.marker(log.clean(line))
        if found and (module == nil or found == module) then
            return found, argv
        end
    end
    raise("no swiftc failure%s in the log", module and (" for " .. module) or "")
end

local function rewrite(argv, mapping)
    local tokens, outputs = {}, {}
    local next_is_output = false
    for token in argv:gmatch("%S+") do
        local value = relocate(token, mapping)
        if next_is_output and not value:find("^/") then
            value = path.join(mapping.scratch, value)
            table.insert(outputs, value)
        end
        next_is_output = token == "-o" or token:find("^%-emit%-.*%-path$") ~= nil
        table.insert(tokens, value)
    end
    if not argv:find("-module-cache-path", 1, true) then
        table.insert(tokens, "-module-cache-path")
        table.insert(tokens, path.join(mapping.scratch, "modules"))
    end
    return tokens, outputs
end

local function test_suite()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local function read(name)
        return io.readfile(path.join(os.scriptdir(), "ci", "data", name))
    end

    local module, argv = find_argv(read("swift.log"), "swiftSpatial")
    check("the module of the marker is found", module, "swiftSpatial")
    check("the argv carries the module name", argv:find("-module-name Spatial", 1, true) ~= nil, true)

    local mapping = {root = "/local/checkout", cache = "/local/cache", scratch = "/local/scratch/swiftSpatial"}
    local tokens, outputs = rewrite(argv, mapping)
    check("the swiftc binary is in the local cache", tokens[1]:find("/local/cache/xmake-global/.xmake/packages/s/swift/6.4.0/", 1, true) == 1, true)
    local runner_left = false
    for _, token in ipairs(tokens) do
        runner_left = runner_left or token:find(RUNNER, 1, true) ~= nil
    end
    check("no runner path is left", runner_left, false)
    check("the prefix map names the local checkout", table.concat(tokens, " "):find("-file-prefix-map /local/checkout=/port", 1, true) ~= nil, true)
    check("the overlay is the checkout's own build file", table.concat(tokens, " "):find("-vfsoverlay /local/checkout/build/generated/backports/overlay/vfs.yaml", 1, true) ~= nil, true)
    local written = table.concat(outputs, " ")
    check("the object goes to the scratch folder", written:find("/local/scratch/swiftSpatial/build/.objs/swiftSpatial/iphoneos/armv7/release/swift/swiftSpatial.o", 1, true) ~= nil, true)
    check("the module goes to the scratch folder", written:find("/local/scratch/swiftSpatial/build/.gens/swiftSpatial/", 1, true) ~= nil, true)
    check("only the outputs move", #outputs, 2)
    check("the compiler gets a fresh module cache in the scratch folder", table.concat(tokens, " "):find("-module-cache-path /local/scratch/swiftSpatial/modules", 1, true) ~= nil, true)
    local pinned = table.concat((rewrite(argv .. " -module-cache-path /pinned", mapping)), " ")
    check("an argv that pins its module cache keeps it", pinned:find("-module-cache-path /pinned", 1, true) ~= nil and not pinned:find("/modules", 1, true), true)
    check("replace_all replaces every occurrence", replace_all("a.b.a", "a", "X"), "X.b.X")

    print("ci_swiftc_replay: %d tests passed", count)
end

function main(...)
    local args = {...}
    if args[1] == "test" and #args == 1 then
        test_suite()
        return
    end
    if #args < 1 or #args > 2 then
        raise("usage: ./xmakew l -P . tools/ci_swiftc_replay.lua <job-log> [module] | test")
    end
    local module, argv = find_argv(io.readfile(args[1]), args[2])
    local mapping = {root = os.projectdir(), cache = workspace.home(), scratch = path.join(workspace.scratch(), "swiftc-replay", module)}
    local tokens, outputs = rewrite(argv, mapping)
    if not os.isfile(tokens[1]) then
        raise("the local Swift package is missing: %s; configure the Swift component first: ./xmakew f -P . -p iphoneos -a armv7 --component=Swift -y", tokens[1])
    end
    local overlay
    for index, token in ipairs(tokens) do
        if token == "-vfsoverlay" then
            overlay = tokens[index + 1]
        end
    end
    if not overlay or not os.isfile(overlay:find("^/") and overlay or path.join(mapping.root, overlay)) then
        raise("the lowered overlay %s is missing from the checkout; configure the Swift component first", tostring(overlay))
    end
    for _, output in ipairs(outputs) do
        os.mkdir(path.directory(output))
    end
    os.tryrm(path.join(mapping.scratch, "modules"))
    os.mkdir(path.join(mapping.scratch, "modules"))
    local command = {}
    for index = 2, #tokens do
        table.insert(command, tokens[index])
    end
    local status = os.execv(tokens[1], command, {curdir = mapping.root, try = true})
    if status ~= 0 then
        raise("swiftc failed for %s with exit code %s", module, tostring(status))
    end
    print("swiftc succeeded for %s; outputs in %s", module, mapping.scratch)
end
