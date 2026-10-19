local pdfwrite = import("pdfwrite", {rootdir = os.scriptdir()})

local FONT = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
local RANGE = "BT /F1 12 Tf 72 720 Td"

local function kern(value)
    local name
    if value < 0 then
        name = string.format("kern-%d", -value)
    else
        name = string.format("kern-plus%d", value)
    end
    return { name, RANGE .. " [(al) " .. tostring(value) .. " (pha)] TJ ET", string.format("TJ kerning %+d", value) }
end

local function td(operator, name, note)
    return { name, RANGE .. " (alpha) Tj " .. operator .. " (beta) Tj ET", note }
end

local function other(operator, name, note, leading)
    if leading then
        return { name, RANGE .. " " .. operator .. " ET", note }
    end
    return { name, RANGE .. " (alpha) Tj " .. operator .. " (beta) Tj ET", note }
end

local function size(points)
    return { string.format("size-%d", points),
        "BT /F1 " .. tostring(points) .. " Tf 72 720 Td [(al) -100 (pha)] TJ ET",
        string.format("kerning -100 at %dpt", points) }
end

local CASES = {
    kern(-20), kern(-50), kern(-100), kern(-150), kern(-250), kern(-500), kern(-1000), kern(250),
    td("72 0 Td", "td-x-only", "x only"),
    td("0 -2 Td", "td-small-y", "small y"),
    td("0 -0.4 Td", "td-y--0.4", "y -0.4"),
    td("0 -14 Td", "td-y--14", "y -14"),
    td("0 -40 Td", "td-y--40", "y -40"),
    other("0 -14 TD", "op-TD-next-line", "TD next line", false),
    other("(alpha) '", "op-quote-operator", "the quote operator", true),
    other("0 -14 Td (beta) Tj T* (gamma) Tj", "op-TD-star-between", "T* between two shows", true),
    size(6), size(12), size(24),
    other("1 0 0 1 72 706 Tm 0 -14 Td", "op-Tm-set", "Tm set", true),
    other("0 -14 T*", "op-TD-star-next-line", "a leading T*", true),
    other('(alpha) "', "op-dquote-operator", "the double-quote operator", true),
}

local function build(file, content)
    local objects = {
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
        "<< /Length " .. #content .. " >>\nstream\n" .. content .. "\nendstream",
        FONT,
    }
    pdfwrite.write_pdf(file, objects)
    return content
end

local function strip(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function main(directory)
    if not directory then
        raise("usage: make-text-fixtures.lua <directory>")
    end
    pdfwrite.make_dirs(directory)
    for _, case in ipairs(CASES) do
        local name, content, note = case[1], case[2], case[3]
        local written = build(path.join(directory, name .. ".pdf"), content)
        print(name .. "\t" .. strip(written) .. "\t" .. note)
    end
end
