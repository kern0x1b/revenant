-- make-text-fixtures.lua - the twenty-two fixtures the -string table in facts/PDFKit/Document11.md was measured on.
--
--     xmake l tools/make-text-fixtures.lua <directory>
--
-- Every row of that table is generated here, so the table is reproducible and not a claim in a message that scrolls
-- away. tools/verify-table.sh regenerates, asks the host through tools/host-string.m, and diffs what came out against
-- what the facts file says.
--
--     row name | content stream | what the table is asking
--
--   the four the first table was measured on
--   kern-20  kern-50  kern-100  kern-150  kern-250  kern-500  kern-1000  kern-plus250
--       a TJ kerning between the same two strings, from -20 to -1000 and one positive: where does a space start,
--       does magnitude buy more than one, and does the sign matter
--   td-x-only  td-small-y  td-y--0.4  td-y--14  td-y--40
--       movement between two shows, in each axis and by magnitude
--   op-TD-next-line  op-quote-operator  op-TD-star-between
--       the other positioning and quoting operators
--   size-6  size-12  size-24
--       the same kerning at three font sizes: is the threshold relative to the em?
--   op-Tm-set  op-TD-star-next-line  op-dquote-operator
--       the three the reader rejects, kept in the table as the VOID cases they are
--
-- Every xref offset and the stream's /Length is measured from the object bytes, never typed.
-- Prints one line per fixture: name, the content stream, and the note, tab separated.

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

-- Python's str.strip() on the stream's text: the spaces and line breaks off both ends.
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
