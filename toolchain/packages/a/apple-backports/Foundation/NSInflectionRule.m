#import <Foundation/Foundation.h>

#import <objc/runtime.h>
#import "RevenantMorphology.h"

@implementation NSInflectionRule

+ (NSInflectionRule *)automaticRule
{
    static NSInflectionRule *rule;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        rule = class_createInstance([NSInflectionRule class], 0);
    });
    return rule;
}

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
