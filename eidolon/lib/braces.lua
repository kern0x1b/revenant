-- The braces a line of Swift really opens and closes.
--
-- Counting them with a plain count of "{" is wrong the moment a line carries a brace in a string or a
-- comment, and from that line on any walk over the file sits at the wrong depth. So the line is read as
-- Swift: "//", "/* */", a plain string, a multi-line one and a raw one with any number of hashes carry no
-- brace, and a block comment or a multi-line literal carries its state to the next line.
--
-- One function, used by every tool that counts depth in Swift on either side of the comparison, so a
-- depth is counted the same way on each side.
--
-- Returns opened, closed, in_block, in_multiline, hashes.

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

function braces(line, in_block, in_multiline, hashes)
    local opened, closed = 0, 0
    local i, n = 1, #line
    while i <= n do
        if in_block then
            if text.startswith(line, "*/", i) then
                in_block = false
                i = i + 2
            else
                i = i + 1
            end
        elseif in_multiline then
            local closing = hashes > 0 and (string.rep("#", hashes) .. '"""') or '"""'
            if text.startswith(line, closing, i) then
                in_multiline = false
                i = i + #closing
            else
                i = i + 1
            end
        elseif text.startswith(line, "//", i) then
            break
        elseif text.startswith(line, "/*", i) then
            in_block = true
            i = i + 2
        elseif string.sub(line, i, i) == "#" then
            local run = 0
            while i + run <= n and string.sub(line, i + run, i + run) == "#" do
                run = run + 1
            end
            if i + run <= n and string.sub(line, i + run, i + run) == '"' then
                hashes = run
                i = i + run + 1
                if text.startswith(line, '"""', i) then
                    in_multiline = true
                    i = i + 3
                else
                    local closing = string.rep("#", hashes) .. '"'
                    local found = string.find(line, closing, i, true)
                    i = found and found + #closing or n + 1
                end
            else
                i = i + run
            end
        elseif string.sub(line, i, i) == '"' then
            if text.startswith(line, '"""', i) then
                in_multiline = true
                i = i + 3
            else
                i = i + 1
                while i <= n do
                    local c = string.sub(line, i, i)
                    if c == "\\" then
                        i = i + 2
                    elseif c == '"' then
                        i = i + 1
                        break
                    else
                        i = i + 1
                    end
                end
            end
        else
            local c = string.sub(line, i, i)
            if c == "{" then
                opened = opened + 1
            elseif c == "}" then
                closed = closed + 1
            end
            i = i + 1
        end
    end
    return opened, closed, in_block, in_multiline, hashes
end
