#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import "check.h"
#import "fontkeys-cases.h"
#import "fontkeys-expectations.h"

int main(void)
{
    @autoreleasepool {
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:fontkeys_expectations length:strlen(fontkeys_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        fontkeys_run(^(NSString *name, NSString *value) {
            records[name] = value;
        });
        CHECK(records.count == expected.count && records.count > 0, "there is one recorded answer for every key");
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)])
            CHECK_EQUAL(records[name], expected[name], name.UTF8String);
        NSDictionary *coretext = @{
            @"UIFontDescriptorNameAttribute": (__bridge NSString *)kCTFontNameAttribute,
            @"UIFontDescriptorFamilyAttribute": (__bridge NSString *)kCTFontFamilyNameAttribute,
            @"UIFontDescriptorFaceAttribute": (__bridge NSString *)kCTFontStyleNameAttribute,
            @"UIFontDescriptorSizeAttribute": (__bridge NSString *)kCTFontSizeAttribute,
            @"UIFontDescriptorVisibleNameAttribute": (__bridge NSString *)kCTFontDisplayNameAttribute,
            @"UIFontDescriptorCharacterSetAttribute": (__bridge NSString *)kCTFontCharacterSetAttribute,
            @"UIFontDescriptorCascadeListAttribute": (__bridge NSString *)kCTFontCascadeListAttribute,
            @"UIFontDescriptorTraitsAttribute": (__bridge NSString *)kCTFontTraitsAttribute,
            @"UIFontDescriptorFixedAdvanceAttribute": (__bridge NSString *)kCTFontFixedAdvanceAttribute,
            @"UIFontDescriptorFeatureSettingsAttribute": (__bridge NSString *)kCTFontFeatureSettingsAttribute,
            @"UIFontSymbolicTrait": (__bridge NSString *)kCTFontSymbolicTrait,
            @"UIFontWeightTrait": (__bridge NSString *)kCTFontWeightTrait,
            @"UIFontWidthTrait": (__bridge NSString *)kCTFontWidthTrait,
            @"UIFontSlantTrait": (__bridge NSString *)kCTFontSlantTrait,
            @"UIFontFeatureTypeIdentifierKey": (__bridge NSString *)kCTFontFeatureTypeIdentifierKey,
            @"UIFontFeatureSelectorIdentifierKey": (__bridge NSString *)kCTFontFeatureSelectorIdentifierKey,
        };
        CHECK_EQUAL((__bridge NSString *)kCTFontMatrixAttribute, @"NSCTFontMatrixAttribute", "the matrix key of CoreText is not the one of UIKit");
        for (NSString *name in coretext)
            CHECK_EQUAL(records[name], coretext[name], [name stringByAppendingString:@" is the CoreText key of the release"].UTF8String);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
