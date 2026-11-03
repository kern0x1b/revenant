package("tree-sitter-bash")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/tree-sitter-bash")
    set_description("tree-sitter-bash 0.23.3, a tree-sitter grammar the code highlighter of react-native-enriched-markdown vendors: its parser, scanner, shared headers and highlights.scm, from its npm tarball")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/tree-sitter-bash/-/tree-sitter-bash-0.23.3.tgz")
    add_versions("0.23.3", "10f4d67f56e07bc6cc34c49afb34e232269c1e0a19933880dfdb5dd738a8fc7d")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    local GRAMMARS = {{id = "bash", scanner = true}}

    on_install(function (package)
        local function replace_plain(text, from, to)
            local pieces, start = {}, 1
            while true do
                local i, j = text:find(from, start, true)
                if not i then break end
                table.insert(pieces, text:sub(start, i - 1))
                table.insert(pieces, to)
                start = j + 1
            end
            table.insert(pieces, text:sub(start))
            return table.concat(pieces)
        end
        for _, grammar in ipairs(GRAMMARS) do
            local base = grammar.subPath or "."
            local src = path.join(base, "src")
            local out = package:installdir("grammars", grammar.id)
            assert(os.isfile(path.join(src, "parser.c")), grammar.id .. ": parser.c is missing under " .. src)
            if grammar.scanner then
                assert(os.isfile(path.join(src, "scanner.c")), grammar.id .. ": scanner.c is missing under " .. src)
            end
            local highlights = path.join(base, "queries", "highlights.scm")
            if not os.isfile(highlights) then
                highlights = path.join("queries", "highlights.scm")
            end
            assert(os.isfile(highlights), grammar.id .. ": queries/highlights.scm is missing")
            os.mkdir(out)
            for _, pattern in ipairs({"*.c", "*.h"}) do
                for _, file in ipairs(os.files(path.join(src, pattern))) do
                    os.cp(file, out)
                end
            end
            if os.isdir(path.join(src, "tree_sitter")) then
                os.mkdir(path.join(out, "tree_sitter"))
                for _, file in ipairs(os.files(path.join(src, "tree_sitter", "*"))) do
                    os.cp(file, path.join(out, "tree_sitter"))
                end
            end
            local text = io.readfile(highlights)
            if grammar.inherits then
                text = "; inherits: " .. table.concat(grammar.inherits, ",") .. "\n" .. text
            end
            io.writefile(path.join(out, "highlights.scm"), text)
            if os.isfile("LICENSE") then
                os.cp("LICENSE", path.join(out, "LICENSE"))
            end
            for _, rel in ipairs(grammar.sharedSrc or {}) do
                local from = path.join(src, rel)
                assert(os.isfile(from), grammar.id .. ": " .. rel .. " is missing under " .. src)
                local name = path.filename(rel)
                os.cp(from, path.join(out, name))
                for _, pattern in ipairs({"*.c", "*.h"}) do
                    for _, file in ipairs(os.files(path.join(out, pattern))) do
                        local content = io.readfile(file)
                        local rewritten = replace_plain(content, '"' .. rel .. '"', '"' .. name .. '"')
                        if rewritten ~= content then
                            io.writefile(file, rewritten)
                        end
                    end
                end
            end
        end
    end)

    on_test(function (package)
        for _, grammar in ipairs(GRAMMARS) do
            local out = package:installdir("grammars", grammar.id)
            assert(os.isfile(path.join(out, "parser.c")), grammar.id .. ": parser.c is not installed")
            assert(os.isfile(path.join(out, "highlights.scm")), grammar.id .. ": highlights.scm is not installed")
        end
    end)
