#import <Foundation/Foundation.h>

#import <objc/runtime.h>
#import "CharonMorphology.h"

@implementation NSInflectionRule

+ (NSInflectionRule *)automaticRule
{
    static NSInflectionRule *rule;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // -init and +new are NS_UNAVAILABLE on the abstract class, so the instance is made through
        // the runtime and left as the class it is: the class object of the receiver, not a name.
        rule = class_createInstance([NSInflectionRule class], 0);
    });
    return rule;
}

/* A real language list, measured: en, en_US, en_GB, fr, fr_FR, de, es, pt, it, nl, ko and hi are 1,
   and ru, ja, ar, zh, pl, tr, he, th, und, the empty string, xx_YY, klingon and 123 are 0. */
+ (BOOL)canInflectLanguage:(NSString *)language
{
    static NSSet *languages;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        languages = [NSSet setWithArray:@[@"en", @"en_US", @"en_GB", @"fr", @"fr_FR", @"de", @"es", @"pt", @"it", @"nl",
                                            @"ko", @"hi"]];
    });
    return language != nil && [languages containsObject:language];
}

+ (BOOL)canInflectPreferredLocalization
{
    NSString *preferred = [[NSBundle mainBundle] preferredLocalizations].firstObject;
    return preferred != nil && [self canInflectLanguage:preferred];
}

- (id)copyWithZone:(NSZone *)zone
{
    // The host refuses this on the explicit subclass - "cannot be sent to an abstract object of class
    // NSInflectionRuleExplicit" - with a class that is concrete (measured), and answers it on the
    // automatic rule. So the refusal is here, where the host's is, and +automaticRule is copied.
    if (![self isMemberOfClass:[NSInflectionRule class]])
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -copyWithZone: cannot be sent to an abstract object of class %@: "
                           @"Create a concrete instance!",
                           NSStringFromClass([self class])];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

@end
