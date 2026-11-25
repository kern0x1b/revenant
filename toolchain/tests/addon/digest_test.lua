import("fixtures")

local function declaring(digest, root, found)
    local folders = {["packages/l/libcxx"] = true, ["packages/b/boringssl"] = true, ["packages/s/swift-runtime"] = true}
    local copy = fixtures.scratch()
    for _, recipe in ipairs(digest.recipes()) do
        if folders[recipe.folder] then
            for _, input in ipairs(recipe.inputs) do
                for _, source in ipairs(os.files(path.join(root, input))) do
                    os.cp(source, path.join(copy, path.relative(source, root)))
                end
            end
            local written = io.readfile(path.join(copy, recipe.folder, "xmake.lua"))
            local committed = digest.recipe_digest(root, recipe)
            local bare = written:gsub("[ \t]*set_policy%(\"package%.links_dependencies\", true%)\n", ""):gsub(", images_only = true", "")
            if bare == written then
                table.insert(found, recipe.folder .. " declares nothing about its key, and this check is of what it declares")
            end
            io.writefile(path.join(copy, recipe.folder, "xmake.lua"), bare)
            if digest.recipe_digest(copy, recipe) ~= committed then
                table.insert(found, recipe.folder .. " has another digest without its declarations about the key")
            end
            io.writefile(path.join(copy, recipe.folder, "xmake.lua"), written .. "\nadd_defines(\"REVENANT_CHANGED\")\n")
            if digest.recipe_digest(copy, recipe) == committed then
                table.insert(found, recipe.folder .. " keeps its digest when a line of what it builds changes")
            end
            folders[recipe.folder] = nil
        end
    end
    for folder in pairs(folders) do
        table.insert(found, folder .. " has no recipe digest")
    end
    os.tryrm(copy)
end

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
        ["trailing blanks"] = base:gsub('"%-%-flag"}\n', '"--flag"}   \n'),
        ["the policy which only composes a key"] = "    set_policy(\"package.links_dependencies\", true)\n" .. base,
        ["the mark of a configuration which only composes a key"] = base:gsub('"a %-%- b"}', '"a -- b", images_only = true}')
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
        ["a comment made code"] = base:gsub("if #flags", "-- if #flags\nif #flags"):gsub("%-%- if", "if"),
        ["another policy"] = "set_policy(\"package.strict_compatibility\", true)\n" .. base,
        ["the mark inside a string"] = base:gsub('"a %-%- b"', '"a -- b, images_only = true"'),
        ["a longer word than the mark's value"] = base:gsub('"a %-%- b"}', '"a -- b", images_only = trueish}')
    }
    for name, changed in pairs(different) do
        if digest.stripped(changed) == reference then
            table.insert(found, name .. " must change the digest")
        end
    end
    if not digest.stripped(base):find('"a -- b"', 1, true) or not digest.stripped(base):find("line -- not a comment", 1, true) then
        table.insert(found, "a string keeps its comment marker")
    end
    local root = path.join(opt.modules, "..", "..")
    declaring(digest, path.absolute(root), found)
    for _, recipe in ipairs(digest.recipes()) do
        local written = io.readfile(path.join(root, recipe.folder, "port", "digest.lua"))
        local expected = digest.digest_file(recipe, digest.recipe_digest(root, recipe))
        if written ~= expected then
            table.insert(found, string.format("%s/digest.lua is not what the sources give; run ./xmakew l toolchain/tools/recipe_digests.lua", recipe.folder))
        end
    end
    return found
end
