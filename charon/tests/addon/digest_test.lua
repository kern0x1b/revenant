-- What a recipe's digest ignores (comments and the layout of code) and what it does not (code, and everything in a string).
function failures(opt)
    local digest = import("digest", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local base = [[
local flags = {"-O", "--flag"}
add_configs("x", {default = "a -- b"})
local script = [=[
line -- not a comment
]=]
if #flags > 1 then
    print(flags)
end
]]
    local same = {
        ["a line comment"] = "-- new words\n" .. base,
        ["a trailing comment"] = base:gsub('print%(flags%)', 'print(flags) -- says hello'),
        ["a block comment"] = "--[[ one\ntwo ]]\n" .. base,
        ["a leveled block comment"] = "--[==[ one ]] two ]==]\n" .. base,
        ["blank lines and indentation of code"] = base:gsub("\n    print", "\n\n\n        print"),
        ["trailing blanks"] = base:gsub('"%-%-flag"}\n', '"--flag"}   \n')
    }
    local reference = digest.stripped(base)
    for name, changed in pairs(same) do
        if digest.stripped(changed) ~= reference then
            table.insert(found, name .. " must not change the digest")
        end
    end
    local different = {
        ["a changed flag"] = base:gsub('"%-O"', '"-Os"'),
        ["a comment marker inside a string is a string"] = base:gsub('a %-%- b', 'a -- c'),
        ["a changed long string"] = base:gsub("not a comment", "no comment"),
        ["a blank line inside a long string"] = base:gsub("line %-%-", "\nline --"),
        ["a comment made code"] = base:gsub("if #flags", "-- if #flags\nif #flags"):gsub("%-%- if", "if")
    }
    for name, changed in pairs(different) do
        if digest.stripped(changed) == reference then
            table.insert(found, name .. " must change the digest")
        end
    end
    -- the strings survive whole
    if not digest.stripped(base):find('"a -- b"', 1, true) or not digest.stripped(base):find("line -- not a comment", 1, true) then
        table.insert(found, "a string keeps its comment marker")
    end
    -- The digests a recipe takes are the ones its sources give now: a source changed without them written again is caught
    -- here, not by a build that quietly kept its old hash.
    local root = path.join(opt.modules, "..")
    for _, recipe in ipairs(digest.recipes()) do
        local written = io.readfile(path.join(root, recipe.folder, "digest.lua"))
        local expected = digest.digest_file(recipe, digest.sources(root, recipe.inputs))
        if written ~= expected then
            table.insert(found, string.format("%s/digest.lua is not what the sources give; run xmake l tools/recipe-digests.lua", recipe.folder))
        end
    end
    return found
end
