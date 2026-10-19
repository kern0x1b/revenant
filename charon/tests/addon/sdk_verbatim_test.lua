-- sdk_verbatim_test.lua: tools/sdk-verbatim.lua reports a comment line that occurs verbatim in an SDK header
-- (red), reports nothing for a source written in its own words (green), and FAILS rather than passing when
-- it has nothing to compare: an unreadable SDK root, or no file at all.
--
-- The fixture is sdk-verbatim/: a fake SDK header under sdk/, a source whose line 3 is a line of that
-- header (red/), and the same source with its comment in other words (green/). Round 3 adds three
-- sources: the same line in capitals (red-case/, a run hit under case folding), the header's 19-character
-- heading (heading19/, a run hit under the 19-character floor), and a sentence of the header quoted inside a
-- longer sentence (quoted/, a words8 hit only). Round 4 adds heading19-only/, the same heading as the file's
-- only comment: the words8 mode compares nothing there, and the hit must still exit 1. Round 5 adds words6/,
-- a 7-word run shared with the fixture header (its 8th word differs): clean at the default, a words6 hit at --words 6.
-- None of it is Apple's text.
function failures(opt)
    local found = {}
    local tool = import("sdk-verbatim", {rootdir = path.join(opt.modules, "..", "tools"), anonymous = true})
    local fixture = path.join(opt.modules, "..", "tests", "addon", "sdk-verbatim")
    local sdk = path.join(fixture, "sdk")
    local red = path.join(fixture, "red", "Source.m")
    local green = path.join(fixture, "green", "Source.m")

    local function check(ok, what)
        if not ok then table.insert(found, what) end
    end

    -- A hit is "mode file:line sdk-file:line"; the check names the mode and our line it must have.
    local function has_hit(report, mode, ours)
        for _, hit in ipairs(report.hits) do
            if hit:find("^" .. mode .. " " .. ours:gsub("%p", "%%%0") .. " ") then return true end
        end
        return false
    end

    local function scan_one(file, what)
        local r = tool.scan(sdk, {file})
        check(#r.errors == 0, what .. ": the scan reported " .. table.concat(r.errors, "; "))
        return r
    end

    -- The copy of the SDK's line, and the same line in capitals: run mode, and words8 for the same line.
    local r = scan_one(red, "red")
    check(has_hit(r, "run", red .. ":3"), "red: expected a run hit at line 3, got " .. table.concat(r.hits, " | "))
    check(has_hit(r, "words8", red .. ":3-3"), "red: expected a words8 hit at line 3, got " .. table.concat(r.hits, " | "))

    local c = scan_one(path.join(fixture, "red-case", "Source.m"), "red-case")
    check(has_hit(c, "run", path.join(fixture, "red-case", "Source.m") .. ":3"),
        "red-case: a case-changed copy must be a run hit (case folding), got " .. table.concat(c.hits, " | "))

    -- A 19-character heading, three words: compared only with the 19-character floor.
    local h = scan_one(path.join(fixture, "heading19", "Source.m"), "heading19")
    check(has_hit(h, "run", path.join(fixture, "heading19", "Source.m") .. ":3"),
        "heading19: a 19-character heading must be a run hit (floor 19), got " .. table.concat(h.hits, " | "))

    -- A sentence of the SDK quoted inside a longer sentence: no run hit, a words8 hit.
    local q = scan_one(path.join(fixture, "quoted", "Source.m"), "quoted")
    local quoted = path.join(fixture, "quoted", "Source.m")
    check(not has_hit(q, "run", quoted .. ":3"), "quoted: the longer sentence is not a run copy")
    check(has_hit(q, "words8", quoted .. ":3-3"), "quoted: a quotation inside a longer sentence must be a words8 hit, got "
        .. table.concat(q.hits, " | "))

    -- Round 4 (review 8): a file whose only comment is the 19-character heading. The words8 mode compares
    -- nothing here, and the hit must still exit 1, not 2.
    local only = path.join(fixture, "heading19-only", "Source.m")
    local o = scan_one(only, "heading19-only")
    check(#o.empty > 0, "heading19-only: the words8 mode should compare nothing in this fixture")
    check(has_hit(o, "run", only .. ":1"), "heading19-only: expected a run hit at line 1, got " .. table.concat(o.hits, " | "))
    check(tool.status(o) == 1, "heading19-only: a hit must exit 1 even though a mode compared nothing, got " .. tool.status(o))

    -- Round 5 (ruling 2): a 7-word run shared with the SDK is no words8 hit, so the default scan is clean; with
    -- --words 6 (window = 6) the same line is a words6 hit and the scan exits 1. The tree-wide count stays at 8.
    local w6 = path.join(fixture, "words6", "Source.m")
    local d = scan_one(w6, "words6 default")
    check(#d.hits == 0, "words6 default: a 7-word run must not be a words8 hit, got " .. table.concat(d.hits, " | "))
    check(tool.status(d) == 0, "words6 default: a clean scan must exit 0, got " .. tool.status(d))
    local s = tool.scan(sdk, {w6}, 6)
    check(has_hit(s, "words6", w6 .. ":3-3"), "words6 at --words 6: expected a words6 hit at line 3, got " .. table.concat(s.hits, " | "))
    check(not has_hit(s, "words8", w6 .. ":3-3"), "words6 at --words 6: the hit must carry the words6 label")
    check(tool.status(s) == 1, "words6 at --words 6: a hit must exit 1, got " .. tool.status(s))

    local g = scan_one(green, "green")
    check(#g.hits == 0, "green: expected no hit, got " .. table.concat(g.hits, " | "))
    check(tool.status(g) == 0, "green: a clean scan must exit 0, got " .. tool.status(g))

    local bad_root = tool.scan(path.join(fixture, "no-such-sdk"), {green})
    check(#bad_root.errors > 0 and tool.status(bad_root) == 2, "an unreadable SDK root was not reported as a failure")

    local none = tool.scan(sdk, {})
    check(#none.empty > 0 and tool.status(none) == 2, "a scan that compared no comment line was not reported as a failure")

    return found
end
