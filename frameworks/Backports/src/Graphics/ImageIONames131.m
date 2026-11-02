#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

extern CFStringRef const kCGImagePropertyExifCompositeImage;
extern CFStringRef const kCGImagePropertyExifSourceExposureTimesOfCompositeImage;
extern CFStringRef const kCGImagePropertyExifSourceImageNumberOfCompositeImage;

CFStringRef const BACKPORT_IMPL(kCGImagePropertyExifCompositeImage) = CFSTR("CompositeImage");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyExifSourceExposureTimesOfCompositeImage) = CFSTR("SourceExposureTimesOfCompositeImage");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyExifSourceImageNumberOfCompositeImage) = CFSTR("SourceImageNumberOfCompositeImage");
