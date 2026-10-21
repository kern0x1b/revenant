import("async.runjobs")

local lexers = import("comments.lexers", {rootdir = os.scriptdir()})
local verify = import("comments.verify", {rootdir = os.scriptdir()})

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

local function candidates(roots)
    local list = os.iorunv("git", table.join({"ls-files", "--"}, roots))
    local files = {}
    for file in list:gmatch("[^\n]+") do
        if lexers.language(file) and os.isfile(file) and not os.islink(file) then
            table.insert(files, file)
        end
    end
    return files
end

local function unspecified(files)
    local kept = {}
    local attrs = os.iorunv("git", table.join({"check-attr", "comments", "--"}, files))
    for line in attrs:gmatch("[^\n]+") do
        local file, value = line:match("^(.*): comments: (%S+)$")
        if file and value == "unspecified" then
            table.insert(kept, file)
        end
    end
    return kept
end

local function scan(roots, visit)
    local files = candidates(roots)
    local batches = {}
    for first = 1, #files, 500 do
        table.insert(batches, table.slice(files, first, first + 499))
    end
    local done = {}
    runjobs("comments", function (index)
        done[index] = {}
        for _, file in ipairs(unspecified(batches[index])) do
            local hit = visit(file)
            if hit then
                table.insert(done[index], hit)
            end
        end
    end, {total = #batches, comax = os.cpuinfo().ncpu})
    local hits = {}
    for _, group in ipairs(done) do
        for _, hit in ipairs(group) do
            table.insert(hits, hit)
        end
    end
    return hits
end

local function changed(rev)
    local files = {}
    for file in os.iorunv("git", {"diff", "--name-only", "--diff-filter=M", rev, "--"}):gmatch("[^\n]+") do
        if lexers.language(file) then
            table.insert(files, file)
        end
    end
    return files
end

local function test_suite()
    local count = 0
    local function check(text, kind, want, name)
        count = count + 1
        local got = #lexers.comments(text, {kind = kind})
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
        local hits = scan(args, function (file)
            local text = io.readfile(file, {encoding = "binary"})
            local spans = lexers.comments(text, lexers.language(file))
            if #spans == 0 then
                return nil
            end
            if command == "strip" then
                io.writefile(file, strip(text, spans), {encoding = "binary"})
            end
            return {file = file, count = #spans}
        end)
        if command == "strip" then
            print("%d files stripped", #hits)
        else
            for _, hit in ipairs(hits) do
                print("%s: %d", hit.file, hit.count)
            end
            if #hits > 0 then
                raise("%d files carry comments", #hits)
            end
        end
    elseif command == "verify" then
        local rev = args[1] or "HEAD"
        local files = changed(rev)
        local differ = verify.differing(files, rev)
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
        raise("usage: ./xmakew l tools/comments.lua check|strip [path ...] | verify [rev] | test")
    end
end
