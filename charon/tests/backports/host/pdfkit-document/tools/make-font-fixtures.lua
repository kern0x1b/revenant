-- make-font-fixtures.lua - fixtures whose /Widths and whose EMBEDDED FONT PROGRAM disagree, on purpose.
--
--     xmake l tools/make-font-fixtures.lua [--with-matrix] <conforming-fixture.pdf> <directory>
--
-- -[PDFSelection boundsForPage:] is still `missing` because the width it answers cannot be reproduced from what the
-- file says: cgfixture-1.pdf's `/Widths` sum to 3058 per 1000 em (36.696pt at 12pt), its embedded `/FontFile2` program's
-- own advances sum to 6264 units per 2048 em (36.7031pt at 12pt), and the host answers 36.7080 - a third number. Two
-- candidates 0.007pt apart cannot say WHICH is read, because a rounding step in either reader explains the gap.
--
-- So the disagreement is made enormous instead of delicate. Every fixture here writes the SAME text ("page 1") through
-- the SAME embedded program, and moves `/Widths` far away from it, one direction per fixture, named for the direction:
--
--   widths-vs-program-wide      the six widths are 1000 each (72.0000pt), the program says 36.7031pt. An answer near 72
--                               read /Widths; an answer near 36.7031 read the PROGRAM.
--   widths-vs-program-narrow    the six widths are 250 each (18.0000pt), the same program. The same three candidates
--                               from the other side, so one of the two fixtures is a check on the other.
--   no-font-program             no /FontFile2 at all, and the six widths are 1000 each (72.0000pt). The system's own
--                               Helvetica advances for those codes come to 36.696pt, so this asks the third question:
--                               does the host fall back to the font by NAME over /BaseFont, with the "ABCDEF+" subset
--                               prefix stripped?
--   broken-font-program         /FontFile2 at the right LENGTH and the wrong BYTES - the real program's bytes with its
--                               sfnt version and table directory overwritten, so the length is honest and the program
--                               is not a font. This is the fixture that decides whether the row is implemented-with-a-
--                               stated-boundary or inert: it is what the host answers when NO reader can open the font.
--
-- WHY A BYTE-LEVEL WRITER AND NOT CGPDFContext: a conforming writer emits a CONSISTENT font - it computes /Widths from
-- the program it embeds - so it cannot write a disagreement, which is the whole point of these four. What is kept from
-- the conforming writer is the PROGRAM, lifted verbatim out of the /FontFile2 stream of a fixture it wrote, so it is a
-- real font a real writer produced rather than one synthesised here. Every offset and every /Length below is measured
-- from the bytes as they are written.
--
-- The /Widths array is /FirstChar 32 .. /LastChar 112, all 81 codes, the same span cgfixture-1.pdf writes, so the six
-- codes the text uses are set here and the other 75 keep the conforming writer's own 0. /Encoding /MacRomanEncoding and
-- the descriptor's /Ascent 770 /Descent -230 are the same on all four, so the y, the height and the x of every answer
-- are the ones already measured.
--
-- zlib (the program is DEFLATEd as zlib.compress writes it, and lifted out of a stream zlib.decompress reads) goes
-- through tools/pdfwrite.lua, which is the one place that touches it.

local pdfwrite = import("pdfwrite", {rootdir = os.scriptdir()})

-- The text every fixture draws, and where: make-pdf.m's own position, at /F1 12 Tf.
local TEXT = "BT /F1 12 Tf 72 720 Td (page 1) Tj ET\n"

-- The codes "page 1" is made of, with what the conforming writer's /Widths says for each.
local CODES = { 112, 97, 103, 101, 32, 49 }      -- p a g e space 1

local WIDE = 1000
local NARROW = 250

-- The standard fourteen of PDF 1.7 Table 7.21 (only counted: the print below says how many fixtures the table is for).
local BASE_FOURTEEN_COUNT = 14

local function read_file(file)
    local handle = assert(io.open(file, "rb"))
    local data = handle:read("a")
    handle:close()
    return data
end

-- The /Widths array over /FirstChar `first` .. /LastChar `last`, with `values` (a table code -> width) set.
local function widths_for(values, first, last)
    first = first or 32
    last = last or 112
    local row = {}
    for i = 1, last - first + 1 do
        row[i] = 0
    end
    for code, width in pairs(values) do
        if code < first or code > last then
            raise(string.format("code %d is outside the /Widths span %d..%d", code, first, last))
        end
        row[code - first + 1] = width
    end
    return "[" .. table.concat(row, " ") .. "]"
end

local function font_dict(descriptor_number, widths, program_number)
    local body = "<< /Type /Font /Subtype /TrueType /BaseFont /AAAAAB+Helvetica /FontDescriptor "
        .. descriptor_number .. " 0 R /Encoding /MacRomanEncoding /FirstChar 32 /LastChar 112 /Widths " .. widths
    if program_number then
        body = body .. " /FontFile2 " .. program_number .. " 0 R"
    end
    return body .. " >>"
end

