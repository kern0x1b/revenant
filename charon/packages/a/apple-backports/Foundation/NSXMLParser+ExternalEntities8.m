#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* Whether an XML parser resolves an external entity, and which URLs it may. The header says the
   policy defaults to NSXMLParserResolveExternalEntitiesNever, and that the two properties are the modern
   spelling of -setShouldResolveExternalEntities:.

   The port follows the release's parser to the end: the policy is kept and mapped onto the release's
   own knob, so a parser that is told to resolve entities does resolve them through the release's
   libxml2 and one that is not does not. The allowed set is kept and checked where the parser asks:
   a parser given a set only resolves an entity whose URL is in it. */

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
