-- make-annotation-fixtures.lua - fixtures with ANNOTATIONS, written with every xref offset and /Length measured.
--
--     xmake l make-annotation-fixtures.lua <directory>
--
-- The PDFKit annotation work needs a page that CARRIES annotations, and the fixtures the other two slices wrote do not:
-- their pages name no /Annots at all. Three shapes, because the members divide by what the annotation has:
--
--   annot-text       a text annotation with a /Rect, /Contents, /T, /M, /C, /Border and /F
--   annot-free       a link annotation with a /Rect, /Contents, /Border and /F and NOTHING else - the members that
--                    read an absent key are the interesting ones
--   annot-two        a page carrying TWO annotations, so a count and an index can be read
--
-- Every offset and length below is measured from the object bytes as they are written.

local pdfwrite = import("pdfwrite", {rootdir = os.scriptdir()})

local FONT = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
local TEXT = "BT /F1 12 Tf 72 720 Td (annotated) Tj ET\n"

-- an annotation's dictionary: the subtype, then each { key, value } pair in order
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

-- a copy of a list without its first element, which is what Python's list[1:] is
local function rest(list)
    local out = {}
    for i = 2, #list do
        out[#out + 1] = list[i]
    end
    return out
end

-- a list of pairs with `first` put in front of `others`
local function with_first(first, others)
    local out = { first }
    for _, pair in ipairs(others) do
        out[#out + 1] = pair
    end
    return out
end

-- 1 catalog, 1 pages, 1 page, the content stream, the annotations, the font.
local function build(file, annotations)
    local objects = {
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        false,      -- the page, filled in once the numbers are known
        "<< /Length " .. #TEXT .. " >>\nstream\n" .. TEXT .. "\nendstream",
    }
    local refs = {}
    for _, body in ipairs(annotations) do
        objects[#objects + 1] = body
        refs[#refs + 1] = tostring(#objects)           -- 1-based object numbers
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
        -- HELD-OUT rects, and two more subtypes. The /Text icon rule - a 24x24 note at (minX, maxY-24) - was derived
        -- from ONE rect; it is not a rule until it is right on a rect it was not fitted to, and not a PDFKit-wide rule
        -- until a subtype that is not a note answers something else.
        { "annot-text-holdout.pdf", { annot("Text", with_first({ "Rect", "[10 20 500 90]" }, rest(FULL))) } },
        { "annot-link-wide.pdf", { annot("Link", with_first({ "Rect", "[0 0 600 700]" }, rest(BARE))) } },
        { "annot-square.pdf", { annot("Square", {
            { "Rect", "[40 40 240 140]" }, { "Contents", "(a square)" }, { "F", "4" } }) } },
        { "annot-highlight.pdf", { annot("Highlight", {
            { "Rect", "[0 0 200 30]" }, { "QuadPoints", "[0 30 200 30 0 0 200 0]" },
            { "Contents", "(highlighted)" }, { "F", "4" } }) } },
        -- FLAGS, held out. Every other shape writes /F 4, so they all answer shouldDisplay=1 and shouldPrint=1, and
        -- "always YES" fits that data exactly as well as "mirrors the bit" does. The two below are the only fixtures
        -- that can tell those two rules apart: /F 0 clears Print, /F 2 is Hidden alone.
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
