#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonSymbols.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 170000

@interface UIImageConfiguration (CharonLocale17)
@property (nonatomic, copy, nullable) NSLocale *locale;
- (instancetype)configurationWithLocale:(nullable NSLocale *)locale;
@end

@interface UIImageConfiguration (CharonLocale17Equality)
- (BOOL)isEqualToConfiguration:(UIImageConfiguration *)otherConfiguration;
@end

#endif

static const char CharonImageConfigurationLocaleKey;

static NSLocale *charon_configuration_locale(UIImageConfiguration *configuration)
{
    return objc_getAssociatedObject(configuration, &CharonImageConfigurationLocaleKey);
}

static void charon_set_configuration_locale(UIImageConfiguration *configuration, NSLocale *locale)
{
    objc_setAssociatedObject(configuration, &CharonImageConfigurationLocaleKey, locale, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static UIImageConfiguration *charon_configuration_with_locale(UIImageConfiguration *configuration, NSLocale *locale)
{
    NSLocale *held = charon_configuration_locale(configuration);
    if (locale == held || (locale && [locale isEqual:held]))
        return configuration;
    UIImageConfiguration *copy = [configuration copy];
    charon_set_configuration_locale(copy, locale);
    return copy;
}

@interface CharonLocaleConfiguration : UIImageConfiguration
@end

@implementation CharonLocaleConfiguration

- (id)copyWithZone:(NSZone *)zone
{
    UIImageConfiguration *copy = [super copyWithZone:zone];
    charon_set_configuration_locale(copy, charon_configuration_locale(self));
    return copy;
}

- (BOOL)charon_isUnspecified
{
    return [super charon_isUnspecified] && !charon_configuration_locale(self);
}

- (void)charon_applyFieldsOfConfiguration:(UIImageConfiguration *)other
{
    [super charon_applyFieldsOfConfiguration:other];
    NSLocale *locale = charon_configuration_locale(other);
    if (locale)
        charon_set_configuration_locale(self, locale);
}

- (BOOL)isEqualToConfiguration:(UIImageConfiguration *)otherConfiguration
{
    if (![super isEqualToConfiguration:otherConfiguration])
        return NO;
    return [charon_configuration_locale(self) isEqual:charon_configuration_locale(otherConfiguration)];
}

- (NSUInteger)hash
{
    return [super hash] ^ charon_configuration_locale(self).hash;
}

- (NSMutableArray<NSString *> *)charon_fieldDescriptions
{
    NSMutableArray *fields = [super charon_fieldDescriptions];
    NSLocale *locale = charon_configuration_locale(self);
    if (locale)
        [fields addObject:[NSString stringWithFormat:@"locale=(%@)", locale]];
    return fields;
}

@end

@implementation UIImageConfiguration (CharonLocale17)

- (NSLocale *)locale
{
    return charon_configuration_locale(self);
}

- (void)setLocale:(NSLocale *)locale
{
    charon_set_configuration_locale(self, locale);
}

- (instancetype)configurationWithLocale:(NSLocale *)locale
{
    return charon_configuration_with_locale(self, locale);
}

+ (instancetype)configurationWithLocale:(NSLocale *)locale
{
    CharonLocaleConfiguration *result = [[CharonLocaleConfiguration alloc] initCharonWithTraitCollection:nil];
    if (locale)
        charon_set_configuration_locale(result, locale);
    return result;
}

+ (instancetype)configurationWithTraitCollection:(UITraitCollection *)traitCollection
{
    CharonLocaleConfiguration *result = [[CharonLocaleConfiguration alloc] initCharonWithTraitCollection:traitCollection];
    return result;
}

@end
