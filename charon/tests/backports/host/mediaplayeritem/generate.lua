-- xmake l tests/backports/host/mediaplayeritem/generate.lua RELEASE
--
-- Emits one release group of MPMediaItem's properties, and the check's table, from ONE list.
--
-- The getters a group carries, the facts rows that cite them, and the table the host contract check
-- asserts are three places that would drift if they were written separately, so all three come from the
-- list below: this script writes the library file, replaces the group's facts rows, and writes the
-- check's table. RELEASE is 70, 80, 92, 100, 103 or 145.
--
--     xmake l tests/backports/host/mediaplayeritem/generate.lua 80
--
-- `key` is the property's own name, and `getter` is the header's `getter=` name when it has one. That the
-- dictionary key is the property name is the documented convention for MPMediaItem's property constants -
-- they are spelled as the property - and it is **not** verified against a populated item, because neither
-- this Mac nor 6.1.3 has one without a media library. What *is* measured is that the release has none of
-- these members at all, so a port-created item is the only thing that can answer them here.
--
-- Ported from generate.py. The facts rows are kept between a begin and an end marker per release, and
-- every release's block is kept in release order: a run replaces its own block, and the blocks two runs
-- of the old script appended are reduced to one each.

-- (property, type, getter, key) - the single list for this group. 7.0 was hand-written before the
-- generator existed and is here now, so one writer emits every group and none is typed twice.
local GROUP_70 = {{"albumTrackNumber", "NSUInteger", "albumTrackNumber", "albumTrackNumber"},
                  {"discNumber", "NSUInteger", "discNumber", "discNumber"}}
local GROUP_80 = {
    {"albumPersistentID", "MPMediaEntityPersistentID", "albumPersistentID", "albumPersistentID"},
    {"artistPersistentID", "MPMediaEntityPersistentID", "artistPersistentID", "artistPersistentID"},
    {"albumArtistPersistentID", "MPMediaEntityPersistentID", "albumArtistPersistentID", "albumArtistPersistentID"},
    {"genrePersistentID", "MPMediaEntityPersistentID", "genrePersistentID", "genrePersistentID"},
    {"composerPersistentID", "MPMediaEntityPersistentID", "composerPersistentID", "composerPersistentID"},
    {"podcastPersistentID", "MPMediaEntityPersistentID", "podcastPersistentID", "podcastPersistentID"},
    {"albumTrackCount", "NSUInteger", "albumTrackCount", "albumTrackCount"},
    {"discCount", "NSUInteger", "discCount", "discCount"},
    {"beatsPerMinute", "NSUInteger", "beatsPerMinute", "beatsPerMinute"},
    {"compilation", "BOOL", "isCompilation", "isCompilation"},
    {"cloudItem", "BOOL", "isCloudItem", "isCloudItem"},
    {"lyrics", "NSString *", "lyrics", "lyrics"},
    {"comments", "NSString *", "comments", "comments"},
    {"userGrouping", "NSString *", "userGrouping", "userGrouping"},
    {"assetURL", "NSURL *", "assetURL", "assetURL"},
}

-- The three groups after 8.0, with the release as the header writes it and as the file names it. Two of
-- the four are declared with a getter=, so the property name is the first field and the selector the third.
local GROUP_92 = {{"protectedAsset", "BOOL", "hasProtectedAsset", "hasProtectedAsset"}}
local GROUP_100 = {{"dateAdded", "NSDate *", "dateAdded", "dateAdded"},
                   {"explicitItem", "BOOL", "isExplicitItem", "isExplicit"}}
local GROUP_103 = {{"playbackStoreID", "NSString *", "playbackStoreID", "playbackStoreID"},
                   {"preorder", "BOOL", "isPreorder", "isPreorder"}}
local GROUP_145 = {}

-- The property-key constants, each the same-named string: the header declares them NSString * const and
-- the dictionary is keyed by the property's name, so a constant that named anything else would name a key
-- nothing reads. The release each arrived in is its own group's, per the header's MP_API.
-- A member's dictionary key is what the constant of that name holds, and this Mac's own MediaPlayer says
-- what that is: the property's own name, except where the 26.2 header declares a getter=, where the value
-- is the getter's name. Measured, not assumed - see constant-values.m, and the five keys it moved are the
-- ones with a getter= (isCompilation, isCloudItem, hasProtectedAsset, isExplicit, isPreorder).
--
-- The property-key constants, one per release, emitted as the globals the header declares: a
-- `NSString * const` at file scope, outside the @implementation, so a caller that spells the constant the
-- way Apple spells it links against a data symbol. A class property would be a method and would not.
local CONSTANTS = {
    [70] = {{"MPMediaItemPropertyIsExplicit", "isExplicit"}},
    [80] = {},
    [92] = {{"MPMediaItemPropertyHasProtectedAsset", "hasProtectedAsset"}},
    [100] = {{"MPMediaItemPropertyDateAdded", "dateAdded"}},
    [103] = {{"MPMediaItemPropertyPlaybackStoreID", "playbackStoreID"}},
    -- MPMediaItemPropertyIsPreorder is 14.5, so it has a group of its own rather than a neighbour's file:
    -- one object, one release, per band()'s own rule.
    [145] = {{"MPMediaItemPropertyIsPreorder", "isPreorder"}},
}

