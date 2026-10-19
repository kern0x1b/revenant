local function digest(text)
    local h = 0
    for k = 1, #text, 4096 do
        for _, b in ipairs({text:byte(k, math.min(k + 4095, #text))}) do
            h = (h * 31 + b) % 4294967296
        end
    end
    return string.format("%08x", h)
end

local function cells_of(line)
    local out = {}
    for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
        out[#out + 1] = cell
    end
    return out
end

function failures(opt)
    local byteorder = import("byteorder", {rootdir = opt.modules})
    local root = path.join(opt.modules, "..")
    local apple = path.join(root, "packages", "a", "apple-backports")
    local facts = path.join(apple, "facts", "Matter")
    local closure = path.join(facts, "emit-closure.tsv")
    local overlap = path.join(facts, "class-overlap.tsv")
    local objects = path.join(apple, "Matter")
    local out = {}
    if not os.isfile(closure) or not os.isfile(overlap) then
        return {"no emit-closure.tsv or class-overlap.tsv under " .. facts}
    end

    local overlap_text = io.readfile(overlap)
    local real, input = {}, 0
    local first = true
    for line in overlap_text:gmatch("[^\n]+") do
        if first then
            first = false
        else
            local cells = cells_of(line)
            if cells[1] then
                real[cells[1]] = cells[2]
                input = input + 1
            end
        end
    end

    local lines = {}
    for line in io.lines(closure) do
        lines[#lines + 1] = line
    end
    local stamp = lines[1] or ""
    local have = stamp:match("^# inputs: class%-overlap%.tsv (%x+);")
    local want = digest(overlap_text)
    if have ~= want then
        out[#out + 1] = "emit-closure.tsv is stale: its class-overlap.tsv digest is " .. tostring(have)
            .. ", the file's is " .. want .. " (re-run tools/matter-closure.lua)"
    end
    if lines[2] ~= "class\treal-stack\tin-closure\treason\temit" then
        out[#out + 1] = "emit-closure.tsv has no column line in its second row"
    end

    local emit, rows, prev = {}, 0, nil
    for index = 3, #lines do
        local cells = cells_of(lines[index])
        local name, real_col, closure_col, reason, emit_col = cells[1], cells[2], cells[3], cells[4], cells[5]
        rows = rows + 1
        if prev and not byteorder.less(prev, name) then
            out[#out + 1] = "row " .. index .. " (" .. tostring(name) .. ") is not in byte order after " .. prev
        end
        prev = name
        if real[name] == nil then
            out[#out + 1] = name .. " is not a generator input (not in class-overlap.tsv)"
        elseif real_col ~= real[name] then
            out[#out + 1] = name .. " real-stack is " .. tostring(real_col) .. ", class-overlap says " .. real[name]
        end
        if closure_col ~= "yes" and closure_col ~= "no" then
            out[#out + 1] = name .. " in-closure is not yes or no"
        elseif (closure_col == "yes") == (reason == "none") then
            out[#out + 1] = name .. " in-closure " .. closure_col .. " disagrees with its reason"
        end
        local expect = (real[name] == "no" and closure_col == "yes") and "yes" or "no"
        if emit_col ~= expect then
            out[#out + 1] = name .. " emit is " .. tostring(emit_col) .. ", the rule says " .. expect
        end
        emit[name] = emit_col
    end
    if rows ~= input then
        out[#out + 1] = "emit-closure.tsv has " .. rows .. " rows for " .. input .. " generator input classes"
    end

    for _, file in ipairs(os.files(path.join(objects, "RevenantMatter*.m"))) do
        local impl = io.readfile(file):match("@implementation%s+([%w_]+)")
        local shown = path.filename(file)
        if not impl then
            out[#out + 1] = shown .. " defines no class"
        elseif emit[impl] == nil then
            out[#out + 1] = shown .. " defines " .. impl .. ", which is not a generator input"
        else
            out[#out + 1] = shown .. " defines " .. impl .. " (emit-closure.tsv " .. emit[impl] .. "): no Matter object is committed since v-matter13"
        end
    end
    return out
end
