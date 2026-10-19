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

function zlib_compress(raw)
    local answer = os.iorunv("/usr/bin/perl", {"-MCompress::Zlib", "-e", PERL_DEFLATE, to_hex(raw)})
    if answer:sub(1, 1) ~= "K" then
        raise("pdfwrite.lua: deflate did not answer")
    end
    return from_hex(answer:sub(2))
end

function zlib_decompress(data)
    local answer = os.iorunv("/usr/bin/perl", {"-MCompress::Zlib", "-e", PERL_INFLATE, to_hex(data)})
    if answer:sub(1, 1) == "K" then
        return from_hex(answer:sub(2))
    end
    return nil
end

function make_dirs(directory)
    os.iorunv("/bin/mkdir", {"-p", directory})
end

function write_file(path, data)
    local handle = assert(io.open(path, "wb"))
    handle:write(data)
    handle:close()
end

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
