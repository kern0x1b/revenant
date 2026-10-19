local pdfwrite = import("pdfwrite", {rootdir = path.join(os.scriptdir(), "tools")})

local TEXT = "q Q"
local FONT = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"

local function build(file, crop, boxes, rotate)
    local page = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]"
    if crop then
        page = page .. " /CropBox [0 0 300 400]"
    end
    if boxes then
        page = page .. " /BleedBox [10 10 290 390] /TrimBox [20 20 280 380] /ArtBox [30 30 270 370]"
    end
    if rotate then
        page = page .. " /Rotate 90"
    end
    page = page .. " /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>"

    local objects = {
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        page,
        "<< /Length " .. #TEXT .. " >>\nstream\n" .. TEXT .. "\nendstream",
        FONT,
    }
    local _, size, offsets = pdfwrite.write_pdf(file, objects)
    return size, offsets
end

function main(directory)
    if not directory then
        raise("usage: make-box-pdfs.lua <directory>")
    end
    pdfwrite.make_dirs(directory)
    local made = {
        { "box-all.pdf", true, true, false },
        { "box-nocrop.pdf", true, false, false },
        { "box-rotated.pdf", true, true, true },
    }
    for _, entry in ipairs(made) do
        local name = entry[1]
        local size, offsets = build(path.join(directory, name), entry[2], entry[3], entry[4])
        print(string.format("  wrote %s: %d bytes, object offsets [%s]", name, size, table.concat(offsets, ", ")))
    end
end
