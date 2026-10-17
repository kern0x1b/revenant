-- The ImageIO name constants the port does not carry, written one object per release band, with their registry rows and the
-- harness's pins. It replaces tools/corpus/gen-imageio-names.py, which did the same, and it reads its inputs from the repository:
--     packages/a/apple-backports/spec/ImageIO/ledger.tsv   the workspace ledger's ImageIO rows (a copy of the corpus ledger)
--     tests/backports/host/imageio-names/probe.c           the host probe that answers each name's value
-- and the first held rung of each name from tools/cache-index/first-rung.lua, which reads the index build.lua writes.
--
-- WHAT IT MEASURES ITSELF:
--   1. every value, with the HOST's own ImageIO over dlsym, one process per symbol, by compiling and running probe.c. Eleven of
--      these names are not their own name: kCGImagePropertyAVISDictionary is "{AVIS}", kCGImagePropertyGroupMonoscopicImageLocation
--      is "GroupImageIndexMonoscopicImageLocation", the two TIFF position names are "XPosition" and "YPosition", and the monoscopic
--      locations and the stereo aggressor keys are bare words, so no naming convention produces this table.
--   2. for every name, the first HELD RUNG that exports the SYMBOL, through tools/cache-index/first-rung.lua. A name no rung carries
--      is placed by the ledger's own introduced release, because the ladder ends at 10.3.4 and nothing else says anything about it.
--
-- It writes packages/a/apple-backports/Graphics/ImageIONames<TAG>.m and packages/a/apple-backports/registry/ImageIO/names<TAG>.json,
-- one pair per release, and rewrites tests/backports/host/imageio-names/objects.txt and expected.txt, which the harness pins.
--
--     xmake l tools/gen/imageio_names.lua [LEDGER] [OUT]
--
-- LEDGER defaults to the committed spec copy. OUT is the root the generated files and the harness pins are written under; it
-- defaults to this repository, and a scratch run names a copy of the same layout so the committed files are not touched. The probe
-- compiles and runs one process per name, so run it under the slot: coordination/heavy.sh xmake l tools/gen/imageio_names.lua

