local REPO = path.directory(path.directory(path.absolute(os.scriptdir())))
local TOOLS = path.join(REPO, "tools")
local property_map = import("gen.property_map", {rootdir = TOOLS, anonymous = true})
local checks = 0

local function expect(condition, message)
    checks = checks + 1
    if not condition then raise("test failed: " .. message) end
end

local function has(text, needle)
    return string.find(text, needle, 1, true) ~= nil
end

local objects = property_map.objects(REPO, "ImageIO")
expect(objects["ImageIOMetadata7.m"] ~= nil, "the ImageIO table writes ImageIOMetadata7.m")
local count = 0
for _ in pairs(objects) do
    count = count + 1
end
expect(count == 1, "the table writes one object, got " .. count)
local text = objects["ImageIOMetadata7.m"]

expect(has(text, "#define CHARON_PROPERTY_ROWS 357\n"), "the row count is 357")
local rows = 0
for line in string.gmatch(text, "[^\n]+") do
    if string.match(line, '^    { "') then
        rows = rows + 1
    end
end
expect(rows == 357, "357 rows are written, got " .. rows)
expect(not has(text, "@PROPERTY"), "no marker is left in the object")

expect(has(text, '    { "{TIFF}", "Compression",\n      "http://ns.adobe.com/tiff/1.0/", "tiff", "Compression" },  // kCGImagePropertyTIFFCompression\n'),
    "the TIFF compression row is written as the table gives it")
expect(has(text, '"http://ns.adobe.com/xap/1.0/", "xmp", "CreatorTool" },  // kCGImagePropertyTIFFSoftware\n'),
    "a row whose tag name differs from its property is written with the tag the host wrote")

expect(has(text, "};\n\n// The row for a (dictionary, property) pair, or NULL."), "the rows close where the template closes them")
expect(has(text, "return CGImageMetadataSetValueWithPath(metadata, NULL, (__bridge CFStringRef)path, value);\n}\n"),
    "the last function of the template is written as it is")

local header = io.readfile(path.join(os.scriptdir(), "property_map_fixture", "CGImageProperties.h"))
local pairs_text = property_map.pairs_header(header)
expect(has(pairs_text, "/* 4 pairs: every property the header declares under a dictionary it names. */\n"), "four pairs, each once")
expect(has(pairs_text, "    out[0].dictionary = kCGImagePropertyTIFFDictionary; out[0].property = kCGImagePropertyTIFFCompression;\n"),
    "the first pair is the TIFF compression")
expect(has(pairs_text, "    out[1].dictionary = kCGImagePropertyTIFFDictionary; out[1].property = kCGImagePropertyTIFFMake;\n"),
    "the second pair is the TIFF make")
expect(has(pairs_text, "    out[2].dictionary = kCGImagePropertyExifDictionary; out[2].property = kCGImagePropertyExifDateTimeOriginal;\n"),
    "a property is paired with the dictionary whose section it is in")
expect(has(pairs_text, "    out[3].dictionary = kCGImagePropertyExifDictionary; out[3].property = kCGImagePropertyOrientation;\n"),
    "every property of a section is paired with it")
expect(has(pairs_text, "    return 4;\n}\n"), "the count is returned")

print("property_map_test: " .. checks .. " checks passed")
