import("byteorder", {rootdir = os.scriptdir()})

local trees = {"", "curr/", "lang/", "region/", "zone/", "unit/", "coll/", "brkitr/", "rbnf/"}
local dropped = {"rbnf/", "translit/"}
local languages = {"af", "am", "ar", "az", "be", "bg", "bn", "bs", "ca", "cs", "cy", "da", "de", "el", "en", "es", "et", "eu", "fa", "fi", "fil", "fr", "ga", "gl", "gu", "he", "hi", "hr", "hu", "hy", "id", "is", "it", "ja", "ka", "kk", "km", "kn", "ko", "lo", "lt", "lv", "mk", "ml", "mr", "ms", "my", "nb", "ne", "nl", "nn", "no", "pa", "pl", "pt", "ro", "ru", "si", "sk", "sl", "sq", "sr", "sv", "sw", "ta", "te", "th", "tl", "tr", "uk", "ur", "uz", "vi", "zh"}
local unindexed = {ja_JP_TRADITIONAL = true, th_TH_TRADITIONAL = true, de_ = true, de__PHONEBOOK = true, es_ = true, es__TRADITIONAL = true}

local function language(name)
    return name:match("^([^_]*)")
end


function trim(bin, archive)
    local keep, kept = {root = true}, 0
    for _, name in ipairs(languages) do
        keep[name] = true
        kept = kept + 1
    end
    local icupkg = path.join(bin, "icupkg")
    local work = path.absolute("data-trim")
    os.tryrm(work)
    local items = {}
    for _, line in ipairs(os.iorunv(icupkg, {"-l", archive}):split("\n")) do
        local item = line:trim():gsub("^icudt%d+[lbe]/", "")
        if item ~= "" then
            items[item] = true
        end
    end
    local removed, added = {}, {}
    local function is_dropped(tree)
        for _, prefix in ipairs(dropped) do
            if prefix == tree then
                return true
            end
        end
        return false
    end
    for _, tree in ipairs(trees) do
        local index = tree .. "res_index.res"
        if items[index] and not is_dropped(tree) then
            os.mkdir(path.join(work, "in", tree))
            os.vrunv(icupkg, {"-x", index, "-d", path.join(work, "in"), archive})
            local text = os.iorunv(path.join(bin, "derb"), {"-c", "-s", path.join(work, "in", tree), "res_index.res"})
            local indexed, lines = {}, {}
            for _, line in ipairs(text:split("\n", {strict = true})) do
                local key = line:match("^%s*([%w_]+)%s*{%s*\"\"%s*}%s*$")
                if key then
                    indexed[key] = true
                end
                if line == "res_index{" then
                    line = "res_index:table(nofallback) {"
                end
                if not key or keep[language(key)] then
                    table.insert(lines, line)
                end
            end
            local count = 0
            for item in pairs(items) do
                local stem = item:startswith(tree) and item:sub(#tree + 1):match("^([^/]+)%.res$")
                if stem and (indexed[stem] or unindexed[stem]) and not keep[language(stem)] then
                    table.insert(removed, item)
                    count = count + 1
                end
            end
            if count > 0 then
                local source = path.join(work, "txt", tree)
                os.mkdir(source)
                io.writefile(path.join(source, "res_index.txt"), table.concat(lines, "\n") .. "\n")
                os.mkdir(path.join(work, "out", tree))
                os.vrunv(path.join(bin, "genrb"), {"-k", "-e", "UTF-8", "-s", source, "-d", path.join(work, "out", tree), "res_index.txt"})
                table.insert(added, index)
            end
        end
    end
    for item in pairs(items) do
        for _, prefix in ipairs(dropped) do
            if item:startswith(prefix) then
                table.insert(removed, item)
            end
        end
    end
    removed = table.unique(removed)
    byteorder.sort(removed)
    io.writefile(path.join(work, "removed.txt"), table.concat(removed, "\n") .. "\n")
    local argv = {"-r", path.join(work, "removed.txt")}
    if #added > 0 then
        io.writefile(path.join(work, "added.txt"), table.concat(added, "\n") .. "\n")
        table.join2(argv, {"-a", path.join(work, "added.txt"), "-s", path.join(work, "out")})
    end
    local trimmed = path.join(work, path.filename(archive))
    os.vrunv(icupkg, table.join(argv, {archive, trimmed}))
    local present, count = {}, 0
    for line in os.iorunv(icupkg, {"-l", trimmed}):gmatch("[^\n]+") do
        local name = line:trim():gsub("^icudt%d+[lbe]/", "")
        present[name] = true
        count = count + 1
    end
    local before = 0
    for _ in pairs(items) do
        before = before + 1
    end
    assert(count == before - #removed, "icu data: the trimmed archive holds " .. count .. " items, expected " .. (before - #removed))
    for _, name in ipairs(removed) do
        assert(not present[name], "icu data: " .. name .. " is still in the trimmed archive")
    end
    for name in pairs(present) do
        local dir, base = name:match("^(.-)([^/]+)%.res$")
        if base and base ~= "root" and base ~= "res_index" then
            local parent = base:match("^(.*)_[^_]*$") or "root"
            assert(present[dir .. parent .. ".res"], "icu data: " .. name .. " depends on the missing " .. dir .. parent .. ".res")
        end
    end
    os.cp(trimmed, archive)
    print("icu data: %d languages kept, %d items removed, %d indexes rewritten, without %s", kept, #removed, #added, table.concat(dropped, " "))
end
