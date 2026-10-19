local host = import("host", {anonymous = true})
local strings = import("strings", {anonymous = true})
local layout = import("layout", {anonymous = true})
local tsv = import("tsv", {anonymous = true})

local injected = nil

function use(source)
    injected = source
end

local function parse(out, into)
    for _, line in ipairs(strings.lines(out)) do
        if line ~= "" then
            local fields = tsv.fields(line)
            assert(#fields == 4, "oracle line with " .. #fields .. " fields: " .. line)
            into[fields[1]] = {fields[2], fields[4]}
        end
    end
end

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

function probe(tree, fw, names)
    if injected then
        return injected(fw, names)
    end
    host.configure(fw, layout.gen_dir(path.absolute(tree), fw))
    local library = host.framework_binary(fw)
    return values(library, names)
end
