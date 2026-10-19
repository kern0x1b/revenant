local pdfwrite = import("pdfwrite", {rootdir = os.scriptdir()})

local FONT = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
local TEXT = "BT /F1 12 Tf 72 720 Td (annotated) Tj ET\n"

local function annot(kind, extra)
    local body = "<< /Type /Annot /Subtype /" .. kind
    for _, pair in ipairs(extra) do
        body = body .. " /" .. pair[1] .. " " .. pair[2]
    end
    return body .. " >>"
end

local FULL = {
    { "Rect", "[100 600 300 650]" },
    { "Contents", "(a note on the page)" },
    { "T", "(the annotator)" },
    { "M", "(D:20260930000000Z)" },
    { "C", "[1 0 0]" },
    { "Border", "[0 0 1]" },
    { "F", "4" },
    { "NM", "(mark-1)" },
}
local BARE = {
    { "Rect", "[20 700 60 720]" },
    { "Contents", "(bare)" },
}

local function rest(list)
    local out = {}
    for i = 2, #list do
        out[#out + 1] = list[i]
    end
    return out
end

local function with_first(first, others)
    local out = { first }
    for _, pair in ipairs(others) do
        out[#out + 1] = pair
    end
    return out
end

local function build(file, annotations)
    local objects = {
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        false,
        "<< /Length " .. #TEXT .. " >>\nstream\n" .. TEXT .. "\nendstream",
    }
    local refs = {}
    for _, body in ipairs(annotations) do
        objects[#objects + 1] = body
        refs[#refs + 1] = tostring(#objects)
    end
    local font_number = #objects + 1
    objects[#objects + 1] = FONT
    objects[3] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [" .. table.concat(refs, " 0 R ")
        .. " 0 R] /Resources << /Font << /F1 " .. font_number .. " 0 R >> >> /Contents 4 0 R >>"
    return pdfwrite.write_pdf(file, objects)
end

function main(directory)
    if not directory then
        raise("usage: make-annotation-fixtures.lua <directory>")
    end
    pdfwrite.make_dirs(directory)
    local shapes = {
        { "annot-text.pdf", { annot("Text", FULL) } },
        { "annot-free.pdf", { annot("Link", BARE) } },
        { "annot-two.pdf", { annot("Text", FULL), annot("Link", BARE) } },
        { "annot-text-holdout.pdf", { annot("Text", with_first({ "Rect", "[10 20 500 90]" }, rest(FULL))) } },
        { "annot-link-wide.pdf", { annot("Link", with_first({ "Rect", "[0 0 600 700]" }, rest(BARE))) } },
        { "annot-square.pdf", { annot("Square", {
            { "Rect", "[40 40 240 140]" }, { "Contents", "(a square)" }, { "F", "4" } }) } },
        { "annot-highlight.pdf", { annot("Highlight", {
            { "Rect", "[0 0 200 30]" }, { "QuadPoints", "[0 30 200 30 0 0 200 0]" },
            { "Contents", "(highlighted)" }, { "F", "4" } }) } },
        { "annot-noprint.pdf", { annot("Square", {
            { "Rect", "[40 40 140 140]" }, { "Contents", "(no flags)" }, { "F", "0" } }) } },
        { "annot-hidden.pdf", { annot("Square", {
            { "Rect", "[40 40 140 140]" }, { "Contents", "(hidden)" }, { "F", "2" } }) } },
    }
    for _, shape in ipairs(shapes) do
        local name, annotations = shape[1], shape[2]
        local count = build(path.join(directory, name), annotations)
        print(string.format("  wrote %-16s %d objects, %d annotation(s)", name, count, #annotations))
    end
end
