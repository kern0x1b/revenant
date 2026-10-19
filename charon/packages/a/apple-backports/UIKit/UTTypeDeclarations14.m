#import <MobileCoreServices/MobileCoreServices.h>
#import "CharonUTType.h"

// The UTI declarations of the process itself, and what -[UTType version], -[UTType referenceURL] and
// the four +exported/importedTypeWithIdentifier: pair answer from them.
//
// Where the answer comes from. A Uniform Type Identifier's version and reference URL are declared
// properties of the type's declaration, not of the type: CoreServices/UTType.h lists
// kUTTypeVersionKey and kUTTypeReferenceURLKey among the keys of a Type Declaration Dictionary, and
// the only place a declaration is written down is an Info.plist -- the process's own
// UTExportedTypeDeclarations and UTImportedTypeDeclarations. So the port reads the same two arrays
// out of the same main-bundle dictionary, under the same key strings, that Apple's implementation
// reads; the strings are the ones the release's own kUT...Key constants carry, measured on the host
// (tests/backports/host/uttypeconstants prints all nine of them and the port's are compared against
// those). The keys are spelled as literals rather than read through kUT...Key because this release's
// CoreServices exports them as data symbols whose presence would have to be measured per band, and
// nothing else here needs them.
//
// What that means for a system type. iOS 6's UTI declarations live in LaunchServices' own store,
// which exports no accessor for a version or a reference URL (the release's UTType surface is
// UTTypeCreatePreferredIdentifierForTag, UTTypeCopyPreferredTagWithClass, UTTypeCopyAllTagsWithClass,
// UTTypeCopyDescription, UTTypeConformsTo and UTTypeIsDeclared/UTTypeIsDynamic, all of which the
// class in UTType.m already calls). So for every type the process does not declare, -version and
// -referenceURL answer nil -- which is what the host answers for the system types the differential
// reads, and what UTType.h itself documents ("Most types do not specify a version", "Most types do
// not specify reference URLs").
//
// +exportedTypeWithIdentifier: is documented to answer a type "declared as exported by the current
// process", and the host, whose process declares no export at all, answers the type carrying the
// identifier it was given. The port therefore answers the type for the identifier whenever the
// process has no declaration narrowing it, and the declaration when it has one. The
// conformingToType: forms are the same answer narrowed by the parent the header says the result is
// "expected to conform to", tested with the release's own UTTypeConformsTo.
//
// +importedTypeWithIdentifier: is the one with a rule of its own, and UTType.h states it: in the
// general case the method hands back a type sharing the identifier, unless that type names a preferred extension of its own,
// and then the extension is preferred by a different type, which is substituted.
// Both halves are the release's own functions -- UTTypeCopyPreferredTagWithClass
// for the extension and UTTypeCreatePreferredIdentifierForTag for the preferred type -- so the rule
// is carried out literally rather than approximated.

static NSArray *CharonUTTypeDeclarations(NSString *key)
{
    id declarations = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    return [declarations isKindOfClass:[NSArray class]] ? declarations : @[];
}

// The one declaration of either array whose UTTypeIdentifier is the identifier asked for.
static NSDictionary *CharonUTTypeDeclaration(NSString *identifier, NSString *key)
{
    for (NSDictionary *declaration in CharonUTTypeDeclarations(key)) {
        if ([declaration isKindOfClass:[NSDictionary class]]
            && [declaration[@"UTTypeIdentifier"] isEqual:identifier])
            return declaration;
    }
    return nil;
}

static UTType *CharonUTTypeNarrowedToParent(UTType *type, UTType *parentType)
{
    if (!type || !parentType)
        return type;
    return [type conformsToType:parentType] ? type : nil;
}

@implementation UTType (CharonDeclarations)

- (NSNumber *)version
{
    NSString *identifier = self.identifier;
    for (NSString *key in @[@"UTExportedTypeDeclarations", @"UTImportedTypeDeclarations"]) {
        id version = CharonUTTypeDeclaration(identifier, key)[@"UTTypeVersion"];
        if ([version isKindOfClass:[NSNumber class]])
            return version;
        if ([version isKindOfClass:[NSString class]])
            return @([version doubleValue]);
    }
    return nil;
}

- (NSURL *)referenceURL
{
    NSString *identifier = self.identifier;
    for (NSString *key in @[@"UTExportedTypeDeclarations", @"UTImportedTypeDeclarations"]) {
        id url = CharonUTTypeDeclaration(identifier, key)[@"UTTypeReferenceURL"];
        if ([url isKindOfClass:[NSString class]])
            return [NSURL URLWithString:url];
    }
    return nil;
}

- (NSSet<UTType *> *)supertypes
{
    // The set of types the receiver conforms to, directly or indirectly, taken over the catalogue the
    // port carries (see UIKit/UTTypeCatalogueIndex.m) with the release's own conformance test, which
    // is what -conformsToType: already calls. The receiver is not one of them: UTType.h calls this the
    // set of types the receiver conforms to, and UTTypeConformsTo answers YES for a type against
    // itself.
    NSMutableSet *supertypes = [NSMutableSet set];
    for (UTType *type in charon_uttype_catalogue_types()) {
        if (![type isEqual:self] && [self conformsToType:type])
            [supertypes addObject:type];
    }
    return supertypes;
}

+ (UTType *)exportedTypeWithIdentifier:(NSString *)identifier
{
    if (!identifier.length)
        return nil;
    NSDictionary *declaration = CharonUTTypeDeclaration(identifier, @"UTExportedTypeDeclarations");
    if (!declaration)
        declaration = CharonUTTypeDeclaration(identifier, @"UTImportedTypeDeclarations");
    return [self typeWithIdentifier:declaration[@"UTTypeIdentifier"] ?: identifier];
}

+ (UTType *)exportedTypeWithIdentifier:(NSString *)identifier conformingToType:(UTType *)parentType
{
    return CharonUTTypeNarrowedToParent([self exportedTypeWithIdentifier:identifier], parentType);
}

+ (UTType *)importedTypeWithIdentifier:(NSString *)identifier
{
    UTType *type = [self exportedTypeWithIdentifier:identifier];
    if (!type)
        return nil;
    NSString *extension = type.preferredFilenameExtension;
    if (!extension.length)
        return type;
    UTType *preferred = [self typeWithFilenameExtension:extension];
    return preferred ? preferred : type;
}

+ (UTType *)importedTypeWithIdentifier:(NSString *)identifier conformingToType:(UTType *)parentType
{
    return CharonUTTypeNarrowedToParent([self importedTypeWithIdentifier:identifier], parentType);
}

@end