local GROUPS = {[70] = GROUP_70, [80] = GROUP_80, [92] = GROUP_92, [100] = GROUP_100, [103] = GROUP_103,
                [145] = GROUP_145}
-- The file and the table are named for the release without its dot; the header line quotes it with.
local LABEL = {[70] = "7.0", [80] = "8.0", [92] = "9.2", [100] = "10.0", [103] = "10.3", [145] = "14.5"}

-- How each type is read out of the property dictionary. A type with no entry is not carried.
local CONVERSION = {
    ["NSUInteger"] = "[[self valueForProperty:@\"%s\"] unsignedIntegerValue]",
    ["BOOL"] = "[[self valueForProperty:@\"%s\"] boolValue]",
    ["MPMediaEntityPersistentID"] = "(MPMediaEntityPersistentID)[self valueForProperty:@\"%s\"]",
    ["NSString *"] = "(NSString *)[self valueForProperty:@\"%s\"]",
    ["NSURL *"] = "(NSURL *)[self valueForProperty:@\"%s\"]",
    ["NSDate *"] = "(NSDate *)[self valueForProperty:@\"%s\"]",
}

local HEADER = [==[// MPMediaItem's %(count)d %(release)s members, the ones this release does not have at all.
//
// Generated from the one list in tests/backports/host/mediaplayeritem/generate.lua, with the facts rows
// and the host check's table, so the three cannot drift. Do not edit by hand: change the list and run the
// generator.
//
// What 6.1.3 has, measured against the 6.1.3 cache: none of these is in any of the image's 236 classes' own
// instance lists nor in any of its 41 categories - not on MPMediaItem (75 own methods), not on MPMediaEntity
// (18), not on MPConcreteMediaItem (29), the private class a real item's receiver is. What the release does
// have is the accessor they are conveniences over: valueForProperty: is an own method of MPMediaEntity. So a
// port-created item answers from its own dictionary, a real item is answered by the release, and a category
// on the public class clobbers nothing because a subclass's own method wins over a category on its public
// ancestor.
//
// Split by introduced release, per band()'s own rule: this file holds the %(count)d the 26.2 header
// declares MP_API(ios(%(release)s)).

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The host contract check compiles this file with the stand-in in place of the framework, so it measures
// this code and not the Mac's own MediaPlayer.
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Charon%(name)s)
%(declarations)s@end

%(constants_decl)s
@implementation MPMediaItem (Charon%(name)s)

%(bodies)s@end

%(constants_def)s]==]

local function fill(template, values)
    return (template:gsub("%%%(([%w_]+)%)[ds]", function(key) return tostring(values[key]) end))
end

local function fmt(template, value)
    return (template:gsub("%%s", function() return value end))
end

local function read(file)
    local handle = io.open(file, "rb")
    if not handle then return nil end
    local text = handle:read("a")
    handle:close()
    return text
end

local function write(file, text)
    local handle = assert(io.open(file, "wb"))
    handle:write(text)
    handle:close()
end

