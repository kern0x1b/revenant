#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

extern CFStringRef const kCGImagePropertyHEIFDictionary;

CFStringRef const BACKPORT_IMPL(kCGImagePropertyHEIFDictionary) = CFSTR("{HEIF}");
