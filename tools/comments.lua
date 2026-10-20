import("async.runjobs")

local languages = {
    c = {kind = "c", clang = "c"},
    h = {kind = "c", cpp = true, clang = "objective-c++"},
    m = {kind = "c", clang = "objective-c"},
    mm = {kind = "c", cpp = true, clang = "objective-c++"},
    cc = {kind = "c", cpp = true, clang = "c++"},
    cpp = {kind = "c", cpp = true, clang = "c++"},
    cxx = {kind = "c", cpp = true, clang = "c++"},
    hpp = {kind = "c", cpp = true, clang = "c++"},
    hh = {kind = "c", cpp = true, clang = "c++"},
    inc = {kind = "c", cpp = true, clang = "c++"},
    swift = {kind = "swift"},
    lua = {kind = "lua"},
    sh = {kind = "sh"},
    yml = {kind = "yaml"},
    yaml = {kind = "yaml"}
}

local legal = {"^SPDX%-", "^[Cc]opyright", "^Licensed under the ", "^Licensed to the ", "^Permission is hereby granted,",
    "^Redistribution and use in source and binary forms", "^This program is free software",
    "^This Source Code Form is subject to the terms of the Mozilla Public", "^Use of this source code is governed by a"}

local function language(file)
    return languages[path.extension(file):sub(2):lower()]
end

local function isident(b)
    return b and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

local function c_comments(text, cpp)
    local spans = {}
    local n = #text
    local i = 1
    while i <= n do
        local b = text:byte(i)
        if b == 47 and text:byte(i + 1) == 47 then
            local j = i + 2
            while j <= n do
                local nl = text:find("\n", j, true)
                if not nl then
                    j = n + 1
                    break
                end
                local k = nl - 1
                if text:byte(k) == 13 then
                    k = k - 1
                end
                if text:byte(k) == 92 then
                    j = nl + 1
                else
                    j = nl
                    break
                end
            end
            table.insert(spans, {i, j - 1})
            i = j
        elseif b == 47 and text:byte(i + 1) == 42 then
            local e = text:find("*/", i + 2, true)
            local j = e and e + 1 or n
            table.insert(spans, {i, j})
            i = j + 1
        elseif b == 34 then
            local s = i - 1
            while isident(text:byte(s)) do
                s = s - 1
            end
            local prefix = text:sub(s + 1, i - 1)
            if cpp and (prefix == "R" or prefix == "u8R" or prefix == "uR" or prefix == "UR" or prefix == "LR") then
                local open = text:find("(", i + 1, true)
                local delim = text:sub(i + 1, open - 1)
                local close = text:find(")" .. delim .. "\"", open + 1, true)
                i = close and close + #delim + 2 or n + 1
            else
                local j = i + 1
                while j <= n do
                    local c = text:byte(j)
                    if c == 92 then
                        j = j + 2
                    elseif c == 34 or c == 10 then
                        break
                    else
                        j = j + 1
                    end
                end
                i = j + 1
            end
        elseif b == 39 then
            local s = i - 1
            while isident(text:byte(s)) or text:byte(s) == 39 or text:byte(s) == 46 do
                s = s - 1
            end
            local first = text:byte(s + 1)
            if cpp and s + 1 < i and first and first >= 48 and first <= 57 then
                i = i + 1
            else
                local j = i + 1
                while j <= n do
                    local c = text:byte(j)
                    if c == 92 then
                        j = j + 2
                    elseif c == 39 or c == 10 then
                        break
                    else
                        j = j + 1
                    end
                end
                i = j + 1
            end
        else
            i = i + 1
        end
    end
    return spans
end

local swift_code

