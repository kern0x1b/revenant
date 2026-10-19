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

local GROUP_92 = {{"protectedAsset", "BOOL", "hasProtectedAsset", "hasProtectedAsset"}}
local GROUP_100 = {{"dateAdded", "NSDate *", "dateAdded", "dateAdded"},
                   {"explicitItem", "BOOL", "isExplicitItem", "isExplicit"}}
local GROUP_103 = {{"playbackStoreID", "NSString *", "playbackStoreID", "playbackStoreID"},
                   {"preorder", "BOOL", "isPreorder", "isPreorder"}}
local GROUP_145 = {}

local CONSTANTS = {
    [70] = {{"MPMediaItemPropertyIsExplicit", "isExplicit"}},
    [80] = {},
    [92] = {{"MPMediaItemPropertyHasProtectedAsset", "hasProtectedAsset"}},
    [100] = {{"MPMediaItemPropertyDateAdded", "dateAdded"}},
    [103] = {{"MPMediaItemPropertyPlaybackStoreID", "playbackStoreID"}},
    [145] = {{"MPMediaItemPropertyIsPreorder", "isPreorder"}},
}

local GROUPS = {[70] = GROUP_70, [80] = GROUP_80, [92] = GROUP_92, [100] = GROUP_100, [103] = GROUP_103,
                [145] = GROUP_145}
local LABEL = {[70] = "7.0", [80] = "8.0", [92] = "9.2", [100] = "10.0", [103] = "10.3", [145] = "14.5"}

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
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
// The host contract check compiles this file with the stand-in in place of the framework, so it measures
// this code and not the Mac's own MediaPlayer.
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Revenant%(name)s)
%(declarations)s@end

%(constants_decl)s
@implementation MPMediaItem (Revenant%(name)s)

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
