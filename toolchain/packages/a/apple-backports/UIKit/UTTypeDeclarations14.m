#import <MobileCoreServices/MobileCoreServices.h>
#import "CharonUTType.h"

static NSArray *CharonUTTypeDeclarations(NSString *key)
{
    id declarations = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    return [declarations isKindOfClass:[NSArray class]] ? declarations : @[];
}

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
