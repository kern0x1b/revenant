#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

extern CFStringRef const kCGImageAuxiliaryDataTypeHDRGainMap;
extern CFStringRef const kCGImageAuxiliaryDataTypeSemanticSegmentationGlassesMatte;
extern CFStringRef const kCGImageAuxiliaryDataTypeSemanticSegmentationSkyMatte;
extern CFStringRef const kCGImageDestinationPreserveGainMap;

CFStringRef const BACKPORT_IMPL(kCGImageAuxiliaryDataTypeHDRGainMap) = CFSTR("kCGImageAuxiliaryDataTypeHDRGainMap");
CFStringRef const BACKPORT_IMPL(kCGImageAuxiliaryDataTypeSemanticSegmentationGlassesMatte) = CFSTR("kCGImageAuxiliaryDataTypeSemanticSegmentationGlassesMatte");
CFStringRef const BACKPORT_IMPL(kCGImageAuxiliaryDataTypeSemanticSegmentationSkyMatte) = CFSTR("kCGImageAuxiliaryDataTypeSemanticSegmentationSkyMatte");
CFStringRef const BACKPORT_IMPL(kCGImageDestinationPreserveGainMap) = CFSTR("kCGImageDestinationPreserveGainMap");
