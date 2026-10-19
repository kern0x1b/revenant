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

    local r = scan_one(red, "red")
    check(has_hit(r, "run", red .. ":3"), "red: expected a run hit at line 3, got " .. table.concat(r.hits, " | "))
    check(has_hit(r, "words8", red .. ":3-3"), "red: expected a words8 hit at line 3, got " .. table.concat(r.hits, " | "))

    local c = scan_one(path.join(fixture, "red-case", "Source.m"), "red-case")
    check(has_hit(c, "run", path.join(fixture, "red-case", "Source.m") .. ":3"),
        "red-case: a case-changed copy must be a run hit (case folding), got " .. table.concat(c.hits, " | "))

    local h = scan_one(path.join(fixture, "heading19", "Source.m"), "heading19")
    check(has_hit(h, "run", path.join(fixture, "heading19", "Source.m") .. ":3"),
        "heading19: a 19-character heading must be a run hit (floor 19), got " .. table.concat(h.hits, " | "))

    local q = scan_one(path.join(fixture, "quoted", "Source.m"), "quoted")
    local quoted = path.join(fixture, "quoted", "Source.m")
    check(not has_hit(q, "run", quoted .. ":3"), "quoted: the longer sentence is not a run copy")
    check(has_hit(q, "words8", quoted .. ":3-3"), "quoted: a quotation inside a longer sentence must be a words8 hit, got "
        .. table.concat(q.hits, " | "))

    local only = path.join(fixture, "heading19-only", "Source.m")
    local o = scan_one(only, "heading19-only")
    check(#o.empty > 0, "heading19-only: the words8 mode should compare nothing in this fixture")
    check(has_hit(o, "run", only .. ":1"), "heading19-only: expected a run hit at line 1, got " .. table.concat(o.hits, " | "))
    check(tool.status(o) == 1, "heading19-only: a hit must exit 1 even though a mode compared nothing, got " .. tool.status(o))

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
