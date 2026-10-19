local pdfwrite = import("pdfwrite", {rootdir = os.scriptdir()})

local TEXT = "BT /F1 12 Tf 72 720 Td (page 1) Tj ET\n"

local CODES = { 112, 97, 103, 101, 32, 49 }

local WIDE = 1000
local NARROW = 250

local BASE_FOURTEEN_COUNT = 14

local function read_file(file)
    local handle = assert(io.open(file, "rb"))
    local data = handle:read("a")
    handle:close()
    return data
end

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
            local body = pdfwrite.zlib_compress(raw)
            objects[#objects + 1] = "<< /Length " .. #body .. " /Length1 " .. #raw
                .. " /Filter /FlateDecode >>\nstream\n" .. body .. "\nendstream"
        end
    end
    pdfwrite.write_pdf(file, objects)
end

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

    build(directory .. "/cgfixture-widths-vs-program-wide.pdf", widths_for(all_six), program)
    build(directory .. "/cgfixture-widths-vs-program-narrow.pdf", widths_for(small_six), program)
    build(directory .. "/cgfixture-no-font-program.pdf", widths_for(all_six), nil)
    local broken = string.rep("\0", 12) .. program:sub(13)
    build(directory .. "/cgfixture-broken-font-program.pdf", widths_for(all_six), broken, broken)

    local helv = widths_for(helv_six)
    build(directory .. "/cgfixture-text-tc.pdf", helv, program,
        nil, "BT 0.0002 Tc 12 0 0 12 72 720 Tm /F1 1 Tf (page 1) Tj 0 Tc ET\n")
    build(directory .. "/cgfixture-text-no-tc.pdf", helv, program,
        nil, "BT 12 0 0 12 72 720 Tm /F1 1 Tf (page 1) Tj ET\n")
    helv = widths_for(helv_six)
    build(directory .. "/cgfixture-text-tc.pdf", helv, program,
        nil, "BT 0.0002 Tc /F1 12 Tf 72 720 Td (page 1) Tj 0 Tc ET\n")
    build(directory .. "/cgfixture-text-no-tc.pdf", helv, program,
        nil, "BT /F1 12 Tf 72 720 Td (page 1) Tj ET\n")
    build(directory .. "/cgfixture-text-tc10.pdf", helv, program,
        nil, "BT 0.002 Tc /F1 12 Tf 72 720 Td (page 1) Tj 0 Tc ET\n")
    build(directory .. "/cgfixture-text-matrix-scale.pdf", helv, program,
        nil, "BT 12 0 0 12 72 720 Tm /F1 1 Tf (page 1) Tj ET\n")
    if with_matrix then
        build(directory .. "/cgfixture-text-matrix-flat.pdf", helv, program,
            nil, "BT 24 0 0 6 72 720 Tm /F1 12 Tf (page 1) Tj ET\n")
        build(directory .. "/cgfixture-text-matrix-skew.pdf", helv, program,
            nil, "BT 12 6 0 12 72 720 Tm /F1 12 Tf (page 1) Tj ET\n")
    end
    build_type1(directory .. "/cgfixture-base14-no-widths.pdf", "Courier", "WinAnsiEncoding",
        "BT /F1 12 Tf 72 720 Td (page 1) Tj ET\n")
    local six_hundreds = {}
    for i = 1, 81 do
        six_hundreds[i] = "600"
    end
    build_type1(directory .. "/cgfixture-base14-with-widths.pdf", "Courier", "WinAnsiEncoding",
        "BT /F1 12 Tf 72 720 Td (page 1) Tj ET\n", "[" .. table.concat(six_hundreds, " ") .. "]", true, 32, 112)
    build_type1(directory .. "/cgfixture-high-byte.pdf", "Helvetica", "WinAnsiEncoding",
        "BT /F1 12 Tf 72 720 Td (caf\233) Tj ET\n",
        widths_for({ [99] = 500, [97] = 556, [102] = 278, [233] = 556 }, 0, 255), true, 0, 255)

    print(string.format("wrote %d font fixtures into %s from a %d byte program",
        13 + 4 * BASE_FOURTEEN_COUNT, directory, #program))
end
