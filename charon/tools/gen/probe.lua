-- The probe of tools/gen.py@52253c0650 (`probe`): the value of each named constant as a library holds it, read by the oracle through dlopen
-- and dlsym. The oracle is built from the project's fixed source (tools/gen-objc-constants-oracle.m) by xmake (host.lua), not from
-- the tree the way the oracle's probe compiles it. The names are passed on the oracle's command line and its output is read through
-- a pipe (stream.lua): no staging file is written, in the tree or in the build directory.

local host = import("host", {anonymous = true})
local strings = import("strings", {anonymous = true})
local layout = import("layout", {anonymous = true})
local tsv = import("tsv", {anonymous = true})

local injected = nil

-- Replaces the host probe by source(fw, names), for the tests of the constant records, which must not configure a host project.
function use(source)
    injected = source
end

-- Adds the oracle's lines (name, status, class, value) of a run to the table name -> {status, value}.
local function parse(out, into)
    for _, line in ipairs(strings.lines(out)) do
        if line ~= "" then
            local fields = tsv.fields(line)
            assert(#fields == 4, "oracle line with " .. #fields .. " fields: " .. line)
            into[fields[1]] = {fields[2], fields[4]}
        end
    end
end

-- The values of the names in one library: name -> {status, value}, where status is found, missing or not-object, and probe-crashed
-- when the oracle exits with an error for that name. All names run in one oracle run, as arguments after the library; when that run
-- fails, each name runs alone, so a crash is reported for the name that caused it, as the oracle's one-run-per-name rule has it.
function values(library, names)
    local built, err = host.build("oracle")
    assert(built, "the oracle does not build: " .. host.tail(err, 300))
    local binary = host.product("oracle")
    local result = {}
    local ok, out = host.run(binary, table.join({library}, names))
    if ok then
        parse(out, result)
        return result
    end
    for _, name in ipairs(names) do
        local ran, text = host.run(binary, {library, name})
        if ran then
            parse(text, result)
        else
            result[name] = {"probe-crashed", "-"}
        end
    end
    return result
end

-- The probe of tools/gen.py@52253c0650 with the same arguments: the values of the names in the framework fw of this host. The project is
-- configured for fw and the tree's constants folder of fw, as the differential does; the probe itself reads only the host framework.
-- Returns name -> {status, value}, as the oracle's probe returns name -> (status, value).
function probe(tree, fw, names)
    if injected then
        return injected(fw, names)
    end
    host.configure(fw, layout.gen_dir(path.absolute(tree), fw))
    local library = host.framework_binary(fw)
    return values(library, names)
end
