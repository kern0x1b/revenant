#import <CoreImage/CoreImage.h>

// The inputs, outputs and options of CoreImage's semantic segmentation mattes (hair, skin and teeth)
// and the context option that the held iOS 13.4 cache is the first to export. Every value is the
// string the release's own filters read the parameter by, read off the host's CoreImage. The names
// the iOS 16.0 cache first exports are in CIConstants16.m; facts/CoreImage/Constants.md has the run
// that read them.
NSString *const kCIContextAllowLowPower = @"kCIContextAllowLowPower";
NSString *const kCIImageAuxiliarySemanticSegmentationHairMatte = @"kCIImageAuxiliarySemanticSegmentationHairMatte";
NSString *const kCIImageAuxiliarySemanticSegmentationSkinMatte = @"kCIImageAuxiliarySemanticSegmentationSkinMatte";
NSString *const kCIImageAuxiliarySemanticSegmentationTeethMatte = @"kCIImageAuxiliarySemanticSegmentationTeethMatte";
NSString *const kCIImageRepresentationAVSemanticSegmentationMattes = @"kCIImageRepresentationAVSemanticSegmentationMattes";
NSString *const kCIImageRepresentationSemanticSegmentationHairMatteImage = @"kCIImageRepresentationSemanticSegmentationHairMatteImage";
NSString *const kCIImageRepresentationSemanticSegmentationSkinMatteImage = @"kCIImageRepresentationSemanticSegmentationSkinMatteImage";
NSString *const kCIImageRepresentationSemanticSegmentationTeethMatteImage = @"kCIImageRepresentationSemanticSegmentationTeethMatteImage";
