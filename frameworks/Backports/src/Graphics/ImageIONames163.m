#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

extern CFStringRef const kCGImagePropertyOpenEXRCompression;

CFStringRef const BACKPORT_IMPL(kCGImagePropertyOpenEXRCompression) = CFSTR("Compression");
