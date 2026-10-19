#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// The names of the inputs, outputs and options CoreImage's own filters and contexts are given their
// parameters by, and the names of the metadata attributes a filter is described by. iOS 6 carries
// some of them and not the rest, and the ones it does not carry are here: every value is the string
// the release's own filters read the parameter by, read off the host's CoreImage rather than
// written out by hand. facts/CoreImage/Constants.md has the run that read them.
// Split by release: an object may only carry API that arrived in one of them, which the
// gate reads off the stub. These arrived in iOS 26; the values are the host's own symbols.
NSString *const kCIContextCVMetalTextureCache = @"kCIContextCVMetalTextureCache";
NSString *const kCIDynamicRangeConstrainedHigh = @"kCIDynamicRangeConstrainedHigh";
NSString *const kCIDynamicRangeHigh = @"kCIDynamicRangeHigh";
NSString *const kCIDynamicRangeStandard = @"kCIDynamicRangeStandard";
NSString *const kCIImageApplyCleanAperture = @"kCIImageApplyCleanAperture";
NSString *const kCIImageContentAverageLightLevel = @"kCIImageContentAverageLightLevel";
NSString *const kCIInputBacksideImageKey = @"inputBacksideImage";
NSString *const kCIInputBiasVectorKey = @"inputBiasVector";
NSString *const kCIInputColor0Key = @"inputColor0";
NSString *const kCIInputColor1Key = @"inputColor1";
NSString *const kCIInputColorSpaceKey = @"inputColorSpace";
NSString *const kCIInputCountKey = @"inputCount";
NSString *const kCIInputExtrapolateKey = @"inputExtrapolate";
NSString *const kCIInputPaletteImageKey = @"inputPaletteImage";
NSString *const kCIInputPerceptualKey = @"inputPerceptual";
NSString *const kCIInputPoint0Key = @"inputPoint0";
NSString *const kCIInputPoint1Key = @"inputPoint1";
NSString *const kCIInputRadius0Key = @"inputRadius0";
NSString *const kCIInputRadius1Key = @"inputRadius1";
NSString *const kCIInputThresholdKey = @"inputThreshold";
