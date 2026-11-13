local OWNERS_SHOWN = 6

local function hex(text)
    return tonumber(text, 16)
end

local function unlifted(corpus, e, image, out)
    local name = path.basename(image)
    local list = path.join(out, name .. ".coverage")
    local covered, log = corpus.run(e.xlate, {"--base", "0x10000000", "--coverage", list, image}, path.join(out, name .. ".coverage.log"))
    if not covered or not log:find("coverage: ", 1, true) then
        corpus.fail("xlate could not read the coverage of %s (see %s.coverage.log)", image, path.join(out, name))
    end
    local words, count = {}, 0
    for line in io.lines(list) do
        local address, word = line:match("^(%x+) (%x+)$")
        if address then
            words[hex(address)] = word
            count = count + 1
        end
    end
    return words, count, log:match("coverage: (%d+) of (%d+)")
end

local function record(found, image, mnemonic, text, word, owner)
    local entry = found[mnemonic]
    if not entry then
        entry = {mnemonic = mnemonic, count = 0, owners = {}, images = {}, example = text, word = word}
        found[mnemonic] = entry
    end
    entry.count = entry.count + 1
    entry.owners[owner] = (entry.owners[owner] or 0) + 1
    entry.images[path.basename(image)] = (entry.images[path.basename(image)] or 0) + 1
end

local function disassemble(image, out, words, found)
    local listing = path.join(out, path.basename(image) .. ".s")
    os.execv("xcrun", {"llvm-objdump", "-d", "--no-show-raw-insn", image}, {stdout = listing})
    local owner = "(before the first symbol)"
    local starts, listed = {}, {}
    for line in io.lines(listing) do
        local start, symbol = line:match("^(%x+) <(.+)>:$")
        if symbol then
            owner = symbol
            table.insert(starts, {address = hex(start), name = symbol})
        else
            local address, text = line:match("^%s+(%x+):%s+(.-)%s*$")
            local word = address and words[hex(address)]
            if word then
                listed[hex(address)] = true
                record(found, image, text:match("^(%S+)") or "?", text, word, owner)
            end
        end
    end
    local unlisted = 0
    for address, word in pairs(words) do
        if not listed[address] then
            unlisted = unlisted + 1
            local name = "(before the first symbol)"
            for _, start in ipairs(starts) do
                if start.address > address then
                    break
                end
                name = start.name
            end
            record(found, image, "(not in the listing)", "no instruction at this address", word, name)
        end
    end
    return unlisted
end

local function sorted_counts(counts)
    local list = {}
    for name, count in pairs(counts) do
        table.insert(list, {name = name, count = count})
    end
    table.sort(list, function (a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.name < b.name
    end)
    return list
end

function main(out, ...)
    local images = {...}
    if not out or #images == 0 then
        raise("usage: ./xmakew l -P . recompiler/tools/coverage.lua <output folder> <arm64 image>...")
    end
    local corpus = import("corpus", {rootdir = os.scriptdir(), anonymous = true})
    local e
    e, out = corpus.setup("coverage", out)
    local found, total, missing, lost = {}, 0, 0, 0
    local lines = {}
    for _, image in ipairs(images) do
        local words, count, failed, instructions = unlifted(corpus, e, image, out)
        local unlisted = disassemble(image, out, words, found)
        total = total + tonumber(instructions)
        missing = missing + count
        lost = lost + unlisted
        table.insert(lines, string.format("%-34s %8s of %8s instructions not lifted (%d not in the listing)", path.basename(image), failed, instructions, unlisted))
    end
    table.insert(lines, string.format("%-34s %8d of %8d instructions not lifted (%d not found in the listings)", "all", missing, total, lost))
    table.insert(lines, "")
    for _, entry in ipairs(sorted_counts((function ()
        local counts = {}
        for mnemonic, entry in pairs(found) do
            counts[mnemonic] = entry.count
        end
        return counts
    end)())) do
        local item = found[entry.name]
        table.insert(lines, string.format("%6d  %-14s e.g. %s  (%s)", item.count, item.mnemonic, item.example, item.word))
        local images_line = {}
        for _, image in ipairs(sorted_counts(item.images)) do
            table.insert(images_line, string.format("%s %d", image.name, image.count))
        end
        table.insert(lines, "        in " .. table.concat(images_line, ", "))
        local shown = 0
        for _, owner in ipairs(sorted_counts(item.owners)) do
            shown = shown + 1
            if shown > OWNERS_SHOWN then
                table.insert(lines, string.format("        ... and %d more functions", #sorted_counts(item.owners) - OWNERS_SHOWN))
                break
            end
            table.insert(lines, string.format("        %5d  %s", owner.count, owner.name))
        end
    end
    local report = path.join(out, "coverage-report.txt")
    io.writefile(report, table.concat(lines, "\n") .. "\n")
    print("%s", table.concat(lines, "\n"))
    print("report: %s", report)
end
