#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

extern CFStringRef const kCGImagePropertyPNGPixelsAspectRatio;

CFStringRef const BACKPORT_IMPL(kCGImagePropertyPNGPixelsAspectRatio) = CFSTR("PixelAspectRatio");
