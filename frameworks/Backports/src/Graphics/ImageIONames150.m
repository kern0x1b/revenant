#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

extern CFStringRef const kCGImagePropertyGroupImageIndexLeft;
extern CFStringRef const kCGImagePropertyGroupImageIndexRight;
extern CFStringRef const kCGImagePropertyGroupImageIsAlternateImage;
extern CFStringRef const kCGImagePropertyGroupImageIsLeftImage;
extern CFStringRef const kCGImagePropertyGroupImageIsRightImage;
extern CFStringRef const kCGImagePropertyGroupImagesAlternate;
extern CFStringRef const kCGImagePropertyGroupIndex;
extern CFStringRef const kCGImagePropertyGroupType;
extern CFStringRef const kCGImagePropertyGroupTypeAlternate;
extern CFStringRef const kCGImagePropertyGroupTypeStereoPair;
extern CFStringRef const kCGImagePropertyGroups;
extern CFStringRef const kCGImagePropertyImageIndex;

CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupImageIndexLeft) = CFSTR("GroupImageIndexLeft");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupImageIndexRight) = CFSTR("GroupImageIndexRight");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupImageIsAlternateImage) = CFSTR("GroupImageIsAlternateImage");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupImageIsLeftImage) = CFSTR("GroupImageIsLeftImage");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupImageIsRightImage) = CFSTR("GroupImageIsRightImage");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupImagesAlternate) = CFSTR("GroupImages");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupIndex) = CFSTR("GroupIndex");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupType) = CFSTR("GroupType");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupTypeAlternate) = CFSTR("Alternate");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroupTypeStereoPair) = CFSTR("StereoPair");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGroups) = CFSTR("{Groups}");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyImageIndex) = CFSTR("ImageIndex");
