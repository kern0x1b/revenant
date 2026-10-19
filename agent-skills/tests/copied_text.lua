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

local function runs(lines)
    local out = {}
    for i = 1, #lines - 4 do
        out[#out + 1] = table.concat(lines, "\n", i, i + 4)
    end
    return out
end

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
