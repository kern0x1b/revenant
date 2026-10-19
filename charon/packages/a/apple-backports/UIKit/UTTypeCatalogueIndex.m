#import <Foundation/Foundation.h>
#import "CharonUTType.h"

// The index of UniformTypeIdentifiers' system type catalogue, which the four
// UIKit/UTTypeCatalogue<BAND>.m files each fill with their own band's constants.
//
// It exists for -[UTType supertypes], which the SDK documents as the set of types that a type conforms to, directly
// or indirectly. The release answers the conformance question
// itself -- UTTypeConformsTo(UTTypeConformsTo.h, iOS 3) is what -conformsToType: already calls --
// but it exports no function that enumerates a type's supertypes, so the set has to be built by
// asking the release about each type in the catalogue. That is the same direction Apple's own
// implementation walks: over the catalogue of declared types, testing conformance to each.
//
// The catalogue is collected at run time rather than written out a second time here, because a
// second copy of a table that exists is exactly the drift the self-review table forbids: adding a
// constant to UTTypeCatalogue14.m would otherwise have to be added here too, and nothing would say
// so. Each catalogue file hands its own types over in its own constructor.
//
// This object is in the deployment band and in every band above it: it exports no API symbol of its
// own (modules/apple/backports.lua's internal_symbol() reads a name beginning `charon_` as Charon's
// own helper, not as API), so no release places anything in it and nothing has to drop it from a
// later band that the files calling it would then miss. That is the same reason Foundation/
// CharonOSLogCore.m is a file of its own rather than a function inside one of the OSLog objects.

static NSMutableArray *charon_uttype_catalogue;

void charon_uttype_catalogue_add(NSArray *types)
{
    if (!types.count)
        return;
    if (!charon_uttype_catalogue)
        charon_uttype_catalogue = [[NSMutableArray alloc] init];
    [charon_uttype_catalogue addObjectsFromArray:types];
}

NSArray *charon_uttype_catalogue_types(void)
{
    return charon_uttype_catalogue ? [charon_uttype_catalogue copy] : @[];
}