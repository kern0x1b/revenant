#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantSymbols.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 170000

@interface UIImageConfiguration (RevenantLocale17)
@property (nonatomic, copy, nullable) NSLocale *locale;
- (instancetype)configurationWithLocale:(nullable NSLocale *)locale;
@end

@interface UIImageConfiguration (RevenantLocale17Equality)
- (BOOL)isEqualToConfiguration:(UIImageConfiguration *)otherConfiguration;
@end

#endif

static const char RevenantImageConfigurationLocaleKey;

static NSLocale *revenant_configuration_locale(UIImageConfiguration *configuration)
{
    return objc_getAssociatedObject(configuration, &RevenantImageConfigurationLocaleKey);
}

static void revenant_set_configuration_locale(UIImageConfiguration *configuration, NSLocale *locale)
{
    objc_setAssociatedObject(configuration, &RevenantImageConfigurationLocaleKey, locale, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static UIImageConfiguration *revenant_configuration_with_locale(UIImageConfiguration *configuration, NSLocale *locale)
{
    NSLocale *held = revenant_configuration_locale(configuration);
    if (locale == held || (locale && [locale isEqual:held]))
        return configuration;
    UIImageConfiguration *copy = [configuration copy];
    revenant_set_configuration_locale(copy, locale);
    return copy;
}

@interface RevenantLocaleConfiguration : UIImageConfiguration
@end

@implementation RevenantLocaleConfiguration

- (id)copyWithZone:(NSZone *)zone
{
    UIImageConfiguration *copy = [super copyWithZone:zone];
    revenant_set_configuration_locale(copy, revenant_configuration_locale(self));
    return copy;
}

- (BOOL)revenant_isUnspecified
{
    return [super revenant_isUnspecified] && !revenant_configuration_locale(self);
}

- (void)revenant_applyFieldsOfConfiguration:(UIImageConfiguration *)other
{
    [super revenant_applyFieldsOfConfiguration:other];
    NSLocale *locale = revenant_configuration_locale(other);
    if (locale)
        revenant_set_configuration_locale(self, locale);
}

- (BOOL)isEqualToConfiguration:(UIImageConfiguration *)otherConfiguration
{
    if (![super isEqualToConfiguration:otherConfiguration])
        return NO;
    return [revenant_configuration_locale(self) isEqual:revenant_configuration_locale(otherConfiguration)];
}

- (NSUInteger)hash
{
    return [super hash] ^ revenant_configuration_locale(self).hash;
}

- (NSMutableArray<NSString *> *)revenant_fieldDescriptions
{
    NSMutableArray *fields = [super revenant_fieldDescriptions];
    NSLocale *locale = revenant_configuration_locale(self);
    if (locale)
        [fields addObject:[NSString stringWithFormat:@"locale=(%@)", locale]];
    return fields;
}

@end

@implementation UIImageConfiguration (RevenantLocale17)

- (NSLocale *)locale
{
    return revenant_configuration_locale(self);
}

- (void)setLocale:(NSLocale *)locale
{
    revenant_set_configuration_locale(self, locale);
}

- (instancetype)configurationWithLocale:(NSLocale *)locale
{
    return revenant_configuration_with_locale(self, locale);
}

+ (instancetype)configurationWithLocale:(NSLocale *)locale
{
    RevenantLocaleConfiguration *result = [[RevenantLocaleConfiguration alloc] initRevenantWithTraitCollection:nil];
    if (locale)
        revenant_set_configuration_locale(result, locale);
    return result;
}

+ (instancetype)configurationWithTraitCollection:(UITraitCollection *)traitCollection
{
    RevenantLocaleConfiguration *result = [[RevenantLocaleConfiguration alloc] initRevenantWithTraitCollection:traitCollection];
    return result;
}

@end
