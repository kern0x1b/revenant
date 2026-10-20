local function long_bracket(source, at)
    return source:match("^%[(=*)%[", at)
end

function stripped(source)
    local out, line = {}, {}
    local at, size = 1, #source
    local function flush()
        local text = table.concat(line):gsub("^%s+", ""):gsub("%s+$", "")
        if text ~= "" then
            table.insert(out, text)
        end
        line = {}
    end
    while at <= size do
        local char = source:sub(at, at)
        if source:sub(at, at + 1) == "--" then
            local level = source:match("^%-%-%[(=*)%[", at)
            if level then
                local close = "]" .. level .. "]"
                local found = source:find(close, at, true)
                at = found and found + #close or size + 1
            else
                at = source:find("\n", at, true) or size + 1
            end
        elseif char == '"' or char == "'" then
            local cursor = at + 1
            while cursor <= size do
                local next = source:sub(cursor, cursor)
                if next == "\\" then
                    cursor = cursor + 2
                elseif next == char then
                    break
                else
                    cursor = cursor + 1
                end
            end
            table.insert(line, source:sub(at, cursor))
            at = cursor + 1
        elseif char == "[" and long_bracket(source, at) then
            local close = "]" .. long_bracket(source, at) .. "]"
            local found = source:find(close, at, true)
            local last = found and found + #close - 1 or size
            table.insert(line, source:sub(at, last))
            at = last + 1
        elseif char == "\n" then
            flush()
            at = at + 1
        else
            table.insert(line, char)
            at = at + 1
        end
    end
    flush()
    return table.concat(out, "\n")
end

local RECIPES = {
    {folder = "packages/runtimes/swift-runtime", variable = "swift_runtime_sources_digest",
     inputs = {"packages/runtimes/swift-runtime/xmake.lua", "toolchain/modules/apple/shared_runtime.lua",
               "toolchain/modules/apple/backports.lua", "toolchain/modules/apple/compat.lua", "toolchain/modules/apple/dyld.lua",
               "toolchain/modules/gyb/bigint.lua", "toolchain/modules/gyb/compiler.lua", "toolchain/modules/gyb/lexer.lua", "toolchain/modules/gyb/main.lua",
               "toolchain/modules/gyb/parser.lua", "toolchain/modules/gyb/random.lua", "toolchain/modules/gyb/runtime.lua", "toolchain/modules/gyb/template.lua"}},
    {folder = "packages/runtimes/libcxx", variable = "libcxx_sources_digest",
     inputs = {"packages/runtimes/libcxx/xmake.lua", "toolchain/modules/apple/shared_runtime.lua"}}
}

function recipes()
    return RECIPES
end

function sources(root, inputs)
    local digests = {}
    for _, input in ipairs(inputs) do
        table.insert(digests, input .. "=" .. hash.strhash128(stripped(io.readfile(path.join(root, input)))))
    end
    return hash.strhash128(table.concat(digests, ";"))
end

function digest_file(recipe, value)
    return string.format("%s = \"%s\"\n", recipe.variable, value)
end
