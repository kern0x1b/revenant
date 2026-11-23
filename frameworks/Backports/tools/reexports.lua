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
