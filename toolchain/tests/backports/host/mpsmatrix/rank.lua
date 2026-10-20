local ulp = import("ulp", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local function family_of(case_name)
    local head, tail = case_name:match("^(.*) ([^ ]*)$")
    if head and tail:match("^%d+$") then
        return head
    end
    return case_name
end

local function strip(text)
    return (text:match("^%s*(.-)%s*$"))
end

local function read_owed(file)
    local owed = {}
    for line in ulp.lines_of(file) do
        local body = strip(line:match("^([^#]*)"))
        local name, reason = body:match("^([^\t]*)\t(.*)$")
        if name then
            owed[strip(name)] = strip(reason)
        end
    end
    return owed
end

local function grade_case(system, port, fam, bound)
    local sname, slen, shex = system.name, system.length, system.hex
    local pname, plen, phex = port.name, port.length, port.hex
    if sname ~= pname or slen ~= plen then
        return "non-ulp", nil, nil, true
    end
    if shex == phex then
        return "identical", 0, 0.0, false
    end
    if slen % 4 ~= 0 or #shex ~= slen * 2 then
        fam.ulp = math.max(fam.ulp, 1 << 30)
        return "non-ulp", nil, nil, false
    end
    local worst_ulp, worst_rel = 0, 0.0
    for k = 0, slen - 1, 4 do
        local sbits, pbits = ulp.word(shex, k), ulp.word(phex, k)
        local d = math.abs(ulp.ordered(sbits) - ulp.ordered(pbits))
        if d > worst_ulp then
            worst_ulp = d
        end
        local fa, fb = ulp.float(shex, k), ulp.float(phex, k)
        if fa ~= fb then
            if fa == 0.0 or fb == 0.0 or fa ~= fa or fb ~= fb then
                fam.zero = fam.zero + 1
            else
                local r = math.abs(fa - fb) / math.max(math.abs(fa), math.abs(fb))
                if r > worst_rel then
                    worst_rel = r
                end
            end
        end
    end
    fam.ulp = math.max(fam.ulp, worst_ulp)
    if worst_rel > 0 then
        fam.rel = math.max(fam.rel, worst_rel)
    end
    local grade = worst_ulp <= bound and "ulp" or "non-ulp"
    return grade, worst_ulp, worst_rel, false
end

local function fmt_ulp(value)
    if value == nil then
        return "-"
    end
    return string.format("%d", value)
end

function grade(system_path, port_path, bound, owed_path)
    local system = ulp.cases(system_path)
    local port = ulp.cases(port_path)
    bound = tonumber(bound)
    local owed = owed_path and read_owed(owed_path) or {}

    local n = math.min(#system, #port)
    local counts = {identical = 0, ulp = 0, ["non-ulp"] = 0}
    local unexplained = {}
    local per_family = {}
    local order = {}

    print(string.format("%-42s %-9s %11s %11s  %s", "case", "class", "max ulp", "max rel", "verdict"))
    for i = 1, n do
        local s, p = system[i], port[i]
        local fname = family_of(s.name)
        if not per_family[fname] then
            per_family[fname] = {cases = 0, same = 0, ulp = 0, rel = 0.0, zero = 0}
            table.insert(order, fname)
        end
        local fam = per_family[fname]
        fam.cases = fam.cases + 1
        local grade_name, worst_ulp, worst_rel, mispaired = grade_case(s, p, fam, bound)
        if mispaired then
            print(string.format("%-42s %-9s %11s %11s  %s", s.name, "MISPAIRED", "-", "-",
                                "the two runs reached different cases"))
            table.insert(unexplained, s.name .. " (mismatched)")
            counts["non-ulp"] = counts["non-ulp"] + 1
        else
            if grade_name == "identical" then
                counts.identical = counts.identical + 1
                fam.same = fam.same + 1
            else
                counts[grade_name] = counts[grade_name] + 1
                local verdict = "ok"
                if grade_name == "non-ulp" then
                    if owed[s.name] then
                        verdict = "OWED: " .. owed[s.name]
                    else
                        verdict = "FAIL: not in the owed file"
                        table.insert(unexplained, s.name)
                    end
                end
                print(string.format("%-42s %-9s %11s %11s  %s", s.name, grade_name,
                                    fmt_ulp(worst_ulp), worst_rel and string.format("%.3g", worst_rel) or "-",
                                    verdict))
            end
        end
    end

    print("")
    print(string.format("%-38s %6s %7s %11s %11s %8s", "family", "cases", "differ", "max ulp", "max rel", "0-vs-nz"))
    table.sort(order)
    for _, name in ipairs(order) do
        local e = per_family[name]
        print(string.format("%-38s %6d %7d %11d %11.3g %8d", name, e.cases, e.cases - e.same, e.ulp, e.rel, e.zero))
    end
    print("")
    print(string.format("compared: %d cases over the first %d of each run", n, n))
    print(string.format("identical: %d   ulp (bound %d): %d   non-ulp: %d", counts.identical, bound, counts.ulp, counts["non-ulp"]))
    if #unexplained > 0 then
        print(string.format("non-ulp cases with no reason in the owed file: %d", #unexplained))
        for _, u in ipairs(unexplained) do
            print("   " .. u)
        end
        return 1
    end
    print("every non-ulp case is listed as owed, with its reason")
    return 0
end

function main(system_path, port_path, bound, owed_path)
    if not bound then
        io.stderr:write("usage: rank.lua <system-prefix> <port-prefix> <ulp-bound> [owed.tsv]\n")
        os.exit(2)
    end
    os.exit(grade(system_path, port_path, bound, owed_path))
end
