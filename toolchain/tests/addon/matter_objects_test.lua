local pinned = 0

function failures(opt)
    local root = path.join(opt.modules, "..")
    local apple = path.join(root, "packages", "frameworks", "apple-backports")
    local overlap = path.join(apple, "facts", "Matter", "class-overlap.tsv")
    local objects = path.join(apple, "Matter")
    local real = path.join(root, "packages", "frameworks", "matter", "registry")
    local out = {}
    if not os.isfile(overlap) then
        return {"no class-overlap.tsv at " .. overlap}
    end

    local generated = {}
    local first = true
    for line in io.lines(overlap) do
        if first then
            first = false
        else
            local name, verdict = line:match("^([^\t]+)\t([^\t]+)")
            if name and verdict == "yes" then
                generated[name] = true
            end
        end
    end

    local real_class = {}
    for _, file in ipairs(os.files(path.join(real, "*.json"))) do
        local text = io.readfile(file)
        for entry in text:gmatch("{[^{}]*}") do
            if entry:find('"kind"%s*:%s*"class"') then
                local api = entry:match('"api"%s*:%s*"([^"]+)"')
                if api then
                    real_class[api] = true
                end
            end
        end
    end

    local files = os.files(path.join(objects, "RevenantMatter*.m"))
    for _, file in ipairs(files) do
        local impl = io.readfile(file):match("@implementation%s+([%w_]+)")
        local shown = path.filename(file)
        if not impl then
            table.insert(out, shown .. " defines no class")
        else
            if generated[impl] then
                table.insert(out, shown .. " defines " .. impl .. ", a generated class (class-overlap.tsv yes): removed in v-matter11")
            end
            if real_class[impl] then
                table.insert(out, shown .. " defines " .. impl .. ", which the real registry carries as a class")
            end
        end
    end
    if #files ~= pinned then
        table.insert(out, "Matter/RevenantMatter*.m has " .. #files .. " objects, pinned at " .. pinned)
    end
    return out
end
