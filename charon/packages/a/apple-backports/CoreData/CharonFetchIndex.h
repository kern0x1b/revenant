#import <CoreData/CoreData.h>

@interface NSFetchIndexDescription () <NSSecureCoding>
- (void)_charon_setEntity:(NSEntityDescription *)entity;
- (void)_charon_throwIfNotEditable;
- (void)_charon_validateCollationTypeChangeFrom:(NSFetchIndexElementType)from to:(NSFetchIndexElementType)to;
@end

@interface NSFetchIndexElementDescription () <NSSecureCoding>
- (void)_charon_setIndexDescription:(NSFetchIndexDescription *)index;
@end

static inline BOOL charon_index_property_allowed(NSPropertyDescription *property)
{
    return [property isKindOfClass:[NSAttributeDescription class]] || [property isKindOfClass:[NSRelationshipDescription class]];
}
