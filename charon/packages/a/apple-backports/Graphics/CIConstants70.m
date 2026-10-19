#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// The names of the inputs, outputs and options CoreImage's own filters and contexts are given their
// parameters by, and the names of the metadata attributes a filter is described by. iOS 6 carries
// some of them and not the rest, and the ones it does not carry are here: every value is the string
// the release's own filters read the parameter by, read off the host's CoreImage rather than
// written out by hand. facts/CoreImage/Constants.md has the run that read them.
// Split by release: an object may only carry API that arrived in one of them, which the
// gate reads off the stub. These arrived in iOS 7.0; the values are the host's own symbols.
CIFormat kCIFormatA8 = 257;
CIFormat kCIFormatLA8 = 260;
CIFormat kCIFormatR8 = 261;
NSString *const CIDetectorEyeBlink = @"CIDetectorEyeBlink";
NSString *const CIDetectorSmile = @"CIDetectorSmile";
NSString *const kCIContextOutputPremultiplied = @"output_premultiplied";
NSString *const kCIInputColorKey = @"inputColor";
NSString *const kCIInputContrastKey = @"inputContrast";
NSString *const kCIInputEVKey = @"inputEV";
NSString *const kCIInputExtentKey = @"inputExtent";
NSString *const kCIInputSharpnessKey = @"inputSharpness";
NSString *const kCIInputTargetImageKey = @"inputTargetImage";
NSString *const kCIInputTimeKey = @"inputTime";
NSString *const kCIInputTransformKey = @"inputTransform";
NSString *const kCIInputWidthKey = @"inputWidth";

NSString *const kCIInputAngleKey = @"inputAngle";
NSString *const kCIInputAspectRatioKey = @"inputAspectRatio";
NSString *const kCIInputBrightnessKey = @"inputBrightness";
NSString *const kCIInputCenterKey = @"inputCenter";
NSString *const kCIInputIntensityKey = @"inputIntensity";
NSString *const kCIInputMaskImageKey = @"inputMaskImage";
NSString *const kCIInputRadiusKey = @"inputRadius";
NSString *const kCIInputSaturationKey = @"inputSaturation";
NSString *const kCIInputScaleKey = @"inputScale";
