local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules"), anonymous = true})

local ALIAS = {
    FLT_MAX = 3.4028234663852886e+38,
    CGFLOAT_MAX = 1.7976931348623157e+308,
    DBL_MAX = 1.7976931348623157e+308,
}

local function lines_of(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    return out
end

local function read(file)
    return io.readfile(file, {encoding = "binary"})
end

local function cut(line)
    local tab = line:find("\t", 1, true)
    if not tab then
        return line, nil
    end
    return line:sub(1, tab - 1), line:sub(tab + 1)
end

local function fields_of(line)
    local out, at = {}, 1
    while true do
        local tab = line:find("\t", at, true)
        if not tab then
            table.insert(out, line:sub(at))
            return out
        end
        table.insert(out, line:sub(at, tab - 1))
        at = tab + 1
    end
end

local function as_float(text)
    local s = text:trim()
    local lower = s:lower()
    if lower == "inf" or lower == "+inf" or lower == "infinity" then
        return math.huge
    end
    if lower == "-inf" or lower == "-infinity" then
        return -math.huge
    end
    if lower == "nan" then
        return 0 / 0
    end
    return tonumber(s)
end

local function digits(value)
    return string.format("%.17g", value)
end

function main(port_map, host_map, host_numeric)
    local port = {}
    for _, line in ipairs(lines_of(read(port_map))) do
        if line:trim() ~= "" then
            local name, value = cut(line)
            port[name] = value
        end
    end
    local host = {}
    for _, line in ipairs(lines_of(read(host_map))) do
        if line:trim() ~= "" then
            local name, rest = cut(line)
            local image, value = cut(rest or "")
            host[name] = {image or "", value or ""}
        end
    end
    local portnum = {}
    if os.isfile(port_map .. ".numeric") then
        for _, line in ipairs(lines_of(read(port_map .. ".numeric"))) do
            if line:trim() ~= "" then
                local name, value = cut(line)
                portnum[name] = value
            end
        end
    end

    local names = {}
    for name in pairs(port) do
        table.insert(names, name)
    end
    byteorder.sort(names)
    local compared, mismatched, unanswered, unproved = 0, 0, 0, 0
    for _, name in ipairs(names) do
        local entry = host[name]
        if not entry then
            unanswered = unanswered + 1
            print("  NO-HOST-SYMBOL  " .. name)
        elseif not entry[1]:find("PDFKit", 1, true) then
            unproved = unproved + 1
            print("  NOT-PROVED      " .. name .. " came from " .. entry[1])
        else
            compared = compared + 1
            if entry[2] ~= port[name] then
                mismatched = mismatched + 1
                print("  MISMATCH        " .. name .. "  port='" .. port[name] .. "'  host='" .. entry[2] .. "'")
            end
        end
    end

    local numeric_mismatch, numeric_unproved = 0, 0
    for _, line in ipairs(lines_of(read(host_numeric))) do
        local parts = fields_of(line)
        if line:trim() ~= "" and #parts >= 3 and portnum[parts[1]] ~= nil then
            local name, image, value = parts[1], parts[2], parts[3]
            if not image:find("PDFKit", 1, true) then
                numeric_unproved = numeric_unproved + 1
                print("  NOT-PROVED      " .. name .. " came from " .. image)
            else
                local printed = as_float(value)
                if printed == nil then
                    numeric_mismatch = numeric_mismatch + 1
                    print("  MISMATCH        " .. name .. " host='" .. value .. "' is not a number")
                else
                    local literal = portnum[name]:trim():gsub(";+$", "")
                    literal = literal:gsub("^%(%s*[%a_][%w_]*%s*%)", "")
                    local theirs = ALIAS[literal] or printed
                    if theirs ~= printed then
                        numeric_mismatch = numeric_mismatch + 1
                        print("  MISMATCH        " .. name .. "  port=" .. literal .. " -> " .. digits(theirs) .. "  host=" .. digits(printed))
                    else
                        compared = compared + 1
                    end
                end
            end
        end
    end

    print(string.format("COMPARED %d MISMATCHES %d", compared, mismatched + numeric_mismatch))
    if unanswered > 0 or unproved > 0 or numeric_unproved > 0 then
        print(string.format("  unanswered by the host: %d   not proved to be PDFKit: %d", unanswered, unproved + numeric_unproved))
    end
    if mismatched > 0 or numeric_mismatch > 0 or unanswered > 0 or unproved > 0 or numeric_unproved > 0 then
        os.exit(1)
    end
end
