#include "../revenant_impl.h"
#import <CoreVideo/CoreVideo.h>

const CFStringRef BACKPORT_IMPL(kCVImageBufferColorPrimaries_DCI_P3) = CFSTR("DCI_P3");
const CFStringRef BACKPORT_IMPL(kCVImageBufferColorPrimaries_ITU_R_2020) = CFSTR("ITU_R_2020");
const CFStringRef BACKPORT_IMPL(kCVImageBufferColorPrimaries_P3_D65) = CFSTR("P3_D65");
const CFStringRef BACKPORT_IMPL(kCVImageBufferTransferFunction_ITU_R_2020) = CFSTR("ITU_R_2020");
const CFStringRef BACKPORT_IMPL(kCVImageBufferYCbCrMatrix_DCI_P3) = CFSTR("DCI_P3");
const CFStringRef BACKPORT_IMPL(kCVImageBufferYCbCrMatrix_ITU_R_2020) = CFSTR("ITU_R_2020");
const CFStringRef BACKPORT_IMPL(kCVImageBufferYCbCrMatrix_P3_D65) = CFSTR("P3_D65");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferOpenGLESTextureCacheCompatibilityKey) = CFSTR("OpenGLESTextureCacheCompatibility");
const CFStringRef BACKPORT_IMPL(kCVPixelFormatComponentRange) = CFSTR("ComponentRange");
const CFStringRef BACKPORT_IMPL(kCVPixelFormatComponentRange_FullRange) = CFSTR("FullRange");
const CFStringRef BACKPORT_IMPL(kCVPixelFormatComponentRange_VideoRange) = CFSTR("VideoRange");
const CFStringRef BACKPORT_IMPL(kCVPixelFormatComponentRange_WideRange) = CFSTR("WideRange");
