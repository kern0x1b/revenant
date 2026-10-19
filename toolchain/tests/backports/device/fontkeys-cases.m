#import <UIKit/UIKit.h>
#import "fontkeys-cases.h"

void fontkeys_run(FontKeysRecorder record)
{
    record(@"UIFontDescriptorNameAttribute", UIFontDescriptorNameAttribute);
    record(@"UIFontDescriptorFamilyAttribute", UIFontDescriptorFamilyAttribute);
    record(@"UIFontDescriptorFaceAttribute", UIFontDescriptorFaceAttribute);
    record(@"UIFontDescriptorSizeAttribute", UIFontDescriptorSizeAttribute);
    record(@"UIFontDescriptorVisibleNameAttribute", UIFontDescriptorVisibleNameAttribute);
    record(@"UIFontDescriptorMatrixAttribute", UIFontDescriptorMatrixAttribute);
    record(@"UIFontDescriptorCharacterSetAttribute", UIFontDescriptorCharacterSetAttribute);
    record(@"UIFontDescriptorCascadeListAttribute", UIFontDescriptorCascadeListAttribute);
    record(@"UIFontDescriptorTraitsAttribute", UIFontDescriptorTraitsAttribute);
    record(@"UIFontDescriptorFixedAdvanceAttribute", UIFontDescriptorFixedAdvanceAttribute);
    record(@"UIFontDescriptorFeatureSettingsAttribute", UIFontDescriptorFeatureSettingsAttribute);
    record(@"UIFontDescriptorTextStyleAttribute", UIFontDescriptorTextStyleAttribute);
    record(@"UIFontSymbolicTrait", UIFontSymbolicTrait);
    record(@"UIFontWeightTrait", UIFontWeightTrait);
    record(@"UIFontWidthTrait", UIFontWidthTrait);
    record(@"UIFontSlantTrait", UIFontSlantTrait);
    record(@"UIFontFeatureTypeIdentifierKey", UIFontFeatureTypeIdentifierKey);
    record(@"UIFontFeatureSelectorIdentifierKey", UIFontFeatureSelectorIdentifierKey);
}
