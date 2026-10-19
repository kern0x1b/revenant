-- ours-check.lua: the controls the brace counter and the walk in ours.lua have to pass.
--
--     xmake l ours-check.lua
--
-- 1. An `Anchor.Source` extension - TextModifiers.swift:168 - must produce `bounds` and `rect`, which a walk at the
--    wrong depth attributes to nothing.
-- 2. A brace inside a string, a raw string, a line comment and a block comment must not move the depth; a real brace
--    must.

local ours = import("ours", {rootdir = os.scriptdir(), anonymous = true})
local braces = import("lib.braces", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local checks = 0
local failed = 0

local function check(what, got, want)
    checks = checks + 1
    if got ~= want then
        failed = failed + 1
    end
    print(string.format("%s %s: %s", got == want and "ok  " or "FAIL", what, tostring(got)))
end

-- control 2, the tokenizer itself
check("a string carrying a brace", (braces.braces('    let s = "a { b"', false, false, 0)), 0)
check("a raw string carrying a brace", (braces.braces('    let s = #"a { b"#', false, false, 0)), 0)
check("a brace in a line comment", (braces.braces('    // a { b', false, false, 0)), 0)
check("a brace in a block comment", (braces.braces('    /* a { b */', false, false, 0)), 0)
check("a real brace", (braces.braces('    struct X {', false, false, 0)), 1)

-- control 1, the walk itself: TextModifiers.swift:168 declares bounds and rect on Anchor.Source
local out = ours.collect(path.join(os.scriptdir(), "..", ".."))

-- the owner is the whole extended name: `Anchor.Source`, not `Source` and not `Anchor`
local function owned_by(owner, kind, name)
    for _, row in ipairs(out) do
        if row.owner == owner and row.kind == kind and row.name == name then
            return true
        end
    end
    return false
end

local function ends_with(s, suffix)
    return suffix == "" or string.sub(s, -#suffix) == suffix
end

local source_bounds = owned_by("Anchor.Source", "var", "bounds")
local source_rect = owned_by("Anchor.Source", "func", "rect")
local stray = {}
for _, row in ipairs(out) do
    if (row.name == "bounds" or row.name == "rect") and row.owner ~= "Anchor.Source" and ends_with(row.owner, "Source") then
        stray[#stray + 1] = row.owner
    end
end
check("Anchor.Source has bounds (TextModifiers.swift:168)", source_bounds, true)
check("Anchor.Source has rect (TextModifiers.swift:168)", source_rect, true)
check("no other owner claims them", #stray, 0)

io.stderr:write(string.format("# %d of %d controls passed\n", checks - failed, checks))
os.exit(failed > 0 and 1 or 0)
