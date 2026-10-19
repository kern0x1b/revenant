#import <CoreGraphics/CoreGraphics.h>

// Its own name in 12.0, the first release whose CoreGraphics exports it (the 12.0 cache holds that string and
// not kCGColorSpaceITUR_2100_PQ, the value later releases and the host give it): facts/CoreGraphics/CGColorSpace.md.
const CFStringRef kCGColorSpaceITUR_2020_PQ_EOTF = CFSTR("kCGColorSpaceITUR_2020_PQ_EOTF");