local function descriptor(program_number)
    local body = "<< /Type /FontDescriptor /FontName /AAAAAB+Helvetica /Flags 32 "
        .. "/FontBBox [-951 -481 1445 1122] /ItalicAngle 0 /Ascent 770 /Descent -230 "
        .. "/CapHeight 717 /StemV 0 /XHeight 523 /StemH 85 /AvgWidth 441 /MaxWidth 1500"
    if program_number then
        body = body .. " /FontFile2 " .. program_number .. " 0 R"
    end
    return body .. " >>"
end

-- 1 catalog, 1 pages, 1 page, its content stream, the font, its descriptor, and the program when there is one.
-- `program` is the sfnt bytes, or nil for the fixture with no /FontFile2 at all. `program_stream_bytes` overrides
-- what goes IN the stream, which is how the broken fixture keeps the right /Length and the wrong bytes.
local function build(file, widths, program, program_stream_bytes, text)
    text = text or TEXT
    local has_program = program ~= nil
    local program_number = has_program and 7 or nil
    local objects = {
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
            .. "/Resources << /Font << /F1 5 0 R >> >> >>",
        "<< /Length " .. #text .. " >>\nstream\n" .. text .. "\nendstream",
        font_dict(6, widths, program_number),
        descriptor(program_number),
    }
    if has_program then
        local raw = program
        if program_stream_bytes then
            raw = program_stream_bytes
            objects[#objects + 1] = "<< /Length " .. #raw .. " >>\nstream\n" .. raw .. "\nendstream"
        else
            -- the real program, DEFLATEd because the fixture it came from was, and /Length1 beside /Length is what names
            -- the UNCOMPRESSED size - a reader that trusts /Length1 on a program that is not compressed gets the wrong
            -- bytes, which is the broken fixture's own trick and not this one's.
            local body = pdfwrite.zlib_compress(raw)
            objects[#objects + 1] = "<< /Length " .. #body .. " /Length1 " .. #raw
                .. " /Filter /FlateDecode >>\nstream\n" .. body .. "\nendstream"
        end
    end
    pdfwrite.write_pdf(file, objects)
end

-- The /FontFile2 stream of a fixture a CONFORMING writer wrote, decompressed. Not synthesised: a real font program, out
-- of a real document.
local function lift_program(conforming)
    local data = read_file(conforming)
    local number = data:match("/FontFile2 (%d+) 0 R")
    if not number then
        raise(conforming .. " carries no /FontFile2, so there is no program to lift")
    end
    local start = data:find("\n" .. tonumber(number) .. " 0 obj", 1, true)
    if not start then
        raise("ValueError: substring not found (no object " .. number .. " in " .. conforming .. ")")
    end
    local stop = data:find("endobj", start, true)
    if not stop then
        raise("ValueError: substring not found (no endobj after object " .. number .. ")")
    end
    local body = data:sub(start, stop - 1)
    local stream_at = body:find("stream\n", 1, true)
    if not stream_at then
        raise("ValueError: substring not found (no stream in object " .. number .. ")")
    end
    local begin = stream_at + #"stream\n"
    local ends = body:find("\nendstream", begin, true)
    if not ends then
        raise("ValueError: substring not found (no endstream in object " .. number .. ")")
    end
    if body:find("/FlateDecode", 1, true) then
        local program = pdfwrite.zlib_decompress(body:sub(begin, ends - 1))
        if not program then
            raise("zlib.error: incomplete or truncated stream")
        end
        return program
    end
    return body:sub(begin, ends - 1)
end

-- A SIMPLE font whose /Widths may be absent, over one of the base fourteen. `widths` nil writes NO /Widths at all.
local function build_type1(file, basefont, encoding, text, widths, descriptor_on, first, last)
    if descriptor_on == nil then
        descriptor_on = true
    end
    local font = "<< /Type /Font /Subtype /Type1 /BaseFont /" .. basefont .. " /Encoding /" .. encoding
    if widths then
        font = font .. " /FirstChar " .. first .. " /LastChar " .. last .. " /Widths " .. widths
    end
    if descriptor_on then
        font = font .. " /FontDescriptor 6 0 R"
    end
    font = font .. " >>"
    local objects = {
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
            .. "/Resources << /Font << /F1 5 0 R >> >> >>",
        "<< /Length " .. #text .. " >>\nstream\n" .. text .. "\nendstream",
        font,
        "<< /Type /FontDescriptor /FontName /" .. basefont .. " /Flags 32 "
            .. "/FontBBox [-166 -225 1000 931] /ItalicAngle 0 /Ascent 770 /Descent -230 "
            .. "/CapHeight 717 /StemV 88 /XHeight 523 /StemH 88 /AvgWidth 441 /MaxWidth 1500 >>",
    }
    pdfwrite.write_pdf(file, objects)
end

function main(...)
    local args = {}
    local with_matrix = false
    for _, arg in ipairs({ ... }) do
        if arg == "--with-matrix" then
            with_matrix = true
        else
            args[#args + 1] = arg
        end
    end
    if #args ~= 2 then
        raise("usage: make-font-fixtures.lua [--with-matrix] <conforming.pdf> <directory>")
    end
    local conforming, directory = args[1], args[2]
    local program = lift_program(conforming)
    local all_six, small_six, helv_six = {}, {}, {}
    for _, code in ipairs(CODES) do
        all_six[code] = WIDE
        small_six[code] = NARROW
        helv_six[code] = code ~= 32 and 556 or 278
    end

    -- 1. /Widths wide, the program as lifted
    build(directory .. "/cgfixture-widths-vs-program-wide.pdf", widths_for(all_six), program)
    -- 2. /Widths narrow, the same program
    build(directory .. "/cgfixture-widths-vs-program-narrow.pdf", widths_for(small_six), program)
    -- 3. NO /FontFile2 at all
    build(directory .. "/cgfixture-no-font-program.pdf", widths_for(all_six), nil)
    -- 4. /FontFile2 at the right LENGTH and the wrong BYTES: the sfnt version and the table directory overwritten with
    --    zeros, so the stream is the program's size and not a font. Python's broken[0:12] = 12 zeros, which also
    --    shortens a program under 12 bytes to exactly 12.
    local broken = string.rep("\0", 12) .. program:sub(13)
    build(directory .. "/cgfixture-broken-font-program.pdf", widths_for(all_six), broken, broken)

    -- 5 and 6. THE CHARACTER SPACING: the text-state operator the /Widths rule does not model. Both fixtures carry the
    --    same /Widths and the same program and differ only in that operator.
    local helv = widths_for(helv_six)
    build(directory .. "/cgfixture-text-tc.pdf", helv, program,
        nil, "BT 0.0002 Tc 12 0 0 12 72 720 Tm /F1 1 Tf (page 1) Tj 0 Tc ET\n")
    build(directory .. "/cgfixture-text-no-tc.pdf", helv, program,
        nil, "BT 12 0 0 12 72 720 Tm /F1 1 Tf (page 1) Tj ET\n")
    -- ALL THREE CARRY AN IDENTITY TEXT MATRIX and /F1 12 Tf, so that Tf's operand IS the effective size and Tc is the only
    -- thing that varies between them. The two superseded writes above are kept only because the Python makes them.
    helv = widths_for(helv_six)
    build(directory .. "/cgfixture-text-tc.pdf", helv, program,
        nil, "BT 0.0002 Tc /F1 12 Tf 72 720 Td (page 1) Tj 0 Tc ET\n")
    build(directory .. "/cgfixture-text-no-tc.pdf", helv, program,
        nil, "BT /F1 12 Tf 72 720 Td (page 1) Tj ET\n")
    build(directory .. "/cgfixture-text-tc10.pdf", helv, program,
        nil, "BT 0.002 Tc /F1 12 Tf 72 720 Td (page 1) Tj 0 Tc ET\n")
    -- The TEXT MATRIX'S SCALE. The flat and skew ones are MEASUREMENT ONLY: --with-matrix writes them.
    build(directory .. "/cgfixture-text-matrix-scale.pdf", helv, program,
        nil, "BT 12 0 0 12 72 720 Tm /F1 1 Tf (page 1) Tj ET\n")
    if with_matrix then
        build(directory .. "/cgfixture-text-matrix-flat.pdf", helv, program,
            nil, "BT 24 0 0 6 72 720 Tm /F1 12 Tf (page 1) Tj ET\n")
        build(directory .. "/cgfixture-text-matrix-skew.pdf", helv, program,
            nil, "BT 12 6 0 12 72 720 Tm /F1 12 Tf (page 1) Tj ET\n")
    end
    -- 7. A BASE-FOURTEEN FONT WITH NO /Widths AT ALL.
    build_type1(directory .. "/cgfixture-base14-no-widths.pdf", "Courier", "WinAnsiEncoding",
        "BT /F1 12 Tf 72 720 Td (page 1) Tj ET\n")
    -- 8. THE SAME, WITH /Widths.
    local six_hundreds = {}
    for i = 1, 81 do
        six_hundreds[i] = "600"
    end
    build_type1(directory .. "/cgfixture-base14-with-widths.pdf", "Courier", "WinAnsiEncoding",
        "BT /F1 12 Tf 72 720 Td (page 1) Tj ET\n", "[" .. table.concat(six_hundreds, " ") .. "]", true, 32, 112)
    -- 9. A CODE AT 0x80 OR ABOVE: one byte 0xE9 in a /WinAnsiEncoding font, which the encoding resolves to U+00E9.
    build_type1(directory .. "/cgfixture-high-byte.pdf", "Helvetica", "WinAnsiEncoding",
        "BT /F1 12 Tf 72 720 Td (caf\233) Tj ET\n",
        widths_for({ [99] = 500, [97] = 556, [102] = 278, [233] = 556 }, 0, 255), true, 0, 255)
    -- NOT WRITTEN: A COMPOSITE (Type0) FONT. It is switched off in the Python (its call is commented out there), and so
    -- its builder (build_cid) is not ported.

    print(string.format("wrote %d font fixtures into %s from a %d byte program",
        13 + 4 * BASE_FOURTEEN_COUNT, directory, #program))
end
