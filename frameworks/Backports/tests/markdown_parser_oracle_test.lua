local TESTS = path.absolute(os.scriptdir())
local PROBE = path.join(TESTS, "device_probe")
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local RENAMES = {
    "-DNSAttributedStringMarkdownParsingOptions=RVMarkdownOptions",
    "-DinitWithMarkdown=rvInitWithMarkdown",
    "-DinitWithMarkdownString=rvInitWithMarkdownString",
    "-DinitWithContentsOfMarkdownFileAtURL=rvInitWithContentsOfMarkdownFileAtURL",
}

local FUZZ_SEEDS = {101, 102, 103}
local FUZZ_CASES = 1500

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function compile(sdk, source, object, renamed)
    local args = {"-isysroot", sdk, "-fobjc-arc", "-O1", "-Wno-unguarded-availability-new", "-Wno-deprecated-declarations", "-I", path.join(PROBE, "markdown_host")}
    if renamed then
        args = table.join(args, RENAMES)
    end
    os.vrunv(clang(), table.join(args, {"-c", source, "-o", object}))
end

local function link(sdk, objects, program)
    os.vrunv(clang(), table.join({"-isysroot", sdk, "-fobjc-arc"}, objects, {"-framework", "Foundation", "-o", program}))
end

local function comment_corpus(file)
    local alphabet = {"-", ">", "a", "<", "!"}
    local lines = {}
    local function walk(tail, depth)
        table.insert(lines, "<!--" .. tail)
        if depth < 7 then
            for _, letter in ipairs(alphabet) do
                walk(tail .. letter, depth + 1)
            end
        end
    end
    walk("", 0)
    io.writefile(file, table.concat(lines, "\n") .. "\n")
    return #lines
end

local function assert_same(program, corpus, what)
    local output = os.iorunv(program, {corpus})
    local same, total = output:match("same (%d+) of (%d+)")
    assert(same and tonumber(total) > 0 and same == total, what .. " differs from the host's markdown:\n" .. output:sub(1, 8000))
    return tonumber(total)
end

function main()
    local work = workspace.fresh("markdown-parser-oracle")
    local sdk = os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
    local shim = path.join(work, "shim.o")
    compile(sdk, path.join(PROBE, "markdown_shim.m"), shim, true)
    local compare_object = path.join(work, "compare.o")
    compile(sdk, path.join(PROBE, "markdown_compare_main.m"), compare_object, false)
    local compare = path.join(work, "compare")
    link(sdk, {shim, compare_object}, compare)
    local fuzz_object = path.join(work, "fuzz.o")
    compile(sdk, path.join(PROBE, "markdown_fuzz_main.m"), fuzz_object, false)
    local fuzz = path.join(work, "fuzz")
    link(sdk, {shim, fuzz_object}, fuzz)

    local corpus = path.join(PROBE, "markdown_corpus.txt")
    local compared = assert_same(compare, corpus, "the corpus")
    print(string.format("MARKDOWN_PARSER corpus %d of %d identical", compared, compared))

    local urls = assert_same(compare, path.join(PROBE, "markdown_url_corpus.txt"), "the URL corpus")
    print(string.format("MARKDOWN_PARSER URL corpus %d of %d identical", urls, urls))

    local comments = path.join(work, "comments.txt")
    local count = comment_corpus(comments)
    local comment_total = assert_same(compare, comments, "the exhaustive HTML comment strings")
    print(string.format("MARKDOWN_PARSER %d comment strings, %d comparisons identical", count, comment_total))

    for _, seed in ipairs(FUZZ_SEEDS) do
        local output = os.iorunv(fuzz, {corpus, tostring(seed), tostring(FUZZ_CASES), "5"})
        local failing = output:match("(%d+) failing")
        assert(failing and tonumber(failing) == 0, string.format("the fuzzer found a source the parser reads differently from the host (seed %d):\n%s", seed, output:sub(1, 8000)))
    end
    print(string.format("MARKDOWN_PARSER fuzz %d seeds x %d sources identical", #FUZZ_SEEDS, FUZZ_CASES))
    os.tryrm(work)
    print("MARKDOWN_PARSER_ORACLE_TEST passed")
end
