-- pdfwrite.lua - what the PDF fixture generators share: a file writer, a writer that measures every xref offset and
-- the trailer from the object bytes as they are written, and zlib (deflate at Python's zlib.compress settings, and the
-- one-shot inflate of zlib.decompress) without a temporary file.
--
-- Lua has no zlib, and the generators need it byte for byte, so zlib goes through /usr/bin/perl, whose Compress::Zlib
-- is the system zlib: deflateInit at level 6 with MemLevel 8, which is what zlib.compress() uses (Compress::Zlib's own
-- compress() picks MemLevel 9 and writes different bytes). The data crosses the process boundary as hex in argv, so no
-- file is written anywhere. The perl prints "K" and the hex of the result, or "E" when the stream is not a whole zlib
-- stream, and exits 0 either way, because os.iorunv raises on a failed run and a decompress that fails is a value here.
--
-- Imported by the generators: import("pdfwrite", {rootdir = path.join(os.scriptdir(), "tools")}).

local PERL_DEFLATE = [[
use Compress::Zlib;
my $data = pack("H*", $ARGV[0]);
my ($z) = Compress::Zlib::deflateInit(-Level => 6, -MemLevel => 8);
my ($head) = $z->deflate($data);
my ($tail) = $z->flush();
print "K" . unpack("H*", $head . $tail);
]]

local PERL_INFLATE = [[
use Compress::Zlib;
my ($i) = Compress::Zlib::inflateInit();
my ($out, $status) = $i->inflate(pack("H*", $ARGV[0]));
if (defined $out && $status == Z_STREAM_END) {
    print "K" . unpack("H*", $out);
} else {
    print "E";
}
]]

local function to_hex(bytes)
    return (bytes:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function from_hex(hex)
    return (hex:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

-- zlib.compress(raw), as bytes.
function zlib_compress(raw)
    local answer = os.iorunv("/usr/bin/perl", {"-MCompress::Zlib", "-e", PERL_DEFLATE, to_hex(raw)})
    if answer:sub(1, 1) ~= "K" then
        raise("pdfwrite.lua: deflate did not answer")
    end
    return from_hex(answer:sub(2))
end

-- zlib.decompress(data), as bytes, or nil when Python's would have raised (a truncated or invalid stream).
function zlib_decompress(data)
    local answer = os.iorunv("/usr/bin/perl", {"-MCompress::Zlib", "-e", PERL_INFLATE, to_hex(data)})
    if answer:sub(1, 1) == "K" then
        return from_hex(answer:sub(2))
    end
    return nil
end

-- os.makedirs(directory, exist_ok=True)
function make_dirs(directory)
    os.iorunv("/bin/mkdir", {"-p", directory})
end

-- open(path, "wb").write(data)
function write_file(path, data)
    local handle = assert(io.open(path, "wb"))
    handle:write(data)
    handle:close()
end

-- The file the generators write: %PDF-1.4, each object as "N 0 obj" .. body .. "endobj", the xref with every
-- offset measured, the trailer and startxref. objects is a list of bodies, object 1 first. Returns the object count,
-- the file's size in bytes, and the list of object offsets.
function write_pdf(path, objects)
    local parts = { "%PDF-1.4\n" }
    local length = #parts[1]
    local offsets = {}
    for number, body in ipairs(objects) do
        offsets[number] = length
        local text = number .. " 0 obj\n" .. body .. "\nendobj\n"
        parts[#parts + 1] = text
        length = length + #text
    end
    local start = length
    local size = tostring(#objects + 1)
    parts[#parts + 1] = "xref\n0 " .. size .. "\n0000000000 65535 f \n"
    for _, offset in ipairs(offsets) do
        parts[#parts + 1] = string.format("%010d 00000 n \n", offset)
    end
    parts[#parts + 1] = "trailer\n<< /Size " .. size .. " /Root 1 0 R >>\nstartxref\n" .. start .. "\n%%EOF\n"
    local text = table.concat(parts)
    write_file(path, text)
    return #objects, #text, offsets
end
