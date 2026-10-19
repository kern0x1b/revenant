#import <CoreData/CoreData.h>

@interface NSFetchIndexDescription () <NSSecureCoding>
- (void)_revenant_setEntity:(NSEntityDescription *)entity;
- (void)_revenant_throwIfNotEditable;
- (void)_revenant_validateCollationTypeChangeFrom:(NSFetchIndexElementType)from to:(NSFetchIndexElementType)to;
@end

@interface NSFetchIndexElementDescription () <NSSecureCoding>
- (void)_revenant_setIndexDescription:(NSFetchIndexDescription *)index;
@end

static inline BOOL revenant_index_property_allowed(NSPropertyDescription *property)
{
    return [property isKindOfClass:[NSAttributeDescription class]] || [property isKindOfClass:[NSRelationshipDescription class]];
}