local function emit(release, members, root)
    local label = LABEL[release]
    local library = path.join(root, "packages", "a", "apple-backports", "MediaPlayer", "MPMediaItem" .. release .. ".m")
    local declarations, bodies = {}, {}
    local constants = CONSTANTS[release] or {}
    -- The value is the property's own name, which is the dictionary key - the same convention the
    -- getters use and the same one coordination/crutches.md records as unverified.
    local constants_decl, constants_def = {}, {}
    for _, constant in ipairs(constants) do
        table.insert(constants_decl, "extern NSString * const " .. constant[1] .. ";\n")
        table.insert(constants_def, "NSString * const " .. constant[1] .. " = @\"" .. constant[2] .. "\";\n")
    end
    for _, member in ipairs(members) do
        local name, kind, getter, key = member[1], member[2], member[3], member[4]
        if not CONVERSION[kind] then
            error(name .. " has type " .. kind .. ", which this generator cannot read")
        end
        table.insert(declarations, "@property (nonatomic, readonly) " .. kind .. " " .. name .. ";\n")
        table.insert(bodies, "- (" .. kind .. ")" .. getter .. " {\n    return " .. fmt(CONVERSION[kind], key)
                             .. ";\n}\n\n")
    end
    write(library, fill(HEADER, {count = #members, release = label, name = release,
                                 declarations = table.concat(declarations), bodies = table.concat(bodies),
                                 constants_decl = table.concat(constants_decl),
                                 constants_def = table.concat(constants_def)}))

    local table_file = path.join(root, "tests", "backports", "host", "mediaplayeritem", "members" .. release .. ".h")
    local rows = {"// Generated by tests/backports/host/mediaplayeritem/generate.lua from its one list.\n",
                  "// (getter, type, key)\n"}
    for _, member in ipairs(members) do
        table.insert(rows, string.format('    {"%s", "%s", "%s"},\n', member[3], member[2], member[4]))
    end
    write(table_file, table.concat(rows))

    local facts = path.join(root, "packages", "a", "apple-backports", "facts", "MediaPlayer", "MPMediaItem.md")
    write_facts(facts, release, members, label)
    print(string.format("wrote %s, %s and the facts rows from %d members", library, table_file, #members))
end

-- The facts rows for a release, written by this script and only by it.
--
-- They live between markers so a re-run replaces them rather than appending a second copy: two writers
-- of the same rows is the drift this generator exists to remove. The blocks are kept in release order.
function write_facts(facts, release, members, label)
    local header = {}
    local renamed = {}
    for _, member in ipairs(members) do
        local name, kind, getter = member[1], member[2], member[3]
        local getter_part = getter ~= name and (", getter = " .. getter) or ""
        table.insert(header, string.format("    @property (nonatomic, readonly%s) %s %s MP_API(ios(%s));",
                                           getter_part, kind, name, label))
        if getter ~= name then table.insert(renamed, {name, getter}) end
    end
    local body = {
        string.format("<!-- generated: %d -->", release),
        "",
        string.format("## %s - `MPMediaItem%d.m`", label, release),
        "",
        string.format("The %d members the 26.2 header declares `MP_API(ios(%s))`, generated from the one list in",
                      #members, label),
        "`tests/backports/host/mediaplayeritem/generate.lua` together with the getters and the check's table:",
        "",
        table.concat(header, "\n"),
        "",
        "Each member's dictionary key is the property's own name, which is the documented convention for",
        "MPMediaItem's property constants and the only reading the header's spelling supports. It is **not**",
        "verified against a populated item, because neither this Mac nor 6.1.3 can be given one without a",
        "media library; what *is* measured is that the release carries none of these members, so a",
        "port-created item - one built from a dictionary, which is exactly what the stand-in in the contract",
        "check is - is the only thing that can answer them here.",
    }
    if #renamed > 0 then
        local parts = {}
        for _, pair in ipairs(renamed) do
            table.insert(parts, string.format("`%s` is implemented as `%s`", pair[1], pair[2]))
        end
        table.insert(body, "")
        table.insert(body, "Declared with a `getter=` attribute, so the property name is not the selector: "
                           .. table.concat(parts, ", ") .. ".")
    end
    table.insert(body, string.format("<!-- /generated: %d -->", release))
    local block = table.concat(body, "\n") .. "\n"

    local text = read(facts) or "# MPMediaItem\n"
    -- Collect every block in the file, first occurrence of each release wins, and the run's own block
    -- replaces the one it has.
    local first, last_end = nil, nil
    local found, order = {}, {}
    local position = 1
    while true do
        local begin_at, begin_end, number = text:find("<!%-%- generated: (%d+) %-%->\n", position)
        if not begin_at then break end
        local close_pattern = "<!%-%- /generated: " .. number .. " %-%->\n"
        local close_at, close_end = text:find(close_pattern, begin_end + 1)
        assert(close_at, "facts: no end marker for release " .. number)
        local release_number = tonumber(number)
        if not first then first = begin_at end
        last_end = close_end
        if not found[release_number] then
            found[release_number] = text:sub(begin_at, close_end)
            table.insert(order, release_number)
        end
        position = close_end + 1
    end
    if first then
        found[release] = block
        local present = false
        for _, n in ipairs(order) do if n == release then present = true end end
        if not present then table.insert(order, release) end
        table.sort(order)
        local parts = {}
        for _, n in ipairs(order) do table.insert(parts, found[n]) end
        local region = table.concat(parts, "")
        write(facts, text:sub(1, first - 1) .. region .. text:sub(last_end + 1))
    else
        write(facts, text:gsub("\n*$", "\n") .. block)
    end
end

function main(release)
    release = tonumber(release)
    if not GROUPS[release] then
        error("no list for release " .. tostring(release) .. "; add one to GROUPS")
    end
    local root = path.absolute(path.join(os.scriptdir(), "..", "..", "..", ".."))
    emit(release, GROUPS[release], root)
end
