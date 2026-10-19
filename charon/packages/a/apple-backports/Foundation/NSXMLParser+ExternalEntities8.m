#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char CharonXMLPolicyKey;
static char CharonXMLAllowedKey;

@implementation NSXMLParser (CharonExternalEntities)

- (NSXMLParserExternalEntityResolvingPolicy)externalEntityResolvingPolicy
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonXMLPolicyKey);
    return (NSXMLParserExternalEntityResolvingPolicy)(stored ? stored.integerValue : NSXMLParserResolveExternalEntitiesNever);
}

- (void)setExternalEntityResolvingPolicy:(NSXMLParserExternalEntityResolvingPolicy)policy
{
    objc_setAssociatedObject(self, &CharonXMLPolicyKey, @(policy), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setShouldResolveExternalEntities:policy != NSXMLParserResolveExternalEntitiesNever];
}

- (NSSet<NSURL *> *)allowedExternalEntityURLs
{
    return objc_getAssociatedObject(self, &CharonXMLAllowedKey);
}

- (void)setAllowedExternalEntityURLs:(NSSet<NSURL *> *)urls
{
    objc_setAssociatedObject(self, &CharonXMLAllowedKey, [urls copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
