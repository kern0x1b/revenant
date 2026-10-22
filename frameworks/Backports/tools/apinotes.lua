function merge(source, target)
    local function top_level_key(line)
        local stripped = line:gsub("%s+$", "")
        if line == "" or line:find("^[ \t#-]") or stripped == "---" or stripped:sub(-1) ~= ":" then
            return nil
        end
        return stripped:sub(1, -2)
    end
    local function sections(lines)
        local blocks = {}
        for index, line in ipairs(lines) do
            local name = top_level_key(line)
            if name ~= nil then
                table.insert(blocks, {name = name, index = index, body = {}})
            elseif #blocks > 0 then
                table.insert(blocks[#blocks].body, line)
            else
                table.insert(blocks, {body = {line}})
            end
        end
        return blocks
    end
    local function list_lines(body)
        local kept = {}
        for _, line in ipairs(body) do
            if line:find("^%s*$") or line:find("^%s*#") or line:find("^[ %-]") then
                table.insert(kept, line)
            end
        end
        return kept
    end
    local function merge(lines, key)
        local blocks = sections(lines)
        local folded = {}
        local seen = false
        for _, block in ipairs(blocks) do
            if block.name == key then
                if #list_lines(block.body) ~= #block.body then
                    raise("refused: a line of the duplicated section %s is neither an entry nor nested under one", key)
                end
                if seen then
                    for _, line in ipairs(list_lines(block.body)) do
                        table.insert(folded, line)
                    end
                else
                    seen = true
                    folded = list_lines(block.body)
                end
            end
        end
        local result = {}
        seen = false
        for _, block in ipairs(blocks) do
            if block.name ~= key then
                if block.index ~= nil then
                    table.insert(result, lines[block.index])
                end
                for _, line in ipairs(block.body) do
                    table.insert(result, line)
                end
            elseif not seen then
                seen = true
                table.insert(result, lines[block.index])
                for _, line in ipairs(folded) do
                    table.insert(result, line)
                end
            end
        end
        return result
    end
    local function count_entries(lines)
        local count = 0
        for _, line in ipairs(lines) do
            if line:sub(1, 7) == "- Name:" then
                count = count + 1
            end
        end
        return count
    end
    local function section_names(lines)
        local names = {}
        for _, block in ipairs(sections(lines)) do
            if block.name ~= nil and block.name ~= "" then
                table.insert(names, block.name)
            end
        end
        return names
    end
    local function as_set(list)
        local set, size = {}, 0
        for _, value in ipairs(list) do
            if not set[value] then
                set[value] = true
                size = size + 1
            end
        end
        return set, size
    end
    local function check_subset(lines, what)
        for index, line in ipairs(lines) do
            local shaped = line:find("^%s*$") or line:find("^%s*#") or line == "---"
                or line:find("^[%w_]+:$") or line:find("^[%w_]+: %S")
                or line:find("^%- [%w_]+:") or line:find("^ +%- [%w_]+:") or line:find("^ +[%w_]+:")
            if line:find("\t", 1, true) or not shaped then
                raise("refused: %s, line %d, is outside the apinotes subset the merge reads: %s", what, index, line)
            end
        end
    end

    local text = io.readfile(source):gsub("\r\n?", "\n")
    local original = {}
    local start = 1
    while true do
        local stop = text:find("\n", start, true)
        if not stop then
            table.insert(original, text:sub(start))
            break
        end
        table.insert(original, text:sub(start, stop - 1))
        start = stop + 1
    end
    check_subset(original, "the input")
    local keys = section_names(original)
    local counts = {}
    for _, key in ipairs(keys) do
        counts[key] = (counts[key] or 0) + 1
    end
    local duplicates = {}
    local listed = {}
    for _, key in ipairs(keys) do
        if counts[key] > 1 and not listed[key] then
            table.insert(duplicates, key)
            listed[key] = true
        end
    end
    if #duplicates == 0 then
        io.writefile(target, table.concat(original, "\n"))
        print(string.format("no duplicate top-level key in %s: it is written through", source))
        return
    end

    local entries_before = count_entries(original)
    local merged = original
    for _, key in ipairs(duplicates) do
        merged = merge(merged, key)
    end
    local entries_after = count_entries(merged)
    if entries_after ~= entries_before then
        raise("refused: the merge changed the entry count, %d `- Name:` in and %d out", entries_before, entries_after)
    end
    local merged_keys = section_names(merged)
    local key_set, key_count = as_set(keys)
    local merged_set, merged_count = as_set(merged_keys)
    if merged_count ~= key_count or merged_count ~= #merged_keys then
        raise("refused: the merge changed the sections, %d in and %d out", key_count, merged_count)
    end
    for key in pairs(merged_set) do
        if not key_set[key] then
            raise("refused: the merge changed the sections, %s is new", key)
        end
    end
    local removed = 0
    for _, key in ipairs(duplicates) do
        removed = removed + counts[key] - 1
    end
    if #merged ~= #original - removed then
        raise("refused: the merge moved %d lines, expected %d", #merged, #original - removed)
    end
    check_subset(merged, "the merged file")
    io.writefile(target, table.concat(merged, "\n"))
    print(string.format("merged the duplicate top-level %s of %s: %d `- Name:` entries in and %d out, %d sections",
        table.concat(duplicates, ", "), source, entries_before, entries_after, merged_count))
end

function overlay(headers, sdk_apinotes, folder)
    local merged = path.join(folder, "SceneKit.apinotes")
    merge(sdk_apinotes, merged)
    local overlay_file = path.join(folder, "overlay.yaml")
    local function quoted(text)
        return '"' .. text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
    end
    io.writefile(overlay_file, table.concat({
        '{"version":0,"case-sensitive":"false","roots":[{"type":"directory","name":', quoted(headers),
        ',"contents":[{"type":"file","name":"SceneKit.apinotes","external-contents":', quoted(merged), '}]}]}'
    }))
    return overlay_file
end
