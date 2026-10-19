#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// The names of the inputs, outputs and options CoreImage's own filters and contexts are given their
// parameters by, and the names of the metadata attributes a filter is described by. iOS 6 carries
// some of them and not the rest, and the ones it does not carry are here: every value is the string
// the release's own filters read the parameter by, read off the host's CoreImage rather than
// written out by hand. facts/CoreImage/Constants.md has the run that read them.
// Split by release: an object may only carry API that arrived in one of them, which the
// gate reads off the stub. These arrived in iOS 9.0; the values are the host's own symbols.
CIFormat kCIFormatA16 = 1793;
CIFormat kCIFormatAf = 2305;
CIFormat kCIFormatAh = 2049;
CIFormat kCIFormatLAf = 2308;
CIFormat kCIFormatLf = 2307;
CIFormat kCIFormatRGf = 2310;
CIFormat kCIFormatRf = 2309;
NSString *const CIDetectorNumberOfAngles = @"CIDetectorNumberOfAngles";
NSString *const CIDetectorReturnSubFeatures = @"CIDetectorReturnSubFeatures";
NSString *const CIDetectorTypeText = @"CIDetectorTypeText";
NSString *const CIFeatureTypeQRCode = @"QRCode";
NSString *const CIFeatureTypeRectangle = @"Rectangle";
NSString *const CIFeatureTypeText = @"Text";
NSString *const kCIActiveKeys = @"activeKeys";
NSString *const kCIAttributeDescription = @"CIAttributeDescription";
NSString *const kCIAttributeFilterAvailable_Mac = @"CIAttributeFilterAvailable_Mac";
NSString *const kCIAttributeFilterAvailable_iOS = @"CIAttributeFilterAvailable_iOS";
NSString *const kCIAttributeReferenceDocumentation = @"CIAttributeReferenceDocumentation";
NSString *const kCIAttributeTypeGradient = @"CIAttributeTypeGradient";
NSString *const kCIAttributeTypeOpaqueColor = @"CIAttributeTypeOpaqueColor";
NSString *const kCICategoryFilterGenerator = @"CICategoryFilterGenerator";
NSString *const kCIContextHighQualityDownsample = @"high_quality_downsample";
NSString *const kCIImageProviderTileSize = @"tile_size";
NSString *const kCIImageProviderUserInfo = @"user_info";
NSString *const kCIInputAllowDraftModeKey = @"inputDraftMode";
NSString *const kCIInputBiasKey = @"inputBias";
NSString *const kCIInputBoostKey = @"inputBoost";
NSString *const kCIInputBoostShadowAmountKey = @"inputBoostShadowAmount";
NSString *const kCIInputColorNoiseReductionAmountKey = @"inputColorNoiseReductionAmount";
NSString *const kCIInputDecoderVersionKey = @"inputDecoderVersion";
NSString *const kCIInputEnableChromaticNoiseTrackingKey = @"inputEnableNoiseTracking";
NSString *const kCIInputEnableSharpeningKey = @"inputEnableSharpening";
NSString *const kCIInputEnableVendorLensCorrectionKey = @"inputEnableVendorLensCorrection";
NSString *const kCIInputGradientImageKey = @"inputGradientImage";
NSString *const kCIInputIgnoreImageOrientationKey = @"inputIgnoreOrientation";
NSString *const kCIInputImageOrientationKey = @"inputImageOrientation";
NSString *const kCIInputLinearSpaceFilter = @"inputLinearSpaceFilter";
NSString *const kCIInputLuminanceNoiseReductionAmountKey = @"inputLuminanceNoiseReductionAmount";
NSString *const kCIInputNeutralChromaticityXKey = @"inputNeutralChromaticityX";
NSString *const kCIInputNeutralChromaticityYKey = @"inputNeutralChromaticityY";
NSString *const kCIInputNeutralLocationKey = @"inputNeutralLocation";
NSString *const kCIInputNeutralTemperatureKey = @"inputNeutralTemperature";
NSString *const kCIInputNeutralTintKey = @"inputNeutralTint";
NSString *const kCIInputNoiseReductionAmountKey = @"inputNoiseReductionAmount";
NSString *const kCIInputNoiseReductionContrastAmountKey = @"inputNoiseReductionContrastAmount";
NSString *const kCIInputNoiseReductionDetailAmountKey = @"inputNoiseReductionDetailAmount";
NSString *const kCIInputNoiseReductionSharpnessAmountKey = @"inputNoiseReductionSharpnessAmount";
NSString *const kCIInputRefractionKey = @"inputRefraction";
NSString *const kCIInputScaleFactorKey = @"inputScaleFactor";
NSString *const kCIInputShadingImageKey = @"inputShadingImage";
NSString *const kCIInputWeightsKey = @"inputWeights";
NSString *const kCIOutputNativeSizeKey = @"outputNativeSize";
NSString *const kCISamplerAffineMatrix = @"affine_matrix";
NSString *const kCISamplerColorSpace = @"color_space";
NSString *const kCISamplerFilterLinear = @"linear";
NSString *const kCISamplerFilterMode = @"filter_mode";
NSString *const kCISamplerFilterNearest = @"nearest";
NSString *const kCISamplerWrapBlack = @"black";
NSString *const kCISamplerWrapClamp = @"clamp";
NSString *const kCISamplerWrapMode = @"wrap_mode";
NSString *const kCISupportedDecoderVersionsKey = @"supportedDecoderVersions";
NSString *const kCIUIParameterSet = @"CIUIParameterSet";
NSString *const kCIUISetAdvanced = @"CIUISetAdvanced";
NSString *const kCIUISetBasic = @"CIUISetBasic";
NSString *const kCIUISetDevelopment = @"CIUISetDevelopment";
NSString *const kCIUISetIntermediate = @"CIUISetIntermediate";
