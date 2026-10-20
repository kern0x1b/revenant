local tsv = import("tsv", {anonymous = true})
local pyjson = import("pyjson", {anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local ROOT = path.join(os.scriptdir(), "..", "..")
local PORT = path.join("packages", "frameworks", "apple-backports")
local FRAMEWORK = "ImageIO"
local FACTS = "facts/ImageIO/Names.md"
local PROBE = path.join(ROOT, "tests", "backports", "host", "imageio-names", "probe.c")
local FIRST_RUNG = path.join(ROOT, "tools", "cache-index", "first-rung.lua")
local SPEC_LEDGER = path.join(ROOT, PORT, "spec", "ImageIO", "ledger.tsv")

local BANDS = {
    ["1001"] = {"10.0.1", "the release's own caches first export these four symbols at iOS 10.0.1, and the 10.0.1 band has no object of its own yet"},
    ["134"] = {"13.4", "the two BC names, kCGImagePropertyBCEncoder and kCGImagePropertyBCFormat, are annotated iOS 12.0, and the first held rung that exports their symbols is iOS 13.4, the release the cache index answers for both"},
    ["160b"] = {"16.0", "the AVIS name, kCGImagePropertyAVISDictionary, is in no held rung at all, so its own annotation of iOS 16.0 places it"},
    ["174"] = {"17.4", "no held rung carries the two TIFF position names - the ladder ends at 10.3.4 - so their own availability places them"},
    ["180"] = {"18.0", "fourteen of these are first exported by the iOS 18.0 caches and eleven are in no held rung with an iOS 18.0 annotation, so one object holds the whole of that band's answer"},
    ["260b"] = {"26.0", "the twelve are in no held rung and are annotated iOS 26.0; ImageIONames260.m already holds the one 26.0 name the port had, and a second object of the same band is what the split by symbol asks for"},
}

local SOURCE = "the host's own ImageIO with dlsym, one process per symbol, by tests/backports/host/imageio-names, which "
    .. "compiles these objects and links them into a pure C reader so the value compared against Apple's is the "
    .. "port's own: 'GREEN (port vs host): 438 agree, 0 differ' and 'imageio-names: 438 constants, 438 mutants "
    .. "run, 438 RED', the last line being the harness proving it can fail on every one of them"

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

local function render(template, values)
    local text = string.gsub(template, "{{", "\1")
    text = string.gsub(text, "}}", "\2")
    text = string.gsub(text, "{(%w+)}", function (key) return values[key] end)
    text = string.gsub(text, "\1", "{")
    return string.gsub(text, "\2", "}")
end

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

function main(ledger, out, mode)
    local objects_only = mode == "--objects"
    out = out or ROOT
    local port = path.join(out, PORT)
    local registry = path.join(port, "registry", FRAMEWORK)
    local harness = path.join(out, "tests", "backports", "host", "imageio-names")
    local spec = path.join(port, "spec", FRAMEWORK, "names.tsv")
    local objects_dir = path.join(port, ".gen", FRAMEWORK)
    os.mkdir(objects_dir)

    local introduced, values, suffix_of = {}, {}, {}
    if objects_only then
        assert(os.isfile(spec), "no spec snapshot at " .. spec .. ": the full run (tools/gen/imageio_names.lua with no mode) writes it")
        for _, row in ipairs(tsv.records(read_bytes(spec))) do
            introduced[row.api] = row.introduced
            values[row.api] = row.value
            suffix_of[row.api] = row.band
        end
    else
        ledger = (ledger and ledger ~= "") and ledger or SPEC_LEDGER
        assert(os.isfile(ledger), "no ledger at " .. ledger)
        introduced = missing_constants(ledger)
        local api_names = {}
        for api in pairs(introduced) do
            table.insert(api_names, api)
        end
        assert(#api_names > 0, "the ledger names no missing ImageIO constant")
        byteorder.sort(api_names)

        local build = import("workspace", {rootdir = path.join(ROOT, "modules"), anonymous = true}).fresh("imageio-names")
        values = measure_values(api_names, build)
        os.tryrm(build)
        local rungs = measure_rungs(api_names)

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
            suffix_of[name] = suffix
        end

        local rows = {"api\tband\tintroduced\tvalue"}
        for _, name in ipairs(api_names) do
            table.insert(rows, name .. "\t" .. suffix_of[name] .. "\t" .. introduced[name] .. "\t" .. values[name])
        end
        os.mkdir(path.directory(spec))
        write_bytes(spec, table.concat(rows, "\n") .. "\n")
    end

    local cut = {}
    local api_names = {}
    for name, suffix in pairs(suffix_of) do
        cut[suffix] = cut[suffix] or {}
        table.insert(cut[suffix], name)
        table.insert(api_names, name)
    end
    byteorder.sort(api_names)

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
        write_bytes(path.join(objects_dir, "ImageIONames" .. suffix .. ".m"), object)

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
        if not objects_only then
            write_bytes(path.join(registry, "names" .. suffix .. ".json"), pyjson.encode(document, "  ") .. "\n")
        end
        print(string.format("%-28s %3d constants", "ImageIONames" .. suffix .. ".m", #names))
    end

    if objects_only then
        return
    end

    local on_disk, where = {}, {}
    for _, dir in ipairs({path.join(port, "Graphics"), objects_dir}) do
        for _, file in ipairs(os.files(path.join(dir, "ImageIONames*.m"))) do
            local name = path.filename(file)
            table.insert(on_disk, name)
            where[name] = file
        end
    end
    local ordered = harness_order(on_disk)
    write_bytes(path.join(harness, "objects.txt"), table.concat(ordered, "\n") .. "\n")

    local counted = {}
    for _, name in ipairs(on_disk) do
        counted_names(read_bytes(where[name]), counted)
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