local function swift_string(text, i, spans)
    local n = #text
    local hashes = 0
    while text:byte(i) == 35 do
        hashes = hashes + 1
        i = i + 1
    end
    local multiline = text:sub(i, i + 2) == "\"\"\""
    local j = multiline and i + 3 or i + 1
    local close = (multiline and "\"\"\"" or "\"") .. string.rep("#", hashes)
    local escape = "\\" .. string.rep("#", hashes)
    while j <= n do
        if text:sub(j, j + #close - 1) == close then
            return j + #close
        elseif text:sub(j, j + #escape - 1) == escape then
            local k = j + #escape
            if text:byte(k) == 40 then
                j = swift_code(text, k + 1, spans, true)
            else
                j = k + 1
            end
        elseif not multiline and text:byte(j) == 10 then
            return j
        else
            j = j + 1
        end
    end
    return n + 1
end

function swift_code(text, i, spans, interpolation)
    local n = #text
    local depth = 0
    while i <= n do
        local b = text:byte(i)
        if b == 47 and text:byte(i + 1) == 47 then
            local nl = text:find("\n", i + 2, true) or n + 1
            table.insert(spans, {i, nl - 1})
            i = nl
        elseif b == 47 and text:byte(i + 1) == 42 then
            local level = 1
            local j = i + 2
            while j <= n and level > 0 do
                if text:byte(j) == 47 and text:byte(j + 1) == 42 then
                    level = level + 1
                    j = j + 2
                elseif text:byte(j) == 42 and text:byte(j + 1) == 47 then
                    level = level - 1
                    j = j + 2
                else
                    j = j + 1
                end
            end
            table.insert(spans, {i, math.min(j - 1, n)})
            i = j
        elseif b == 34 then
            i = swift_string(text, i, spans)
        elseif b == 35 and text:match("^#+\"", i) then
            i = swift_string(text, i, spans)
        elseif interpolation and b == 40 then
            depth = depth + 1
            i = i + 1
        elseif interpolation and b == 41 then
            if depth == 0 then
                return i + 1
            end
            depth = depth - 1
            i = i + 1
        else
            i = i + 1
        end
    end
    return n + 1
end

local function swift_comments(text)
    local spans = {}
    swift_code(text, 1, spans, false)
    return spans
end

local function lua_long(text, i)
    local eq = text:match("^%[(=*)%[", i)
    if not eq then
        return nil
    end
    local close = text:find("]" .. eq .. "]", i + #eq + 2, true)
    return close and close + #eq + 1 or #text
end

local function lua_comments(text)
    local spans = {}
    local n = #text
    local i = 1
    if text:byte(1) == 35 then
        i = (text:find("\n", 1, true) or n) + 1
    end
    while i <= n do
        local b = text:byte(i)
        if b == 45 and text:byte(i + 1) == 45 then
            local e = lua_long(text, i + 2)
            if not e then
                e = (text:find("\n", i + 2, true) or n + 1) - 1
            end
            table.insert(spans, {i, e})
            i = e + 1
        elseif b == 34 or b == 39 then
            local j = i + 1
            while j <= n do
                local c = text:byte(j)
                if c == 92 then
                    j = j + 2
                elseif c == b or c == 10 then
                    break
                else
                    j = j + 1
                end
            end
            i = j + 1
        elseif b == 91 then
            local e = lua_long(text, i)
            i = e and e + 1 or i + 1
        else
            i = i + 1
        end
    end
    return spans
end

local sh_boundary = {[9] = true, [10] = true, [32] = true, [38] = true, [59] = true, [124] = true}

local function sh_heredocs(text, pos, pending)
    while #pending > 0 do
        local hd = table.remove(pending, 1)
        while pos <= #text do
            local nl = text:find("\n", pos, true) or #text + 1
            local line = text:sub(pos, nl - 1):gsub("\r$", "")
            pos = nl + 1
            if hd.strip then
                line = line:gsub("^\t+", "")
            end
            if line == hd.delim then
                break
            end
        end
    end
    return pos
end

local function sh_spans(text, i)
    local spans, pending = {}, {}
    local stack = {{kind = "code", depth = 0}}
    local n = #text
    local function push(kind)
        table.insert(stack, {kind = kind, depth = 0})
    end
    while i <= n do
        local top = stack[#stack]
        local kind = top.kind
        local c, nxt = text:byte(i), text:byte(i + 1)
        local step = 1
        if c == 92 then
            step = 2
        elseif c == 10 then
            i = sh_heredocs(text, i + 1, pending)
            step = 0
        elseif (c == 34 and kind == "dq") or (c == 96 and kind == "bt") or (c == 125 and kind == "param") then
            table.remove(stack)
        elseif c == 41 and nxt == 41 and kind == "arith" and top.depth == 0 then
            table.remove(stack)
            step = 2
        elseif c == 36 and nxt == 40 then
            local arith = text:byte(i + 2) == 40
            push(arith and "arith" or "sub")
            step = arith and 3 or 2
        elseif c == 36 and nxt == 123 then
            push("param")
            step = 2
        elseif c == 96 then
            push("bt")
        elseif c == 39 and kind ~= "dq" then
            local j = i + 1
            local ansi = text:byte(i - 1) == 36
            while j <= n and text:byte(j) ~= 39 do
                j = j + ((ansi and text:byte(j) == 92) and 2 or 1)
            end
            step = j + 1 - i
        elseif c == 34 then
            push("dq")
        elseif kind == "arith" then
            if c == 40 then
                top.depth = top.depth + 1
            elseif c == 41 and top.depth > 0 then
                top.depth = top.depth - 1
            end
        elseif kind == "code" or kind == "sub" or kind == "bt" then
            if c == 40 then
                if nxt == 40 then
                    push("arith")
                    step = 2
                else
                    top.depth = top.depth + 1
                end
            elseif c == 41 then
                if top.depth > 0 then
                    top.depth = top.depth - 1
                elseif kind == "sub" then
                    table.remove(stack)
                end
            elseif c == 60 and nxt == 60 and text:byte(i + 2) ~= 60 then
                local p = i + 2
                local strip = text:byte(p) == 45
                if strip then
                    p = p + 1
                end
                p = p + #(text:match("^[ \t]*", p) or "")
                local full, delim = text:match("^(\\?['\"]?([^%s;&|<>()'\"\\]+)['\"]?)", p)
                if full then
                    table.insert(pending, {delim = delim, strip = strip})
                    step = p + #full - i
                end
            elseif c == 35 and (i == 1 or sh_boundary[text:byte(i - 1)]) then
                local e = (text:find("\n", i, true) or n + 1) - 1
                if text:byte(e) == 13 then
                    e = e - 1
                end
                table.insert(spans, {i, e})
                step = e - i + 1
            end
        end
        i = i + step
    end
    return spans
end

local function sh_comments(text)
    local i = 1
    if text:sub(1, 2) == "#!" then
        i = (text:find("\n", 1, true) or #text) + 1
    end
    return sh_spans(text, i)
end

local yaml_opens = {[44] = true, [45] = true, [58] = true, [63] = true, [91] = true, [123] = true}

local function yaml_hash(text, from, to)
    local last
    local i = from
    while i <= to do
        local c = text:byte(i)
        if c == 35 and (i == from or text:byte(i - 1) == 32 or text:byte(i - 1) == 9) then
            return i
        elseif (c == 39 or c == 34) and (not last or yaml_opens[last]) then
            local j = i + 1
            while j <= to do
                local d = text:byte(j)
                if c == 39 and d == 39 and text:byte(j + 1) == 39 then
                    j = j + 2
                elseif c == 34 and d == 92 then
                    j = j + 2
                elseif d == c then
                    break
                else
                    j = j + 1
                end
            end
            i = j + 1
            last = 0
        else
            if c ~= 32 and c ~= 9 then
                last = c
            end
            i = i + 1
        end
    end
end

local function yaml_comments(text)
    local spans = {}
    local n = #text
    local pos = 1
    while pos <= n do
        local nl = text:find("\n", pos, true) or n + 1
        local hash = yaml_hash(text, pos, nl - 1)
        local code = text:sub(pos, (hash or nl) - 1)
        if hash then
            local e = nl - 1
            if text:byte(e) == 13 then
                e = e - 1
            end
            table.insert(spans, {hash, e})
        end
        pos = nl + 1
        if code:match("[:%-]%s*[|>][-+%d]*%s*$") or code:match("^%s*[|>][-+%d]*%s*$") then
            local indent = #code:match("^ *")
            local first, last = pos, pos - 1
            while pos <= n do
                local e = text:find("\n", pos, true) or n + 1
                local line = text:sub(pos, e - 1)
                if line:match("%S") and #line:match("^ *") <= indent then
                    break
                end
                last = e - 1
                pos = e + 1
            end
            if code:match("^%s*%-?%s*run%s*:") then
                for _, span in ipairs(sh_spans(text:sub(first, last), 1)) do
                    table.insert(spans, {first - 1 + span[1], first - 1 + span[2]})
                end
            end
        end
    end
    return spans
end

local function comments(text, lang)
    local spans
    if lang.kind == "c" then
        spans = c_comments(text, lang.cpp)
    elseif lang.kind == "swift" then
        spans = swift_comments(text)
    elseif lang.kind == "sh" then
        spans = sh_comments(text)
    elseif lang.kind == "yaml" then
        spans = yaml_comments(text)
    else
        spans = lua_comments(text)
    end
    local header = 0
    local last = 0
    if (lang.kind == "lua" and text:byte(1) == 35) or (lang.kind == "sh" and text:sub(1, 2) == "#!") then
        last = text:find("\n", 1, true) or 0
    end
    for index, span in ipairs(spans) do
        if text:sub(last + 1, span[1] - 1):match("^%s*$") then
            header = index
            last = span[2]
        else
            break
        end
    end
    if header > 0 then
        local block = text:sub(spans[1][1], spans[header][2])
        local islegal = false
        for line in (block .. "\n"):gmatch("(.-)\n") do
            local words = line:gsub("^[%s/*#%-!;]*", "")
            for _, pattern in ipairs(legal) do
                if words:find(pattern) then
                    islegal = true
                end
            end
        end
        if islegal then
            spans = table.slice(spans, header + 1)
        end
    end
    return spans
end

local function strip(text, spans)
    local mark = "\1"
    local parts = {}
    local pos = 1
    for _, span in ipairs(spans) do
        table.insert(parts, text:sub(pos, span[1] - 1))
        table.insert(parts, mark)
        pos = span[2] + 1
    end
    table.insert(parts, text:sub(pos))
    local marked = table.concat(parts)
    local lines = {}
    local dropped = false
    local function last()
        return lines[#lines]
    end
    for line in (marked .. "\n"):gmatch("(.-)\n") do
        if line:find(mark, 1, true) then
            local cleaned = line:gsub("([^%s\1]?)\1+([^%s\1]?)", function (a, b)
                if a ~= "" and b ~= "" then
                    return a .. " " .. b
                end
                return a .. b
            end)
            cleaned = cleaned:gsub(mark, ""):gsub("%s+$", "")
            if cleaned:match("^%s*$") then
                dropped = true
            else
                if dropped and last() == "" and cleaned:match("^%s*[}%])]") then
                    table.remove(lines)
                end
                table.insert(lines, cleaned)
                dropped = false
            end
        else
            if not (dropped and line:match("^%s*$") and (#lines == 0 or last() == "" or last():match("[{%[(]%s*$"))) then
                if dropped and last() == "" and line:match("^%s*[}%])]") then
                    table.remove(lines)
                end
                table.insert(lines, line)
            end
            dropped = false
        end
    end
    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end
    while #lines > 0 and lines[1] == "" do
        table.remove(lines, 1)
    end
    return table.concat(lines, "\n") .. "\n"
end

local function tracked(roots)
    local list = os.iorunv("git", table.join({"ls-files", "--"}, roots))
    local files = {}
    for file in list:gmatch("[^\n]+") do
        if language(file) and os.isfile(file) and not os.islink(file) then
            table.insert(files, file)
        end
    end
    if #files == 0 then
        return files
    end
    local kept = {}
    for first = 1, #files, 500 do
        local attrs = os.iorunv("git", table.join({"check-attr", "comments", "--"}, table.slice(files, first, first + 499)))
        for line in attrs:gmatch("[^\n]+") do
            local file, value = line:match("^(.*): comments: (%S+)$")
            if file and value == "unspecified" then
                table.insert(kept, file)
            end
        end
    end
    return kept
end

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

local function verify(files, rev)
    local scratch = path.join(os.getenv("HOME"), ".revenant", "cache", "comments-verify")
    os.tryrm(scratch)
    local differ = {}
    local luapairs = {}
    runjobs("verify", function (index)
        local file = files[index]
        local lang = language(file)
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
            if code(before, comments(before, lang)) ~= code(after, comments(after, lang)) then
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

local function changed(rev)
    local files = {}
    for file in os.iorunv("git", {"diff", "--name-only", "--diff-filter=M", rev, "--"}):gmatch("[^\n]+") do
        if language(file) then
            table.insert(files, file)
        end
    end
    return files
end

local function test_suite()
    local count = 0
    local function check(text, kind, want, name)
        count = count + 1
        local got = #comments(text, {kind = kind})
        assert(got == want, string.format("test %s: %d comments, want %d", name, got, want))
    end

    check("#!/bin/sh\necho ok\n", "sh", 0, "shebang is not a comment")
    check("# note\necho ok\n", "sh", 1, "comment without shebang")
    check("#!/bin/sh\n# note\necho ok\n", "sh", 1, "comment after shebang")
    check("#!/bin/sh\necho ok # note\n", "sh", 1, "trailing comment")
    check("#!/bin/sh\necho http://x#y foo#bar\n", "sh", 0, "hash inside a word")
    check("#!/bin/sh\necho '#a' \"#b\" $# ${#v} ${v#p}\n", "sh", 0, "quotes and expansions")
    check("#!/bin/sh\necho \"$(printf %s '#x')\" # note\n", "sh", 1, "substitution inside quotes")
    check("#!/bin/sh\ncase x in \\#) ;; esac\n", "sh", 0, "escaped hash")
    check("#!/bin/sh\necho $(( 2#1010 ))\n", "sh", 0, "arithmetic")
    check("#!/bin/sh\ncat <<-EOF\n\t# text\n\tEOF\n# note\n", "sh", 1, "heredoc body is not a comment")
    check("#!/bin/sh\n# Copyright 2026\necho ok\n", "sh", 0, "licence header")
    check("key: val\n", "yaml", 0, "no comment")
    check("# note\nkey: val\n", "yaml", 1, "comment line")
    check("key: val # note\n", "yaml", 1, "trailing comment")
    check("key: '#a' \"#b\"\n", "yaml", 0, "quoted hash")
    check("url: http://x#y\n", "yaml", 0, "hash inside a word")
    check("desc: |\n  # text\n  x\n", "yaml", 0, "block scalar body")
    check("run: | # note\n  echo ok\n", "yaml", 1, "block scalar header comment")
    check("run: |\n  # note\n  echo $#\n", "yaml", 1, "run block is shell")
    check("# Copyright 2026\nname: x\n", "yaml", 0, "licence header")

    print(string.format("comments: %d tests passed", count))
end

function main(command, ...)
    local args = {...}
    os.cd(os.iorunv("git", {"rev-parse", "--show-toplevel"}):trim())
    if command == "check" or command == "strip" then
        local found = 0
        for _, file in ipairs(tracked(args)) do
            local text = io.readfile(file, {encoding = "binary"})
            local spans = comments(text, language(file))
            if #spans > 0 then
                found = found + 1
                if command == "strip" then
                    io.writefile(file, strip(text, spans), {encoding = "binary"})
                else
                    print("%s: %d", file, #spans)
                end
            end
        end
        if command == "check" and found > 0 then
            raise("%d files carry comments", found)
        end
        if command == "strip" then
            print("%d files stripped", found)
        end
    elseif command == "verify" then
        local rev = args[1] or "HEAD"
        local files = changed(rev)
        local differ = verify(files, rev)
        for _, file in ipairs(differ) do
            print("changed beyond comments: %s", file)
        end
        if #differ > 0 then
            raise("%d of %d files changed beyond comments", #differ, #files)
        end
        print("%d files differ from %s only in comments", #files, rev)
    elseif command == "test" then
        test_suite()
    else
        raise("usage: xmake l tools/comments.lua check|strip [path ...] | verify [rev] | test")
    end
end
