local stream = import("stream", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local sdk = import("sdk", {anonymous = true})

local ENTITIES = {class = true, method = true, property = true}
local FRAMEWORK_SUFFIX = ".framework"
local FIELDS = {"entity", "owner", "section", "name", "decl", "types", "address", "superclass", "protocols", "category"}

function framework_of(image)
    local folder = string.match(string.match(image, "^(.*)/[^/]*$") or "", "([^/]*)$")
    if string.sub(folder, -#FRAMEWORK_SUFFIX) == FRAMEWORK_SUFFIX then
        return string.sub(folder, 1, #folder - #FRAMEWORK_SUFFIX)
    end
    return string.match(image, "([^/]*)$")
end

function key_of(row)
    return row.entity .. "\t" .. row.owner .. "\t" .. row.section .. "\t" .. row.name
end

function each(corpus, release, wanted, fn)
    local names = sdk.names(release)
    local columns = nil
    local header = nil
    local count = 0
    local memo = {}
    for _, part in ipairs(names.objc_parts) do
        local file = path.join(corpus, names.cache_dir, part)
        assert(os.isfile(file), "no objc table part: " .. file)
        local first = true
        local number = 0
        local status = stream.lines("gzip", {"-dc", file}, function(line)
            number = number + 1
            if first then
                first = false
                if header == nil then
                    header = line
                    columns = {}
                    local names = tsv.fields(line)
                    for i, name in ipairs(names) do
                        columns[name] = i
                    end
                    assert(columns.image == 1 and columns.entity == 2, "the objc table's first columns are image and entity")
                    for _, name in ipairs(FIELDS) do
                        assert(columns[name], "the objc table has no column " .. name)
                    end
                    count = #names
                else
                    assert(line == header, "objc table part " .. part .. " has another header")
                end
                return
            end
            local t1 = string.find(line, "\t", 1, true)
            assert(t1, string.format("objc table %s line %d is a short row (no tab): %s", file, number, string.sub(line, 1, 80)))
            local t2 = string.find(line, "\t", t1 + 1, true)
            local entity = string.sub(line, t1 + 1, (t2 or (#line + 1)) - 1)
            if not ENTITIES[entity] then
                return
            end
            assert(t2, string.format("objc table %s line %d is a short row (no cell after its entity): %s", file, number,
                                     string.sub(line, 1, 80)))
            local image = string.sub(line, 1, t1 - 1)
            local fw = memo[image]
            if fw == nil then
                fw = framework_of(image)
                memo[image] = fw
            end
            if wanted == nil or wanted[fw] then
                local cells = tsv.fields(line)
                assert(#cells >= count, string.format("objc table %s line %d is a short row: %d cells where the header has %d: %s",
                                                      file, number, #cells, count, string.sub(line, 1, 80)))
                local row = {}
                for _, name in ipairs(FIELDS) do
                    row[name] = cells[columns[name]]
                end
                fn(fw, row)
            end
        end)
        assert(status == 0, "gzip failed on " .. part .. " (status " .. tostring(status) .. ")")
    end
end

function facts(corpus, release, fw)
    local list, index = {}, {}
    each(corpus, release, {[fw] = true}, function(_, row)
        local k = key_of(row)
        if index[k] == nil then
            index[k] = row
            table.insert(list, row)
        end
    end)
    return {list = list, index = index}
end
