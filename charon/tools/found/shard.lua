function name_of(kind, usr)
    if usr == "-" then return "" end
    if kind == "method" or kind == "property" or kind == "interface" or kind == "protocol" then
        return usr:match("%)([^%)]*)$") or ""
    end
    return usr:match("@([^@]*)$") or ""
end

function side_of(kind, usr)
    if kind == "method" and usr:find("(cm)", 1, true) then return "+" end
    return "-"
end

function encode(kind, usr, name, side)
    local stored_name = name_of(kind, usr) == name and "" or name
    local stored_side = side_of(kind, usr) == side and "" or side
    return stored_name, stored_side
end

function decode(kind, usr, stored_name, stored_side)
    local name = stored_name ~= "" and stored_name or name_of(kind, usr)
    local side = stored_side ~= "" and stored_side or side_of(kind, usr)
    return name, side
end
