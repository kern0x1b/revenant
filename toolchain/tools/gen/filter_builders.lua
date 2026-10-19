local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local layout = import("layout", {anonymous = true})
local order = import("order", {anonymous = true})

local FRAMEWORK = "CoreImage"
local TABLE_NAME = "filter-builders.tsv"
local MEASURE_NAME = "filter-builders-differential.tsv"

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

local BY_VERSION = {}
for tag, band in pairs(BANDS) do
    BY_VERSION[band.version] = tag
end

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
// on it, and revenant_collect installs a category method only where the class does not answer the
// selector, which is exactly the band this object is for.

@implementation CIFilter ({category})

]]

local function fill(text, values)
    return (string.gsub(text, "{(%a+)}", function(key)
        assert(values[key] ~= nil, "the object's text names {" .. key .. "}, which has no value")
        return tostring(values[key])
    end))
end

local function method_text(selector, name)
    return "+ (CIFilter *)" .. selector .. "\n{\n    return [CIFilter filterWithName:@\"" .. name .. "\"];\n}\n\n"
end

local function measured_rows(text)
    local rows = tsv.records(text)
    for _, row in ipairs(rows) do
        assert(row.selector ~= nil and row.selector ~= "", "a row names no selector")
        assert(row["filter-name"] ~= nil and row["filter-name"] ~= "", "the row of " .. row.selector .. " names no filter")
    end
    return rows
end

local function band_of(row)
    local tag = BY_VERSION[row.rung]
    if tag == nil then
        tag = BY_VERSION[row.introduced]
    end
    assert(tag ~= nil, string.format("%s is first held at %s and introduced at %s, which name no band", row.selector, row.rung, row.introduced))
    return tag
end

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
            examplename = example["filter-name"], category = "RevenantFilterBuiltins" .. tag, checked = counts["fields-compared"],
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
