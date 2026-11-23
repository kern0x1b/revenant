-- The classes an older Backports build exported and the system framework still holds. An image linked against that build
-- binds such a class by name to the Backports library (the linker takes a symbol from the first library on its command
-- line that exports it, and the Backports libraries come before the system ones), so a library that stops exporting the
-- class stops the app at launch: dyld "Symbol not found: _OBJC_CLASS_$_X, Expected in libXBackports".
--
-- Each row of reexported-classes.txt is `<library> <symbol> <framework>`. The library re-exports the symbol from the
-- framework: its export trie carries a re-export entry (ordinal and imported name), which dyld follows to the
-- framework's own class, so the old image gets that same object, never a second class.

local ROWS

local function rows()
    if ROWS == nil then
        ROWS = {}
        local file = path.join(os.scriptdir(), "reexported-classes.txt")
        for line in io.readfile(file):gmatch("[^\n]+") do
            local library, symbol, framework = line:match("^(%S+)%s+(%S+)%s+(%S+)$")
            if not library then
                raise("%s: the line %q is not `<library> <symbol> <framework>`", file, line)
            end
            ROWS[library] = ROWS[library] or {}
            table.insert(ROWS[library], {symbol = symbol, framework = framework})
        end
    end
    return ROWS
end

-- What `library` (a row of backports_libraries()) re-exports: the sorted symbols, the file text that lists them for the
-- linker, and the frameworks that must be linked for the linker to find them (those the library does not link already).
function of(library)
    local symbols, frameworks, seen = {}, {}, {}
    for _, row in ipairs(rows()[library.name] or {}) do
        table.insert(symbols, row.symbol)
        if not seen[row.framework] and not table.contains(library.frameworks, row.framework) then
            seen[row.framework] = true
            table.insert(frameworks, row.framework)
        end
    end
    table.sort(symbols)
    table.sort(frameworks)
    return {symbols = symbols, frameworks = frameworks, text = #symbols > 0 and table.concat(symbols, "\n") .. "\n" or ""}
end
