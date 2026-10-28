local limits = import("air2es_limits", {rootdir = path.join(os.scriptdir(), "..", "tools")})

local function shader(header, body)
    return "#version 100\nvoid main() {\n    for (" .. header .. ") {\n" .. body .. "    }\n}\n"
end

local CASES = {
    {name = "a constant loop", source = shader("int t0 = 0; t0 < 61; t0++", "        t1 = t0;\n")},
    {name = "a parenthesized negative start with +=", source = shader("int t0 = (-3); t0 <= 2; t0 += 1", "        t1 = t0;\n")},
    {name = "a counting-down loop", source = shader("int t0 = 61; t0 > 0; t0--", "        t1 = t0;\n")},
    {name = "a float index with a constant step", source = shader("float f = 0.0; f < 1.0; f += 0.25", "        t1 = f;\n")},
    {name = "a comparison of the index in the body", source = shader("int t0 = 0; t0 < 4; t0++", "        if (t0 == 3) { t1 = 1.0; }\n")},
    {name = "a non-constant bound", expect = "a for loop whose bound is not a constant-expression",
     source = shader("int t0 = 0; t0 < n; t0++", "        t1 = t0;\n")},
    {name = "a non-constant start", expect = "starts at something other than a constant-expression",
     source = shader("int t0 = n; t0 < 4; t0++", "        t1 = t0;\n")},
    {name = "an update that is not ++, -- or += a constant", expect = "update is not ++, --, += or -= a constant",
     source = shader("int t0 = 1; t0 < 64; t0 *= 2", "        t1 = t0;\n")},
    {name = "a body that assigns the index", expect = "assigns to its index t0",
     source = shader("int t0 = 0; t0 < 4; t0++", "        t0 = 3;\n")},
    {name = "a body that adds to the index", expect = "assigns to its index t0",
     source = shader("int t0 = 0; t0 < 4; t0++", "        t0 += 1;\n")},
    {name = "a body that increments the index", expect = "assigns to its index t0",
     source = shader("int t0 = 0; t0 < 4; t0++", "        t0++;\n")},
    {name = "a nested loop that declares the index again", expect = "declares its index t0 again",
     source = shader("int t0 = 0; t0 < 4; t0++", "        for (int t0 = 0; t0 < 2; t0++) {\n            t1 = 1.0;\n        }\n")},
    {name = "a while loop", expect = "a while or do-while loop",
     source = "#version 100\nvoid main() {\n    while (t1 < 4.0) {\n        t1 += 1.0;\n    }\n}\n"},
    {name = "an array index that is not constant", expect = "an array index that is not a constant-index-expression",
     source = "#version 100\nvoid main() {\n    t1 = a[i];\n}\n"},
    {name = "a constant array index", source = "#version 100\nvoid main() {\n    t1 = a[2];\n}\n"},
}

function main()
    for _, case in ipairs(CASES) do
        local reason = limits.check(case.source)
        if case.expect then
            assert(reason and reason:find(case.expect, 1, true),
                   case.name .. ": expected a refusal containing '" .. case.expect .. "', got " .. tostring(reason))
        else
            assert(reason == nil, case.name .. ": expected to pass, refused with " .. tostring(reason))
        end
    end
    print("air2es limits: all %d cases passed", #CASES)
end
