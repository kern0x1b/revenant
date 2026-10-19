-- The ImageIO property-to-tag table of CGImageMetadata (iOS 7): the rows of CGImageMetadataCopyTagMatchingImageProperty and
-- CGImageMetadataSetValueMatchingImageProperty, written into .gen/ImageIO/ImageIOMetadata7.m from the object's hand-written text
-- (spec/ImageIO/ImageIOMetadata7.m.in) and the measured table (spec/ImageIO/property-map.tsv). The table is what the host's own
-- ImageIO answered for each (dictionary, property) pair of the SDK's CGImageProperties.h, one process per pair, by
-- tests/backports/host/imageio-metadata/property-table.m; its rows are in the pairs' order, and a pair the host does not map has no row.
--
-- It replaces tools/corpus/gen-imageio-property-map.py, which printed the same rows, and it reads no file outside the repository.
-- The pair list the probe asks about is written by pairs_header below, from the SDK's header:
--     xmake l tools/gen/property_map.lua <SDK>/System/Library/Frameworks/ImageIO.framework/Headers/CGImageProperties.h
-- which prints tests/backports/host/imageio-metadata/property-pairs-all.h.

local tsv = import("tsv", {anonymous = true})
local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})

local FRAMEWORK = "ImageIO"
local TABLE_NAME = "property-map.tsv"
local TEMPLATE_NAME = "ImageIOMetadata7.m.in"
local OBJECT_NAME = "ImageIOMetadata7.m"
local ROWS_MARK = "@PROPERTY_ROWS@\n"
local COUNT_MARK = "@PROPERTY_COUNT@"

-- The ten public namespaces ImageIO declares, with the prefix the port names each by. A table row whose URI is none of them, or whose
-- prefix is not its namespace's, stops the writer: a tag in another namespace is not carried as a string literal.
local NAMESPACE_PREFIX = {
    ["http://ns.adobe.com/exif/1.0/"] = "exif",
    ["http://ns.adobe.com/exif/1.0/aux/"] = "aux",
    ["http://cipa.jp/exif/1.0/"] = "exifEX",
    ["http://purl.org/dc/elements/1.1/"] = "dc",
    ["http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/"] = "Iptc4xmpCore",
    ["http://iptc.org/std/Iptc4xmpExt/2008-02-29/"] = "Iptc4xmpExt",
    ["http://ns.adobe.com/photoshop/1.0/"] = "photoshop",
    ["http://ns.adobe.com/tiff/1.0/"] = "tiff",
    ["http://ns.adobe.com/xap/1.0/"] = "xmp",
    ["http://ns.adobe.com/xap/1.0/rights/"] = "xmpRights",
}

-- The text with every occurrence of a plain needle replaced by a plain text (no pattern is read from either).
local function replace_plain(text, needle, with)
    local out, pos = {}, 1
    while true do
        local start, stop = string.find(text, needle, pos, true)
        if start == nil then
            break
        end
        table.insert(out, string.sub(text, pos, start - 1))
        table.insert(out, with)
        pos = stop + 1
    end
    table.insert(out, string.sub(text, pos))
    return table.concat(out)
end

-- The rows of the table, checked: each is a mapped namespace with its own prefix, a String tag (kind 1), and an answer of the host.
local function checked_rows(rows)
    for _, row in ipairs(rows) do
        local prefix = NAMESPACE_PREFIX[row.uri]
        assert(prefix ~= nil, string.format("pair %s maps into %s, which is not one of the ten public namespaces", row.pair, row.uri))
        assert(row.prefix == prefix, string.format("pair %s answered prefix %s where its namespace declares %s", row.pair, row.prefix, prefix))
        assert(row.kind == "1", string.format("pair %s wrote a tag of type %s, not String", row.pair, row.kind))
    end
    return rows
end

-- The C rows of the table: each row is its two strings, its URI, prefix and name, and the property constant it answers as a comment.
local function row_text(rows)
    local lines = {}
    for _, row in ipairs(rows) do
        table.insert(lines, string.format('    { "%s", "%s",', row["dictionary-value"], row["property-value"]))
        table.insert(lines, string.format('      "%s", "%s", "%s" },  // %s', row.uri, row.prefix, row.name, row.property))
    end
    return table.concat(lines, "\n") .. "\n"
end

-- The object of ImageIO's property table: name -> text. Empty for any other framework.
function objects(tree, fw)
    local out = {}
    if fw ~= FRAMEWORK then
        return out
    end
    local dir = layout.snap_dir(tree, fw)
    local table_text = files.read_text(path.join(dir, TABLE_NAME))
    assert(table_text ~= nil, "the measured property table is missing: " .. path.join(dir, TABLE_NAME))
    local template = files.read_text(path.join(dir, TEMPLATE_NAME))
    assert(template ~= nil, "the template of " .. OBJECT_NAME .. " is missing: " .. path.join(dir, TEMPLATE_NAME))
    local rows = checked_rows(tsv.records(table_text))
    local text = replace_plain(template, ROWS_MARK, row_text(rows))
    text = replace_plain(text, COUNT_MARK, tostring(#rows))
    out[OBJECT_NAME] = text
    return out
end

-- The (dictionary, property) pairs of a header: every property the header declares under a dictionary it names, in the header's order,
-- one entry per pair (two constants may share one string, and the pair is asked once).
local function pairs_of(header_text)
    local current = nil
    local out, seen = {}, {}
    for line in string.gmatch(header_text .. "\n", "([^\n]*)\n") do
        local section = string.match(line, "/%* Possible keys for (kCGImageProperty[%w_]+Dictionary) %*/")
        if section ~= nil then
            current = section
        else
            if string.match(line, "IMAGEIO_EXTERN const CFStringRef (kCGImageProperty[%w_]+Dictionary)%s") ~= nil then
                current = nil
            end
            local property = string.match(line, "IMAGEIO_EXTERN const CFStringRef (kCGImageProperty[%w_]+)%s")
            if property ~= nil and current ~= nil then
                local key = current .. " " .. property
                if not seen[key] then
                    seen[key] = true
                    table.insert(out, {current, property})
                end
            end
        end
    end
    return out
end

-- The header the probe reads its pair list from: the same text the python printed, with the producer line naming this module.
function pairs_header(header_text)
    local found = pairs_of(header_text)
    local lines = {
        "/* Generated by: xmake l tools/gen/property_map.lua <iOS SDK>/System/Library/Frameworks/ImageIO.framework/Headers/CGImageProperties.h",
        "   SDK used: the one this tree builds against; this file is generated, not edited. */",
        string.format("/* %d pairs: every property the header declares under a dictionary it names. */", #found),
        "typedef struct {",
        "    CFStringRef dictionary;",
        "    CFStringRef property;",
        "} charon_pair;",
        "",
        "static size_t charon_pairs(charon_pair *out)",
        "{",
    }
    for i, pair in ipairs(found) do
        table.insert(lines, string.format("    out[%d].dictionary = %s; out[%d].property = %s;", i - 1, pair[1], i - 1, pair[2]))
    end
    table.insert(lines, string.format("    return %d;", #found))
    table.insert(lines, "}")
    return table.concat(lines, "\n") .. "\n"
end

-- `xmake l tools/gen/property_map.lua HEADER`: prints the pair list of CGImageProperties.h to stdout.
function main(header)
    assert(header ~= nil, "usage: xmake l tools/gen/property_map.lua <CGImageProperties.h>")
    local text = files.read_text(header)
    assert(text ~= nil, "no header at " .. header)
    io.write(pairs_header(text))
end
