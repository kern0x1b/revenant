#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

extern CFStringRef const kCGImagePropertyTGACompression;
extern CFStringRef const kCGImagePropertyTGADictionary;
extern CFStringRef const kCGImagePropertyWebPCanvasPixelHeight;
extern CFStringRef const kCGImagePropertyWebPCanvasPixelWidth;
extern CFStringRef const kCGImagePropertyWebPDelayTime;
extern CFStringRef const kCGImagePropertyWebPDictionary;
extern CFStringRef const kCGImagePropertyWebPFrameInfoArray;
extern CFStringRef const kCGImagePropertyWebPLoopCount;
extern CFStringRef const kCGImagePropertyWebPUnclampedDelayTime;

CFStringRef const BACKPORT_IMPL(kCGImagePropertyTGACompression) = CFSTR("Compression");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyTGADictionary) = CFSTR("{TGA}");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyWebPCanvasPixelHeight) = CFSTR("CanvasPixelHeight");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyWebPCanvasPixelWidth) = CFSTR("CanvasPixelWidth");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyWebPDelayTime) = CFSTR("DelayTime");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyWebPDictionary) = CFSTR("{WebP}");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyWebPFrameInfoArray) = CFSTR("FrameInfo");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyWebPLoopCount) = CFSTR("LoopCount");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyWebPUnclampedDelayTime) = CFSTR("UnclampedDelayTime");
