local workspace = import("@addon.revenant.workspace", {anonymous = true})
local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "Foundation")
local DUMP = path.join(TESTS, "url_components", "dump.m")
local CORPUS = path.join(TESTS, "url_components", "corpus.txt")
local FUZZ_COUNT = 20000
local FUZZ_SEEDS = {20261109, 424242, 9001}

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

local function section(row, urls)
    local components, rest = string.match(row, "^(.-)\turl:(.*)$")
    return urls and ("url:" .. rest) or components
end

local function compare(oracle, backport, urls, urls_only)
    local differing = {}
    for index, url in ipairs(urls) do
        local expected, actual = section(oracle[index], urls_only), section(backport[index], urls_only)
        if expected ~= actual then
            table.insert(differing, string.format("%s\n    macOS:    %s\n    backport: %s", url, expected, actual))
        end
    end
    return differing
end

local function explain(title, differing)
    if #differing == 0 then
        return nil
    end
    local shown = {}
    for index = 1, math.min(#differing, 12) do
        table.insert(shown, differing[index])
    end
    return string.format("%s disagrees with macOS on %d URLs, first %d:\n  %s", title, #differing, #shown, table.concat(shown, "\n  "))
end

function main()
    local work = workspace.fresh("url-components-oracle")
    local fuzz = import("fuzz", {rootdir = path.join(TESTS, "url_components"), anonymous = true})

    local oracle_program = build(work, "oracle_url", {DUMP})
    local backport_sources = {DUMP, path.join(SRC, "NSURLComponents.m"), path.join(SRC, "RevenantURLGrammar.m"), path.join(SRC, "RevenantURLParser.m"), path.join(SRC, "NSURL+Encoding17.m")}
    for _, file in ipairs(os.files(path.join(SRC, "NSURLComponents+*.m"))) do
        table.insert(backport_sources, file)
    end
    local backport_program = build(work, "backport_url", backport_sources, {"-DREVENANT_HOST_BUILD", "-I" .. SRC})

    local urls = corpus_of(CORPUS)
    local oracle = dump(oracle_program, CORPUS)
    local backport = dump(backport_program, CORPUS)
    local corpus_components = compare(oracle, backport, urls, false)
    local corpus_urls = compare(oracle, backport, urls, true)

    local complaints = {}
    local function complain(title, differing)
        local complaint = explain(title, differing)
        if complaint then
            table.insert(complaints, complaint)
        end
    end
    complain("NSURLComponents on the corpus", corpus_components)
    complain("NSURL on the corpus", corpus_urls)
    local generated_total, generated_components, generated_urls = 0, 0, 0
    for _, seed in ipairs(FUZZ_SEEDS) do
        local fuzz_file = path.join(work, "fuzz" .. seed .. ".txt")
        io.writefile(fuzz_file, table.concat(fuzz.lines(FUZZ_COUNT, seed), "\n") .. "\n")
        local fuzz_urls = corpus_of(fuzz_file)
        local fuzz_oracle = dump(oracle_program, fuzz_file)
        local fuzz_backport = dump(backport_program, fuzz_file)
        local fuzz_components = compare(fuzz_oracle, fuzz_backport, fuzz_urls, false)
        local fuzz_nsurl = compare(fuzz_oracle, fuzz_backport, fuzz_urls, true)
        generated_total = generated_total + #fuzz_urls
        generated_components = generated_components + #fuzz_components
        generated_urls = generated_urls + #fuzz_nsurl
        complain("NSURLComponents on the generated URLs of seed " .. seed, fuzz_components)
        complain("NSURL on the generated URLs of seed " .. seed, fuzz_nsurl)
    end
    print(string.format("NSURLComponents: corpus %d of %d differ, generated %d of %d differ; NSURL: corpus %d differ, generated %d differ",
        #corpus_components, #urls, generated_components, generated_total, #corpus_urls, generated_urls))
    assert(#complaints == 0, table.concat(complaints, "\n"))

    local mutated = path.join(work, "mutated.txt")
    local changed = {}
    for _, url in ipairs(urls) do
        table.insert(changed, url .. "/neg")
    end
    io.writefile(mutated, table.concat(changed, "\n") .. "\n")
    local damaged = dump(backport_program, mutated)
    local detected = compare(oracle, damaged, urls, false)
    local detected_urls = compare(oracle, damaged, urls, true)
    assert(#detected > 0 and #detected_urls > 0, "the negative control passed: every changed URL compared equal to macOS, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("URL_COMPONENTS_ORACLE_TEST passed (%d corpus and %d generated URLs agree with macOS, negative control detected %d and %d)", #urls, generated_total, #detected, #detected_urls))
end
