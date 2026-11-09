local function decode(literal)
    local quote = literal:sub(1, 1)
    local body = literal:sub(2, -2)
    local points = {}
    local index = 1
    while index <= #body do
        local c = body:sub(index, index)
        if c == "\\" then
            local kind = body:sub(index + 1, index + 1)
            if kind == "x" then
                table.insert(points, tonumber(body:sub(index + 2, index + 3), 16))
                index = index + 4
            elseif kind == "u" then
                table.insert(points, tonumber(body:sub(index + 2, index + 5), 16))
                index = index + 6
            elseif kind == "U" then
                table.insert(points, tonumber(body:sub(index + 2, index + 9), 16))
                index = index + 10
            elseif kind == "n" then
                table.insert(points, 10)
                index = index + 2
            elseif kind == "t" then
                table.insert(points, 9)
                index = index + 2
            elseif kind == "r" then
                table.insert(points, 13)
                index = index + 2
            else
                table.insert(points, string.byte(kind))
                index = index + 2
            end
        else
            assert(c ~= quote, "unterminated literal " .. literal)
            table.insert(points, string.byte(c))
            index = index + 1
        end
    end
    return points
end

function main(source, output)
    local entries = {}
    for line in io.lines(source) do
        local name, literal = line:match("^    '([%w]+;)': (['\"].*['\"]),$")
        if name then
            local points = decode(literal)
            assert(#points >= 1 and #points <= 2, name .. " has " .. #points .. " code points")
            table.insert(entries, {name = name:sub(1, -2), first = points[1], second = points[2] or 0})
        end
    end
    table.sort(entries, function(a, b)
        local shorter = math.min(#a.name, #b.name)
        for index = 1, shorter do
            local left, right = a.name:byte(index), b.name:byte(index)
            if left ~= right then
                return left < right
            end
        end
        return #a.name < #b.name
    end)
    local lines = {"#import \"RevenantMarkdownEntities.h\"", "", "static const RevenantMarkdownEntity RevenantMarkdownEntities[] = {"}
    for _, entry in ipairs(entries) do
        table.insert(lines, string.format("    {\"%s\", 0x%x, 0x%x},", entry.name, entry.first, entry.second))
    end
    table.insert(lines, "};")
    table.insert(lines, "")
    table.insert(lines, "const RevenantMarkdownEntity *RevenantMarkdownEntityNamed(const char *name, size_t length)")
    table.insert(lines, "{")
    table.insert(lines, "    size_t low = 0, high = sizeof(RevenantMarkdownEntities) / sizeof(RevenantMarkdownEntities[0]);")
    table.insert(lines, "    while (low < high) {")
    table.insert(lines, "        size_t middle = low + (high - low) / 2;")
    table.insert(lines, "        const char *candidate = RevenantMarkdownEntities[middle].name;")
    table.insert(lines, "        int order = strncmp(name, candidate, length);")
    table.insert(lines, "        if (order == 0)")
    table.insert(lines, "            order = candidate[length] ? -1 : 0;")
    table.insert(lines, "        if (order == 0)")
    table.insert(lines, "            return &RevenantMarkdownEntities[middle];")
    table.insert(lines, "        if (order < 0)")
    table.insert(lines, "            high = middle;")
    table.insert(lines, "        else")
    table.insert(lines, "            low = middle + 1;")
    table.insert(lines, "    }")
    table.insert(lines, "    return NULL;")
    table.insert(lines, "}")
    io.writefile(output, table.concat(lines, "\n") .. "\n")
    print(#entries .. " entities")
end
