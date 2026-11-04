#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

const CFStringRef BACKPORT_IMPL(kCGImageDestinationDateTime) = CFSTR("kCGImageDestinationDateTime");
const CFStringRef BACKPORT_IMPL(kCGImageDestinationMergeMetadata) = CFSTR("kCGImageDestinationMergeMetadata");
const CFStringRef BACKPORT_IMPL(kCGImageDestinationMetadata) = CFSTR("kCGImageDestinationMetadata");
const CFStringRef BACKPORT_IMPL(kCGImageDestinationOrientation) = CFSTR("kCGImageDestinationOrientation");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataEnumerateRecursively) = CFSTR("kCGImageMetadataEnumerateRecursively");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataNamespaceExifEX) = CFSTR("http://cipa.jp/exif/1.0/");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixDublinCore) = CFSTR("dc");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixExif) = CFSTR("exif");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixExifAux) = CFSTR("aux");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixExifEX) = CFSTR("exifEX");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixIPTCCore) = CFSTR("Iptc4xmpCore");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixPhotoshop) = CFSTR("photoshop");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixTIFF) = CFSTR("tiff");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixXMPBasic) = CFSTR("xmp");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataPrefixXMPRights) = CFSTR("xmpRights");
const CFStringRef BACKPORT_IMPL(kCGImageMetadataShouldExcludeXMP) = CFSTR("kCGImageMetadataShouldExcludeXMP");
const CFStringRef BACKPORT_IMPL(kCGImagePropertyExifISOSpeed) = CFSTR("ISOSpeed");
const CFStringRef BACKPORT_IMPL(kCGImagePropertyExifISOSpeedLatitudeyyy) = CFSTR("ISOSpeedLatitudeyyy");
const CFStringRef BACKPORT_IMPL(kCGImagePropertyExifISOSpeedLatitudezzz) = CFSTR("ISOSpeedLatitudezzz");
const CFStringRef BACKPORT_IMPL(kCGImagePropertyExifRecommendedExposureIndex) = CFSTR("RecommendedExposureIndex");
const CFStringRef BACKPORT_IMPL(kCGImagePropertyExifSensitivityType) = CFSTR("SensitivityType");
const CFStringRef BACKPORT_IMPL(kCGImagePropertyExifStandardOutputSensitivity) = CFSTR("StandardOutputSensitivity");
const CFStringRef BACKPORT_IMPL(kCGImagePropertyMakerAppleDictionary) = CFSTR("{MakerApple}");
