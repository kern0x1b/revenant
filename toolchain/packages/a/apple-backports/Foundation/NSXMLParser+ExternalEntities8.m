#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantXMLPolicyKey;
static char RevenantXMLAllowedKey;

@implementation NSXMLParser (RevenantExternalEntities)

- (NSXMLParserExternalEntityResolvingPolicy)externalEntityResolvingPolicy
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantXMLPolicyKey);
    return (NSXMLParserExternalEntityResolvingPolicy)(stored ? stored.integerValue : NSXMLParserResolveExternalEntitiesNever);
}

- (void)setExternalEntityResolvingPolicy:(NSXMLParserExternalEntityResolvingPolicy)policy
{
    objc_setAssociatedObject(self, &RevenantXMLPolicyKey, @(policy), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setShouldResolveExternalEntities:policy != NSXMLParserResolveExternalEntitiesNever];
}

- (NSSet<NSURL *> *)allowedExternalEntityURLs
{
    return objc_getAssociatedObject(self, &RevenantXMLAllowedKey);
}

- (void)setAllowedExternalEntityURLs:(NSSet<NSURL *> *)urls
{
    objc_setAssociatedObject(self, &RevenantXMLAllowedKey, [urls copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
