-- The CIFilter convenience constructors of CoreImage, one object per band of the release that first exports them, written into
-- .gen/CoreImage/ from the measured table spec/CoreImage/filter-builders.tsv: one row per class method of CIFilter the host answers
-- (its selector, the filter name the host gives it, the first held rung that exports the selector, and the SDK's introduced release).
-- A selector no held rung exports is placed by its introduced release, because the ladder ends before the release that adds it.
--
-- The counts the object's header states come from the differential that compares the port's objects with the host's own
-- (tests/backports/host/ciimagefilter), recorded in spec/CoreImage/filter-builders-differential.tsv. This module does not run that
-- differential, and the record is what it was measured as, not what it would measure now.
--
-- It replaces tools/corpus/gen-cifilter-builtins.py, which measured the same table and wrote the same objects. The registry rows that
-- script wrote are committed (registry/CoreImage/filterbuilders<tag>.json) and are not written here.

local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local layout = import("layout", {anonymous = true})
local order = import("order", {anonymous = true})

local FRAMEWORK = "CoreImage"
local TABLE_NAME = "filter-builders.tsv"
local MEASURE_NAME = "filter-builders-differential.tsv"

-- The band of each object: its tag in the file name, the release it names, and the reason the release is a band of its own. The tags are
-- the file names' suffixes, and the release is the first held rung a band's selectors are in (or their introduced release, for none).
local BANDS = {
    ["7"] = {version = "7.0", why = "iOS 7.0 is the first held rung that exports +gaussianBlurFilter."},
    ["80"] = {version = "8.0", why = "iOS 8.0 is the first held rung that exports +colorCubeFilter and +vibranceFilter."},
    ["841"] = {version = "8.4.1", why = "iOS 8.4.1 is the first held rung that exports +colorMatrixFilter."},
    ["11"] = {version = "11.0", why = "iOS 11.0 is the first held rung that exports +edgesFilter."},
    ["16"] = {version = "16.0", why = "iOS 16.0 is the first held rung that exports the other 220, and the release that started "
        .. "answering the family."},
    ["18"] = {version = "18.0", why = "iOS 18.0 is the first held rung that exports the other eight."},
    ["26"] = {version = "26.0", why = "the other six are in no held rung at all - the ladder ends at 10.3.4 - so their own SDK "
        .. "availability places them."},
}

-- The release of each band, back to its tag.
local BY_VERSION = {}
for tag, band in pairs(BANDS) do
    BY_VERSION[band.version] = tag
end

-- The object's header. Its {name} fields are the values of the object, filled in by fill below; the text is the one the python wrote.
local OBJECT = [[#import <CoreImage/CoreImage.h>

// The CIFilter convenience constructors of iOS {version}: {count} of the {total} the SDK's own
// CIFilterBuiltins.h declares, which are class methods that take nothing and answer a filter.
//
// {why}
//
// WHAT THEY ARE, MEASURED: on the host, +[CIFilter {example}] answers exactly the object
// +[CIFilter filterWithName:@"{examplename}"] answers - the same class, the same name, the same
// inputKeys, outputKeys and attributes, and, for {rendered} of the {total}, the same rendered RGBA
// bytes over a fixed 32x32 window.  tests/backports/host/ciimagefilter/ builds these very objects with
// their selectors prefixed and asks both in one process; it compared {checked} fields over all {total}
// constructors, rendered and compared {rendered} of them, and reported {different} differences.  Every
// input of every filter is given the value a FRESH filter of that name already answers for it, so the
// values compared are Apple's own defaults and not ones the harness chose; the two it cannot render are
// named in facts/CoreImage/FilterBuiltins.md.
//
// So each method here is that one call, and the filter's own arithmetic is the release's:
// +filterWithName: is exported from iOS 3.0 and answers nil for a name the release has no filter of,
// which is what Apple documents for a filter that does not exist on the running system
// (facts/CoreImage/ImageApplyingFilter.md).
//
// The port carries CIFilter's constructors and not CIFilter: the class is the release's own from
// iOS 5.0 (tools/cache-index/first-rung.lua _OBJC_CLASS_$_CIFilter -> 5.0), so these are a category
// on it, and charon_collect installs a category method only where the class does not answer the
// selector, which is exactly the band this object is for.

@implementation CIFilter ({category})

]]

-- The text of {name} with each {key} of values replaced by its value; a key the values do not give is refused.
local function fill(text, values)
    return (string.gsub(text, "{(%a+)}", function(key)
        assert(values[key] ~= nil, "the object's text names {" .. key .. "}, which has no value")
        return tostring(values[key])
    end))
end

-- One constructor: the class method that answers the host's filter of that name.
local function method_text(selector, name)
    return "+ (CIFilter *)" .. selector .. "\n{\n    return [CIFilter filterWithName:@\"" .. name .. "\"];\n}\n\n"
end

-- The table's rows, checked: each selector and name is present, and each names a band the objects are written for.
local function measured_rows(text)
    local rows = tsv.records(text)
    for _, row in ipairs(rows) do
        assert(row.selector ~= nil and row.selector ~= "", "a row names no selector")
        assert(row["filter-name"] ~= nil and row["filter-name"] ~= "", "the row of " .. row.selector .. " names no filter")
    end
    return rows
end

-- The band a row is written in: the release of the first held rung that exports its selector, or, where no held rung does, the release
-- the SDK introduces it in. Refused when that release is not the release of one of the bands.
local function band_of(row)
    local tag = BY_VERSION[row.rung]
    if tag == nil then
        tag = BY_VERSION[row.introduced]
    end
    assert(tag ~= nil, string.format("%s is first held at %s and introduced at %s, which name no band", row.selector, row.rung, row.introduced))
    return tag
end

-- The differential's numbers, as the record gives them: the constructors it compared, the fields, the rendered, and the differences.
local function measured_counts(text)
    local counts = {}
    for _, row in ipairs(tsv.records(text)) do
        counts[row.measure] = tonumber(row.value)
    end
    for _, key in ipairs({"constructors", "fields-compared", "rendered", "different"}) do
        assert(counts[key] ~= nil, "the differential record has no " .. key)
    end
    return counts
end

-- The objects of CoreImage that the measured table defines: name -> text, each name a file of .gen/CoreImage/. Empty for any other framework.
function objects(tree, fw)
    local out = {}
    if fw ~= FRAMEWORK then
        return out
    end
    local dir = layout.snap_dir(tree, fw)
    local table_text = files.read_text(path.join(dir, TABLE_NAME))
    assert(table_text ~= nil, "the measured table is missing: " .. path.join(dir, TABLE_NAME))
    local record_text = files.read_text(path.join(dir, MEASURE_NAME))
    assert(record_text ~= nil, "the differential record is missing: " .. path.join(dir, MEASURE_NAME))
    local rows = measured_rows(table_text)
    local counts = measured_counts(record_text)
    assert(counts.constructors == #rows, string.format("the table has %d constructors and the record says %d", #rows, counts.constructors))

    local by_band = {}
    for _, row in ipairs(rows) do
        local tag = band_of(row)
        by_band[tag] = by_band[tag] or {}
        table.insert(by_band[tag], row)
    end
    for tag, band_rows in pairs(by_band) do
        table.sort(band_rows, function(a, b)
            return order.less(a.selector, b.selector)
        end)
        local band = BANDS[tag]
        local example = band_rows[1]
        local values = {
            version = band.version, count = #band_rows, total = #rows, why = band.why, example = example.selector,
            examplename = example["filter-name"], category = "CharonFilterBuiltins" .. tag, checked = counts["fields-compared"],
            rendered = counts.rendered, different = counts.different,
        }
        local parts = {fill(OBJECT, values)}
        for _, row in ipairs(band_rows) do
            table.insert(parts, method_text(row.selector, row["filter-name"]))
        end
        table.insert(parts, "@end\n")
        out["CIFilterBuiltins" .. tag .. ".m"] = table.concat(parts)
    end
    return out
end
