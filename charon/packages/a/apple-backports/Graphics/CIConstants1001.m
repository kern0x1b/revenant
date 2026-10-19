#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// The names of the inputs, outputs and options CoreImage's own filters and contexts are given their
// parameters by, and the names of the metadata attributes a filter is described by. iOS 6 carries
// some of them and not the rest, and the ones it does not carry are here: every value is the string
// the release's own filters read the parameter by, read off the host's CoreImage rather than
// written out by hand. facts/CoreImage/Constants.md has the run that read them.
// Split by release: an object may only carry API that arrived in one of them, which the
// gate reads off the stub. These arrived in iOS 10.0.1; the values are the host's own symbols.
NSString *const CIDetectorMaxFeatureCount = @"CIDetectorMaxFeatureCount";
NSString *const kCIInputBaselineExposureKey = @"inputBaselineExposure";
NSString *const kCIInputDisableGamutMapKey = @"inputDisableGamutMap";
