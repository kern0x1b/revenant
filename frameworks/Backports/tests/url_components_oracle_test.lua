local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "Foundation")
local DUMP = path.join(TESTS, "url_components", "dump.m")
local CORPUS = path.join(TESTS, "url_components", "corpus.txt")

-- The rows the backport prints where it differs from macOS's NSURLComponents, keyed by the URL. The backport's grammar
-- rejects what macOS percent-encodes (a space, a brace, a quote, a second '#', a lone '%'), drops the colon of an empty
-- port, and does not IDNA-encode a non-ASCII host. Each entry is the row the backport prints today, so a change to the
-- grammar fails this test until the entry is updated, and a fixed case fails until its entry is removed.
local KNOWN = {
    ["https://example.com:/"] = "https\t(nil)\t(nil)\texample.com\t(nil)\t/\t(nil)\t(nil)\thttps://example.com/",
    ["https://example.com/#a#b"] = "nil",
    ["https://example.com/a{b}c"] = "nil",
    ["https://example.com/a|b"] = "nil",
    ["https://example.com/a\"b<c>"] = "nil",
    ["https://example.com/a\\b"] = "nil",
    ["https://example.com/a^b`c"] = "nil",
    ["https://example.com/a%b"] = "nil",
    ["https://example.com/a b"] = "nil",
    ["https://example.com/a?x=y z"] = "nil",
    ["https://example.com/a?x=[y]"] = "nil",
    ["https://example.com/a#f g"] = "nil",
    ["https://example.com/a#f\"g"] = "nil",
    ["https://例子.测试/路径"] = "nil",
    ["https://example.com/路径?q=é"] = "nil",
    ["https://user:pa:ss@example.com/"] = "nil",
    ["https://us er@example.com/"] = "nil",
    [":x"] = "nil",
}

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function macos_sdk()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
end

local function build(work, name, sources, extra)
    local output = path.join(work, name)
    local flags = {"-O1", "-fobjc-arc", "-w", "-isysroot", macos_sdk(), "-framework", "Foundation"}
    os.vrunv(clang(), table.join(flags, extra or {}, sources, {"-o", output}))
    return output
end

local function lines_of(text)
    local lines = {}
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function corpus_of(file)
    local urls = {}
    for _, line in ipairs(lines_of(io.readfile(file))) do
        if line ~= "" then
            table.insert(urls, line == "<empty>" and "" or line)
        end
    end
    return urls
end

-- Each dump row starts with its index and a tab; the rest of the row is what the comparison reads.
local function rows_of(output, count)
    local rows = {}
    for _, line in ipairs(lines_of(output)) do
        if line ~= "" then
            local index, row = string.match(line, "^(%d+)\t(.*)$")
            assert(index, "a dump row without its index: " .. line)
            rows[tonumber(index) + 1] = row
        end
    end
    assert(#rows == count, "the dump printed " .. #rows .. " rows for " .. count .. " URLs")
    return rows
end

local function dump(program, file)
    return rows_of(os.iorunv(program, {file}), #corpus_of(file))
end

-- Returns the URLs whose rows differ from the oracle and are not known divergences, and how many known ones it saw.
local function compare(oracle, backport, urls)
    local unexpected, known = {}, 0
    for index, url in ipairs(urls) do
        local expected = KNOWN[url]
        if oracle[index] == backport[index] then
            -- agrees with macOS
        elseif expected ~= nil and backport[index] == expected then
            known = known + 1
        else
            table.insert(unexpected, string.format("%s\n    macOS:    %s\n    backport: %s", url, oracle[index], backport[index]))
        end
    end
    return unexpected, known
end

function main()
    local work = path.join(os.tmpdir(), "url-components-oracle")
    os.tryrm(work)
    os.mkdir(work)

    local oracle_program = build(work, "oracle_url", {DUMP})
    local backport_sources = {DUMP, path.join(SRC, "NSURLComponents.m"), path.join(SRC, "RevenantURLGrammar.m")}
    for _, file in ipairs(os.files(path.join(SRC, "NSURLComponents+*.m"))) do
        table.insert(backport_sources, file)
    end
    local backport_program = build(work, "backport_url", backport_sources, {"-DREVENANT_HOST_BUILD", "-I" .. SRC})

    local urls = corpus_of(CORPUS)
    local oracle = dump(oracle_program, CORPUS)
    local backport = dump(backport_program, CORPUS)
    local unexpected, known = compare(oracle, backport, urls)
    assert(#unexpected == 0, "the backport's NSURLComponents disagrees with macOS on URLs it is not known to differ on:\n  "
        .. table.concat(unexpected, "\n  "))

    -- Negative control: the same URLs with a path appended must not compare equal to macOS's rows for the originals.
    local mutated = path.join(work, "mutated.txt")
    local changed = {}
    for _, url in ipairs(urls) do
        table.insert(changed, url .. "/neg")
    end
    io.writefile(mutated, table.concat(changed, "\n") .. "\n")
    local damaged = dump(backport_program, mutated)
    local detected = compare(oracle, damaged, urls)
    assert(#detected > 0, "the negative control passed: every changed URL compared equal to macOS, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("URL_COMPONENTS_ORACLE_TEST passed (%d URLs agree with macOS, %d known divergences, negative control detected %d)",
        #urls - known, known, #detected))
end
