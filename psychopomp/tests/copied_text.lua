-- Verdict helper for tests/check.sh: lists the project files that repeat a run of five significant lines from the
-- plugin's own text. A significant line is at least eight characters after its whitespace is collapsed and trimmed.
-- Files that are not UTF-8, and files that cannot be read, are skipped.
-- Usage: xmake l tests/copied_text.lua PLUGIN_DIR PROJECT_DIR
-- Output, one line per copied file: "PATH repeats PLUGIN_PATH: FIRST_LINE" (FIRST_LINE cut to 60 characters).
-- This replaces an inline python3 script. The Python walked with os.walk, which took the first plugin file it saw
-- for each run; this takes them in sorted order. Differences: only ASCII whitespace is collapsed (Python's split()
-- also takes Unicode spaces), and a run's "first line" is the first matching run in file order, not a set's order.

-- Lines of a file that count, as the Python made them: universal newlines, the splitlines() separators, collapsed
-- whitespace, and a length of eight or more characters.
local function significant_lines(text)
    text = (string.gsub(text, "\r\n", "\n"))
    text = (string.gsub(text, "\r", "\n"))
    text = (string.gsub(text, "[\v\f\28\29\30]", "\n"))
    text = (string.gsub(text, "\194\133", "\n"))
    text = (string.gsub(text, "\226\128\168", "\n"))
    text = (string.gsub(text, "\226\128\169", "\n"))
    local lines = {}
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        local norm = string.match(string.gsub(line, "%s+", " "), "^ ?(.-) ?$")
        if utf8.len(norm) >= 8 then
            lines[#lines + 1] = norm
        end
    end
    return lines
end

-- Every run of five consecutive significant lines, in file order.
local function runs(lines)
    local out = {}
    for i = 1, #lines - 4 do
        out[#out + 1] = table.concat(lines, "\n", i, i + 4)
    end
    return out
end

-- Files and symlinks under root, skipping the named directories at any depth; find does not follow links, as
-- os.walk did not. The Python listed hidden files too, and so does find.
local function files_under(root, skip)
    local prune = {}
    for _, name in ipairs(skip) do
        prune[#prune + 1] = "-name " .. name
    end
    local expr = 'find "$0" \\( -type d \\( ' .. table.concat(prune, " -o ") .. ' \\) \\) -prune -o '
        .. '\\( -type f -o -type l \\) -print 2>/dev/null; true'
    local body = os.iorunv("/bin/sh", {"-c", expr, root})
    local list = {}
    for line in string.gmatch(body, "[^\n]+") do
        list[#list + 1] = line
    end
    table.sort(list)
    return list
end

local function read_text(file)
    local handle = io.open(file, "rb")
    if not handle then
        return nil
    end
    local data = handle:read("a")
    handle:close()
    if not data or not utf8.len(data) then
        return nil
    end
    return data
end

function main(plugin, project)
    local known = {}
    for _, file in ipairs(files_under(plugin, {".git", "scenarios", ".agent-work"})) do
        local text = read_text(file)
        if text then
            local rel = string.sub(file, #plugin + 2)
            for _, key in ipairs(runs(significant_lines(text))) do
                if not known[key] then
                    known[key] = rel
                end
            end
        end
    end
    for _, file in ipairs(files_under(project, {"build", ".xmake", ".logs", ".git"})) do
        local base = string.match(file, "([^/]+)$")
        local text = base ~= "answers.md" and read_text(file)
        if text then
            for _, key in ipairs(runs(significant_lines(text))) do
                if known[key] then
                    local first = string.match(key, "^[^\n]*")
                    local cut = utf8.offset(first, 61)
                    if cut then
                        first = string.sub(first, 1, cut - 1)
                    end
                    print(file .. " repeats " .. known[key] .. ": " .. first)
                    break
                end
            end
        end
    end
end
