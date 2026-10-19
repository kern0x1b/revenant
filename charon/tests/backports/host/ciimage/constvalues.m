// constvalues.m : the value of every CoreImage constant name the port carries, read out of the
// host's own CoreImage. Each name is referenced strongly, so a name the SDK does not declare is a
// link error here rather than a row nobody checked, and the value printed is the string the real
// symbol points at. registry/CoreImage/constants10.json names this run as the source of every value
// it carries, so a value that is not what Apple's symbol holds is a difference, not an assumption.
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

extern NSString *const kCIActiveKeys;
extern NSString *const kCIAttributeDescription;
extern NSString *const kCIAttributeFilterAvailable_Mac;
extern NSString *const kCIAttributeFilterAvailable_iOS;
extern NSString *const kCIAttributeReferenceDocumentation;
extern NSString *const kCIAttributeTypeGradient;
extern NSString *const kCIAttributeTypeOpaqueColor;
extern NSString *const kCICategoryFilterGenerator;
extern NSString *const kCIContextAllowLowPower;
extern NSString *const kCIContextCVMetalTextureCache;
extern NSString *const kCIContextHighQualityDownsample;
extern NSString *const kCIContextMemoryLimit;
extern NSString *const kCIContextName;
extern NSString *const kCIContextOutputPremultiplied;
extern NSString *const kCIContextWorkingFormat;
extern NSString *const kCIInputAmountKey;
extern NSString *const kCIInputBaselineExposureKey;
extern NSString *const kCIInputBiasKey;
extern NSString *const kCIInputBoostKey;
extern NSString *const kCIInputBoostShadowAmountKey;
extern NSString *const kCIInputColorKey;
extern NSString *const kCIInputColorNoiseReductionAmountKey;
extern NSString *const kCIInputContrastKey;
extern NSString *const kCIInputDecoderVersionKey;
extern NSString *const kCIInputDepthImageKey;
extern NSString *const kCIInputDisableGamutMapKey;
extern NSString *const kCIInputDisparityImageKey;
extern NSString *const kCIInputEVKey;
extern NSString *const kCIInputEnableChromaticNoiseTrackingKey;
extern NSString *const kCIInputEnableSharpeningKey;
extern NSString *const kCIInputEnableVendorLensCorrectionKey;
extern NSString *const kCIInputExtentKey;
extern NSString *const kCIInputGradientImageKey;
extern NSString *const kCIInputIgnoreImageOrientationKey;
extern NSString *const kCIInputImageOrientationKey;
extern NSString *const kCIInputLuminanceNoiseReductionAmountKey;
extern NSString *const kCIInputMatteImageKey;
extern NSString *const kCIInputMoireAmountKey;
extern NSString *const kCIInputNeutralChromaticityXKey;
extern NSString *const kCIInputNeutralChromaticityYKey;
extern NSString *const kCIInputNeutralLocationKey;
extern NSString *const kCIInputNeutralTemperatureKey;
extern NSString *const kCIInputNeutralTintKey;
extern NSString *const kCIInputNoiseReductionAmountKey;
extern NSString *const kCIInputNoiseReductionContrastAmountKey;
extern NSString *const kCIInputNoiseReductionDetailAmountKey;
extern NSString *const kCIInputNoiseReductionSharpnessAmountKey;
extern NSString *const kCIInputRefractionKey;
extern NSString *const kCIInputScaleFactorKey;
extern NSString *const kCIInputShadingImageKey;
extern NSString *const kCIInputSharpnessKey;
extern NSString *const kCIInputTargetImageKey;
extern NSString *const kCIInputTimeKey;
extern NSString *const kCIInputTransformKey;
extern NSString *const kCIInputWeightsKey;
extern NSString *const kCIInputWidthKey;
extern NSString *const kCIOutputNativeSizeKey;
extern NSString *const kCIPropertiesKey;
extern NSString *const kCISamplerWrapMode;
extern NSString *const kCISupportedDecoderVersionsKey;
extern NSString *const kCIUIParameterSet;
extern NSString *const kCIUISetAdvanced;
extern NSString *const kCIUISetBasic;
extern NSString *const kCIUISetDevelopment;
extern NSString *const kCIUISetIntermediate;

