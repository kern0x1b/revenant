function mangle(api)
    local body = string.gsub(string.gsub(api, "[^A-Za-z0-9]+", "_"), "^_+", "")
    body = string.gsub(body, "_+$", "")
    if string.sub(api, 1, 1) == "+" then
        return "class_" .. body
    end
    return body
end

function rows(members, classes, framework)
    local out, seen = {}, {}
    for _, m in ipairs(members) do
        if not seen[m.api] then
            seen[m.api] = true
            local tbd = "-"
            if classes ~= nil then
                tbd = classes[m.cls] and "class-exported" or "class-not-exported"
            end
            table.insert(out, {kind = m.kind, api = m.api, cls = m.cls, key = mangle(m.api), introduced = "-", type = m.type or "-",
                               availability = m.text ~= "" and m.text or "-", hash = m.hash, value_status = "-", value = "-",
                               host_value = "-", value_source = "-", owned = "-", tbd = tbd, shape = "-", measured = "-"})
        end
    end
    return out
end
