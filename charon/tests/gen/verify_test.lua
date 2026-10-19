local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local known = import("gen.known", {rootdir = TOOLS, anonymous = true})
    local files = import("gen.files", {rootdir = TOOLS, anonymous = true})

    local rows, malformed = known.parse("headers A x, y\t3\tthe cause\n# a comment\n\nheaders B z\t1\tanother cause\n")
    check(malformed == nil, "a key, a count and a cause, a comment and a blank line parse")
    check(rows["headers A x, y"] ~= nil and rows["headers A x, y"].count == 3, "a key may hold spaces and commas; its count is a number")
    check(rows["headers A x, y"].cause == "the cause", "the cause is the text after the count")
    check(rows["headers B z"].count == 1, "every row is kept")

    local _, bad_count = known.parse("headers A\tnot a number\tcause\n")
    check(bad_count == 1, "a line whose count is not a number is named, by its line number")
    local _, bad_cause = known.parse("headers A\t1\n")
    check(bad_cause == 1, "a line without a cause is named")
    local _, twice = known.parse("k\t1\ta\nk\t2\tb\n")
    check(twice == 2, "a key named twice is named at its second line")

    local row = {k = {count = 1, cause = "a"}}
    check(#known.problems({k = 1}, row) == 0, "a difference at its row's count is explained")
    check(#known.problems({k = 2}, row) == 1, "a difference at another count than its row's is a problem")
    check(#known.problems({k = 1}, {}) == 1, "a difference with no row is a problem")
    check(#known.problems({}, row) == 1, "a row the run does not measure is a problem")
    check(#known.problems({}, {}) == 0, "no difference and no row is no problem")
    local both = known.problems({j = 1, k = 2}, row)
    check(#both == 2 and string.find(both[1], "^unexplained: j") ~= nil and string.find(both[2], "^unexplained: k") ~= nil,
          "the problems come in key order, one line each")

    local text = files.read_text(path.join(TOOLS, "gen", "verify-known.tsv"))
    check(text ~= nil, "the committed table is readable")
    local _, committed_bad = known.parse(text or "")
    check(committed_bad == nil, "the committed table parses (line " .. tostring(committed_bad) .. ")")

    if failures > 0 then
        print(string.format("verify test: %d of %d checks failed", failures, count))
        os.exit(1)
    end
    print(string.format("verify test: OK (%d checks)", count))
end