int main(void)
{
    @autoreleasepool {
        const char *names[] = {
            "kCIActiveKeys",
            "kCIAttributeDescription",
            "kCIAttributeFilterAvailable_Mac",
            "kCIAttributeFilterAvailable_iOS",
            "kCIAttributeReferenceDocumentation",
            "kCIAttributeTypeGradient",
            "kCIAttributeTypeOpaqueColor",
            "kCICategoryFilterGenerator",
            "kCIContextAllowLowPower",
            "kCIContextCVMetalTextureCache",
            "kCIContextHighQualityDownsample",
            "kCIContextMemoryLimit",
            "kCIContextName",
            "kCIContextOutputPremultiplied",
            "kCIContextWorkingFormat",
            "kCIInputAmountKey",
            "kCIInputBaselineExposureKey",
            "kCIInputBiasKey",
            "kCIInputBoostKey",
            "kCIInputBoostShadowAmountKey",
            "kCIInputColorKey",
            "kCIInputColorNoiseReductionAmountKey",
            "kCIInputContrastKey",
            "kCIInputDecoderVersionKey",
            "kCIInputDepthImageKey",
            "kCIInputDisableGamutMapKey",
            "kCIInputDisparityImageKey",
            "kCIInputEVKey",
            "kCIInputEnableChromaticNoiseTrackingKey",
            "kCIInputEnableSharpeningKey",
            "kCIInputEnableVendorLensCorrectionKey",
            "kCIInputExtentKey",
            "kCIInputGradientImageKey",
            "kCIInputIgnoreImageOrientationKey",
            "kCIInputImageOrientationKey",
            "kCIInputLuminanceNoiseReductionAmountKey",
            "kCIInputMatteImageKey",
            "kCIInputMoireAmountKey",
            "kCIInputNeutralChromaticityXKey",
            "kCIInputNeutralChromaticityYKey",
            "kCIInputNeutralLocationKey",
            "kCIInputNeutralTemperatureKey",
            "kCIInputNeutralTintKey",
            "kCIInputNoiseReductionAmountKey",
            "kCIInputNoiseReductionContrastAmountKey",
            "kCIInputNoiseReductionDetailAmountKey",
            "kCIInputNoiseReductionSharpnessAmountKey",
            "kCIInputRefractionKey",
            "kCIInputScaleFactorKey",
            "kCIInputShadingImageKey",
            "kCIInputSharpnessKey",
            "kCIInputTargetImageKey",
            "kCIInputTimeKey",
            "kCIInputTransformKey",
            "kCIInputWeightsKey",
            "kCIInputWidthKey",
            "kCIOutputNativeSizeKey",
            "kCIPropertiesKey",
            "kCISamplerWrapMode",
            "kCISupportedDecoderVersionsKey",
            "kCIUIParameterSet",
            "kCIUISetAdvanced",
            "kCIUISetBasic",
            "kCIUISetDevelopment",
            "kCIUISetIntermediate",
        };
        NSString *const *values[] = {
            &kCIActiveKeys,
            &kCIAttributeDescription,
            &kCIAttributeFilterAvailable_Mac,
            &kCIAttributeFilterAvailable_iOS,
            &kCIAttributeReferenceDocumentation,
            &kCIAttributeTypeGradient,
            &kCIAttributeTypeOpaqueColor,
            &kCICategoryFilterGenerator,
            &kCIContextAllowLowPower,
            &kCIContextCVMetalTextureCache,
            &kCIContextHighQualityDownsample,
            &kCIContextMemoryLimit,
            &kCIContextName,
            &kCIContextOutputPremultiplied,
            &kCIContextWorkingFormat,
            &kCIInputAmountKey,
            &kCIInputBaselineExposureKey,
            &kCIInputBiasKey,
            &kCIInputBoostKey,
            &kCIInputBoostShadowAmountKey,
            &kCIInputColorKey,
            &kCIInputColorNoiseReductionAmountKey,
            &kCIInputContrastKey,
            &kCIInputDecoderVersionKey,
            &kCIInputDepthImageKey,
            &kCIInputDisableGamutMapKey,
            &kCIInputDisparityImageKey,
            &kCIInputEVKey,
            &kCIInputEnableChromaticNoiseTrackingKey,
            &kCIInputEnableSharpeningKey,
            &kCIInputEnableVendorLensCorrectionKey,
            &kCIInputExtentKey,
            &kCIInputGradientImageKey,
            &kCIInputIgnoreImageOrientationKey,
            &kCIInputImageOrientationKey,
            &kCIInputLuminanceNoiseReductionAmountKey,
            &kCIInputMatteImageKey,
            &kCIInputMoireAmountKey,
            &kCIInputNeutralChromaticityXKey,
            &kCIInputNeutralChromaticityYKey,
            &kCIInputNeutralLocationKey,
            &kCIInputNeutralTemperatureKey,
            &kCIInputNeutralTintKey,
            &kCIInputNoiseReductionAmountKey,
            &kCIInputNoiseReductionContrastAmountKey,
            &kCIInputNoiseReductionDetailAmountKey,
            &kCIInputNoiseReductionSharpnessAmountKey,
            &kCIInputRefractionKey,
            &kCIInputScaleFactorKey,
            &kCIInputShadingImageKey,
            &kCIInputSharpnessKey,
            &kCIInputTargetImageKey,
            &kCIInputTimeKey,
            &kCIInputTransformKey,
            &kCIInputWeightsKey,
            &kCIInputWidthKey,
            &kCIOutputNativeSizeKey,
            &kCIPropertiesKey,
            &kCISamplerWrapMode,
            &kCISupportedDecoderVersionsKey,
            &kCIUIParameterSet,
            &kCIUISetAdvanced,
            &kCIUISetBasic,
            &kCIUISetDevelopment,
            &kCIUISetIntermediate,
        };
        for (size_t i = 0; i < sizeof names / sizeof *names; i++)
            printf("%s NSString \"%s\"\n", names[i], values[i][0].UTF8String);
    }
    return 0;
}
