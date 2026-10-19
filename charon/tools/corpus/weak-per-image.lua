import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local tsv = import("tsv", {rootdir = os.scriptdir()})

local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local CORPUS = workspace.corpus()
local ORDER = {"c++", "mixed", "objc/c", "unknown", "swift"}
local RANK = {}
for index, class in ipairs(ORDER) do
    RANK[class] = index - 1
end

local function rank_of(class)
    return RANK[class] or 4
end

local function in_rank_order(names)
    local keyed = {}
    for _, name in ipairs(names) do
        keyed[string.format("%d", rank_of(name)) .. "\1" .. name] = name
    end
    local out = {}
    for _, key in ipairs(byteorder.keys(keyed)) do
        table.insert(out, keyed[key])
    end
    return out
end

local function starts(text, prefix)
    return text:sub(1, #prefix) == prefix
end

local function classify(undefined)
    local swift, cpp, total = 0, 0, 0
    for sym in pairs(undefined) do
        total = total + 1
        if starts(sym, "_$s") or starts(sym, "_$S") or starts(sym, "$s") or starts(sym, "$S") or sym:find("swiftCore", 1, true) then
            swift = swift + 1
        end
        if starts(sym, "__Z") or starts(sym, "_Z") then
            cpp = cpp + 1
        end
    end
    if swift >= 10 and cpp >= 5 then
        return "mixed"
    end
    if swift >= 10 then
        return "swift"
    end
    if cpp >= 5 then
        return "c++"
    end
    return total > 0 and "objc/c" or "unknown"
end

local function units_of(dir, base)
    local found = {}
    for _, file in ipairs(os.files(path.join(dir, "**"))) do
        local rel = file:sub(#base + 2)
        local folder = rel:match("^(.*)/[^/]*$") or "."
        local name = rel:match("([^/]*)$")
        local unit = folder == "." and name:gsub("%.txt$", "") or folder
        table.insert(found, {unit = unit, file = file})
    end
    return found
end

function main(dir, flag)
    if not dir or not os.isdir(dir) then
        raise("usage: weak-per-image.lua <dir of per-image nm -m outputs> [--any]")
    end
    local any_strength = flag == "--any"
    local base = path.absolute(dir)
    local images = {}
    for _, entry in ipairs(units_of(dir, base)) do
        local e = images[entry.unit]
        if e == nil then
            e = {weak = {}, undef = {}}
            images[entry.unit] = e
        end
        for line in io.lines(entry.file) do
            local sym = line:match("%(undefined%) external (%S+)") or line:match("%(undefined%) weak external (%S+)")
            if sym then
                e.undef[sym] = true
                if line:match("%(undefined%) weak external (%S+)") or any_strength then
                    e.weak[sym] = true
                end
            end
        end
    end
    local by_sym = {}
    for img, e in pairs(images) do
        e.class = classify(e.undef)
        for sym in pairs(e.weak) do
            by_sym[sym] = by_sym[sym] or {}
            table.insert(by_sym[sym], img)
        end
    end

    local ranked = tsv.body(path.join(CORPUS, "weak-imports-ranked.tsv"))
    local rows = {}
    for index, f in ipairs(ranked) do
        if #f < 8 then
            raise("weak-per-image.lua: weak-imports-ranked.tsv row %d has %d fields, not 8", index + 1, #f)
        end
        local tier, sym, kind, fw, intro, reg, apps = f[1], f[2], f[3], f[4], f[5], f[6], f[7]
        local imgs = by_sym[sym] or {}
        byteorder.sort(imgs)
        local seen, classes = {}, {}
        for _, img in ipairs(imgs) do
            local class = images[img].class
            if not seen[class] then
                seen[class] = true
                table.insert(classes, class)
            end
        end
        classes = in_rank_order(classes)
        local best = classes[1] or "not in these images"
        table.insert(rows, {tier = tier, best = best, sym = sym, kind = kind, fw = fw, intro = intro, reg = reg,
                            apps = apps, imgs = imgs, classes = classes, index = index})
    end

    local keyed = {}
    for _, row in ipairs(rows) do
        local key = table.concat({row.tier, string.format("%d", rank_of(row.best)),
                                  string.format("%07d", 1000000 - tonumber(row.apps)), row.sym,
                                  string.format("%07d", row.index)}, "\1")
        keyed[key] = row
    end
    local sorted = {}
    for _, key in ipairs(byteorder.keys(keyed)) do
        table.insert(sorted, keyed[key])
    end
    rows = sorted

    local out = path.join(CORPUS, any_strength and "weak-imports-by-image-any.tsv" or "weak-imports-by-image.tsv")
    local file_out = assert(io.open(out, "w"))
    file_out:write("tier\tmost_exposed_image_class\tsymbol\tkind\tframework\tintroduced\tregistry\tcorpus_apps\timages\n")
    for _, row in ipairs(rows) do
        local shown = {}
        for index = 1, math.min(4, #row.imgs) do
            table.insert(shown, row.imgs[index])
        end
        local list = table.concat(shown, "; ") .. (#row.imgs > 4 and " ..." or "")
        file_out:write(table.concat({row.tier, row.best, row.sym, row.kind, row.fw, row.intro, row.reg, row.apps, list}, "\t") .. "\n")
    end
    file_out:close()

    local count_by_class = {}
    local image_count = 0
    for _, e in pairs(images) do
        image_count = image_count + 1
        count_by_class[e.class] = (count_by_class[e.class] or 0) + 1
    end
    local class_parts = {}
    for _, class in ipairs(ORDER) do
        table.insert(class_parts, string.format("%s %d", class, count_by_class[class] or 0))
    end
    print(string.format("%d images read; image classes: %s", image_count, table.concat(class_parts, ", ")))
    local found = 0
    for _, row in ipairs(rows) do
        if #row.classes > 0 then
            found = found + 1
        end
    end
    print(string.format("weak symbols in the ranked list found in these images: %d of %d -> %s", found, #rows, out))

    local cross, cross_tiers = {}, {}
    for _, row in ipairs(rows) do
        if not cross[row.tier] then
            cross[row.tier] = {}
            table.insert(cross_tiers, row.tier)
        end
        cross[row.tier][row.best] = (cross[row.tier][row.best] or 0) + 1
    end
    byteorder.sort(cross_tiers)
    for _, tier in ipairs(cross_tiers) do
        local kinds = {}
        for kind in pairs(cross[tier]) do
            table.insert(kinds, kind)
        end
        kinds = in_rank_order(kinds)
        local parts = {}
        for _, kind in ipairs(kinds) do
            table.insert(parts, string.format("%s %d", kind, cross[tier][kind]))
        end
        print(string.format("  %-30s %s", tier, table.concat(parts, ", ")))
    end
    return rows
end
