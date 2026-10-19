#import "RevenantFetchIndex.h"
#import <objc/runtime.h>

static const char RevenantIndexesKey;
static const char RevenantSpotlightKey;

@implementation NSEntityDescription (RevenantIndexes)

- (NSArray<NSFetchIndexDescription *> *)indexes
{
    return objc_getAssociatedObject(self, &RevenantIndexesKey) ?: @[];
}

- (void)setIndexes:(NSArray<NSFetchIndexDescription *> *)indexes
{
    if ([self respondsToSelector:@selector(_throwIfNotEditable)])
        [self performSelector:@selector(_throwIfNotEditable)];
    NSMutableSet *names = [NSMutableSet set];
    for (NSFetchIndexDescription *index in indexes) {
        if ([names containsObject:index.name])
            [NSException raise:NSInvalidArgumentException format:@"Entity %@ already has an index with name %@", self.name, index.name];
        [names addObject:index.name];
        for (NSFetchIndexElementDescription *element in index.elements) {
            NSString *name = element.propertyName;
            if ([element.property isKindOfClass:[NSAttributeDescription class]]) {
                if (!self.attributesByName[name])
                    [NSException raise:NSInvalidArgumentException format:@"can't find attribute named %@", name];
            } else if (!self.relationshipsByName[name]) {
                [NSException raise:NSInvalidArgumentException format:@"can't find relationship named %@", name];
            }
        }
    }
    NSArray *held = [indexes copy];
    for (NSFetchIndexDescription *index in held)
        [index _revenant_setEntity:self];
    objc_setAssociatedObject(self, &RevenantIndexesKey, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSExpression *)coreSpotlightDisplayNameExpression
{
    return objc_getAssociatedObject(self, &RevenantSpotlightKey);
}

- (void)setCoreSpotlightDisplayNameExpression:(NSExpression *)expression
{
    if ([self respondsToSelector:@selector(_throwIfNotEditable)])
        [self performSelector:@selector(_throwIfNotEditable)];
    objc_setAssociatedObject(self, &RevenantSpotlightKey, expression, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
