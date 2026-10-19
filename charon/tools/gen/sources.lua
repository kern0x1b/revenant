-- The sources the generator reads and the open-source leads it may read as references: the tables the README of each
-- framework prints. One place for the rows; the generated README takes its tables from here.

local sdk = import("sdk", {anonymous = true})

local OSS_LEADS = {
    {"swift-corelibs-foundation", "swift-corelibs-foundation", "Apache-2.0", "link", "candidate, not pinned"},
    {"swift-foundation", "swift-foundation", "Apache-2.0", "link", "candidate, not pinned"},
    {"winobjc", "WinObjC (UIKit)", "MIT", "link", "candidate, not pinned"},
    {"chameleon", "Chameleon (UIKit)", "BSD", "link", "candidate, not pinned"},
    {"apple-oss-distributions", "CoreFoundation, objc4, libdispatch", "APSL-2.0", "reference-only", "reference only, by the owner's rule"},
    {"gnustep", "GNUstep base and gui", "LGPL / GPL", "reference-only", "reference only"},
}

-- The rows of the sources table for one SDK release (the version sdk.discover reads): name, kind, licence, loader, status, what it adds.
-- The rows that name the release take it here, so the table of a release bump is the same table with its own release.
function sources(release)
    local names = sdk.names(release)
    return {
        {names.sdk_id, "Apple SDK " .. release .. " headers", "Apple SDK licence (read as input, never shipped)", "cmd_input: constant_decls, members_of", "built", "every constant, property and method declaration; hashes"},
        {"tbd-" .. release, "Apple SDK " .. release .. " .tbd export lists", "Apple SDK licence (read as input)", "tbd_exports", "built", "per row, whether " .. release .. " exports the symbol (constants) or the class (members), arm64 slice"},
        {"oracle-host", "macOS host framework, dlsym", "read at run time, never copied", "probe: tools/gen-objc-constants-oracle.m", "built", "string constant values, as macOS holds them"},
        {"oracle-defaults", "host and Catalyst capture of default values", "read at run time, never copied", "not built", "planned: v-cache26 item 8", "defaults for members without a value source"},
        {names.cache_dir, "iOS " .. release .. " dyld cache, extracted by v-cache26", "Apple, read as input", "not built", "planned: coordination/corpus/" .. names.cache_dir .. "/", "exported symbols and ObjC metadata of " .. release .. " itself"},
        {"icu-tzdb", "ICU and tzdb data", "Unicode licence / public domain; pinned package, compact tables generated in tools/", "not built", "planned", "formatter, collation, calendar and zone tables"},
        {"ipsw-resources", "iOS IPSW resources listed by v-cache26", "Apple, read as input; ipsw never run without asking", "not built", "planned: listed by v-cache26 only", "images, strings and resource data of the release"},
    }
end

-- The rows of the open-source leads table: lead, library, licence, use, status.
function oss_leads()
    return OSS_LEADS
end
