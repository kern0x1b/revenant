#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// The names of the inputs, outputs and options CoreImage's own filters and contexts are given their
// parameters by, and the names of the metadata attributes a filter is described by. iOS 6 carries
// some of them and not the rest, and the ones it does not carry are here: every value is the string
// the release's own filters read the parameter by, read off the host's CoreImage rather than
// written out by hand. facts/CoreImage/Constants.md has the run that read them.
// Split by release: an object may only carry API that arrived in one of them, which the
// gate reads off the stub. These arrived in iOS 8.0; the values are the host's own symbols.
CIFormat kCIFormatL16 = 1795;
CIFormat kCIFormatLA16 = 1796;
CIFormat kCIFormatLAh = 2052;
CIFormat kCIFormatLh = 2051;
CIFormat kCIFormatR16 = 1797;
CIFormat kCIFormatRG16 = 1798;
CIFormat kCIFormatRGBA16 = 1800;
CIFormat kCIFormatRGBAf = 2312;
CIFormat kCIFormatRGh = 2054;
CIFormat kCIFormatRh = 2053;

NSString *const CIDetectorAspectRatio = @"CIDetectorAspectRatio";
NSString *const CIDetectorFocalLength = @"CIDetectorFocalLength";
NSString *const CIDetectorTypeQRCode = @"CIDetectorTypeQRCode";
NSString *const CIDetectorTypeRectangle = @"CIDetectorTypeRectangle";
NSString *const kCIContextWorkingFormat = @"working_format";
NSString *const kCIImageAutoAdjustCrop = @"kCIImageAutoAdjustCrop";
NSString *const kCIImageAutoAdjustLevel = @"kCIImageAutoAdjustLevel";
