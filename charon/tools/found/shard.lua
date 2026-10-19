-- The shard encoding of a declaration row (ir.lua writes it, facts.lua reads it). A shard keeps the columns of the IR the generator
-- reads, and a name or a side that its USR already gives is stored as an empty cell: the USR is the derivation, and a cell is
-- written only where the derivation is not the row's value. The round trip is checked by ir.lua for every row.

-- The name the USR gives, or "" when it gives none (a super or conforms row has no USR; an anonymous tag's USR carries the name of
-- its first constant; a class extension has no name).
function name_of(kind, usr)
    if usr == "-" then return "" end
    if kind == "method" or kind == "property" or kind == "interface" or kind == "protocol" then
        return usr:match("%)([^%)]*)$") or ""
    end
    return usr:match("@([^@]*)$") or ""
end

-- The side the USR gives: a class method (USR class part "(cm)") is "+", every other row is "-".
function side_of(kind, usr)
    if kind == "method" and usr:find("(cm)", 1, true) then return "+" end
    return "-"
end

-- The stored cells of a row: name and side, each empty where the USR gives the value.
function encode(kind, usr, name, side)
    local stored_name = name_of(kind, usr) == name and "" or name
    local stored_side = side_of(kind, usr) == side and "" or side
    return stored_name, stored_side
end

-- The name and the side of a row from its stored cells.
function decode(kind, usr, stored_name, stored_side)
    local name = stored_name ~= "" and stored_name or name_of(kind, usr)
    local side = stored_side ~= "" and stored_side or side_of(kind, usr)
    return name, side
end