local tsv = import("tsv", {anonymous = true})
local pyjson = import("pyjson", {anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local ROOT = path.join(os.scriptdir(), "..", "..")
local PORT = path.join("packages", "a", "apple-backports")
local FRAMEWORK = "ImageIO"
local FACTS = "facts/ImageIO/Names.md"
local PROBE = path.join(ROOT, "tests", "backports", "host", "imageio-names", "probe.c")
local FIRST_RUNG = path.join(ROOT, "tools", "cache-index", "first-rung.lua")
local SPEC_LEDGER = path.join(ROOT, PORT, "spec", "ImageIO", "ledger.tsv")

-- suffix -> release the object's symbols are placed at, and one line saying why it is an object of its own
local BANDS = {
    ["1001"] = {"10.0.1", "the release's own caches first export these four symbols at iOS 10.0.1, and the 10.0.1 band has no object of its own yet"},
    ["160b"] = {"16.0", "the two BC names are annotated iOS 12.0 but their symbols first appear in a held rung at iOS 16.0, and kCGImagePropertyAVISDictionary is in no held rung at all, so its own annotation of iOS 16.0 places it beside them"},
    ["174"] = {"17.4", "no held rung carries the two TIFF position names - the ladder ends at 10.3.4 - so their own availability places them"},
    ["180"] = {"18.0", "fourteen of these are first exported by the iOS 18.0 caches and eleven are in no held rung with an iOS 18.0 annotation, so one object holds the whole of that band's answer"},
    ["260b"] = {"26.0", "the twelve are in no held rung and are annotated iOS 26.0; ImageIONames260.m already holds the one 26.0 name the port had, and a second object of the same band is what the split by symbol asks for"},
}

local SOURCE = "the host's own ImageIO with dlsym, one process per symbol, by tests/backports/host/imageio-names, which "
    .. "compiles these objects and links them into a pure C reader so the value compared against Apple's is the "
    .. "port's own: 'GREEN (port vs host): 438 agree, 0 differ' and 'imageio-names: 438 constants, 438 mutants "
    .. "run, 438 RED', the last line being the harness proving it can fail on every one of them"

-- The object's text. {name} is replaced once, in a single pass, so a value that holds a brace is not read again; {{ and }} are
-- the braces they stand for.
local OBJECT = [[#import <ImageIO/ImageIO.h>

// The iOS {release} band's ImageIO name constants, {count} of them that the port did not carry, one object per
// release band because release-split refuses an object whose symbols first appear in more than one release.
//
// {why}.
//
// EVERY VALUE WAS READ FROM THE HOST S OWN ImageIO with dlsym, one process per symbol, and printed as
// text and as bytes by tests/backports/host/imageio-names, which reads this object s values by LINKING it
// into a pure C reader so the value compared against Apple s is the port s own. A convention would have
// been wrong for eleven of these forty-six: kCGImagePropertyAVISDictionary is "{{AVIS}}", the two TIFF
// position names are "XPosition" and "YPosition", kCGImagePropertyGroupMonoscopicImageLocation is
// "GroupImageIndexMonoscopicImageLocation", and the four monoscopic locations and the three stereo
// aggressor keys are "Center", "Left", "Right", "Unspecified", "Severity", "SubTypeURI" and "Type".
// The same family holds both shapes, so no rule picks the right one and the measurement is the only thing
// that does.
//
// A name is plain data - a caller looks a metadata key up with it - so the port answers it itself and the
// release is never asked. They are const CFStringRef like every other in this family.

{externs}

{definitions}
]]

-- Renders the object's template: {{ and }} become one brace each, and each {name} becomes its value. The braces are first set
-- aside as two bytes that no template holds, so a value's own braces are never read as a placeholder.
local function render(template, values)
    local text = string.gsub(template, "{{", "\1")
    text = string.gsub(text, "}}", "\2")
    text = string.gsub(text, "{(%w+)}", function (key) return values[key] end)
    text = string.gsub(text, "\1", "{")
    return string.gsub(text, "\2", "}")
end

-- The text of a name's value as the host's ImageIO gives it, one probe process per name. The probe is compiled against the
-- host's frameworks into `build`; a name it does not know has no TYPE line and fails the assert, as the Python did.
local function measure_values(names, build)
    os.mkdir(build)
    local probe = path.join(build, "iio-probe")
    os.execv("xcrun", {"clang", "-w", PROBE, "-framework", "CoreFoundation", "-framework", "ImageIO", "-o", probe})
    local values = {}
    for _, name in ipairs(names) do
        local output = os.iorunv(probe, {name})
        local kind, text = nil, ""
        for line in string.gmatch(output, "[^\n]+") do
            if string.sub(line, 1, 7) == "  TYPE " then
                kind = string.match(string.sub(line, 8), "^%s*(.-)%s*$")
            elseif string.sub(line, 1, 8) == "  VALUE " then
                text = string.match(string.sub(line, 9), "^%s*(.-)%s*$")
            end
        end
        assert(kind == "cfstring" and text ~= "", "no CFString value for " .. name .. " (type " .. tostring(kind) .. ")")
        values[name] = text
    end
    return values
end

-- The first held rung of each name, from tools/cache-index/first-rung.lua: name TAB release, one line per name asked.
local function measure_rungs(names)
    local args = {"l", FIRST_RUNG}
    for _, name in ipairs(names) do
        table.insert(args, name)
    end
    local rungs = {}
    for line in string.gmatch(os.iorunv("xmake", args), "[^\n]+") do
        local name, release = string.match(line, "^([^\t]+)\t(.+)$")
        assert(name, "first-rung printed a line that is not name TAB release: " .. line)
        rungs[name] = release
    end
    return rungs
end

-- objects.txt in release order, with a dotted version (10.0.1) beside the release it follows.
local function harness_order(names)
    local function major_of(name)
        return tonumber(string.match(name, "^ImageIONames(%d+)"))
    end
    local function suffix_of(name)
        return string.match(name, "^ImageIONames%d+([a-z]?)%.m$") or ""
    end
    local ordered = table.join(names)
    table.sort(ordered, function (a, b)
        if major_of(a) ~= major_of(b) then
            return major_of(a) < major_of(b)
        end
        return suffix_of(a) < suffix_of(b)
    end)
    -- 10.0.1 reads as 1001 in the file name, which sorts after every other object; it goes back beside 10.0
    local tail, rest = {}, {}
    for _, name in ipairs(ordered) do
        if string.match(name, "^ImageIONames%d%d%d%d%.m$") then
            table.insert(tail, name)
        else
            table.insert(rest, name)
        end
    end
    for _, name in ipairs(tail) do
        local shorter = "ImageIONames" .. string.sub(name, 13, 15) .. ".m"
        local at = nil
        for index, candidate in ipairs(rest) do
            if candidate == shorter then
                at = index
            end
        end
        table.insert(rest, at and at + 1 or #rest + 1, name)
    end
    return rest
end

-- The names of the constants a band object declares and defines: the two patterns the harness counts by, line by line.
local function counted_names(text, into)
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        for _, pattern in ipairs({
            "^extern[ \t]+CFStringRef[ \t]+([A-Za-z0-9_]+)[ \t]*;",
            "^extern[ \t]+const[ \t]+CFStringRef[ \t]+([A-Za-z0-9_]+)[ \t]*;",
            "^extern[ \t]+CFStringRef[ \t]+const[ \t]+([A-Za-z0-9_]+)[ \t]*;",
            "^const[ \t]+CFStringRef[ \t]+([A-Za-z0-9_]+)[ \t]*=",
            "^CFStringRef[ \t]+const[ \t]+([A-Za-z0-9_]+)[ \t]*=",
        }) do
            local name = string.match(line, pattern)
            if name then
                into[name] = true
            end
        end
    end
    return into
end

local function read_bytes(filepath)
    local handle = assert(io.open(filepath, "rb"), "cannot read " .. filepath)
    local text = handle:read("a")
    handle:close()
    return text
end

local function write_bytes(filepath, text)
    io.writefile(filepath, text, {encoding = "binary"})
end

-- The ledger's rows as records: a missing ImageIO constant maps to the release the ledger introduces it at.
local function missing_constants(ledger)
    local introduced = {}
    local count = 0
    for _, row in ipairs(tsv.records(read_bytes(ledger))) do
        if row.kind == "constant" and row.status == "missing" then
            introduced[row.api] = row.introduced
            count = count + 1
        end
    end
    return introduced, count
end

function main(ledger, out)
    ledger = ledger or SPEC_LEDGER
    out = out or ROOT
    local graphics = path.join(out, PORT, "Graphics")
    local registry = path.join(out, PORT, "registry", FRAMEWORK)
    local harness = path.join(out, "tests", "backports", "host", "imageio-names")

    assert(os.isfile(ledger), "no ledger at " .. ledger)
    local introduced = missing_constants(ledger)
    local api_names = {}
    for api in pairs(introduced) do
        table.insert(api_names, api)
    end
    assert(#api_names > 0, "the ledger names no missing ImageIO constant")
    byteorder.sort(api_names)

    local build = path.join(ROOT, ".agent-work", "imageio-names")
    local values = measure_values(api_names, build)
    os.tryrm(build)
    local rungs = measure_rungs(api_names)

    local cut = {}
    for _, name in ipairs(api_names) do
        local release = rungs[name]
        if release == "NONE" then
            release = introduced[name]
        end
        local suffix = nil
        for tag, band in pairs(BANDS) do
            if band[1] == release then
                suffix = tag
            end
        end
        assert(suffix, "no band for " .. name .. " at " .. tostring(release))
        cut[suffix] = cut[suffix] or {}
        table.insert(cut[suffix], name)
    end

    local suffixes = {}
    for suffix in pairs(cut) do
        table.insert(suffixes, suffix)
    end
    byteorder.sort(suffixes)

    for _, suffix in ipairs(suffixes) do
        local names = cut[suffix]
        byteorder.sort(names)
        local release, why = BANDS[suffix][1], BANDS[suffix][2]
        local externs, definitions = {}, {}
        for _, name in ipairs(names) do
            table.insert(externs, "extern CFStringRef const " .. name .. ";")
            table.insert(definitions, 'CFStringRef const ' .. name .. ' = CFSTR("' .. values[name] .. '");')
        end
        local object = render(OBJECT, {
            release = release,
            count = tostring(#names),
            why = string.upper(string.sub(why, 1, 1)) .. string.sub(why, 2),
            externs = table.concat(externs, "\n"),
            definitions = table.concat(definitions, "\n"),
        })
        write_bytes(path.join(graphics, "ImageIONames" .. suffix .. ".m"), object)

        local entries = {}
        for _, name in ipairs(names) do
            table.insert(entries, {object = {
                {"api", name},
                {"kind", "constant"},
                {"introduced", introduced[name]},
                {"minimum", "6.0"},
                {"status", "implemented"},
                {"reason", "iOS 6 does not export the name; " .. why .. ", and it is carried with the text the host's own ImageIO gives it, so that an application that names it loads"},
                {"effect", "the string " .. values[name] .. ", which is the text Apple's own ImageIO gives this name and not always the name itself; nothing of iOS 6 produces it, and where an application hands it to the release the release treats it as it treats any string it does not know"},
                {"facts", FACTS},
                {"source", SOURCE},
            }})
        end
        local document = {object = {{"framework", FRAMEWORK}, {"entries", {array = entries}}}}
        write_bytes(path.join(registry, "names" .. suffix .. ".json"), pyjson.encode(document, "  ") .. "\n")
        print(string.format("%-28s %3d constants", "ImageIONames" .. suffix .. ".m", #names))
    end

    -- the harness counts every band object on disk and pins the total, so both files move with the slice
    local on_disk = {}
    for _, file in ipairs(os.files(path.join(graphics, "ImageIONames*.m"))) do
        table.insert(on_disk, path.filename(file))
    end
    local ordered = harness_order(on_disk)
    write_bytes(path.join(harness, "objects.txt"), table.concat(ordered, "\n") .. "\n")

    -- the names the harness can see, declared or defined, are the number it pins
    local counted = {}
    for _, name in ipairs(on_disk) do
        counted_names(read_bytes(path.join(graphics, name)), counted)
    end
    local total = 0
    for _ in pairs(counted) do
        total = total + 1
    end
    local expected = path.join(harness, "expected.txt")
    local pinned = {}
    for line in string.gmatch(read_bytes(expected), "([^\n]*)\n") do
        if string.match(line, "^constants=%d+$") then
            line = "constants=" .. total
        elseif string.match(line, "^objects=%d+$") then
            line = "objects=" .. #on_disk
        end
        table.insert(pinned, line)
    end
    write_bytes(expected, table.concat(pinned, "\n") .. "\n")
    print(string.format("%-28s %3d constants", "TOTAL", #api_names))
end
