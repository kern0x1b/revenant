import("async.runjobs")

local lexers = import("lexers", {rootdir = os.scriptdir()})

local function clang_tokens(file, lang)
    local _, out = os.iorunv("clang", {"-cc1", "-dump-raw-tokens", "-x", lang.clang, file})
    assert(#out > 0 or os.filesize(file) == 0, "clang printed no tokens for %s", file)
    local tokens = {}
    for token in out:gmatch("(.-)\tLoc=<[^>]*>\n") do
        token = token:gsub("\t[^\t]*$", "")
        local kind = token:match("^(%S+) ")
        if kind ~= "comment" and kind ~= "unknown" then
            table.insert(tokens, token)
        end
    end
    return table.concat(tokens, "\n")
end

local function swift_tree(file, name)
    local out = os.iorunv("xcrun", {"swift-frontend", "-dump-parse", file})
    assert(#out > 0, "swift-frontend printed no tree for %s", file)
    out = out:gsub("range=%[[^%]]*%]", ""):gsub("@[^%s\"]+:%d+:%d+", ""):gsub("0x%x+", ""):gsub((path.directory(file):gsub("%p", "%%%0")), name)
    return out
end

local function lua_program()
    local program = path.join(path.directory(os.programfile()), "lua")
    assert(os.isexec(program), "no Lua beside %s: run this through ./xmakew, which builds xmake's own Lua there", os.programfile())
    return program
end

local lua_compare = [[
local function canonical(s)
    local pos = 42
    local out = {s:sub(1, 41)}
    local function byte()
        local b = assert(s:byte(pos), "bytecode ends early")
        pos = pos + 1
        return b
    end
    local function varint()
        local x = 0
        repeat
            local b = byte()
            x = x * 128 + (b & 0x7f)
        until b < 128
        return x
    end
    local function align(n)
        local p = (pos - 1) % n
        if p ~= 0 then
            pos = pos + n - p
        end
    end
    local function take(n)
        local v = s:sub(pos, pos + n - 1)
        assert(#v == n, "bytecode ends early")
        pos = pos + n
        return v
    end
    local function str()
        local size = varint()
        if size == 0 then
            return "s" .. varint()
        end
        return "S" .. take(size)
    end
    local function func()
        varint()
        varint()
        table.insert(out, take(3))
        local n = varint()
        align(4)
        table.insert(out, "c" .. take(4 * n))
        n = varint()
        for _ = 1, n do
            local tt = byte()
            table.insert(out, "k" .. tt)
            if tt == 0x13 then
                table.insert(out, take(8))
            elseif tt == 0x03 then
                table.insert(out, "i" .. varint())
            elseif tt == 0x04 or tt == 0x14 then
                table.insert(out, str())
            end
        end
        n = varint()
        table.insert(out, "u" .. take(3 * n))
        n = varint()
        table.insert(out, "p" .. n)
        for _ = 1, n do
            func()
        end
        table.insert(out, str())
        for _ = 1, 4 do
            assert(varint() == 0, "debug data in a stripped dump")
        end
    end
    func()
    assert(pos == #s + 1, "bytecode has bytes past the main function")
    return table.concat(out, "\0")
end
print("compared " .. (#arg // 2))
for i = 1, #arg, 2 do
    local function dump(file)
        local f = assert(io.open(file, "rb"))
        local chunk = load(f:read("a"), "=x")
        f:close()
        return chunk and canonical(string.dump(chunk, true))
    end
    local old = dump(arg[i])
    local new = dump(arg[i + 1])
    if not old or not new or old ~= new then
        print("differ " .. arg[i + 1])
    end
end
]]

local function code(text, spans)
    local parts, pos = {}, 1
    for _, span in ipairs(spans) do
        table.insert(parts, text:sub(pos, span[1] - 1))
        pos = span[2] + 1
    end
    table.insert(parts, text:sub(pos))
    local lines = {}
    for line in (table.concat(parts) .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("%s+$", "")
        if line ~= "" then
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

function differing(files, rev)
    local scratch = path.join(import("@addon.revenant.workspace", {anonymous = true}).scratch(), "comments-verify")
    os.tryrm(scratch)
    local differ = {}
    local luapairs = {}
    runjobs("verify", function (index)
        local file = files[index]
        local lang = lexers.language(file)
        local old = path.join(scratch, "old", file)
        local new = path.join(scratch, "new", file)
        io.writefile(old, os.iorunv("git", {"show", rev .. ":" .. file}))
        os.cp(file, new)
        if lang.kind == "c" then
            if clang_tokens(old, lang) ~= clang_tokens(new, lang) then
                table.insert(differ, file)
            end
        elseif lang.kind == "swift" then
            local same = try {function ()
                return swift_tree(old, "x") == swift_tree(new, "x")
            end}
            if not same then
                table.insert(differ, file)
            end
        elseif lang.kind == "sh" or lang.kind == "yaml" then
            local before = io.readfile(old, {encoding = "binary"})
            local after = io.readfile(new, {encoding = "binary"})
            if code(before, lexers.comments(before, lang)) ~= code(after, lexers.comments(after, lang)) then
                table.insert(differ, file)
            end
        else
            table.insert(luapairs, old)
            table.insert(luapairs, new)
        end
    end, {total = #files, comax = os.cpuinfo().ncpu})
    if #luapairs > 0 then
        local program = path.join(scratch, "compare.lua")
        io.writefile(program, lua_compare)
        local out = os.iorunv(lua_program(), table.join({program}, luapairs))
        assert(out:find("compared " .. (#luapairs // 2), 1, true), "the Lua oracle did not run: %s", out)
        local prefix = path.join(scratch, "new") .. "/"
        for line in out:gmatch("[^\n]+") do
            local file = line:match("^differ (.+)$")
            if file then
                table.insert(differ, file:sub(#prefix + 1))
            end
        end
    end
    os.tryrm(scratch)
    return differ
end
